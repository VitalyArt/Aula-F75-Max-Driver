/* GTK presentation helpers. Included after transport callbacks so all GTK state
 * stays on the main thread; workers receive immutable command snapshots. */
extern void aula_preview_color(int, int, int, int, int, int, double, double, double, double *);
extern int aula_preview_key(int, double *, char *);
extern int aula_profiles(int, int, const char *, int *, char *, int);

typedef struct { double x, y, w, h, light, row; char label[32]; } PreviewKey;
static PreviewKey preview_keys[96];
static int preview_key_count;

typedef struct {
    AulaLinuxUI *ui;
    int kind; /* 0 home, 1 editing, 2 screen */
    cairo_surface_t *caps, *base;
    cairo_surface_t *halos[16];
    double halo_widths[16];
    int halo_count;
    int width, height;
} KeyboardStage;

typedef struct { AulaLinuxUI *ui; int mode; } EffectSample;

static LightingState current_lighting(AulaLinuxUI *ui) {
    return (LightingState){ selected_index(ui->rgb_mode, 11),
        gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(ui->rgb_brightness)),
        gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(ui->rgb_speed)),
        selected_index(ui->rgb_direction, 0), gtk_switch_get_active(GTK_SWITCH(ui->rgb_colorful)), selected_color(ui->rgb_color) };
}

static gboolean lighting_equal(LightingState a, LightingState b) {
    return a.mode == b.mode && a.brightness == b.brightness && a.speed == b.speed &&
        a.direction == b.direction && a.colorful == b.colorful && a.color == b.color;
}

static LightingState stage_lighting(KeyboardStage *stage) {
    if (stage->kind == 1) return current_lighting(stage->ui);
    if (stage->ui->has_applied) return stage->ui->applied;
    return (LightingState){7, 2, 2, 0, 0, 0xffffff};
}

static void effect_color(LightingState s, double x, double y, double time, double *rgb) {
    aula_preview_color(s.mode, s.brightness, s.speed, s.direction, s.colorful, s.color, x, y, time, rgb);
}

static void rounded(cairo_t *cr, double x, double y, double w, double h, double r) {
    cairo_new_sub_path(cr);
    cairo_arc(cr, x+w-r, y+r, r, -G_PI/2, 0);
    cairo_arc(cr, x+w-r, y+h-r, r, 0, G_PI/2);
    cairo_arc(cr, x+r, y+h-r, r, G_PI/2, G_PI);
    cairo_arc(cr, x+r, y+r, r, G_PI, 3*G_PI/2);
    cairo_close_path(cr);
}

static void gradient_fill(cairo_t *cr, double y, double height, double top, double bottom) {
    cairo_pattern_t *pattern = cairo_pattern_create_linear(0, y, 0, y+height);
    cairo_pattern_add_color_stop_rgb(pattern, 0, top, top, top);
    cairo_pattern_add_color_stop_rgb(pattern, 1, bottom, bottom, bottom);
    cairo_set_source(cr, pattern);
    cairo_fill(cr);
    cairo_pattern_destroy(pattern);
}

static void stage_transform(cairo_t *cr, int width, int height) {
    double unit = fmin((width-32.)/17.1, (height-24.)/7.4);
    cairo_translate(cr, (width-unit*17.1)/2, (height-unit*7.4)/2);
    cairo_scale(cr, unit, unit);
}

static void paint_case(cairo_t *cr) {
    for (int i=14; i>0; i--) {
        cairo_set_source_rgba(cr, 0, 0, 0, 0.018);
        rounded(cr, -i*.025, .15-i*.014, 17.1+i*.05, 7.4+i*.028, .5);
        cairo_fill(cr);
    }
    rounded(cr, 0, 0, 17.1, 7.4, .45);
    gradient_fill(cr, 0, 7.4, .16, .07);
    rounded(cr, 0, 0, 17.1, 7.4, .45);
    cairo_set_source_rgba(cr, 1, 1, 1, .12);
    cairo_set_line_width(cr, .04); cairo_stroke(cr);
    rounded(cr, .22, .22, 16.66, 6.96, .28);
    cairo_set_source_rgb(cr, .035, .035, .035); cairo_fill(cr);
}

static void paint_caps(cairo_t *cr, gboolean legends) {
    for (int i=0; i<preview_key_count; i++) {
        PreviewKey k=preview_keys[i];
        double x=k.x+.55+.075, y=k.y+.5+.075, w=k.w-.15, h=k.h-.15;
        double lift=k.row==3 ? .08 : 0;
        rounded(cr,x,y,w,h,.13);
        gradient_fill(cr,y,h,k.light ? .66 : .13+lift,k.light ? .5 : .07+lift);
        rounded(cr,x+.09,y+.05,w-.18,h-.2,.1);
        gradient_fill(cr,y+.05,h-.2,k.light ? .86 : .24+lift,k.light ? .74 : .17+lift);
        if (legends && k.label[0]) {
            cairo_set_source_rgb(cr,k.light ? .25 : .62,k.light ? .25 : .62,k.light ? .25 : .62);
            // Lay out legends in device pixels: subpixel key units otherwise
            // round to zero in Pango's font metrics.
            cairo_matrix_t matrix; cairo_get_matrix(cr,&matrix);
            double px=x+.17, py=y+.43; cairo_user_to_device(cr,&px,&py);
            cairo_save(cr); cairo_identity_matrix(cr);
            PangoLayout *layout=pango_cairo_create_layout(cr);
            PangoFontDescription *font=pango_font_description_from_string("Sans Medium");
            pango_font_description_set_absolute_size(font,.2*matrix.xx*PANGO_SCALE);
            pango_layout_set_font_description(layout,font);
            pango_layout_set_text(layout,k.label,-1);
            cairo_move_to(cr,px,py); pango_cairo_show_layout(cr,layout);
            pango_font_description_free(font); g_object_unref(layout); cairo_restore(cr);
        }
    }
    // Screen bezel and the brushed metal knob use the macOS layout coordinates.
    rounded(cr,14.5,.55,1.1,.9,.08);
    cairo_set_source_rgb(cr,.02,.02,.02); cairo_fill(cr);
    cairo_pattern_t *knob=cairo_pattern_create_radial(15.98,.85,.03,16.1,1,.42);
    cairo_pattern_add_color_stop_rgb(knob,0,.42,.42,.42);
    cairo_pattern_add_color_stop_rgb(knob,1,.12,.13,.15);
    cairo_arc(cr,16.1,1,.42,0,2*G_PI); cairo_set_source(cr,knob); cairo_fill(cr);
    cairo_pattern_destroy(knob);
    cairo_set_source_rgba(cr,0,0,0,.35); cairo_set_line_width(cr,.015);
    for(int i=0;i<36;i++) {
        double angle=i/36.*2*G_PI;
        cairo_move_to(cr,16.1+cos(angle)*.42*.84,1+sin(angle)*.42*.84);
        cairo_line_to(cr,16.1+cos(angle)*.42*.97,1+sin(angle)*.42*.97);
    }
    cairo_stroke(cr);
    cairo_arc(cr,16.1,1,.36,0,2*G_PI); cairo_set_source_rgba(cr,1,1,1,.22);
    cairo_set_line_width(cr,.02); cairo_stroke(cr);
}

