#include "CAulaLinuxGTK.h"

#include <gtk/gtk.h>
#include <gio/gio.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>

#ifdef __clang__
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif

extern void aula_linux_refresh(char *buffer, int capacity);
extern void aula_linux_query_battery(char *buffer, int capacity);
extern void aula_linux_sync_time(char *buffer, int capacity);
extern void aula_linux_factory_reset(char *buffer, int capacity);
extern void aula_linux_upload_display(char *buffer, int capacity, const unsigned char *bytes, int length, int slot, void *context);
extern void aula_linux_endpoint_counts(int *wired, int *dongle);
extern void aula_linux_apply_rgb(char *buffer, int capacity, int mode, int brightness, int speed, int direction, int colorful, int color);
extern void aula_linux_apply_performance(char *buffer, int capacity, int level, int sleep_time);
extern void aula_linux_restore_command(char *buffer, int capacity, int level, int sleep_time);
extern void aula_linux_set_game_mode(char *buffer, int capacity, int enabled, int level, int sleep_time);
extern void aula_linux_configure_language(const char *language_code, char *buffer, int capacity);
extern void aula_linux_current_language_code(char *buffer, int capacity);
extern void aula_linux_localized_string(const char *key, char *buffer, int capacity);

#define AULA_LINUX_LANGUAGE_SCHEMA_ID "vitalyart.aula-f75-max-driver"
#define AULA_LINUX_LANGUAGE_KEY "language-code"
#define AULA_LINUX_LANGUAGE_DEFAULT "system"
#define AULA_LINUX_LANGUAGE_DIRECTORY "aula-f75-max-driver"
static void writeCString(const char *message, char *buffer, int capacity) {
    if (buffer == NULL || capacity <= 0) {
        return;
    }

    if (message == NULL) {
        message = "";
    }

    size_t limit = (size_t)capacity > 0 ? (size_t)capacity - 1 : 0;
    size_t length = strlen(message);
    if (length > limit) {
        length = limit;
    }

    memcpy(buffer, message, length);
    buffer[length] = '\0';
}

#define AULA_LINUX_LANGUAGE_FILENAME "language-code"

static GSettings *aula_linux_language_settings(void) {
    static GSettings *settings = NULL;
    static gboolean initialized = FALSE;

    if (!initialized) {
        initialized = TRUE;
        GSettingsSchemaSource *source = g_settings_schema_source_get_default();
        if (source != NULL) {
            GSettingsSchema *schema = g_settings_schema_source_lookup(source, AULA_LINUX_LANGUAGE_SCHEMA_ID, TRUE);
            if (schema != NULL) {
                settings = g_settings_new(AULA_LINUX_LANGUAGE_SCHEMA_ID);
                g_settings_schema_unref(schema);
            }
        }
    }

    return settings;
}

static char *aula_linux_language_fallback_path(void) {
    return g_build_filename(g_get_user_config_dir(), AULA_LINUX_LANGUAGE_DIRECTORY, AULA_LINUX_LANGUAGE_FILENAME, NULL);
}

static char *aula_linux_language_fallback_read(void) {
    char *path = aula_linux_language_fallback_path();
    char *contents = NULL;
    gsize length = 0;
    char *result = NULL;

    if (g_file_get_contents(path, &contents, &length, NULL) && contents != NULL) {
        if (length > 0 && contents[length - 1] == '\n') {
            contents[length - 1] = '\0';
        } else {
            contents[length] = '\0';
        }
        result = g_strdup(g_strstrip(contents));
    }

    g_free(contents);
    g_free(path);
    return result;
}

static void aula_linux_language_fallback_write(const char *language_code) {
    char *path = aula_linux_language_fallback_path();
    char *directory = g_path_get_dirname(path);
    g_mkdir_with_parents(directory, 0755);
    g_file_set_contents(path, language_code, -1, NULL);
    g_free(directory);
    g_free(path);
}

void aula_linux_load_language(char *buffer, int capacity) {
    const char *code = AULA_LINUX_LANGUAGE_DEFAULT;
    GSettings *settings = aula_linux_language_settings();

    if (settings != NULL) {
        char *stored = g_settings_get_string(settings, AULA_LINUX_LANGUAGE_KEY);
        if (stored != NULL && stored[0] != '\0') {
            code = stored;
        }
        writeCString(code, buffer, capacity);
        g_free(stored);
        return;
    }

    char *persisted = aula_linux_language_fallback_read();
    if (persisted != NULL && persisted[0] != '\0') {
        code = persisted;
    }
    writeCString(code, buffer, capacity);
    g_free(persisted);
}

void aula_linux_store_language(const char *language_code) {
    const char *code = (language_code != NULL && language_code[0] != '\0') ? language_code : AULA_LINUX_LANGUAGE_DEFAULT;
    GSettings *settings = aula_linux_language_settings();

    if (settings != NULL && g_settings_set_string(settings, AULA_LINUX_LANGUAGE_KEY, code)) {
        return;
    }

    aula_linux_language_fallback_write(code);
}

typedef struct { int mode, brightness, speed, direction, colorful, color; } LightingState;

typedef struct {
    GtkStack *stack;
    GtkListBox *navigation;
    LightingState applied, launch;
    gboolean has_applied, loading_controls, busy, closed;
    GtkWidget *home_stage, *lighting_stage, *screen_stage, *effect_flow;
    GtkWidget *preview_badge, *revert_button, *profiles_flow, *home_profiles;
    GtkWidget *profile_update, *profile_rename, *profile_delete;
    GtkWidget *frame_strip, *frame_label, *upload_progress, *log_count;
    GtkTextView *log_view;
    GtkWidget *controls[7];
    int selected_profile, profile_count, log_entries;
    LightingState selected_profile_settings;
    gboolean has_profile_settings;
    GBytes *display_bytes;
    GPtrArray *display_frames;
    guint preview_generation, animation_timer;
    gint64 animation_start, last_clock_redraw;
    int current_frame;
    GtkWidget *page_title;
    GtkWidget *status_message;
    GtkWidget *wired_value;
    GtkWidget *wired_detail;
    GtkWidget *dongle_value;
    GtkWidget *dongle_detail;
    GtkWidget *battery_value;
    GtkWidget *battery_detail;
    GtkWidget *ready_pill;

    GtkWidget *sync_button;
    GtkWidget *factory_reset_button;
    GtkWidget *choose_image_button;
    GtkWidget *upload_image_button;
    GtkWidget *selected_image_label;
    GtkWidget *screen_preview;
    GtkWidget *display_slot;
    GtkWidget *fit_mode;
    char *selected_image_path;
    GtkWidget *battery_button;
    GtkWidget *apply_rgb_button;
    GtkWidget *apply_performance_button;
    GtkWidget *restore_command_button;
    GtkWidget *game_mode_button;

    GtkWidget *rgb_mode;
    GtkWidget *rgb_brightness;
    GtkWidget *rgb_speed;
    GtkWidget *rgb_direction;
    GtkWidget *rgb_colorful;
    GtkWidget *rgb_color;
    GtkWidget *response_level;
    GtkWidget *sleep_time;
    GtkWidget *language_combo;
    GtkWindow *window;
    GtkApplication *app;
    int selected_language_index;
    gboolean game_mode_enabled;
    gboolean has_counts;
    int wired_count;
    int dongle_count;
    int battery_percent;
    gint64 last_battery_query_usec;
    guint refresh_timer_id;

    GtkTextBuffer *endpoint_buffer;
    GtkTextBuffer *log_buffer;
} AulaLinuxUI;

static const char *rgb_modes[] = {
    "LED Off", "Static", "SingleOn", "SingleOff", "Glittering", "Falling", "Colourful", "Breath", "Spectrum", "Outward",
    "Scrolling", "Rolling", "Rotating", "Explode", "Launch", "Ripples", "Flowing", "Pulsating", "Tilt", "Shuttle"
};

static const char *directions[] = { "Right", "Down", "Left", "Up" };
static const char *responses[] = {
    "Level 1 Fastest - 2.4G 5-6 ms",
    "Level 2 Balanced - 2.4G 7-9 ms",
    "Level 3 Stable - 2.4G 10-12 ms",
    "Level 4 Conservative - 2.4G 15-17 ms",
    "Level 5 Max Stability - 2.4G 19-21 ms"
};
static const char *sleep_values[] = { "No Sleep", "1 min", "5 min", "30 min" };
static const char *fit_values[] = { "Fit", "Fill", "Stretch" };

static const char *language_codes[] = { "system", "en", "ru", "es", "uz", "kk", "pt", "zh-Hans" };

static int language_index_for_code(const char *language_code) {
    if (language_code == NULL || *language_code == '\0') {
        return 0;
    }

    for (int i = 0; i < (int)(sizeof(language_codes) / sizeof(language_codes[0])); i++) {
        if (g_ascii_strcasecmp(language_codes[i], language_code) == 0) {
            return i;
        }
    }

    return 0;
}

