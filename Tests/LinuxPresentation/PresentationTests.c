/* Integration test against real GTK widgets and Swift previews; HID is mocked.
 * Run with scripts/linux-ui-test.sh. No keyboard commands reach hardware. */
#include "../../Sources/CAulaLinuxGTK/AulaLinuxGTK.c"
#include <assert.h>

static int mock_install_result=-2;
void aula_updates_install_finished(int success) { mock_install_result=success; }
void aula_updates_command(int action) { (void)action; }
static int mock_update_mode;
void aula_updates_read(int field,char *b,int n) {
    const char *value="";
    switch(field) {
        case 0: value="0.1.0+test"; break;
        case 1: value=mock_update_mode ? "alpha" : "stable"; break;
        case 2: value="0"; break;
        case 3: value=mock_update_mode==1 ? "Update available: v0.2.0-rc1 · Pre-release" : mock_update_mode==2 ? "Downloading update… 50%" : mock_update_mode==3 ? "Update installed. Restart the app." : "You’re up to date"; break;
        case 4: if(mock_update_mode) value="https://github.com/VitalyArt/Aula-F75-Max-Driver/releases/download/v0.2.0-rc1/app.deb"; break;
        case 5: if(mock_update_mode) value="https://github.com/VitalyArt/Aula-F75-Max-Driver/releases/tag/v0.2.0-rc1"; break;
        case 6: value="Last checked: Today, 12:00"; break;
        case 7: value=mock_update_mode ? "1" : "0"; break;
        case 8: case 13: value=mock_update_mode==2 ? "1" : "0"; break;
        case 9: value=mock_update_mode ? "Stable and preview releases, including beta and RC. May be unstable." : "Stable releases only."; break;
        case 11: value=mock_update_mode==3 ? "1" : "0"; break;
        case 14: value=mock_update_mode==2 ? "0.5" : "-1"; break;
    }
    g_strlcpy(b,value,n);
}

static int mock_wired, mock_dongle, sent_rgb;
static gboolean fail_rgb;
static const unsigned char *expected_upload;
static int expected_length;
void aula_linux_refresh(char *b,int n) { g_strlcpy(b,"Mock HID endpoints",n); }
void aula_linux_query_battery(char *b,int n) { g_strlcpy(b,"Battery: 80%.",n); }
void aula_linux_sync_time(char *b,int n) { g_strlcpy(b,"Clock synced",n); }
void aula_linux_factory_reset(char *b,int n) { g_strlcpy(b,"Reset",n); }
void aula_linux_upload_display(char *b,int n,const unsigned char *bytes,int length,int slot,void *context) {
    assert(slot==1); assert(length==expected_length); assert(!memcmp(bytes,expected_upload,length));
    aula_linux_report_upload_progress(context,1,2); g_usleep(20000); aula_linux_report_upload_progress(context,2,2);
    g_strlcpy(b,"Uploaded",n);
}
void aula_linux_endpoint_counts(int *w,int *d) { *w=mock_wired; *d=mock_dongle; }
void aula_linux_apply_rgb(char *b,int n,int m,int br,int s,int d,int c,int color) {
    (void)m;(void)br;(void)s;(void)d;(void)c;(void)color; sent_rgb++;
    g_strlcpy(b,fail_rgb ? "Error: simulated disconnect" : "Applied",n);
}
void aula_linux_apply_performance(char *b,int n,int l,int s) { (void)l;(void)s;g_strlcpy(b,"Applied",n); }
void aula_linux_restore_command(char *b,int n,int l,int s) { (void)l;(void)s;g_strlcpy(b,"Restored",n); }
void aula_linux_set_game_mode(char *b,int n,int e,int l,int s) { (void)e;(void)l;(void)s;g_strlcpy(b,"Game",n); }
void aula_linux_configure_language(const char *code,char *b,int n) { g_strlcpy(b,code,n); }
void aula_linux_current_language_code(char *b,int n) { g_strlcpy(b,"en",n); }
void aula_linux_localized_string(const char *key,char *b,int n) { g_strlcpy(b,key,n); }