static void draw_keyboard(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer data) {
    (void)area;
    KeyboardStage *stage=data;
    if (!stage->ui->rgb_mode) return;
    LightingState settings=stage_lighting(stage);
    gboolean animations=TRUE;
    g_object_get(gtk_settings_get_default(),"gtk-enable-animations",&animations,NULL);
    double time=animations ? (g_get_monotonic_time()-stage->ui->animation_start)/1e6 : 1.7;
    double unit=fmin((width-32.)/17.1,(height-24.)/7.4);
    if(!stage->caps || stage->width!=width || stage->height!=height) {
        if(stage->caps) cairo_surface_destroy(stage->caps);
        if(stage->base) cairo_surface_destroy(stage->base);
        for(int i=0;i<stage->halo_count;i++) cairo_surface_destroy(stage->halos[i]);
        stage->halo_count=0;
        stage->base=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,width,height);
        stage->caps=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,width,height);
        stage->width=width; stage->height=height;
        cairo_t *cache=cairo_create(stage->base); stage_transform(cache,width,height); paint_case(cache); cairo_destroy(cache);
        cache=cairo_create(stage->caps); stage_transform(cache,width,height); paint_caps(cache,unit>=24); cairo_destroy(cache);
    }
    cairo_set_source_surface(cr,stage->base,0,0); cairo_paint(cr);
    cairo_save(cr); stage_transform(cr,width,height);
    double colors[96][3];
    for(int i=0;i<preview_key_count;i++) {
        PreviewKey k=preview_keys[i];
        effect_color(settings,(k.x+k.w/2)/16.,(k.y+k.h/2)/6.4,time,colors[i]);
        int sprite=0;
        while(sprite<stage->halo_count && stage->halo_widths[sprite]!=k.w) sprite++;
        if(sprite==stage->halo_count && sprite<16) {
            stage->halo_widths[sprite]=k.w;
            cairo_surface_t *mask=cairo_image_surface_create(CAIRO_FORMAT_A8,(int)ceil((k.w+.6)*unit),(int)ceil(1.6*unit));
            cairo_t *halo=cairo_create(mask); cairo_scale(halo,unit,unit);
            for(int j=7;j>=0;j--) {
                rounded(halo,.3-.025*j,.3-.025*j,k.w+.05*j,1+.05*j,.14+.025*j);
                cairo_set_source_rgba(halo,1,1,1,.055); cairo_fill(halo);
            }
            cairo_destroy(halo); stage->halos[sprite]=mask; stage->halo_count++;
        }
        if(sprite<stage->halo_count) {
            double x=k.x+.55-.3, y=k.y+.5-.3; cairo_user_to_device(cr,&x,&y);
            cairo_save(cr); cairo_identity_matrix(cr);
            cairo_set_source_rgb(cr,colors[i][0],colors[i][1],colors[i][2]);
            cairo_mask_surface(cr,stage->halos[sprite],x,y); cairo_restore(cr);
        }
    }
    cairo_restore(cr);
    cairo_set_source_surface(cr,stage->caps,0,0); cairo_paint(cr);
    cairo_save(cr); stage_transform(cr,width,height);
    for(int i=0;i<preview_key_count;i++) {
        PreviewKey k=preview_keys[i];
        rounded(cr,k.x+.625,k.y+.575,k.w-.15,k.h-.15,.13);
        cairo_set_source_rgba(cr,colors[i][0],colors[i][1],colors[i][2],.45);
        cairo_set_line_width(cr,.03); cairo_stroke(cr);
        cairo_set_source_rgba(cr,colors[i][0],colors[i][1],colors[i][2],.95);
        if(k.w==6.25) {
            rounded(cr,k.x+.55+k.w/2-.45,k.y+.5+k.h-.24,.9,.05,.025); cairo_fill(cr);
        } else if(!strcmp(k.label,"Caps")) {
            cairo_arc(cr,k.x+.55-.3,k.y+.5+k.h/2,.06,0,2*G_PI); cairo_fill(cr);
        }
    }
    if(stage->kind==2 && stage->ui->display_frames && stage->ui->display_frames->len) {
        GdkPixbuf *frame=g_ptr_array_index(stage->ui->display_frames,stage->ui->current_frame);
        cairo_save(cr);
        rounded(cr,14.56,.61,.98,.78,.04); cairo_clip(cr);
        cairo_translate(cr,14.56,.61); cairo_scale(cr,.98/128,.78/128);
        gdk_cairo_set_source_pixbuf(cr,frame,0,0);
        cairo_pattern_set_filter(cairo_get_source(cr),CAIRO_FILTER_NEAREST); cairo_paint(cr); cairo_restore(cr);
    } else {
        rounded(cr,14.56,.61,.98,.78,.04);
        cairo_set_source_rgb(cr,.04,.06,.12); cairo_fill(cr);
        GDateTime *now=g_date_time_new_now_local(); char *clock=g_date_time_format(now,"%H:%M");
        cairo_set_source_rgba(cr,1,1,1,.9); cairo_set_font_size(cr,.24);
        cairo_move_to(cr,14.7,1.09); cairo_show_text(cr,clock);
        g_free(clock); g_date_time_unref(now);
    }
    cairo_restore(cr);
}