static const char *language_code_for_index(int index) {
    if (index < 0 || index >= (int)(sizeof(language_codes) / sizeof(language_codes[0]))) {
        return language_codes[0];
    }
    return language_codes[index];
}

static const char *localized(const char *key);

static void append_language_items(GtkComboBoxText *combo) {
    gtk_combo_box_text_append_text(combo, localized("System default"));
    gtk_combo_box_text_append_text(combo, "English");
    gtk_combo_box_text_append_text(combo, "Русский");
    gtk_combo_box_text_append_text(combo, "Español");
    gtk_combo_box_text_append_text(combo, "O'zbekcha");
    gtk_combo_box_text_append_text(combo, "Қазақша");
    gtk_combo_box_text_append_text(combo, "Português");
    gtk_combo_box_text_append_text(combo, "简体中文");
}

static gboolean relaunch_app_idle(gpointer user_data) {
    GtkApplication *app = GTK_APPLICATION(user_data);
    g_application_activate(G_APPLICATION(app));
    g_application_release(G_APPLICATION(app));
    g_object_unref(app);
    return G_SOURCE_REMOVE;
}

static void on_language_changed(GtkComboBox *combo, gpointer user_data) {
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    int index = gtk_combo_box_get_active(combo);
    if (index < 0 || index == ui->selected_language_index) {
        return;
    }

    ui->selected_language_index = index;
    char result[32];
    aula_linux_configure_language(language_code_for_index(index), result, (int)sizeof(result));
    g_application_hold(G_APPLICATION(ui->app));
    g_idle_add(relaunch_app_idle, g_object_ref(ui->app));
    gtk_window_close(GTK_WINDOW(ui->window));
}

static const char *localized(const char *key) {
    static _Thread_local char buffers[8][1024];
    static _Thread_local unsigned index;
    char *buffer = buffers[index++ % 8];
    aula_linux_localized_string(key, buffer, 1024);
    return buffer;
}

#define L(key) localized(key)

static void format_localized(char *buffer, size_t capacity, const char *key, ...) {
    char format[1024];
    const char *source = L(key);
    size_t out = 0;
    for (size_t i = 0; source[i] != '\0' && out + 1 < sizeof(format); i++) {
        if (source[i] == '%' && source[i + 1] == '@') {
            if (out + 2 >= sizeof(format)) {
                break;
            }
            format[out++] = '%';
            format[out++] = 's';
            i++;
            continue;
        }
        format[out++] = source[i];
    }
    format[out] = '\0';

    va_list args;
    va_start(args, key);
    vsnprintf(buffer, capacity, format, args);
    va_end(args);
}

static void add_class(GtkWidget *widget, const char *css_class) {
    gtk_widget_add_css_class(widget, css_class);
}

static GtkWidget *label_new(const char *text, const char *css_class) {
    GtkWidget *label = gtk_label_new(L(text));
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
    gtk_label_set_wrap(GTK_LABEL(label), TRUE);
    if (css_class != NULL) {
        add_class(label, css_class);
    }
    return label;
}

static GtkWidget *hbox_new(int spacing) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, spacing);
    gtk_widget_set_hexpand(box, TRUE);
    return box;
}

static GtkWidget *vbox_new(int spacing) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, spacing);
    gtk_widget_set_hexpand(box, TRUE);
    return box;
}

static GtkWidget *icon_box(const char *icon_name, const char *css_class) {
    GtkWidget *frame = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_size_request(frame, 38, 38);
    gtk_widget_set_valign(frame, GTK_ALIGN_START);
    add_class(frame, "icon-box");
    if (css_class != NULL) {
        add_class(frame, css_class);
    }

    GtkWidget *image = gtk_image_new_from_icon_name(icon_name);
    gtk_widget_set_halign(image, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(image, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(frame), image);
    return frame;
}

static GtkWidget *make_button(const char *title, const char *icon_name) {
    GtkWidget *button = gtk_button_new();
    GtkWidget *content = hbox_new(8);
    gtk_widget_set_halign(content, GTK_ALIGN_CENTER);
    gtk_widget_set_hexpand(content, FALSE);
    gtk_box_append(GTK_BOX(content), gtk_image_new_from_icon_name(icon_name));
    gtk_box_append(GTK_BOX(content), gtk_label_new(L(title)));
    gtk_button_set_child(GTK_BUTTON(button), content);
    gtk_widget_set_hexpand(button, TRUE);
    return button;
}

static GtkWidget *make_panel(const char *title, const char *subtitle, const char *icon_name, GtkWidget **content_out) {
    GtkWidget *panel = vbox_new(16);
    add_class(panel, "panel");

    GtkWidget *head = hbox_new(12);
    gtk_box_append(GTK_BOX(head), icon_box(icon_name, "accent-icon"));

    GtkWidget *title_box = vbox_new(2);
    gtk_box_append(GTK_BOX(title_box), label_new(title, "panel-title"));
    if (subtitle[0]) {
        GtkWidget *caption = label_new(subtitle, "muted");
        gtk_label_set_max_width_chars(GTK_LABEL(caption), 30);
        gtk_box_append(GTK_BOX(title_box), caption);
    }
    gtk_box_append(GTK_BOX(head), title_box);
    gtk_box_append(GTK_BOX(panel), head);

    GtkWidget *content = vbox_new(14);
    gtk_box_append(GTK_BOX(panel), content);
    *content_out = content;
    return panel;
}

static GtkWidget *make_status_card(const char *title, const char *icon_name, GtkWidget **value_out, GtkWidget **detail_out) {
    GtkWidget *card = hbox_new(12);
    add_class(card, "status-card");

    gtk_box_append(GTK_BOX(card), icon_box(icon_name, "status-icon"));

    GtkWidget *text = vbox_new(4);
    gtk_box_append(GTK_BOX(text), label_new(title, "eyebrow"));
    GtkWidget *value = label_new("--", "status-value");
    GtkWidget *detail = label_new("Idle", "muted");
    gtk_box_append(GTK_BOX(text), value);
    gtk_box_append(GTK_BOX(text), detail);
    gtk_box_append(GTK_BOX(card), text);

    *value_out = value;
    *detail_out = detail;
    return card;
}

static GtkWidget *make_combo(const char **items, int count, int active) {
    GtkWidget *combo = gtk_combo_box_text_new();
    for (int i = 0; i < count; i++) {
        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo), L(items[i]));
    }
    gtk_combo_box_set_active(GTK_COMBO_BOX(combo), active);
    gtk_widget_set_hexpand(combo, TRUE);
    return combo;
}

static GtkWidget *make_spin(int min, int max, int value) {
    GtkAdjustment *adjustment = gtk_adjustment_new(value, min, max, 1, 1, 0);
    GtkWidget *spin = gtk_spin_button_new(adjustment, 1, 0);
    gtk_widget_set_hexpand(spin, TRUE);
    return spin;
}

static GtkWidget *setting_row(const char *title, GtkWidget *control) {
    GtkWidget *row = hbox_new(12);
    GtkWidget *label = label_new(title, "setting-label");
    gtk_widget_set_size_request(label, 100, -1);
    gtk_box_append(GTK_BOX(row), label);
    gtk_box_append(GTK_BOX(row), control);
    return row;
}

static LightingState current_lighting(AulaLinuxUI *ui);
static void update_lighting_preview(AulaLinuxUI *ui);
static void prepare_screen(AulaLinuxUI *ui);
static void start_command(AulaLinuxUI *ui, int kind);
static void confirm_reset(GtkButton *button, gpointer data);

static void append_log(AulaLinuxUI *ui, const char *message) {
    gtk_label_set_text(GTK_LABEL(ui->status_message), message);
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(ui->log_buffer, &end);
    gtk_text_buffer_insert(ui->log_buffer, &end, message, -1);
    gtk_text_buffer_insert(ui->log_buffer, &end, "\n", -1);
    ui->log_entries++;
    char count[64];
    format_localized(count, sizeof(count), "%d entries", ui->log_entries);
    if (ui->log_count) gtk_label_set_text(GTK_LABEL(ui->log_count), count);
    if (ui->log_view) {
        GtkTextMark *mark = gtk_text_buffer_get_insert(ui->log_buffer);
        gtk_text_buffer_place_cursor(ui->log_buffer, &end);
        gtk_text_view_scroll_mark_onscreen(ui->log_view, mark);
    }
}

static int selected_index(GtkWidget *combo, int fallback) {
    int active = gtk_combo_box_get_active(GTK_COMBO_BOX(combo));
    return active < 0 ? fallback : active;
}