static void pump(int milliseconds) {
    gint64 until=g_get_monotonic_time()+milliseconds*1000;
    do { while(g_main_context_iteration(NULL,FALSE)); g_usleep(1000); } while(g_get_monotonic_time()<until);
}
static void wait_command(AulaLinuxUI *ui) {
    gint64 deadline=g_get_monotonic_time()+5*G_USEC_PER_SEC;
    while(ui->busy && g_get_monotonic_time()<deadline) pump(10);
    assert(!ui->busy);
}
static void wait_preview(AulaLinuxUI *ui) {
    gint64 deadline=g_get_monotonic_time()+5*G_USEC_PER_SEC;
    while(!ui->display_bytes && g_get_monotonic_time()<deadline) pump(10);
    assert(ui->display_bytes && ui->display_frames->len);
}
static void choose_page(AulaLinuxUI *ui,int index) {
    gtk_list_box_select_row(ui->navigation,gtk_list_box_get_row_at_index(ui->navigation,index>=5 ? index+1 : index));
}
static void record_animation(AulaLinuxUI *ui,const char *name) {
    (void)ui;
    char *path=g_build_filename(g_getenv("AULA_TEST_OUTPUT"),name,NULL);
    GError *error=NULL;
    GSubprocess *record=g_subprocess_new(G_SUBPROCESS_FLAGS_STDOUT_SILENCE|G_SUBPROCESS_FLAGS_STDERR_SILENCE,&error,
        "ffmpeg","-loglevel","error","-f","x11grab","-video_size","1100x840","-framerate","20","-i",g_getenv("DISPLAY"),"-t","2","-y",path,NULL);
    assert(record); pump(2300); assert(g_subprocess_wait_check(record,NULL,&error));
    g_object_unref(record);g_free(path);
}
static void screenshot(AulaLinuxUI *ui,const char *name) {
    pump(250);
    GtkWidget *widget=GTK_WIDGET(ui->window);
    GdkPaintable *paintable=gtk_widget_paintable_new(widget);
    gtk_widget_queue_draw(widget); pump(100);
    GtkSnapshot *snapshot=gtk_snapshot_new();
    int width=gtk_widget_get_width(widget),height=gtk_widget_get_height(widget);
    gdk_paintable_snapshot(paintable,GDK_SNAPSHOT(snapshot),width,height);
    GskRenderNode *node=gtk_snapshot_free_to_node(snapshot); assert(node);
    GskRenderer *renderer=gtk_native_get_renderer(GTK_NATIVE(widget));
    GdkTexture *texture=gsk_renderer_render_texture(renderer,node,NULL);
    char *path=g_build_filename(g_getenv("AULA_TEST_OUTPUT"),name,NULL);
    assert(gdk_texture_save_to_png(texture,path));
    g_free(path);g_object_unref(texture);gsk_render_node_unref(node);g_object_unref(paintable);
}
int main(int argc,char **argv) {
    // PackageKit completion must distinguish success, failure and an earlier ErrorCode.
    AulaPackageInstall *install=g_new0(AulaPackageInstall,1); install->refs=1;
    GVariant *finished=g_variant_ref_sink(g_variant_new("(uu)",1,0));
    package_signal(NULL,NULL,NULL,NULL,"Finished",finished,install);
    assert(mock_install_result==1 && install->finished); package_unref(install);
    install=g_new0(AulaPackageInstall,1); install->refs=1; install->failed=TRUE;
    package_signal(NULL,NULL,NULL,NULL,"Finished",finished,install);
    assert(mock_install_result==0 && install->finished); package_unref(install); g_variant_unref(finished);

    assert(argc==3); gtk_init();
    GtkApplication *app=gtk_application_new("test.aula.preview",G_APPLICATION_NON_UNIQUE);
    GError *error=NULL; assert(g_application_register(G_APPLICATION(app),NULL,&error));
    activate(app,NULL); GtkWindow *window=gtk_application_get_active_window(app); assert(window);
    AulaLinuxUI *ui=g_object_get_data(G_OBJECT(window),"aula-ui");
    pump(150); assert(preview_key_count==80); assert(ui->profile_count==3);
    assert(!gtk_widget_get_sensitive(ui->apply_rgb_button));
    GtkFlowBoxChild *tile=gtk_flow_box_get_child_at_index(GTK_FLOW_BOX(ui->effect_flow),19);
    g_signal_emit_by_name(gtk_flow_box_child_get_child(GTK_FLOW_BOX_CHILD(tile)),"clicked");
    assert(current_lighting(ui).mode==19 && sent_rgb==0);
    select_profile(ui,0); assert(sent_rgb==0); assert(current_lighting(ui).brightness==4);
    mock_dongle=1; refresh_status(ui); fail_rgb=TRUE; start_command(ui,4); wait_command(ui);
    assert(!ui->has_applied); fail_rgb=FALSE; start_command(ui,4); wait_command(ui);
    assert(ui->has_applied && ui->applied.brightness==4);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(ui->rgb_brightness),1);
    assert(gtk_widget_get_visible(ui->preview_badge)); assert(ui->applied.brightness==4);
    revert_lighting(NULL,ui); assert(current_lighting(ui).brightness==4);
    // Profile CRUD persists, including an intentionally empty collection.
    int v[6]; state_values(current_lighting(ui),v); char name[512]={0};
    assert(aula_profiles(1,-1,"Test profile",v,name,sizeof(name))==4);
    assert(aula_profiles(3,3,"Renamed profile",v,name,sizeof(name))==4);
    assert(aula_profiles(0,3,NULL,v,name,sizeof(name))==4); assert(!strcmp(name,"Renamed profile"));
    assert(aula_profiles(4,3,NULL,v,name,sizeof(name))==3);
    // Preview uses the same RGB565 bytes that upload receives, in every fit mode.
    g_free(ui->selected_image_path); ui->selected_image_path=g_strdup(argv[1]);
    for(int fit=0;fit<3;fit++) {
        gtk_combo_box_set_active(GTK_COMBO_BOX(ui->fit_mode),fit); prepare_screen(ui); wait_preview(ui);
        const unsigned char *bytes=g_bytes_get_data(ui->display_bytes,NULL);
        GdkPixbuf *decoded=decode_frame(bytes,0),*shown=g_ptr_array_index(ui->display_frames,0);
        assert(gdk_pixbuf_get_byte_length(decoded)==gdk_pixbuf_get_byte_length(shown));
        assert(!memcmp(gdk_pixbuf_get_pixels(decoded),gdk_pixbuf_get_pixels(shown),gdk_pixbuf_get_byte_length(decoded)));
        g_object_unref(decoded);
    }
    // Two overlapping jobs: only the last selected file wins.
    prepare_screen(ui); g_free(ui->selected_image_path); ui->selected_image_path=g_strdup(argv[2]); prepare_screen(ui); wait_preview(ui);
    gtk_label_set_text(GTK_LABEL(ui->selected_image_label),"animated.gif");
    assert(ui->display_frames->len==2); const unsigned char *bytes=g_bytes_get_data(ui->display_bytes,NULL);
    assert(bytes[1]==50 && bytes[2]==100); // 100ms and 200ms, in 1/500s units.
    gtk_stack_set_visible_child_name(ui->stack,"screen"); pump(150); assert(ui->current_frame==1);
    g_object_set(gtk_settings_get_default(),"gtk-enable-animations",FALSE,NULL); pump(60); assert(ui->current_frame==0);
    g_object_set(gtk_settings_get_default(),"gtk-enable-animations",TRUE,NULL);
    mock_wired=1; refresh_status(ui); gsize length; expected_upload=g_bytes_get_data(ui->display_bytes,&length); expected_length=(int)length;
    start_command(ui,1); wait_command(ui); assert(gtk_progress_bar_get_fraction(GTK_PROGRESS_BAR(ui->upload_progress))==1);
    const char *pages[]={"home","lighting","screen","performance","settings","diagnostics","log"};
    for(int i=0;i<7;i++) {
        choose_page(ui,i);
        char name[64]; snprintf(name,sizeof(name),"%s.png",pages[i]); screenshot(ui,name);
    }
    choose_page(ui,4);
    const char *update_shots[]={"updates-available.png","updates-downloading.png","updates-installed.png"};
    for(mock_update_mode=1;mock_update_mode<=3;mock_update_mode++) { pump(1100); screenshot(ui,update_shots[mock_update_mode-1]); }
    mock_update_mode=0; pump(1100);
    choose_page(ui,1); record_animation(ui,"lighting.mp4");
    GtkScrolledWindow *lighting_scroll=GTK_SCROLLED_WINDOW(gtk_stack_get_visible_child(ui->stack));
    GtkAdjustment *adjustment=gtk_scrolled_window_get_vadjustment(lighting_scroll);
    gtk_adjustment_set_value(adjustment,gtk_adjustment_get_upper(adjustment)-gtk_adjustment_get_page_size(adjustment));
    screenshot(ui,"lighting-controls.png"); gtk_adjustment_set_value(adjustment,0);
    choose_page(ui,2); record_animation(ui,"screen-gif.mp4");
    choose_page(ui,1); gtk_window_set_default_size(window,820,560); screenshot(ui,"lighting-narrow.png");
    g_object_set(gtk_settings_get_default(),"gtk-application-prefer-dark-theme",TRUE,NULL); screenshot(ui,"lighting-dark.png");
    for(int i=2;i>=0;i--) assert(aula_profiles(4,i,NULL,v,name,sizeof(name))==i);
    assert(aula_profiles(0,-1,NULL,v,name,sizeof(name))==0);
    // Closing while preparation is running must not touch destroyed widgets.
    g_object_ref(window);
    prepare_screen(ui); start_command(ui,4); gtk_window_close(window); wait_command(ui);
    pump(200); g_object_unref(window); g_object_unref(app);
    puts("GTK integration: effects, profiles, failure/revert, RGB565, GIF, progress, lifecycle passed");
    return 0;
}