static void free_stage(gpointer data) {
    KeyboardStage *s=data;
    if(s->caps) cairo_surface_destroy(s->caps);
    if(s->base) cairo_surface_destroy(s->base);
    for(int i=0;i<s->halo_count;i++) cairo_surface_destroy(s->halos[i]);
    g_free(s);
}

static GtkWidget *keyboard_stage(AulaLinuxUI *ui, int kind, int height) {
    if(!preview_key_count) {
        double geometry[6]; char label[32]={0};
        while(preview_key_count<96 && aula_preview_key(preview_key_count,geometry,label)) {
            PreviewKey *k=&preview_keys[preview_key_count++];
            k->x=geometry[0]; k->y=geometry[1]; k->w=geometry[2]; k->h=geometry[3];
            k->light=geometry[4]; k->row=geometry[5]; g_strlcpy(k->label,label,sizeof(k->label));
        }
    }
    GtkWidget *area=gtk_drawing_area_new();
    gtk_drawing_area_set_content_height(GTK_DRAWING_AREA(area),height);
    KeyboardStage *stage=g_new0(KeyboardStage,1); stage->ui=ui; stage->kind=kind;
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(area),draw_keyboard,stage,free_stage);
    add_class(area,"keyboard-stage");
    gtk_widget_set_tooltip_text(area,L("Aula F75 Max keyboard preview"));
    return area;
}

static void draw_swatch(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer data) {
    (void)area;
    EffectSample *sample=data;
    LightingState settings=current_lighting(sample->ui); settings.mode=sample->mode; settings.brightness=5;
    rounded(cr,0,0,width,height,8); cairo_clip(cr);
    cairo_set_source_rgb(cr,.06,.06,.06); cairo_paint(cr);
    for(int x=0;x<12;x++) {
        double rgb[3]={0};
        for(int y=0;y<3;y++) {
            double c[3]; effect_color(settings,(x+.5)/12.,.25+y*.25,1.7,c);
            for(int i=0;i<3;i++) rgb[i]=fmax(rgb[i],c[i]);
        }
        cairo_set_source_rgb(cr,rgb[0],rgb[1],rgb[2]);
        cairo_rectangle(cr,x*width/12.,0,width/12.+.5,height); cairo_fill(cr);
    }
}

static void effect_selected(GtkButton *button, gpointer data) {
    AulaLinuxUI *ui=data;
    gtk_combo_box_set_active(GTK_COMBO_BOX(ui->rgb_mode),GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button),"mode")));
}

static void update_lighting_preview(AulaLinuxUI *ui) {
    if(!ui->rgb_mode || ui->loading_controls) return;
    LightingState current=current_lighting(ui);
    gboolean dirty=!ui->has_applied || !lighting_equal(current,ui->applied);
    gtk_widget_set_visible(ui->preview_badge,dirty);
    gtk_widget_set_sensitive(ui->revert_button,ui->has_applied && dirty && !ui->busy);
    gtk_widget_set_sensitive(ui->rgb_color,!current.colorful && !ui->busy);
    for(GtkWidget *child=gtk_widget_get_first_child(ui->effect_flow);child;child=gtk_widget_get_next_sibling(child)) {
        GtkWidget *button=gtk_flow_box_child_get_child(GTK_FLOW_BOX_CHILD(child));
        int mode=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button),"mode"));
        if(mode==current.mode) add_class(button,"selected-effect");
        else gtk_widget_remove_css_class(button,"selected-effect");
        gtk_widget_queue_draw(button);
    }
    gtk_widget_queue_draw(ui->lighting_stage);
    if(ui->profile_update) gtk_widget_set_sensitive(ui->profile_update,ui->selected_profile>=0 && !ui->busy);
}

static void lighting_changed(GtkWidget *widget, gpointer data) { (void)widget; update_lighting_preview(data); }
static void colorful_changed(GObject *object, GParamSpec *pspec, gpointer data) { (void)object; (void)pspec; update_lighting_preview(data); }

static void load_lighting(AulaLinuxUI *ui, LightingState s) {
    ui->loading_controls=TRUE;
    gtk_combo_box_set_active(GTK_COMBO_BOX(ui->rgb_mode),s.mode);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(ui->rgb_brightness),s.brightness);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(ui->rgb_speed),s.speed);
    gtk_combo_box_set_active(GTK_COMBO_BOX(ui->rgb_direction),s.direction);
    gtk_switch_set_active(GTK_SWITCH(ui->rgb_colorful),s.colorful);
    GdkRGBA c={((s.color>>16)&255)/255.,((s.color>>8)&255)/255.,(s.color&255)/255.,1};
    gtk_color_chooser_set_rgba(GTK_COLOR_CHOOSER(ui->rgb_color),&c);
    ui->loading_controls=FALSE; update_lighting_preview(ui);
}

static void revert_lighting(GtkButton *button, gpointer data) {
    (void)button; AulaLinuxUI *ui=data; if(ui->has_applied) load_lighting(ui,ui->applied);
}

typedef struct { AulaLinuxUI *ui; int kind, index; GtkWidget *entry; } ProfileAction;

static void state_values(LightingState s, int *v) {
    v[0]=s.mode; v[1]=s.brightness; v[2]=s.speed; v[3]=s.direction; v[4]=s.colorful; v[5]=s.color;
}
static LightingState values_state(int *v) { return (LightingState){v[0],v[1],v[2],v[3],v[4],v[5]}; }
static void refresh_profiles(AulaLinuxUI *ui);

static void select_profile(AulaLinuxUI *ui, int index) {
    int v[6]={0}; char name[512]={0};
    if(aula_profiles(0,index,NULL,v,name,sizeof(name))<0) { append_log(ui,name); return; }
    ui->selected_profile=index; ui->selected_profile_settings=values_state(v); ui->has_profile_settings=TRUE;
    load_lighting(ui,ui->selected_profile_settings); refresh_profiles(ui);
    if(ui->dongle_count>0 && !ui->busy) start_command(ui,4);
}