static int selected_color(GtkWidget *color_button) {
    GdkRGBA color;
    gtk_color_chooser_get_rgba(GTK_COLOR_CHOOSER(color_button), &color);
    int red = (int)round(fmax(0.0, fmin(1.0, color.red)) * 255.0);
    int green = (int)round(fmax(0.0, fmin(1.0, color.green)) * 255.0);
    int blue = (int)round(fmax(0.0, fmin(1.0, color.blue)) * 255.0);
    return (red << 16) | (green << 8) | blue;
}

static void update_status_widgets(AulaLinuxUI *ui) {
    char value[64];
    g_strlcpy(value, L("USB cable connected"), sizeof(value));
    gtk_label_set_text(GTK_LABEL(ui->wired_value), ui->wired_count > 0 ? value : L("Not connected"));
    gtk_label_set_text(GTK_LABEL(ui->wired_detail), ui->wired_count > 0 ? L("Ready for wired operations") : L("Connect the keyboard by USB-C."));

    g_strlcpy(value, L("2.4G receiver connected"), sizeof(value));
    gtk_label_set_text(GTK_LABEL(ui->dongle_value), ui->dongle_count > 0 ? value : L("Not connected"));
    gtk_label_set_text(GTK_LABEL(ui->dongle_detail), ui->dongle_count > 0 ? L("Required for battery, RGB and performance.") : L("Plug in the 2.4G receiver."));

    gtk_label_set_text(GTK_LABEL(ui->ready_pill), ui->busy ? L("Working…") : (ui->wired_count > 0 || ui->dongle_count > 0) ? L("Ready") : L("Idle"));
    gtk_label_set_text(GTK_LABEL(ui->battery_detail), ui->dongle_count > 0 ? L("Query over the 2.4G dongle.") : L("Battery is unavailable without the dongle."));

    gtk_widget_set_sensitive(ui->sync_button, ui->wired_count > 0 && !ui->busy);
    gtk_widget_set_sensitive(ui->factory_reset_button, ui->wired_count > 0 && !ui->busy);
    gtk_widget_set_sensitive(ui->upload_image_button, ui->wired_count > 0 && ui->display_bytes != NULL && !ui->busy);
    gtk_widget_set_sensitive(ui->battery_button, ui->dongle_count > 0 && !ui->busy);
    gtk_widget_set_sensitive(ui->apply_rgb_button, ui->dongle_count > 0 && !ui->busy);
    gtk_widget_set_sensitive(ui->apply_performance_button, ui->dongle_count > 0 && !ui->busy);
    gtk_widget_set_sensitive(ui->restore_command_button, ui->dongle_count > 0 && !ui->busy);
    gtk_widget_set_sensitive(ui->game_mode_button, ui->dongle_count > 0 && !ui->busy);
    if (ui->controls[4]) gtk_widget_set_sensitive(ui->controls[4], ui->dongle_count > 0 && !ui->busy);
    if (ui->controls[5]) gtk_widget_set_sensitive(ui->controls[5], ui->dongle_count > 0 && !ui->busy);
    if (ui->display_slot) gtk_widget_set_sensitive(ui->display_slot, ui->wired_count > 0 && !ui->busy);
    GtkWidget *usb_note = g_object_get_data(G_OBJECT(ui->wired_detail), "requirement-note");
    GtkWidget *receiver_note = g_object_get_data(G_OBJECT(ui->dongle_detail), "requirement-note");
    GtkWidget *performance_note = g_object_get_data(G_OBJECT(ui->dongle_detail), "performance-note");
    GtkWidget *clock = g_object_get_data(G_OBJECT(ui->sync_button), "screen-clock");
    if (usb_note) gtk_widget_set_visible(usb_note, ui->wired_count == 0);
    if (receiver_note) gtk_widget_set_visible(receiver_note, ui->dongle_count == 0);
    if (performance_note) gtk_widget_set_visible(performance_note, ui->dongle_count == 0);
    if (clock) gtk_widget_set_sensitive(clock, ui->wired_count > 0 && !ui->busy);
}

static gboolean refresh_status(AulaLinuxUI *ui) {
    if (ui->busy) return FALSE;
    int previous_wired = ui->wired_count;
    int previous_dongle = ui->dongle_count;
    int wired = 0;
    int dongle = 0;
    aula_linux_endpoint_counts(&wired, &dongle);

    gboolean changed = !ui->has_counts || wired != previous_wired || dongle != previous_dongle;
    ui->has_counts = TRUE;
    ui->wired_count = wired;
    ui->dongle_count = dongle;

    if (changed && previous_dongle > 0 && dongle == 0) {
        ui->battery_percent = -1;
        gtk_label_set_text(GTK_LABEL(ui->battery_value), L("Unknown"));
    }

    update_status_widgets(ui);
    return changed;
}

static void refresh_endpoints(AulaLinuxUI *ui, gboolean log_result) {
    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    aula_linux_refresh(buffer, (int)sizeof(buffer));
    gtk_text_buffer_set_text(ui->endpoint_buffer, buffer[0] == '\0' ? L("No output.") : buffer, -1);
    if (log_result) {
        append_log(ui, buffer[0] == '\0' ? L("Rescan finished.") : buffer);
    }
    refresh_status(ui);
}

static gboolean query_battery(AulaLinuxUI *ui, gboolean log_result) {
    (void)log_result;
    if (ui->busy || ui->dongle_count <= 0) return FALSE;
    start_command(ui, 8);
    return TRUE;
}

static gboolean poll_devices(gpointer user_data) {
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    if (ui->closed) { ui->refresh_timer_id = 0; return G_SOURCE_REMOVE; }
    if (ui->busy) return G_SOURCE_CONTINUE;
    int previous_dongle = ui->dongle_count;
    gboolean changed = refresh_status(ui);

    if (changed) {
        refresh_endpoints(ui, FALSE);
        char message[128];
        snprintf(
            message,
            sizeof(message),
            "Device status changed: wired %d endpoint%s, 2.4G %d endpoint%s.",
            ui->wired_count,
            ui->wired_count == 1 ? "" : "s",
            ui->dongle_count,
            ui->dongle_count == 1 ? "" : "s"
        );
        append_log(ui, message);
    }

    if (ui->dongle_count > 0 && previous_dongle == 0) {
        query_battery(ui, TRUE);
    } else if (ui->dongle_count > 0 && g_get_monotonic_time() - ui->last_battery_query_usec > 300 * G_USEC_PER_SEC) {
        query_battery(ui, FALSE);
    }

    return G_SOURCE_CONTINUE;
}

static void on_rescan_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    refresh_endpoints(ui, TRUE);
    query_battery(ui, TRUE);
}

static void on_battery_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    refresh_status(ui);
    query_battery(ui, TRUE);
}

static unsigned char device_delay_byte(int delay_ms) {
    int normalized = delay_ms <= 0 ? 100 : delay_ms;
    int value = (int)round((double)normalized / 2.0);
    if (value < 1) { return 1; }
    if (value > 255) { return 255; }
    return (unsigned char)value;
}

static gboolean render_pixbuf_to_frame(GdkPixbuf *source, int fit_mode, unsigned char *stream, int frame_index, char *error_buffer, size_t error_capacity) {
    GdkPixbuf *canvas = gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, 128, 128);
    if (canvas == NULL) {
        snprintf(error_buffer, error_capacity, "Failed to allocate 128x128 image canvas.");
        return FALSE;
    }
    gdk_pixbuf_fill(canvas, 0x000000ff);

    int source_width = gdk_pixbuf_get_width(source);
    int source_height = gdk_pixbuf_get_height(source);
    double scale_x = 128.0 / (double)source_width;
    double scale_y = 128.0 / (double)source_height;
    double scale = scale_x < scale_y ? scale_x : scale_y;
    int dest_x = 0;
    int dest_y = 0;
    int dest_width = 128;
    int dest_height = 128;
    double offset_x = 0.0;
    double offset_y = 0.0;

    if (fit_mode == 1) {
        scale = scale_x > scale_y ? scale_x : scale_y;
        dest_width = 128;
        dest_height = 128;
        offset_x = (128.0 - (double)source_width * scale) / 2.0;
        offset_y = (128.0 - (double)source_height * scale) / 2.0;
    } else if (fit_mode == 2) {
        scale = 1.0;
        scale_x = 128.0 / (double)source_width;
        scale_y = 128.0 / (double)source_height;
        gdk_pixbuf_composite(source, canvas, 0, 0, 128, 128, 0.0, 0.0, scale_x, scale_y, GDK_INTERP_BILINEAR, 255);
        goto encode_pixels;
    } else {
        dest_width = (int)round((double)source_width * scale);
        dest_height = (int)round((double)source_height * scale);
        if (dest_width < 1) { dest_width = 1; }
        if (dest_height < 1) { dest_height = 1; }
        dest_x = (128 - dest_width) / 2;
        dest_y = (128 - dest_height) / 2;
        offset_x = (double)dest_x;
        offset_y = (double)dest_y;
    }

    gdk_pixbuf_composite(source, canvas, dest_x, dest_y, dest_width, dest_height, offset_x, offset_y, scale, scale, GDK_INTERP_BILINEAR, 255);

