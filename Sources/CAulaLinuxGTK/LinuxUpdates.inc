#include "LinuxPackageInstaller.inc"
extern void aula_updates_command(int action);
extern void aula_updates_read(int field, char *buffer, int capacity);
typedef struct {
    GtkWidget *status, *checked, *detail, *download, *notes, *check, *banner, *banner_label;
    GtkWidget *channel, *automatic, *restart, *progress, *banner_download;
    AulaLinuxUI *host;
    gboolean syncing;
} UpdatesUI;
static const char *update_read(int field) {
    static char buffers[15][2048];
    aula_updates_read(field,buffers[field],sizeof(buffers[field]));
    return buffers[field];
}
static void update_open(GtkButton *button,gpointer data) {
    const char *url=update_read(GPOINTER_TO_INT(data));
    if (*url) g_app_info_launch_default_for_uri(url,NULL,NULL);
}
static void update_install(GtkButton *button,gpointer data) { aula_updates_command(6); }
static void update_restart(GtkButton *button,gpointer data) {
    UpdatesUI *u=data;
    if(u->host->busy) return;
    const char *path=update_read(12);
    char *argv[]={(char *)path,NULL}; GError *error=NULL;
    if(g_spawn_async(NULL,argv,NULL,G_SPAWN_DEFAULT,NULL,NULL,NULL,&error)) g_application_quit(G_APPLICATION(u->host->app));
    g_clear_error(&error);
}
static void update_check(GtkButton *button,gpointer data) { aula_updates_command(5); }
static void update_dismiss(GtkButton *button,gpointer data) { aula_updates_command(4); }
static void update_channel(GtkComboBox *combo,gpointer data) {
    UpdatesUI *u=data;
    if (!u->syncing) aula_updates_command(gtk_combo_box_get_active(combo)==0 ? 1 : 2);
}
static void update_automatic(GtkSwitch *widget,GParamSpec *spec,gpointer data) {
    UpdatesUI *u=data;
    if (!u->syncing) aula_updates_command(3);
}
static gboolean update_tick(gpointer data) {
    UpdatesUI *u=data;
    aula_updates_command(0);
    u->syncing=TRUE;
    gtk_combo_box_set_active(GTK_COMBO_BOX(u->channel),strcmp(update_read(1),"alpha")==0 ? 1 : 0);
    gtk_switch_set_active(GTK_SWITCH(u->automatic),strcmp(update_read(2),"1")==0);
    u->syncing=FALSE;
    gtk_label_set_text(GTK_LABEL(u->status),update_read(3));
    gtk_label_set_text(GTK_LABEL(u->checked),update_read(6));
    gtk_widget_set_visible(u->status,*update_read(3)!=0);
    gtk_widget_set_visible(u->checked,*update_read(6)!=0);
    gtk_label_set_text(GTK_LABEL(u->detail),update_read(9));
    gtk_label_set_text(GTK_LABEL(u->banner_label),update_read(3));
    gtk_widget_set_visible(u->download,*update_read(4)!=0 && strcmp(update_read(11),"1")!=0);
    gtk_widget_set_visible(u->notes,*update_read(5)!=0);
    gtk_widget_set_visible(u->banner,strcmp(update_read(7),"1")==0);
    gtk_widget_set_sensitive(u->check,strcmp(update_read(8),"1")!=0);
    gboolean installing=strcmp(update_read(13),"1")==0;
    gtk_widget_set_sensitive(u->download,!installing && strcmp(update_read(11),"1")!=0);
    gtk_widget_set_visible(u->progress,installing);
    double fraction=g_ascii_strtod(update_read(14),NULL);
    if(fraction>=0) gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(u->progress),fraction);
    else if(installing) gtk_progress_bar_pulse(GTK_PROGRESS_BAR(u->progress));
    gtk_widget_set_sensitive(u->channel,!installing);
    gtk_widget_set_sensitive(u->automatic,!installing);
    gtk_widget_set_sensitive(u->banner_download,!installing);
    gtk_widget_set_visible(u->banner_download,strcmp(update_read(11),"1")!=0);
    gtk_widget_set_visible(u->restart,strcmp(update_read(11),"1")==0);
    gtk_widget_set_sensitive(u->restart,!u->host->busy);
    const char *pending=update_read(10);
    if(*pending && !u->host->busy) {
        char *file=g_strdup(pending);
        aula_updates_command(7); start_package_install(file); g_free(file);
    }
    return G_SOURCE_CONTINUE;
}
static void update_destroy(gpointer data) { g_free(data); }
static void update_remove_timer(gpointer data) { g_source_remove(GPOINTER_TO_UINT(data)); }
static void create_updates(GtkWidget *page,GtkWidget *home,AulaLinuxUI *host) {
    UpdatesUI *u=g_new0(UpdatesUI,1); u->host=host;
    GtkWidget *box=NULL,*panel=make_panel("Updates","Current version","software-update-available-symbolic",&box);
    gtk_box_append(GTK_BOX(page),panel);
    gtk_box_append(GTK_BOX(box),label_new(update_read(0),"muted"));
    u->channel=gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(u->channel),"Stable");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(u->channel),"Alpha");
    gtk_box_append(GTK_BOX(box),setting_row("Update channel",u->channel));
    u->detail=label_new("","muted"); gtk_label_set_wrap(GTK_LABEL(u->detail),TRUE); gtk_box_append(GTK_BOX(box),u->detail);
    u->automatic=gtk_switch_new(); gtk_box_append(GTK_BOX(box),setting_row("Automatically check for updates",u->automatic));
    u->status=label_new("","value"); gtk_label_set_wrap(GTK_LABEL(u->status),TRUE); gtk_box_append(GTK_BOX(box),u->status);
    u->progress=gtk_progress_bar_new(); gtk_box_append(GTK_BOX(box),u->progress);
    u->checked=label_new("","muted"); gtk_box_append(GTK_BOX(box),u->checked);
    GtkWidget *actions=hbox_new(10); gtk_box_append(GTK_BOX(box),actions);
    u->check=make_button("Check now","view-refresh-symbolic"); g_signal_connect(u->check,"clicked",G_CALLBACK(update_check),u); gtk_box_append(GTK_BOX(actions),u->check);
    u->download=make_button("Update…","folder-download-symbolic"); add_class(u->download,"suggested-action"); g_signal_connect(u->download,"clicked",G_CALLBACK(update_install),u); gtk_box_append(GTK_BOX(actions),u->download);
    u->restart=make_button("Restart now","system-reboot-symbolic"); add_class(u->restart,"suggested-action"); g_signal_connect(u->restart,"clicked",G_CALLBACK(update_restart),u); gtk_box_append(GTK_BOX(actions),u->restart);
    u->notes=make_button("What’s new","help-about-symbolic"); g_signal_connect(u->notes,"clicked",G_CALLBACK(update_open),GINT_TO_POINTER(5)); gtk_box_append(GTK_BOX(actions),u->notes);
    u->banner=hbox_new(12); add_class(u->banner,"update-banner");
    gtk_widget_set_margin_start(u->banner,28); gtk_widget_set_margin_end(u->banner,28);
    gtk_widget_set_margin_top(u->banner,12); gtk_widget_set_margin_bottom(u->banner,4);
    u->banner_label=label_new("","value"); gtk_label_set_wrap(GTK_LABEL(u->banner_label),TRUE); gtk_widget_set_hexpand(u->banner_label,TRUE); gtk_box_append(GTK_BOX(u->banner),u->banner_label);
    GtkWidget *download=make_button("Update…","folder-download-symbolic"); u->banner_download=download; gtk_widget_set_hexpand(download,FALSE); g_signal_connect(download,"clicked",G_CALLBACK(update_install),u); gtk_box_append(GTK_BOX(u->banner),download);
    GtkWidget *dismiss=make_button("Dismiss","window-close-symbolic"); gtk_widget_set_hexpand(dismiss,FALSE); g_signal_connect(dismiss,"clicked",G_CALLBACK(update_dismiss),u); gtk_box_append(GTK_BOX(u->banner),dismiss);
    gtk_box_prepend(GTK_BOX(home),u->banner);
    g_signal_connect(u->channel,"changed",G_CALLBACK(update_channel),u);
    g_signal_connect(u->automatic,"notify::active",G_CALLBACK(update_automatic),u);
    update_tick(u);
    guint timer=g_timeout_add_seconds_full(G_PRIORITY_DEFAULT,1,update_tick,u,update_destroy);
    g_object_set_data_full(G_OBJECT(panel),"updates-timer",GUINT_TO_POINTER(timer),update_remove_timer);
}