static void profile_confirmation_done(GObject *object, GAsyncResult *result, gpointer data) {
    ProfileAction *a=data; GError *error=NULL;
    int answer=gtk_alert_dialog_choose_finish(GTK_ALERT_DIALOG(object),result,&error);
    if(answer==1 && !a->ui->closed && !a->ui->busy) {
        if(a->kind==4) {
            int v[6]={0}; char message[512]={0};
            if(aula_profiles(4,a->index,NULL,v,message,sizeof(message))<0) append_log(a->ui,message);
            else { a->ui->selected_profile=-1; a->ui->has_profile_settings=FALSE; refresh_profiles(a->ui); }
        } else select_profile(a->ui,a->index);
    }
    g_clear_error(&error); g_object_unref(a->ui->window); g_free(a);
}

static void confirm_profile(AulaLinuxUI *ui, int kind, int index) {
    ProfileAction *a=g_new0(ProfileAction,1); a->ui=ui; a->kind=kind; a->index=index;
    GtkAlertDialog *dialog=gtk_alert_dialog_new("%s",L(kind==4 ? "Delete this profile?" : "Discard your unsaved lighting changes?"));
    const char *buttons[]={L("Cancel"),L(kind==4 ? "Delete" : "Discard and Switch"),NULL};
    gtk_alert_dialog_set_buttons(dialog,buttons); gtk_alert_dialog_set_cancel_button(dialog,0);
    gtk_alert_dialog_set_default_button(dialog,0); g_object_ref(ui->window);
    gtk_alert_dialog_choose(dialog,ui->window,NULL,profile_confirmation_done,a); g_object_unref(dialog);
}

static void profile_clicked(GtkButton *button, gpointer data) {
    AulaLinuxUI *ui=data; if(ui->busy) return;
    int index=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button),"profile-index"));
    LightingState current=current_lighting(ui);
    gboolean saved=ui->has_profile_settings && lighting_equal(current,ui->selected_profile_settings);
    gboolean applied=ui->has_applied && lighting_equal(current,ui->applied);
    gboolean untouched=!ui->has_profile_settings && !ui->has_applied && lighting_equal(current,ui->launch);
    if(!saved && !applied && !untouched) confirm_profile(ui,0,index);
    else select_profile(ui,index);
}

static void draw_profile_swatch(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer data) {
    (void)area; LightingState *s=data;
    for(int x=0;x<12;x++) {
        double c[3]={0};
        for(int y=0;y<3;y++) {
            double rgb[3]; effect_color(*s,(x+.5)/12.,.25+y*.25,1.7,rgb);
            for(int j=0;j<3;j++) c[j]=fmax(c[j],rgb[j]);
        }
        cairo_set_source_rgb(cr,c[0],c[1],c[2]);
        cairo_rectangle(cr,x*width/12.,0,width/12.+1,height); cairo_fill(cr);
    }
}

static void refresh_profiles(AulaLinuxUI *ui) {
    GtkWidget *flows[]={ui->profiles_flow,ui->home_profiles};
    int values[6]={0}; char name[512]={0};
    int count=aula_profiles(0,-1,NULL,values,name,sizeof(name));
    if(count<0) { append_log(ui,name); count=0; }
    ui->profile_count=count;
    for(int f=0;f<2;f++) {
        GtkWidget *flow=flows[f];
        while(gtk_widget_get_first_child(flow)) gtk_flow_box_remove(GTK_FLOW_BOX(flow),gtk_widget_get_first_child(flow));
        for(int i=0;i<count;i++) {
            if(aula_profiles(0,i,NULL,values,name,sizeof(name))<0) break;
            GtkWidget *button=gtk_button_new(); GtkWidget *box=hbox_new(8);
            LightingState *state=g_new(LightingState,1); *state=values_state(values);
            GtkWidget *swatch=gtk_drawing_area_new(); gtk_widget_set_size_request(swatch,34,22);
            gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(swatch),draw_profile_swatch,state,g_free);
            GtkWidget *title=label_new(name,NULL); gtk_label_set_wrap(GTK_LABEL(title),FALSE);
            gtk_label_set_ellipsize(GTK_LABEL(title),PANGO_ELLIPSIZE_END);
            gtk_box_append(GTK_BOX(box),swatch); gtk_box_append(GTK_BOX(box),title);
            gtk_button_set_child(GTK_BUTTON(button),box);
            g_object_set_data(G_OBJECT(button),"profile-index",GINT_TO_POINTER(i));
            g_signal_connect(button,"clicked",G_CALLBACK(profile_clicked),ui);
            if(i==ui->selected_profile) add_class(button,"selected-effect");
            gtk_widget_set_sensitive(button,!ui->busy);
            gtk_flow_box_insert(GTK_FLOW_BOX(flow),button,-1);
        }
        if(count==0) gtk_flow_box_insert(GTK_FLOW_BOX(flow),label_new("No saved profiles yet. Set up a look you like and save it.","muted"),-1);
    }
    gtk_widget_set_sensitive(ui->profile_update,ui->selected_profile>=0 && !ui->busy);
    gtk_widget_set_sensitive(ui->profile_rename,ui->selected_profile>=0 && !ui->busy);
    gtk_widget_set_sensitive(ui->profile_delete,ui->selected_profile>=0 && !ui->busy);
}