encode_pixels:
    ;
    int rowstride = gdk_pixbuf_get_rowstride(canvas);
    int channels = gdk_pixbuf_get_n_channels(canvas);
    const unsigned char *pixels = gdk_pixbuf_read_pixels(canvas);
    int frame_offset = 256 + frame_index * 128 * 128 * 2;
    for (int y = 0; y < 128; y++) {
        const unsigned char *row = pixels + y * rowstride;
        for (int x = 0; x < 128; x++) {
            const unsigned char *pixel = row + x * channels;
            uint16_t red = (uint16_t)pixel[0] >> 3;
            uint16_t green = (uint16_t)pixel[1] >> 2;
            uint16_t blue = (uint16_t)pixel[2] >> 3;
            uint16_t rgb565 = (uint16_t)((red << 11) | (green << 5) | blue);
            int offset = frame_offset + (y * 128 + x) * 2;
            stream[offset] = (unsigned char)(rgb565 & 0xff);
            stream[offset + 1] = (unsigned char)(rgb565 >> 8);
        }
    }

    g_object_unref(canvas);
    return TRUE;
}

static void add_milliseconds_to_time(GTimeVal *time, int delay_ms) {
    int normalized = delay_ms <= 0 ? 100 : delay_ms;
    time->tv_usec += (glong)(normalized % 1000) * 1000;
    time->tv_sec += normalized / 1000;
    if (time->tv_usec >= 1000000) {
        time->tv_sec += time->tv_usec / 1000000;
        time->tv_usec %= 1000000;
    }
}

static gboolean encoded_frame_matches_first(const unsigned char *stream, int frame_index) {
    if (frame_index <= 0) {
        return FALSE;
    }
    const int frame_bytes = 128 * 128 * 2;
    const unsigned char *first = stream + 256;
    const unsigned char *current = stream + 256 + frame_index * frame_bytes;
    return memcmp(first, current, frame_bytes) == 0;
}

static gboolean encode_display_image(const char *path, int fit_mode, unsigned char **bytes_out, int *length_out, char *error_buffer, size_t error_capacity) {
    GError *error = NULL;
    GdkPixbufAnimation *animation = gdk_pixbuf_animation_new_from_file(path, &error);
    if (animation == NULL) {
        snprintf(error_buffer, error_capacity, "Failed to load image: %s", error != NULL ? error->message : path);
        if (error != NULL) {
            g_error_free(error);
        }
        return FALSE;
    }

    const int header_length = 256;
    const int frame_bytes = 128 * 128 * 2;
    const int chunk_length = 4096;
    const int max_frames = 255;
    const int max_payload_length = header_length + max_frames * frame_bytes;
    const int max_stream_length = ((max_payload_length + chunk_length - 1) / chunk_length) * chunk_length;
    unsigned char *stream = g_malloc0((gsize)max_stream_length);
    if (stream == NULL) {
        g_object_unref(animation);
        snprintf(error_buffer, error_capacity, "Failed to allocate encoded display stream.");
        return FALSE;
    }

    int frame_count = 0;
    if (gdk_pixbuf_animation_is_static_image(animation)) {
        GdkPixbuf *pixbuf = gdk_pixbuf_animation_get_static_image(animation);
        if (!render_pixbuf_to_frame(pixbuf, fit_mode, stream, 0, error_buffer, error_capacity)) {
            g_free(stream);
            g_object_unref(animation);
            return FALSE;
        }
        stream[1] = 50;
        frame_count = 1;
    } else {
        GTimeVal time = { 0, 0 };
        GdkPixbufAnimationIter *iter = gdk_pixbuf_animation_get_iter(animation, &time);
        for (int frame_index = 0; frame_index < max_frames; frame_index++) {
            GdkPixbuf *pixbuf = gdk_pixbuf_animation_iter_get_pixbuf(iter);
            if (pixbuf == NULL) {
                break;
            }
            if (!render_pixbuf_to_frame(pixbuf, fit_mode, stream, frame_index, error_buffer, error_capacity)) {
                g_object_unref(iter);
                g_free(stream);
                g_object_unref(animation);
                return FALSE;
            }
            if (frame_index > 0 && encoded_frame_matches_first(stream, frame_index)) {
                break;
            }

            int delay_ms = gdk_pixbuf_animation_iter_get_delay_time(iter);
            stream[1 + frame_index] = device_delay_byte(delay_ms);
            frame_count++;

            add_milliseconds_to_time(&time, delay_ms);
            if (!gdk_pixbuf_animation_iter_advance(iter, &time) && frame_count > 0) {
                break;
            }
        }
        g_object_unref(iter);
    }

    g_object_unref(animation);
    if (frame_count <= 0) {
        g_free(stream);
        snprintf(error_buffer, error_capacity, "Failed to decode any GIF/image frames.");
        return FALSE;
    }

    stream[0] = (unsigned char)frame_count;
    int payload_length = header_length + frame_count * frame_bytes;
    int stream_length = ((payload_length + chunk_length - 1) / chunk_length) * chunk_length;
    *bytes_out = stream;
    *length_out = stream_length;
    return TRUE;
}

static void on_choose_image_done(GObject *source_object, GAsyncResult *result, gpointer user_data) {
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    GError *error = NULL;
    GFile *file = gtk_file_dialog_open_finish(GTK_FILE_DIALOG(source_object), result, &error);
    if (ui->closed) { g_clear_object(&file); g_clear_error(&error); g_object_unref(ui->window); return; }
    if (file == NULL) {
        if (error != NULL) {
            if (!g_error_matches(error, GTK_DIALOG_ERROR, GTK_DIALOG_ERROR_DISMISSED)) {
                append_log(ui, error->message);
            }
            g_error_free(error);
        }
        g_object_unref(ui->window);
        return;
    }

    char *path = g_file_get_path(file);
    if (path != NULL) {
        g_free(ui->selected_image_path);
        ui->selected_image_path = path;
        prepare_screen(ui);
        char *basename = g_path_get_basename(path);
        gtk_label_set_text(GTK_LABEL(ui->selected_image_label), basename != NULL ? basename : path);
        char message[512];
        format_localized(message, sizeof(message), "Selected %@.", basename != NULL ? basename : path);
        append_log(ui, message);
        g_free(basename);
        update_status_widgets(ui);
    }
    g_object_unref(file);
    g_object_unref(ui->window);
}

static void on_choose_image_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    GtkFileDialog *dialog = gtk_file_dialog_new();
    gtk_file_dialog_set_title(dialog, L("Choose File"));
    g_object_ref(ui->window);
    gtk_file_dialog_open(dialog, ui->window, NULL, on_choose_image_done, ui);
    g_object_unref(dialog);
}

static void on_upload_image_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 1); }
static void on_sync_time_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 2); }
static void on_factory_reset_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 3); }
static void on_apply_rgb_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 4); }

static int current_response_level(AulaLinuxUI *ui) {
    return selected_index(ui->response_level, 0) + 1;
}

static int current_sleep_time(AulaLinuxUI *ui) {
    return selected_index(ui->sleep_time, 1);
}

static void on_apply_performance_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 5); }
static void on_restore_command_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 6); }
static void on_game_mode_clicked(GtkButton *button, gpointer data) { (void)button; start_command(data, 7); }

static void install_icon_search_path(void) {
    char exe_path[PATH_MAX];
    ssize_t length = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (length <= 0) {
        return;
    }
    exe_path[length] = '\0';

    char *last_slash = strrchr(exe_path, '/');
    if (last_slash == NULL) {
        return;
    }
    *last_slash = '\0';

    char icon_path[PATH_MAX];
    int written = snprintf(icon_path, sizeof(icon_path), "%s/share/icons", exe_path);
    if (written <= 0 || written >= (int)sizeof(icon_path)) {
        return;
    }

    GtkIconTheme *theme = gtk_icon_theme_get_for_display(gdk_display_get_default());
    gtk_icon_theme_add_search_path(theme, icon_path);
}

