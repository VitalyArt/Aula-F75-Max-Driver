/* Offline reference; included after LinuxPresentation.inc for shared cap drawing. */
#include "KeyboardGuideCatalog.inc"

static void guide_draw_key(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer data) {
    (void)area;
    const char *label = data;
    gboolean knob = strcmp(label, "Knob") == 0;
    if (knob) {
        cairo_pattern_t *pattern = cairo_pattern_create_radial(15, 12, 0, 24, 24, 28);
        cairo_pattern_add_color_stop_rgb(pattern, 0, .42, .42, .42);
        cairo_pattern_add_color_stop_rgb(pattern, 1, .12, .12, .12);
        cairo_arc(cr, width/2., height/2., 23, 0, 2*G_PI);
        cairo_set_source(cr, pattern); cairo_fill(cr); cairo_pattern_destroy(pattern);
        cairo_set_source_rgba(cr, 1, 1, 1, .6); cairo_set_line_width(cr, 2);
        cairo_move_to(cr, width/2., 9); cairo_line_to(cr, width/2., 17); cairo_stroke(cr);
        return;
    }
    paint_keycap(cr, 0, 0, width, height, 48, TRUE, 0);
    PangoLayout *layout = pango_cairo_create_layout(cr);
    PangoFontDescription *font = pango_font_description_from_string("Monospace Semi-Bold 11");
    pango_layout_set_font_description(layout, font);
    pango_layout_set_text(layout, label, -1);
    int w, h; pango_layout_get_pixel_size(layout, &w, &h);
    cairo_set_source_rgb(cr, .18, .18, .18);
    cairo_move_to(cr, (width-w)/2., (height-h)/2.-3);
    pango_cairo_show_layout(cr, layout);
    pango_font_description_free(font); g_object_unref(layout);
}

static GtkWidget *guide_keycap(const char *key) {
    GtkWidget *cap = gtk_drawing_area_new();
    gtk_drawing_area_set_content_width(GTK_DRAWING_AREA(cap), strcmp(key, "Knob") == 0 ? 48 : MAX(48, (int)g_utf8_strlen(key, -1)*10+22));
    gtk_drawing_area_set_content_height(GTK_DRAWING_AREA(cap), 48);
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(cap), guide_draw_key, (gpointer)key, NULL);
    gtk_widget_set_valign(cap, GTK_ALIGN_CENTER);
    gtk_accessible_update_property(GTK_ACCESSIBLE(cap), GTK_ACCESSIBLE_PROPERTY_LABEL,
        strcmp(key, "Knob") == 0 ? L("guide.knob") : key, -1);
    return cap;
}

static GtkWidget *guide_row(const GuideEntry *entry) {
    GtkWidget *row = vbox_new(8), *keys = hbox_new(8);
    gtk_box_append(GTK_BOX(keys), guide_keycap(entry->first));
    if (entry->second) {
        gtk_box_append(GTK_BOX(keys), label_new("+", "muted"));
        gtk_box_append(GTK_BOX(keys), guide_keycap(entry->second));
    }
    gtk_box_append(GTK_BOX(row), keys);
    const char *action_text = g_str_has_prefix(entry->action, "guide.") ? L(entry->action) : entry->action;
    GtkWidget *action_label = gtk_label_new(action_text);
    gtk_label_set_xalign(GTK_LABEL(action_label), 0);
    gtk_label_set_wrap(GTK_LABEL(action_label), TRUE);
    gtk_box_append(GTK_BOX(row), action_label);
    if (entry->hold) {
        GtkWidget *hold_label = label_new("guide.hold", "muted");
        gtk_accessible_update_state(GTK_ACCESSIBLE(hold_label), GTK_ACCESSIBLE_STATE_HIDDEN, TRUE, -1);
        gtk_box_append(GTK_BOX(row), hold_label);
    }
    // The row is one announcement, rather than unrelated painted keys and labels.
    char *first = g_strdup(L(entry->first));
    char *second = g_strdup(entry->second && strcmp(entry->second, "Knob") == 0 ? L("guide.knob") : (entry->second ? entry->second : ""));
    char *action = g_strdup(g_str_has_prefix(entry->action, "guide.") ? L(entry->action) : entry->action);
    char *spoken = g_strdup_printf("%s%s%s: %s%s%s", first, entry->second ? " + " : "", second, action,
        entry->hold ? ". " : "", entry->hold ? L("guide.hold") : "");
    gtk_accessible_update_state(GTK_ACCESSIBLE(keys), GTK_ACCESSIBLE_STATE_HIDDEN, TRUE, -1);
    gtk_accessible_update_property(GTK_ACCESSIBLE(action_label), GTK_ACCESSIBLE_PROPERTY_LABEL, spoken, -1);
    g_free(first); g_free(second); g_free(action); g_free(spoken);
    return row;
}

static void guide_rebuild(GtkDropDown *picker, GParamSpec *spec, gpointer data) {
    (void)spec;
    GtkWidget *content = data;
    GtkWidget *child;
    while ((child = gtk_widget_get_first_child(content))) gtk_box_remove(GTK_BOX(content), child);
    const char *mode = gtk_drop_down_get_selected(picker) == 1 ? "mac" : "windows";
    for (guint i = 0; i < G_N_ELEMENTS(guide_groups); i++) {
        const GuideGroup *group = &guide_groups[i];
        GtkWidget *body = NULL;
        GtkWidget *panel = make_panel(group->title, "", i == 5 ? "dialog-warning-symbolic" : "input-keyboard-symbolic", &body);
        gtk_box_append(GTK_BOX(body), label_new(group->note, i == 5 ? "warning-box" : "muted"));
        gboolean has_row = FALSE;
        for (int j = 0; j < group->count; j++) {
            const GuideEntry *entry = &group->entries[j];
            if (strcmp(entry->mode, "all") && strcmp(entry->mode, mode)) continue;
            if (has_row) gtk_box_append(GTK_BOX(body), gtk_separator_new(GTK_ORIENTATION_HORIZONTAL));
            gtk_box_append(GTK_BOX(body), guide_row(entry));
            has_row = TRUE;
        }
        gtk_box_append(GTK_BOX(content), panel);
    }
    GtkWidget *link = gtk_link_button_new_with_label(GUIDE_MANUAL_URL, L("guide.manual"));
    gtk_widget_set_halign(link, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(content), link);
}

static void create_keyboard_guide(GtkWidget *page) {
    gtk_box_append(GTK_BOX(page), label_new("guide.intro", "panel-title"));
    GtkWidget *body = NULL;
    GtkWidget *panel = make_panel("guide.mode", "", "input-keyboard-symbolic", &body);
    const char *modes[] = {"Windows", "Mac", NULL};
    GtkWidget *picker = gtk_drop_down_new_from_strings(modes);
    gtk_widget_set_halign(picker, GTK_ALIGN_START);
    gtk_accessible_update_property(GTK_ACCESSIBLE(picker), GTK_ACCESSIBLE_PROPERTY_LABEL, L("guide.mode"), -1);
    gtk_box_append(GTK_BOX(body), picker);
    gtk_box_append(GTK_BOX(body), label_new("guide.mode_note", "muted"));
    gtk_box_append(GTK_BOX(page), panel);
    GtkWidget *content = vbox_new(16);
    gtk_box_append(GTK_BOX(page), content);
    g_signal_connect(picker, "notify::selected", G_CALLBACK(guide_rebuild), content);
    guide_rebuild(GTK_DROP_DOWN(picker), NULL, content);
}