static void profile_name_response(GtkDialog *dialog, int response, gpointer data) {
    ProfileAction *a=data;
    if(response==GTK_RESPONSE_ACCEPT && !a->ui->closed && !a->ui->busy) {
        int v[6]; state_values(current_lighting(a->ui),v); char result[512]={0};
        const char *name=gtk_editable_get_text(GTK_EDITABLE(a->entry));
        int count=aula_profiles(a->kind,a->index,name,v,result,sizeof(result));
        if(count<0) append_log(a->ui,result);
        else {
            if(a->kind==1) { a->ui->selected_profile=count-1; a->ui->selected_profile_settings=current_lighting(a->ui); a->ui->has_profile_settings=TRUE; }
            refresh_profiles(a->ui);
        }
    }
    gtk_window_destroy(GTK_WINDOW(dialog)); g_object_unref(a->ui->window); g_free(a);
}
static void profile_name_changed(GtkEditable *entry, gpointer data) {
    char *name=g_strdup(gtk_editable_get_text(entry)); g_strstrip(name);
    gtk_dialog_set_response_sensitive(GTK_DIALOG(data),GTK_RESPONSE_ACCEPT,name[0]!=0); g_free(name);
}
static void profile_name_dialog(GtkButton *button, gpointer data) {
    AulaLinuxUI *ui=data; if(ui->busy) return;
    int kind=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button),"profile-action"));
    ProfileAction *a=g_new0(ProfileAction,1); a->ui=ui; a->kind=kind; a->index=ui->selected_profile;
    GtkWidget *dialog=gtk_dialog_new_with_buttons(L(kind==1 ? "Save as New Profile" : "Rename Profile"),ui->window,GTK_DIALOG_MODAL,
        L("Cancel"),GTK_RESPONSE_CANCEL,L("Save"),GTK_RESPONSE_ACCEPT,NULL);
    a->entry=gtk_entry_new(); gtk_widget_set_margin_start(a->entry,20); gtk_widget_set_margin_end(a->entry,20);
    gtk_widget_set_margin_top(a->entry,16); gtk_widget_set_margin_bottom(a->entry,16);
    gtk_widget_set_size_request(a->entry,300,-1); gtk_entry_set_max_length(GTK_ENTRY(a->entry),100);
    gtk_entry_set_activates_default(GTK_ENTRY(a->entry),TRUE);
    gtk_dialog_set_default_response(GTK_DIALOG(dialog),GTK_RESPONSE_ACCEPT);
    if(kind==3) { int v[6]={0}; char name[512]={0}; aula_profiles(0,ui->selected_profile,NULL,v,name,sizeof(name)); gtk_editable_set_text(GTK_EDITABLE(a->entry),name); }
    gtk_box_append(GTK_BOX(gtk_dialog_get_content_area(GTK_DIALOG(dialog))),a->entry);
    g_signal_connect(a->entry,"changed",G_CALLBACK(profile_name_changed),dialog);
    profile_name_changed(GTK_EDITABLE(a->entry),dialog);
    g_object_ref(ui->window); g_signal_connect(dialog,"response",G_CALLBACK(profile_name_response),a);
    gtk_window_present(GTK_WINDOW(dialog));
}
static void profile_update_clicked(GtkButton *button, gpointer data) {
    (void)button; AulaLinuxUI *ui=data; if(ui->busy || ui->selected_profile<0) return;
    int v[6]; state_values(current_lighting(ui),v); char message[512]={0};
    if(aula_profiles(2,ui->selected_profile,NULL,v,message,sizeof(message))<0) append_log(ui,message);
    else { ui->selected_profile_settings=current_lighting(ui); ui->has_profile_settings=TRUE; refresh_profiles(ui); }
}
static void profile_delete_clicked(GtkButton *button, gpointer data) {
    (void)button; AulaLinuxUI *ui=data; if(!ui->busy && ui->selected_profile>=0) confirm_profile(ui,4,ui->selected_profile);
}