static void install_css(void) {
    GtkCssProvider *provider = gtk_css_provider_new();
    const char *css =
        ".aula-window { background: @theme_bg_color; color: @theme_fg_color; }"
        ".sidebar { background: alpha(@theme_fg_color, 0.035); padding: 20px 12px 12px; }"
        ".sidebar list { background: transparent; }"
        ".sidebar row { border-radius: 8px; padding: 9px 8px; margin: 2px 0; }"
        ".brand { padding: 12px 6px 20px; }"
        ".page { padding: 16px 28px 24px; }"
        ".hero-title { font-size: 26px; font-weight: bold; padding: 20px 28px 6px; }"
        ".subtitle, .muted { opacity: 0.65; font-size: 12px; }"
        ".update-banner { background: alpha(@theme_selected_bg_color, .10); border: 1px solid alpha(@theme_selected_bg_color, .20); border-radius: 12px; padding: 10px 12px; }"
        ".ready-pill { color: #38a86b; padding: 12px 6px; }"
        ".status-card, .panel { background: alpha(@theme_base_color, 0.65); border: 1px solid alpha(@theme_fg_color, 0.10); border-radius: 12px; padding: 18px; }"
        ".panel-title { font-size: 16px; font-weight: bold; }"
        ".eyebrow { opacity: 0.65; font-size: 11px; }"
        ".status-value { font-size: 24px; font-weight: bold; }"
        ".icon-box { border-radius: 10px; padding: 9px; color: @theme_selected_bg_color; }"
        ".setting-label, .section-title { font-weight: bold; }"
        ".status-bar { border-radius: 999px; margin: 6px 28px 12px; padding: 8px 14px; background: alpha(@theme_base_color, 0.8); box-shadow: 0 3px 10px alpha(black, 0.12); }"
        "button { border-radius: 8px; padding: 8px 12px; }"
        "textview { border-radius: 8px; padding: 10px; }"
        ".stage-backdrop { background: linear-gradient(135deg, #22252b, #101115); color: #f0f0f2; border-radius: 14px; padding: 16px; border: 1px solid alpha(white, .09); }"
        ".stage-backdrop .status-card { background: transparent; border: none; padding: 8px; }"
        ".stage-backdrop .status-value { font-size: 16px; }"
        ".stage-backdrop .icon-box { color: #7eb5ff; }"
        ".stage-backdrop button { background: #30323a; color: #eeeef0; }"
        ".stage-backdrop button:hover { background: #3c3f48; }"
        ".stage-backdrop button:disabled { opacity: .45; }"
        ".stage-backdrop button.effect-tile { padding: 4px; border: 1px solid transparent; border-radius: 10px; background: transparent; }"
        ".effect-title { font-size: 11px; }"
        ".stage-backdrop button.selected-effect, button.selected-effect { border: 2px solid #68a6ff; background: alpha(#68a6ff, .16); }"
        ".preview-badge { color: #ffba67; background: alpha(#ffad50, .14); border-radius: 12px; padding: 4px 10px; }"
        ".screen-bezel { background: #050609; border: 8px solid #292c32; border-radius: 14px; padding: 4px; }"
        ".warning-box { background: alpha(#e69a35, .12); color: #b77b24; border-radius: 8px; padding: 10px 12px; }"
        "flowboxchild { padding: 0; }"
        ".control-card { background: alpha(@theme_base_color, .6); border: 1px solid alpha(@theme_fg_color, .1); border-radius: 10px; padding: 12px; }"
        ".segments button { padding: 7px 9px; }";
    gtk_css_provider_load_from_data(provider, css, -1);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

static void destroy_ui(gpointer data) {
    AulaLinuxUI *ui = (AulaLinuxUI *)data;
    if (ui == NULL) {
        return;
    }
    if (ui->refresh_timer_id != 0) {
        g_source_remove(ui->refresh_timer_id);
        ui->refresh_timer_id = 0;
    }
    if (ui->animation_timer) g_source_remove(ui->animation_timer);
    g_clear_pointer(&ui->display_bytes, g_bytes_unref);
    g_clear_pointer(&ui->display_frames, g_ptr_array_unref);
    g_free(ui->selected_image_path);
    g_free(ui);
}

static void on_page_selected(GtkListBox *list, GtkListBoxRow *row, gpointer data) {
    (void)list;
    if (row == NULL) return;
    AulaLinuxUI *ui = data;
    const char *name = g_object_get_data(G_OBJECT(row), "page-name");
    if (name == NULL) return;
    gtk_stack_set_visible_child_name(ui->stack, name);
    GtkStackPage *page = gtk_stack_get_page(ui->stack, gtk_stack_get_visible_child(ui->stack));
    gtk_label_set_text(GTK_LABEL(ui->page_title), gtk_stack_page_get_title(page));
    ui->last_clock_redraw = 0;
}

static void open_shortcut(GtkButton *button, gpointer data) {
    GtkListBox *navigation = data;
    int index = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(button), "row-index"));
    gtk_list_box_select_row(navigation, gtk_list_box_get_row_at_index(navigation, index));
}

static void open_activity_log(GtkListBox *navigation) {
    gtk_list_box_select_row(navigation, gtk_list_box_get_row_at_index(navigation, 7));
}

#include "LinuxPresentation.inc"

static GtkWidget *wrapping_flow(int max, int spacing) {
    GtkWidget *flow=gtk_flow_box_new();
    gtk_flow_box_set_selection_mode(GTK_FLOW_BOX(flow),GTK_SELECTION_NONE);
    gtk_flow_box_set_min_children_per_line(GTK_FLOW_BOX(flow),1);
    gtk_flow_box_set_max_children_per_line(GTK_FLOW_BOX(flow),max);
    gtk_flow_box_set_row_spacing(GTK_FLOW_BOX(flow),spacing);
    gtk_flow_box_set_column_spacing(GTK_FLOW_BOX(flow),spacing);
    gtk_flow_box_set_homogeneous(GTK_FLOW_BOX(flow),TRUE);
    return flow;
}

static GtkWidget *requirement_note(const char *text) {
    GtkWidget *note=label_new(text,"warning-box");
    return note;
}

#include "LinuxUpdates.inc"