typedef struct { char *path; int fit; guint generation; GBytes *bytes; GPtrArray *frames; char error[512]; } ScreenJob;
static void screen_job_free(gpointer data) {
    ScreenJob *job=data; g_free(job->path); g_clear_pointer(&job->bytes,g_bytes_unref);
    g_clear_pointer(&job->frames,g_ptr_array_unref); g_free(job);
}
static GdkPixbuf *decode_frame(const unsigned char *stream, int index) {
    GdkPixbuf *image=gdk_pixbuf_new(GDK_COLORSPACE_RGB,FALSE,8,128,128);
    unsigned char *pixels=gdk_pixbuf_get_pixels(image); int stride=gdk_pixbuf_get_rowstride(image);
    const unsigned char *source=stream+256+index*128*128*2;
    for(int y=0;y<128;y++) for(int x=0;x<128;x++) {
        int i=(y*128+x)*2; unsigned int v=source[i]|(source[i+1]<<8);
        unsigned char *p=pixels+y*stride+x*3;
        unsigned int r=(v>>11)&31,g=(v>>5)&63,b=v&31;
        p[0]=(r<<3)|(r>>2); p[1]=(g<<2)|(g>>4); p[2]=(b<<3)|(b>>2);
    }
    return image;
}
static void screen_worker(GTask *task, gpointer source, gpointer data, GCancellable *cancel) {
    (void)source; (void)cancel; ScreenJob *job=data;
    unsigned char *stream=NULL; int length=0;
    if(encode_display_image(job->path,job->fit,&stream,&length,job->error,sizeof(job->error))) {
        job->bytes=g_bytes_new_take(stream,length);
        job->frames=g_ptr_array_new_with_free_func(g_object_unref);
        for(int i=0;i<stream[0];i++) g_ptr_array_add(job->frames,decode_frame(stream,i));
    }
    g_task_return_boolean(task,job->bytes!=NULL);
}
static void set_screen_frame(AulaLinuxUI *ui, int index) {
    if(!ui->display_frames || !ui->display_frames->len) return;
    ui->current_frame=index;
    GdkTexture *texture=gdk_texture_new_for_pixbuf(g_ptr_array_index(ui->display_frames,index));
    gtk_picture_set_paintable(GTK_PICTURE(ui->screen_preview),GDK_PAINTABLE(texture)); g_object_unref(texture);
    char text[96]; snprintf(text,sizeof(text),"%d / %u",index+1,ui->display_frames->len);
    gtk_label_set_text(GTK_LABEL(ui->frame_label),ui->display_frames->len>1 ? text : L("Still image"));
    int i=0;
    for(GtkWidget *child=gtk_widget_get_first_child(ui->frame_strip);child;child=gtk_widget_get_next_sibling(child),i++) {
        GtkWidget *button=gtk_flow_box_child_get_child(GTK_FLOW_BOX_CHILD(child));
        if(i==index) add_class(button,"selected-effect"); else gtk_widget_remove_css_class(button,"selected-effect");
    }
    gtk_widget_queue_draw(ui->screen_stage);
}
static void thumbnail_clicked(GtkButton *button, gpointer data) {
    AulaLinuxUI *ui=data;
    int index=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button),"frame-index"));
    if(!ui->display_frames || (guint)index>=ui->display_frames->len) return;
    const unsigned char *bytes=g_bytes_get_data(ui->display_bytes,NULL);
    double elapsed=0; for(int i=0;i<index;i++) elapsed+=bytes[i+1]/500.;
    ui->animation_start=g_get_monotonic_time()-(gint64)(elapsed*1e6); set_screen_frame(ui,index);
}
static void screen_ready(GObject *object, GAsyncResult *result, gpointer data) {
    (void)object; AulaLinuxUI *ui=data;
    ScreenJob *job=g_task_get_task_data(G_TASK(result));
    if(ui->closed || job->generation!=ui->preview_generation) return;
    gboolean success=g_task_propagate_boolean(G_TASK(result),NULL);
    if(!success) { gtk_label_set_text(GTK_LABEL(ui->frame_label),L("Failed to encode image.")); append_log(ui,job->error); return; }
    g_clear_pointer(&ui->display_bytes,g_bytes_unref); g_clear_pointer(&ui->display_frames,g_ptr_array_unref);
    ui->display_bytes=g_bytes_ref(job->bytes); ui->display_frames=g_ptr_array_ref(job->frames);
    while(gtk_widget_get_first_child(ui->frame_strip)) gtk_flow_box_remove(GTK_FLOW_BOX(ui->frame_strip),gtk_widget_get_first_child(ui->frame_strip));
    // The strip is scrollable, so all encoded frames remain available.
    for(guint i=0;i<ui->display_frames->len;i++) {
        GtkWidget *button=gtk_button_new(); GtkWidget *picture=gtk_picture_new();
        GdkTexture *texture=gdk_texture_new_for_pixbuf(g_ptr_array_index(ui->display_frames,i));
        gtk_picture_set_paintable(GTK_PICTURE(picture),GDK_PAINTABLE(texture)); g_object_unref(texture);
        gtk_widget_set_size_request(picture,36,36); gtk_picture_set_can_shrink(GTK_PICTURE(picture),TRUE);
        gtk_button_set_child(GTK_BUTTON(button),picture);
        g_object_set_data(G_OBJECT(button),"frame-index",GINT_TO_POINTER(i));
        g_signal_connect(button,"clicked",G_CALLBACK(thumbnail_clicked),ui);
        gtk_flow_box_insert(GTK_FLOW_BOX(ui->frame_strip),button,-1);
    }
    gtk_widget_set_visible(ui->frame_strip,ui->display_frames->len>1);
    gtk_widget_set_visible(g_object_get_data(G_OBJECT(ui->frame_strip),"scroller"),ui->display_frames->len>1);
    ui->animation_start=g_get_monotonic_time(); set_screen_frame(ui,0); update_status_widgets(ui);
}
static void prepare_screen(AulaLinuxUI *ui) {
    if(!ui->selected_image_path) return;
    g_clear_pointer(&ui->display_bytes,g_bytes_unref); g_clear_pointer(&ui->display_frames,g_ptr_array_unref);
    gtk_picture_set_paintable(GTK_PICTURE(ui->screen_preview),NULL);
    gtk_label_set_text(GTK_LABEL(ui->frame_label),L("Preparing preview…"));
    gtk_widget_set_visible(ui->frame_strip,FALSE);
    gtk_widget_set_visible(g_object_get_data(G_OBJECT(ui->frame_strip),"scroller"),FALSE); ui->current_frame=0;
    gtk_widget_queue_draw(ui->screen_stage); gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(ui->upload_progress),0);
    ScreenJob *job=g_new0(ScreenJob,1); job->path=g_strdup(ui->selected_image_path);
    job->fit=selected_index(ui->fit_mode,0); job->generation=++ui->preview_generation;
    GTask *task=g_task_new(ui->window,NULL,screen_ready,ui);
    g_task_set_task_data(task,job,screen_job_free); g_task_run_in_thread(task,screen_worker); g_object_unref(task);
    update_status_widgets(ui);
}
static void fit_changed(GtkComboBox *combo, gpointer data) { (void)combo; prepare_screen(data); }
static gboolean image_dropped(GtkDropTarget *target, const GValue *value, double x, double y, gpointer data) {
    (void)target; (void)x; (void)y; AulaLinuxUI *ui=data; if(ui->busy) return FALSE;
    GFile *file=g_value_get_object(value); char *path=g_file_get_path(file); if(!path) return FALSE;
    g_free(ui->selected_image_path); ui->selected_image_path=path;
    char *name=g_path_get_basename(path); gtk_label_set_text(GTK_LABEL(ui->selected_image_label),name); g_free(name);
    prepare_screen(ui); return TRUE;
}

static gboolean animate_previews(gpointer data) {
    AulaLinuxUI *ui=data;
    if(ui->closed) { ui->animation_timer=0; return G_SOURCE_REMOVE; }
    if(!gtk_widget_get_mapped(GTK_WIDGET(ui->window))) return G_SOURCE_CONTINUE;
    GdkSurface *surface=gtk_native_get_surface(GTK_NATIVE(ui->window));
    if(GDK_IS_TOPLEVEL(surface) && (gdk_toplevel_get_state(GDK_TOPLEVEL(surface))&GDK_TOPLEVEL_STATE_MINIMIZED)) return G_SOURCE_CONTINUE;
    gboolean animations=TRUE; g_object_get(gtk_settings_get_default(),"gtk-enable-animations",&animations,NULL);
    const char *page=gtk_stack_get_visible_child_name(ui->stack);
    if(!animations) {
        if(ui->current_frame) set_screen_frame(ui,0);
        if(g_get_monotonic_time()-ui->last_clock_redraw < 60*G_USEC_PER_SEC) return G_SOURCE_CONTINUE;
        ui->last_clock_redraw=g_get_monotonic_time();
    }
    if(!g_strcmp0(page,"home")) gtk_widget_queue_draw(ui->home_stage);
    else if(!g_strcmp0(page,"lighting")) gtk_widget_queue_draw(ui->lighting_stage);
    else if(!g_strcmp0(page,"screen")) {
        if(ui->display_bytes && ui->display_frames && ui->display_frames->len>1) {
            const unsigned char *bytes=g_bytes_get_data(ui->display_bytes,NULL);
            double duration=0; for(guint i=0;i<ui->display_frames->len;i++) duration+=fmax(bytes[i+1]/500.,.002);
            double time=animations ? fmod((g_get_monotonic_time()-ui->animation_start)/1e6,duration) : 0;
            int index=0;
            while((guint)index+1<ui->display_frames->len && time>=fmax(bytes[index+1]/500.,.002)) { time-=fmax(bytes[index+1]/500.,.002); index++; }
            if(index!=ui->current_frame) set_screen_frame(ui,index);
        }
        gtk_widget_queue_draw(ui->screen_stage);
    }
    return G_SOURCE_CONTINUE;
}

typedef struct { GtkWindow *window; int sent, total; } UploadProgress;
static gboolean upload_progress_idle(gpointer data) {
    UploadProgress *p=data;
    AulaLinuxUI *ui=g_object_get_data(G_OBJECT(p->window),"aula-ui");
    if(ui && !ui->closed && p->total>0) {
        gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(ui->upload_progress),(double)p->sent/p->total);
        char text[64]; snprintf(text,sizeof(text),"%d / %d",p->sent,p->total);
        gtk_progress_bar_set_text(GTK_PROGRESS_BAR(ui->upload_progress),text);
    }
    g_object_unref(p->window); g_free(p); return G_SOURCE_REMOVE;
}
void aula_linux_report_upload_progress(void *context, int sent, int total) {
    if(!context) return;
    UploadProgress *p=g_new(UploadProgress,1); p->window=g_object_ref(context); p->sent=sent; p->total=total;
    g_idle_add(upload_progress_idle,p);
}

typedef struct {
    int kind, level, sleep, slot; gboolean game_enabled;
    LightingState lighting; GBytes *bytes; char result[8192];
    GtkWindow *window;
} CommandJob;
static void command_free(gpointer data) { CommandJob *job=data; g_clear_pointer(&job->bytes,g_bytes_unref); g_free(job); }
static void command_worker(GTask *task, gpointer source, gpointer data, GCancellable *cancel) {
    (void)source; (void)cancel; CommandJob *job=data;
    char *out=job->result; int size=sizeof(job->result); LightingState s=job->lighting;
    switch(job->kind) {
        case 1: {
            gsize length; const unsigned char *bytes=g_bytes_get_data(job->bytes,&length);
            aula_linux_upload_display(out,size,bytes,(int)length,job->slot,job->window); break;
        }
        case 2: aula_linux_sync_time(out,size); break;
        case 3: aula_linux_factory_reset(out,size); break;
        case 4: aula_linux_apply_rgb(out,size,s.mode,s.brightness,s.speed,s.direction,s.colorful,s.color); break;
        case 5: aula_linux_apply_performance(out,size,job->level,job->sleep); break;
        case 6: aula_linux_restore_command(out,size,job->level,job->sleep); break;
        case 7: aula_linux_set_game_mode(out,size,job->game_enabled,job->level,job->sleep); break;
        case 8: aula_linux_query_battery(out,size); break;
    }
    g_task_return_boolean(task,!g_str_has_prefix(out,"Error:"));
}
static void command_ready(GObject *object, GAsyncResult *result, gpointer data) {
    (void)object; AulaLinuxUI *ui=data; CommandJob *job=g_task_get_task_data(G_TASK(result));
    if(ui->closed) {
        ui->busy=FALSE;
        g_application_release(G_APPLICATION(ui->app));
        return;
    }
    gboolean success=g_task_propagate_boolean(G_TASK(result),NULL);
    ui->busy=FALSE;
    if(success && job->kind==4) { ui->applied=job->lighting; ui->has_applied=TRUE; }
    if(success && job->kind==3) { ui->has_applied=FALSE; }
    if(success && job->kind==7) {
        ui->game_mode_enabled=job->game_enabled;
        gtk_button_set_label(GTK_BUTTON(ui->game_mode_button),L(ui->game_mode_enabled ? "Disable Game Mode" : "Enable Game Mode"));
    }
    if(job->kind==8) {
        int percent=-1;
        if(success && sscanf(job->result,"%*[^0-9]%d%%",&percent)==1 && percent>=0 && percent<=100) {
            ui->battery_percent=percent; char text[16]; snprintf(text,sizeof(text),"%d%%",percent);
            gtk_label_set_text(GTK_LABEL(ui->battery_value),text);
        }
        ui->last_battery_query_usec=g_get_monotonic_time();
    }
    append_log(ui,job->result[0] ? job->result : L("No output."));
    for(int i=0;i<7;i++) if(ui->controls[i]) gtk_widget_set_sensitive(ui->controls[i],TRUE);
    gtk_widget_set_sensitive(ui->language_combo,TRUE);
    if(job->kind==1) gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(ui->upload_progress),success ? 1 : 0);
    refresh_status(ui); update_lighting_preview(ui); refresh_profiles(ui);
    g_application_release(G_APPLICATION(ui->app));
}
static void start_command(AulaLinuxUI *ui, int kind) {
    if(ui->busy || ui->closed) return;
    if((kind<=3 && ui->wired_count<=0) || (kind>=4 && ui->dongle_count<=0)) return;
    if(kind==1 && !ui->display_bytes) return;
    CommandJob *job=g_new0(CommandJob,1); job->kind=kind; job->window=ui->window;
    job->lighting=current_lighting(ui); job->level=current_response_level(ui); job->sleep=current_sleep_time(ui);
    job->game_enabled=!ui->game_mode_enabled;
    if(kind==1) { job->bytes=g_bytes_ref(ui->display_bytes); job->slot=gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(ui->display_slot)); }
    ui->busy=TRUE; update_status_widgets(ui);
    gtk_label_set_text(GTK_LABEL(ui->status_message),L("Working…"));
    for(int i=0;i<7;i++) if(ui->controls[i]) gtk_widget_set_sensitive(ui->controls[i],FALSE);
    gtk_widget_set_sensitive(ui->language_combo,FALSE);
    update_lighting_preview(ui); refresh_profiles(ui);
    g_application_hold(G_APPLICATION(ui->app));
    GTask *task=g_task_new(ui->window,NULL,command_ready,ui);
    g_task_set_task_data(task,job,command_free); g_task_run_in_thread(task,command_worker); g_object_unref(task);
}
static void reset_confirmed(GObject *object, GAsyncResult *result, gpointer data) {
    AulaLinuxUI *ui=data; GError *error=NULL;
    int answer=gtk_alert_dialog_choose_finish(GTK_ALERT_DIALOG(object),result,&error);
    if(answer==1 && !ui->closed) on_factory_reset_clicked(NULL,ui);
    g_clear_error(&error); g_object_unref(ui->window);
}
static void confirm_reset(GtkButton *button, gpointer data) {
    (void)button; AulaLinuxUI *ui=data;
    GtkAlertDialog *dialog=gtk_alert_dialog_new("%s",L("Factory Reset Keyboard…"));
    gtk_alert_dialog_set_detail(dialog,L("Clears uploaded screen images and resets keyboard settings changed by this app."));
    const char *buttons[]={L("Cancel"),L("Factory Reset Keyboard"),NULL};
    gtk_alert_dialog_set_buttons(dialog,buttons); gtk_alert_dialog_set_cancel_button(dialog,0);
    g_object_ref(ui->window); gtk_alert_dialog_choose(dialog,ui->window,NULL,reset_confirmed,ui); g_object_unref(dialog);
}
static gboolean window_closing(GtkWindow *window, gpointer data) {
    (void)window; AulaLinuxUI *ui=data; ui->closed=TRUE; return FALSE;
}
static void copy_log(GtkButton *button, gpointer data) {
    (void)button; AulaLinuxUI *ui=data; GtkTextIter start,end;
    gtk_text_buffer_get_bounds(ui->log_buffer,&start,&end);
    char *text=gtk_text_buffer_get_text(ui->log_buffer,&start,&end,FALSE);
    gdk_clipboard_set_text(gtk_widget_get_clipboard(GTK_WIDGET(ui->window)),text); g_free(text);
}