static void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;
    GtkWindow *existing=gtk_application_get_active_window(app);
    if(existing) { gtk_window_present(existing); return; }
    install_css(); install_icon_search_path();
    AulaLinuxUI *ui=g_new0(AulaLinuxUI,1);
    ui->battery_percent=-1; ui->selected_profile=-1;
    ui->animation_start=g_get_monotonic_time();
    GtkWidget *window=gtk_application_window_new(app);
    ui->app=app; ui->window=GTK_WINDOW(window);
    gtk_window_set_title(ui->window,L("Aula F75 Max Driver"));
    gtk_window_set_icon_name(ui->window,"vitalyart.aula-f75-max-driver");
    gtk_window_set_default_size(ui->window,1100,840);
    gtk_widget_set_size_request(window,820,560);
    add_class(window,"aula-window");
    g_signal_connect(window,"close-request",G_CALLBACK(window_closing),ui);
    GtkWidget *root=hbox_new(0); gtk_window_set_child(ui->window,root);
    GtkWidget *sidebar=vbox_new(8); add_class(sidebar,"sidebar");
    gtk_widget_set_hexpand(sidebar,FALSE); gtk_widget_set_size_request(sidebar,220,-1);
    gtk_box_append(GTK_BOX(root),sidebar);
    GtkWidget *brand=hbox_new(10); add_class(brand,"brand");
    GtkWidget *app_icon=gtk_image_new_from_icon_name("vitalyart.aula-f75-max-driver"); gtk_image_set_pixel_size(GTK_IMAGE(app_icon),32);
    gtk_box_append(GTK_BOX(brand),app_icon);
    GtkWidget *brand_text=vbox_new(2);
    gtk_box_append(GTK_BOX(brand_text),label_new("Aula F75 Max","panel-title"));
    gtk_box_append(GTK_BOX(brand_text),label_new("Keyboard Control","muted"));
    gtk_box_append(GTK_BOX(brand),brand_text); gtk_box_append(GTK_BOX(sidebar),brand);
    GtkWidget *detail=vbox_new(0); gtk_box_append(GTK_BOX(root),detail);
    ui->page_title=label_new("Home","hero-title"); gtk_box_append(GTK_BOX(detail),ui->page_title);
    ui->stack=GTK_STACK(gtk_stack_new());
    gtk_stack_set_transition_type(ui->stack,GTK_STACK_TRANSITION_TYPE_CROSSFADE);
    gtk_stack_set_transition_duration(ui->stack,150);
    gtk_stack_set_hhomogeneous(ui->stack,FALSE); gtk_stack_set_vhomogeneous(ui->stack,FALSE);
    gtk_widget_set_vexpand(GTK_WIDGET(ui->stack),TRUE); gtk_box_append(GTK_BOX(detail),GTK_WIDGET(ui->stack));
    const char *names[]={"home","lighting","screen","performance","settings","diagnostics","log"};
    const char *titles[]={"Home","Lighting","Screen","Performance","Settings","Diagnostics","Activity Log"};
    const char *icons[]={"go-home-symbolic","weather-clear-symbolic","video-display-symbolic","preferences-system-symbolic","emblem-system-symbolic","network-transmit-receive-symbolic","view-list-symbolic"};
    GtkWidget *pages[7]; GtkWidget *navigation=gtk_list_box_new();
    ui->navigation=GTK_LIST_BOX(navigation);
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(navigation),GTK_SELECTION_SINGLE);
    gtk_box_append(GTK_BOX(sidebar),navigation);
    for(int i=0;i<7;i++) {
        if(i==5) {
            GtkWidget *section=gtk_list_box_row_new();
            gtk_list_box_row_set_selectable(GTK_LIST_BOX_ROW(section),FALSE);
            gtk_list_box_row_set_activatable(GTK_LIST_BOX_ROW(section),FALSE);
            gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(section),label_new("Advanced","muted"));
            gtk_list_box_append(GTK_LIST_BOX(navigation),section);
        }
        GtkWidget *row=gtk_list_box_row_new(), *content=hbox_new(10);
        gtk_box_append(GTK_BOX(content),gtk_image_new_from_icon_name(icons[i]));
        gtk_box_append(GTK_BOX(content),label_new(titles[i],NULL));
        gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(row),content);
        g_object_set_data(G_OBJECT(row),"page-name",(gpointer)names[i]); gtk_list_box_append(GTK_LIST_BOX(navigation),row);
        GtkWidget *scroll=gtk_scrolled_window_new();
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll),GTK_POLICY_NEVER,GTK_POLICY_AUTOMATIC);
        pages[i]=vbox_new(16); add_class(pages[i],"page");
        gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroll),pages[i]);
        gtk_stack_add_titled(ui->stack,scroll,names[i],L(titles[i]));
    }
    g_signal_connect(navigation,"row-selected",G_CALLBACK(on_page_selected),ui);
    GtkEventController *keys=gtk_event_controller_key_new();
    g_signal_connect(keys,"key-pressed",G_CALLBACK(page_shortcuts),navigation);
    gtk_widget_add_controller(window,keys);
    GtkWidget *spacer=vbox_new(0); gtk_widget_set_vexpand(spacer,TRUE); gtk_box_append(GTK_BOX(sidebar),spacer);
    ui->ready_pill=label_new("Ready","ready-pill"); gtk_box_append(GTK_BOX(sidebar),ui->ready_pill);
    GtkWidget *status_button=gtk_button_new(); add_class(status_button,"status-bar");
    ui->status_message=label_new("No activity yet","muted"); gtk_label_set_wrap(GTK_LABEL(ui->status_message),FALSE);
    gtk_label_set_ellipsize(GTK_LABEL(ui->status_message),PANGO_ELLIPSIZE_END);
    gtk_button_set_child(GTK_BUTTON(status_button),ui->status_message);
    g_signal_connect_swapped(status_button,"clicked",G_CALLBACK(open_activity_log),navigation);
    gtk_box_append(GTK_BOX(detail),status_button);

    // Home: one stage with the connection summary underneath.
    GtkWidget *summary=vbox_new(16); add_class(summary,"stage-backdrop");
    ui->home_stage=keyboard_stage(ui,0,260); gtk_box_append(GTK_BOX(summary),ui->home_stage);
    GtkWidget *status=hbox_new(16);
    GtkWidget *connections=vbox_new(4);
    gtk_box_append(GTK_BOX(status),connections);
    gtk_box_append(GTK_BOX(connections),make_status_card("Wired USB","network-wired-symbolic",&ui->wired_value,&ui->wired_detail));
    gtk_box_append(GTK_BOX(connections),make_status_card("2.4G Receiver","network-wireless-symbolic",&ui->dongle_value,&ui->dongle_detail));
    GtkWidget *battery=make_status_card("Battery","battery-good-symbolic",&ui->battery_value,&ui->battery_detail);
    ui->battery_button=make_button("Refresh battery","view-refresh-symbolic");
    g_signal_connect(ui->battery_button,"clicked",G_CALLBACK(on_battery_clicked),ui);
    GtkWidget *battery_box=vbox_new(8); gtk_box_append(GTK_BOX(battery_box),battery); gtk_box_append(GTK_BOX(battery_box),ui->battery_button);
    gtk_box_append(GTK_BOX(status),battery_box);
    gtk_widget_set_valign(battery_box,GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(summary),status); gtk_box_append(GTK_BOX(pages[0]),summary);
    GtkWidget *home_profiles_content=NULL;
    GtkWidget *home_profiles_panel=make_panel("Profiles","","view-grid-symbolic",&home_profiles_content);
    ui->home_profiles=wrapping_flow(4,8); gtk_box_append(GTK_BOX(home_profiles_content),ui->home_profiles);
    gtk_box_append(GTK_BOX(pages[0]),home_profiles_panel);
    GtkWidget *quick=wrapping_flow(3,12); gtk_box_append(GTK_BOX(pages[0]),quick);
    const char *quick_titles[]={"Screen clock","Lighting","Screen image"};
    const char *quick_details[]={"Wired operations require the keyboard over USB-C","Effects, colour and brightness","Show a picture or GIF on the keyboard display"};
    for(int i=0;i<3;i++) {
        GtkWidget *content=NULL; GtkWidget *tile=make_panel(quick_titles[i],quick_details[i],icons[i==0?2:i],&content);
        GtkWidget *button=make_button(i==0 ? "Sync Clock" : i==1 ? "Open Lighting" : "Open Screen",i==0?"view-refresh-symbolic":"go-next-symbolic");
        if(i==0) { ui->sync_button=button; g_signal_connect(button,"clicked",G_CALLBACK(on_sync_time_clicked),ui); }
        else { g_object_set_data(G_OBJECT(button),"row-index",GINT_TO_POINTER(i)); g_signal_connect(button,"clicked",G_CALLBACK(open_shortcut),navigation); }
        gtk_box_append(GTK_BOX(content),button); gtk_flow_box_insert(GTK_FLOW_BOX(quick),tile,-1);
    }

    // Lighting: live model, effect gallery, controls, explicit apply, saved looks.
    GtkWidget *lighting_backdrop=vbox_new(12); add_class(lighting_backdrop,"stage-backdrop");
    ui->preview_badge=label_new("Preview · not applied","preview-badge");
    gtk_widget_set_halign(ui->preview_badge,GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(lighting_backdrop),ui->preview_badge);
    gtk_box_append(GTK_BOX(lighting_backdrop),label_new("Preview is an approximation of the keyboard's effect","muted"));
    ui->lighting_stage=keyboard_stage(ui,1,330); gtk_box_append(GTK_BOX(lighting_backdrop),ui->lighting_stage);
    ui->effect_flow=wrapping_flow(20,10);
    for(int i=0;i<20;i++) {
        GtkWidget *button=gtk_button_new(); add_class(button,"effect-tile"); GtkWidget *box=vbox_new(5);
        GtkWidget *swatch=gtk_drawing_area_new(); gtk_widget_set_size_request(swatch,86,46);
        EffectSample *sample=g_new(EffectSample,1); sample->ui=ui; sample->mode=i;
        gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(swatch),draw_swatch,sample,g_free);
        GtkWidget *title=label_new(rgb_modes[i],"effect-title");
        gtk_label_set_max_width_chars(GTK_LABEL(title),14);
        gtk_label_set_xalign(GTK_LABEL(title),.5);
        gtk_box_append(GTK_BOX(box),swatch); gtk_box_append(GTK_BOX(box),title);
        gtk_button_set_child(GTK_BUTTON(button),box);
        g_object_set_data(G_OBJECT(button),"mode",GINT_TO_POINTER(i));
        g_signal_connect(button,"clicked",G_CALLBACK(effect_selected),ui); gtk_flow_box_insert(GTK_FLOW_BOX(ui->effect_flow),button,-1);
    }
    gtk_box_append(GTK_BOX(lighting_backdrop),ui->effect_flow); gtk_box_append(GTK_BOX(pages[1]),lighting_backdrop);
    GtkWidget *receiver_note=requirement_note("Plug in the 2.4G receiver to use these controls.");
    gtk_box_append(GTK_BOX(pages[1]),receiver_note);
    GtkWidget *lighting_controls=vbox_new(12);
    gtk_box_append(GTK_BOX(pages[1]),lighting_controls); ui->controls[0]=lighting_controls;
    ui->rgb_mode=make_combo(rgb_modes,20,11);
    ui->rgb_brightness=make_spin(1,5,5); ui->rgb_speed=make_spin(1,5,3);
    ui->rgb_direction=make_combo(directions,4,0); ui->rgb_colorful=gtk_switch_new();
    gtk_widget_set_halign(ui->rgb_colorful,GTK_ALIGN_START); gtk_switch_set_active(GTK_SWITCH(ui->rgb_colorful),TRUE);
    ui->rgb_color=gtk_color_button_new(); GdkRGBA color={0,.478,1,1}; gtk_color_chooser_set_rgba(GTK_COLOR_CHOOSER(ui->rgb_color),&color);
    gtk_widget_set_visible(ui->rgb_mode,FALSE);
    gtk_box_append(GTK_BOX(lighting_controls),ui->rgb_mode);
    GtkWidget *control_grid=wrapping_flow(2,12); gtk_box_append(GTK_BOX(lighting_controls),control_grid);
    const char *numbers[]={"1","2","3","4","5"};
    const char *color_modes[]={"Single colour","Rainbow"};
    GtkWidget *color_controls=hbox_new(8);
    gtk_box_append(GTK_BOX(color_controls),segments(ui->rgb_colorful,2,color_modes,2,0));
    gtk_box_append(GTK_BOX(color_controls),ui->rgb_color);
    GtkWidget *widgets[]={segments(ui->rgb_brightness,0,numbers,5,1),segments(ui->rgb_speed,0,numbers,5,1),segments(ui->rgb_direction,1,directions,4,0),color_controls};
    const char *labels[]={"Brightness","Speed","Direction","Colour"};
    for(int i=0;i<4;i++) {
        GtkWidget *card=vbox_new(8); add_class(card,"control-card");
        gtk_box_append(GTK_BOX(card),label_new(labels[i],"section-title")); gtk_box_append(GTK_BOX(card),widgets[i]);
        gtk_flow_box_insert(GTK_FLOW_BOX(control_grid),card,-1);
    }
    GtkWidget *apply_row=hbox_new(10);
    GtkWidget *apply_hint=label_new("Changes are sent when you press Apply to Keyboard.","muted");
    gtk_widget_set_hexpand(apply_hint,TRUE); gtk_label_set_max_width_chars(GTK_LABEL(apply_hint),38);
    gtk_box_append(GTK_BOX(apply_row),apply_hint);
    ui->revert_button=make_button("Revert","edit-undo-symbolic"); g_signal_connect(ui->revert_button,"clicked",G_CALLBACK(revert_lighting),ui);
    ui->apply_rgb_button=make_button("Apply to Keyboard","emblem-ok-symbolic"); add_class(ui->apply_rgb_button,"suggested-action");
    g_signal_connect(ui->apply_rgb_button,"clicked",G_CALLBACK(on_apply_rgb_clicked),ui);
    gtk_widget_set_hexpand(ui->revert_button,FALSE); gtk_widget_set_hexpand(ui->apply_rgb_button,FALSE);
    gtk_box_append(GTK_BOX(apply_row),ui->revert_button); gtk_box_append(GTK_BOX(apply_row),ui->apply_rgb_button);
    gtk_box_append(GTK_BOX(pages[1]),apply_row);
    GtkWidget *profile_content=NULL;
    GtkWidget *profile_panel=make_panel("Profiles","","view-grid-symbolic",&profile_content); gtk_box_append(GTK_BOX(pages[1]),profile_panel);
    ui->profiles_flow=wrapping_flow(4,8); gtk_box_append(GTK_BOX(profile_content),ui->profiles_flow);
    GtkWidget *profile_actions=wrapping_flow(4,8); ui->controls[1]=profile_actions;
    GtkWidget *save_profile=make_button("Save as New Profile…","list-add-symbolic");
    g_object_set_data(G_OBJECT(save_profile),"profile-action",GINT_TO_POINTER(1)); g_signal_connect(save_profile,"clicked",G_CALLBACK(profile_name_dialog),ui);
    ui->profile_update=make_button("Update","document-save-symbolic"); g_signal_connect(ui->profile_update,"clicked",G_CALLBACK(profile_update_clicked),ui);
    ui->profile_rename=make_button("Rename…","document-edit-symbolic"); g_object_set_data(G_OBJECT(ui->profile_rename),"profile-action",GINT_TO_POINTER(3));
    g_signal_connect(ui->profile_rename,"clicked",G_CALLBACK(profile_name_dialog),ui);
    ui->profile_delete=make_button("Delete…","edit-delete-symbolic"); g_signal_connect(ui->profile_delete,"clicked",G_CALLBACK(profile_delete_clicked),ui);
    GtkWidget *profile_buttons[]={save_profile,ui->profile_update,ui->profile_rename,ui->profile_delete};
    for(int i=0;i<4;i++) gtk_flow_box_insert(GTK_FLOW_BOX(profile_actions),profile_buttons[i],-1);
    gtk_box_append(GTK_BOX(profile_content),profile_actions);
    g_signal_connect(ui->rgb_mode,"changed",G_CALLBACK(lighting_changed),ui);
    g_signal_connect(ui->rgb_brightness,"value-changed",G_CALLBACK(lighting_changed),ui);
    g_signal_connect(ui->rgb_speed,"value-changed",G_CALLBACK(lighting_changed),ui);
    g_signal_connect(ui->rgb_direction,"changed",G_CALLBACK(lighting_changed),ui);
    g_signal_connect(ui->rgb_colorful,"notify::active",G_CALLBACK(colorful_changed),ui);
    g_signal_connect(ui->rgb_color,"color-set",G_CALLBACK(lighting_changed),ui);
    ui->launch=current_lighting(ui);

    // Display: exact encoded pixels in a framed screen and on the keyboard.
    GtkWidget *screen_backdrop=vbox_new(12); add_class(screen_backdrop,"stage-backdrop");
    GtkWidget *screen_pair=wrapping_flow(2,20); gtk_box_append(GTK_BOX(screen_backdrop),screen_pair);
    GtkWidget *screen_column=vbox_new(12);
    ui->screen_preview=gtk_picture_new(); gtk_picture_set_content_fit(GTK_PICTURE(ui->screen_preview),GTK_CONTENT_FIT_CONTAIN);
    gtk_picture_set_can_shrink(GTK_PICTURE(ui->screen_preview),TRUE);
    gtk_widget_set_size_request(ui->screen_preview,192,192); gtk_widget_set_halign(ui->screen_preview,GTK_ALIGN_CENTER);
    add_class(ui->screen_preview,"screen-bezel"); gtk_box_append(GTK_BOX(screen_column),ui->screen_preview);
    ui->frame_label=label_new("Exactly what the keyboard screen will show","muted"); gtk_box_append(GTK_BOX(screen_column),ui->frame_label);
    gtk_flow_box_insert(GTK_FLOW_BOX(screen_pair),screen_column,-1);
    ui->screen_stage=keyboard_stage(ui,2,220); gtk_flow_box_insert(GTK_FLOW_BOX(screen_pair),ui->screen_stage,-1);
    GtkWidget *frame_scroll=gtk_scrolled_window_new(); gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(frame_scroll),GTK_POLICY_AUTOMATIC,GTK_POLICY_NEVER);
    ui->frame_strip=wrapping_flow(255,4); gtk_flow_box_set_min_children_per_line(GTK_FLOW_BOX(ui->frame_strip),255);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(frame_scroll),ui->frame_strip);
    gtk_widget_set_size_request(frame_scroll,-1,64);
    g_object_set_data(G_OBJECT(ui->frame_strip),"scroller",frame_scroll);
    gtk_widget_set_visible(frame_scroll,FALSE); gtk_box_append(GTK_BOX(screen_backdrop),frame_scroll);
    gtk_widget_set_visible(ui->frame_strip,FALSE); gtk_box_append(GTK_BOX(pages[2]),screen_backdrop);
    GtkWidget *usb_note=requirement_note("Connect the keyboard with a USB-C cable to use these controls."); gtk_box_append(GTK_BOX(pages[2]),usb_note);
    GtkWidget *picture_content=NULL;
    GtkWidget *picture_panel=make_panel("Picture","PNG, JPEG, GIF, BMP, TIFF or WebP. Shown at 128 × 128.","image-x-generic-symbolic",&picture_content);
    ui->controls[2]=picture_content; gtk_box_append(GTK_BOX(pages[2]),picture_panel);
    ui->selected_image_label=label_new("No file selected","muted");
    gtk_label_set_ellipsize(GTK_LABEL(ui->selected_image_label),PANGO_ELLIPSIZE_MIDDLE); gtk_label_set_wrap(GTK_LABEL(ui->selected_image_label),FALSE);
    ui->choose_image_button=make_button("Choose File…","document-open-symbolic"); g_signal_connect(ui->choose_image_button,"clicked",G_CALLBACK(on_choose_image_clicked),ui);
    GtkWidget *file_row=hbox_new(12); gtk_box_append(GTK_BOX(file_row),ui->selected_image_label); gtk_box_append(GTK_BOX(file_row),ui->choose_image_button);
    gtk_box_append(GTK_BOX(picture_content),file_row);
    ui->display_slot=make_spin(1,255,1); ui->fit_mode=make_combo(fit_values,3,0);
    gtk_box_append(GTK_BOX(picture_content),setting_row("Fit",segments(ui->fit_mode,1,fit_values,3,0))); gtk_box_append(GTK_BOX(picture_content),setting_row("Slot",ui->display_slot));
    g_signal_connect(ui->fit_mode,"changed",G_CALLBACK(fit_changed),ui);
    ui->upload_progress=gtk_progress_bar_new(); gtk_progress_bar_set_show_text(GTK_PROGRESS_BAR(ui->upload_progress),TRUE);
    gtk_box_append(GTK_BOX(picture_content),ui->upload_progress);
    ui->upload_image_button=make_button("Upload to Keyboard","go-down-symbolic"); add_class(ui->upload_image_button,"suggested-action");
    g_signal_connect(ui->upload_image_button,"clicked",G_CALLBACK(on_upload_image_clicked),ui); gtk_box_append(GTK_BOX(picture_content),ui->upload_image_button);
    GtkDropTarget *drop=gtk_drop_target_new(G_TYPE_FILE,GDK_ACTION_COPY); g_signal_connect(drop,"drop",G_CALLBACK(image_dropped),ui);
    gtk_widget_add_controller(pages[2],GTK_EVENT_CONTROLLER(drop));
    GtkWidget *clock_content=NULL; GtkWidget *clock_panel=make_panel("Screen clock","Wired operations require the keyboard over USB-C","preferences-system-time-symbolic",&clock_content);
    GtkWidget *clock_button=make_button("Sync Clock","view-refresh-symbolic");
    g_signal_connect(clock_button,"clicked",G_CALLBACK(on_sync_time_clicked),ui); gtk_box_append(GTK_BOX(clock_content),clock_button); gtk_box_append(GTK_BOX(pages[2]),clock_panel);
    ui->controls[3]=clock_content;

    GtkWidget *performance_note=requirement_note("Plug in the 2.4G receiver to use these controls."); gtk_box_append(GTK_BOX(pages[3]),performance_note);
    GtkWidget *performance_columns=wrapping_flow(2,16); gtk_box_append(GTK_BOX(pages[3]),performance_columns);
    GtkWidget *typing=NULL; GtkWidget *typing_panel=make_panel("Typing","Changes are sent when you press Apply.","input-keyboard-symbolic",&typing);
    ui->controls[4]=typing; gtk_flow_box_insert(GTK_FLOW_BOX(performance_columns),typing_panel,-1);
    ui->response_level=make_combo(responses,5,0); ui->sleep_time=make_combo(sleep_values,4,1);
    gtk_box_append(GTK_BOX(typing),setting_row("Key response",ui->response_level)); gtk_box_append(GTK_BOX(typing),setting_row("Sleep after",segments(ui->sleep_time,1,sleep_values,4,0)));
    ui->apply_performance_button=make_button("Apply","emblem-ok-symbolic"); add_class(ui->apply_performance_button,"suggested-action");
    g_signal_connect(ui->apply_performance_button,"clicked",G_CALLBACK(on_apply_performance_clicked),ui); gtk_box_append(GTK_BOX(typing),ui->apply_performance_button);
    GtkWidget *game=NULL; GtkWidget *game_panel=make_panel("Game Mode","Locks the Windows/Super key. Also sends the Typing settings above.","input-gaming-symbolic",&game);
    ui->controls[5]=game; gtk_flow_box_insert(GTK_FLOW_BOX(performance_columns),game_panel,-1);
    ui->game_mode_button=make_button("Enable Game Mode","changes-prevent-symbolic"); g_signal_connect(ui->game_mode_button,"clicked",G_CALLBACK(on_game_mode_clicked),ui);
    ui->restore_command_button=make_button("Restore Windows/Super Key","edit-undo-symbolic"); g_signal_connect(ui->restore_command_button,"clicked",G_CALLBACK(on_restore_command_clicked),ui);
    gtk_box_append(GTK_BOX(game),ui->game_mode_button); gtk_box_append(GTK_BOX(game),ui->restore_command_button);

    create_updates(pages[4],detail,ui);
    GtkWidget *general=NULL; GtkWidget *general_panel=make_panel("General","Language","emblem-system-symbolic",&general); gtk_box_append(GTK_BOX(pages[4]),general_panel);
    ui->language_combo=gtk_combo_box_text_new(); append_language_items(GTK_COMBO_BOX_TEXT(ui->language_combo));
    char language[32]={0}; aula_linux_current_language_code(language,sizeof(language)); ui->selected_language_index=language_index_for_code(language);
    gtk_combo_box_set_active(GTK_COMBO_BOX(ui->language_combo),ui->selected_language_index); g_signal_connect(ui->language_combo,"changed",G_CALLBACK(on_language_changed),ui);
    gtk_box_append(GTK_BOX(general),setting_row("Language",ui->language_combo));
    GtkWidget *danger=NULL; GtkWidget *danger_panel=make_panel("Danger Zone","Clears uploaded screen images and resets keyboard settings changed by this app.","dialog-warning-symbolic",&danger);
    ui->factory_reset_button=make_button("Factory Reset Keyboard…","edit-delete-symbolic"); add_class(ui->factory_reset_button,"destructive-action");
    g_signal_connect(ui->factory_reset_button,"clicked",G_CALLBACK(confirm_reset),ui);
    gtk_box_append(GTK_BOX(danger),ui->factory_reset_button); gtk_box_append(GTK_BOX(pages[4]),danger_panel);
    GtkWidget *endpoints=NULL; GtkWidget *endpoint_panel=make_panel("Connections","Diagnostic view for permissions and transport troubleshooting","network-transmit-receive-symbolic",&endpoints);
    GtkWidget *rescan=make_button("Rescan","view-refresh-symbolic"); g_signal_connect(rescan,"clicked",G_CALLBACK(on_rescan_clicked),ui); gtk_box_append(GTK_BOX(endpoints),rescan);
    gtk_box_append(GTK_BOX(endpoints),label_new("Linux udev hidraw access is required for keyboard commands.","muted"));
    GtkWidget *endpoint_view=gtk_text_view_new(); gtk_text_view_set_editable(GTK_TEXT_VIEW(endpoint_view),FALSE); gtk_text_view_set_monospace(GTK_TEXT_VIEW(endpoint_view),TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(endpoint_view),GTK_WRAP_WORD_CHAR); ui->endpoint_buffer=gtk_text_view_get_buffer(GTK_TEXT_VIEW(endpoint_view));
    GtkWidget *endpoint_scroll=gtk_scrolled_window_new(); gtk_widget_set_size_request(endpoint_scroll,-1,260);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(endpoint_scroll),endpoint_view); gtk_box_append(GTK_BOX(endpoints),endpoint_scroll); gtk_box_append(GTK_BOX(pages[5]),endpoint_panel);

    GtkWidget *log_header=hbox_new(12); ui->log_count=label_new("0 entries","muted"); gtk_box_append(GTK_BOX(log_header),ui->log_count);
    GtkWidget *copy=make_button("Copy Log","edit-copy-symbolic"); g_signal_connect(copy,"clicked",G_CALLBACK(copy_log),ui); gtk_box_append(GTK_BOX(log_header),copy);
    gtk_box_append(GTK_BOX(pages[6]),log_header);
    GtkWidget *log_scroll=gtk_scrolled_window_new(); gtk_widget_set_vexpand(log_scroll,TRUE); gtk_widget_set_size_request(log_scroll,-1,320);
    ui->log_view=GTK_TEXT_VIEW(gtk_text_view_new()); gtk_text_view_set_editable(ui->log_view,FALSE); gtk_text_view_set_monospace(ui->log_view,TRUE);
    gtk_text_view_set_wrap_mode(ui->log_view,GTK_WRAP_WORD_CHAR); ui->log_buffer=gtk_text_view_get_buffer(ui->log_view);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(log_scroll),GTK_WIDGET(ui->log_view)); gtk_box_append(GTK_BOX(pages[6]),log_scroll);
    g_object_set_data(G_OBJECT(ui->wired_detail),"requirement-note",usb_note);
    g_object_set_data(G_OBJECT(ui->dongle_detail),"requirement-note",receiver_note);
    g_object_set_data(G_OBJECT(ui->dongle_detail),"performance-note",performance_note);
    g_object_set_data(G_OBJECT(ui->sync_button),"screen-clock",clock_button);
    gtk_list_box_select_row(GTK_LIST_BOX(navigation),gtk_list_box_get_row_at_index(GTK_LIST_BOX(navigation),0));
    append_log(ui,L("Linux app started.")); refresh_endpoints(ui,FALSE);
    update_lighting_preview(ui); refresh_profiles(ui);
    ui->animation_timer=g_timeout_add(50,animate_previews,ui);
    ui->refresh_timer_id=g_timeout_add_seconds(2,poll_devices,ui);
    g_object_set_data_full(G_OBJECT(window),"aula-ui",ui,destroy_ui);
    gtk_window_present(ui->window);
}

int aula_linux_app_run(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("vitalyart.aula-f75-max-driver", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