typedef struct { GtkWidget *control; int kind, value; } SegmentAction;
static int segment_value(GtkWidget *control, int kind) {
    if(kind==0) return gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(control));
    if(kind==1) return gtk_combo_box_get_active(GTK_COMBO_BOX(control));
    return gtk_switch_get_active(GTK_SWITCH(control));
}
static void segment_clicked(GtkToggleButton *button, gpointer data) {
    SegmentAction *a=data; if(!gtk_toggle_button_get_active(button)) return;
    if(a->kind==0) gtk_spin_button_set_value(GTK_SPIN_BUTTON(a->control),a->value);
    else if(a->kind==1) gtk_combo_box_set_active(GTK_COMBO_BOX(a->control),a->value);
    else gtk_switch_set_active(GTK_SWITCH(a->control),a->value);
}
static void sync_segments(GtkWidget *control, gpointer data) {
    GtkWidget *box=data; int kind=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(box),"kind"));
    int value=segment_value(control,kind);
    for(GtkWidget *child=gtk_widget_get_first_child(box);child;child=gtk_widget_get_next_sibling(child)) {
        if(!GTK_IS_TOGGLE_BUTTON(child)) continue;
        int v=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(child),"value"));
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(child),v==value);
    }
}
static void sync_switch_segments(GObject *object, GParamSpec *pspec, gpointer data) {
    (void)pspec; sync_segments(GTK_WIDGET(object),data);
}
static void free_segment_action(gpointer data, GClosure *closure) { (void)closure; g_free(data); }
static GtkWidget *segments(GtkWidget *control, int kind, const char **labels, int count, int first) {
    GtkWidget *box=hbox_new(0); add_class(box,"linked"); add_class(box,"segments");
    g_object_set_data(G_OBJECT(box),"kind",GINT_TO_POINTER(kind));
    gtk_widget_set_visible(control,FALSE); gtk_box_append(GTK_BOX(box),control);
    GtkToggleButton *group=NULL;
    for(int i=0;i<count;i++) {
        GtkWidget *button=gtk_toggle_button_new_with_label(L(labels[i]));
        gtk_widget_set_hexpand(button,TRUE);
        if(group) gtk_toggle_button_set_group(GTK_TOGGLE_BUTTON(button),group); else group=GTK_TOGGLE_BUTTON(button);
        g_object_set_data(G_OBJECT(button),"value",GINT_TO_POINTER(i+first));
        SegmentAction *action=g_new(SegmentAction,1); *action=(SegmentAction){control,kind,i+first};
        g_signal_connect_data(button,"toggled",G_CALLBACK(segment_clicked),action,free_segment_action,0);
        gtk_box_append(GTK_BOX(box),button);
    }
    if(kind==2) g_signal_connect(control,"notify::active",G_CALLBACK(sync_switch_segments),box);
    else g_signal_connect(control,kind==0?"value-changed":"changed",G_CALLBACK(sync_segments),box);
    sync_segments(control,box); return box;
}
static gboolean page_shortcuts(GtkEventControllerKey *controller, guint key, guint code, GdkModifierType modifiers, gpointer data) {
    (void)controller; (void)code;
    if(!(modifiers&GDK_CONTROL_MASK)) return FALSE;
    GtkListBox *navigation=data;
    if(key>=GDK_KEY_1 && key<=GDK_KEY_7) {
        int index=key-GDK_KEY_1; if(index>=5) index++;
        gtk_list_box_select_row(navigation,gtk_list_box_get_row_at_index(navigation,index)); return TRUE;
    }
    return FALSE;
}
