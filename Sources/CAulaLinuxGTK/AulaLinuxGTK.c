#include "CAulaLinuxGTK.h"

#include <gtk/gtk.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef __clang__
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif

extern void aula_linux_refresh(char *buffer, int capacity);
extern void aula_linux_query_battery(char *buffer, int capacity);
extern void aula_linux_sync_time(char *buffer, int capacity);
extern void aula_linux_factory_reset(char *buffer, int capacity);
extern void aula_linux_upload_display(char *buffer, int capacity, const unsigned char *bytes, int length, int slot);
extern void aula_linux_endpoint_counts(int *wired, int *dongle);
extern void aula_linux_apply_rgb(char *buffer, int capacity, int mode, int brightness, int speed, int direction, int colorful, int color);
extern void aula_linux_apply_performance(char *buffer, int capacity, int level, int sleep_time);
extern void aula_linux_restore_command(char *buffer, int capacity, int level, int sleep_time);
extern void aula_linux_set_game_mode(char *buffer, int capacity, int enabled, int level, int sleep_time);

typedef struct {
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

static void add_class(GtkWidget *widget, const char *css_class) {
    gtk_widget_add_css_class(widget, css_class);
}

static GtkWidget *label_new(const char *text, const char *css_class) {
    GtkWidget *label = gtk_label_new(text);
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
    gtk_box_append(GTK_BOX(content), gtk_label_new(title));
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
    gtk_box_append(GTK_BOX(title_box), label_new(subtitle, "muted"));
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
    GtkWidget *detail = label_new("Waiting for scan", "muted");
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
        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo), items[i]);
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
    gtk_widget_set_size_request(label, 128, -1);
    gtk_box_append(GTK_BOX(row), label);
    gtk_box_append(GTK_BOX(row), control);
    return row;
}

static void append_log(AulaLinuxUI *ui, const char *message) {
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(ui->log_buffer, &end);
    gtk_text_buffer_insert(ui->log_buffer, &end, message, -1);
    gtk_text_buffer_insert(ui->log_buffer, &end, "\n", -1);
}

static void run_buffer_action(AulaLinuxUI *ui, void (*action)(char *, int), char *out, int capacity) {
    memset(out, 0, (size_t)capacity);
    action(out, capacity);
    append_log(ui, out[0] == '\0' ? "No output." : out);
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
    snprintf(value, sizeof(value), "%d endpoint%s", ui->wired_count, ui->wired_count == 1 ? "" : "s");
    gtk_label_set_text(GTK_LABEL(ui->wired_value), ui->wired_count > 0 ? value : "Not connected");
    gtk_label_set_text(GTK_LABEL(ui->wired_detail), ui->wired_count > 0 ? "Ready for clock sync" : "Connect the keyboard by USB-C");

    snprintf(value, sizeof(value), "%d endpoint%s", ui->dongle_count, ui->dongle_count == 1 ? "" : "s");
    gtk_label_set_text(GTK_LABEL(ui->dongle_value), ui->dongle_count > 0 ? value : "Not connected");
    gtk_label_set_text(GTK_LABEL(ui->dongle_detail), ui->dongle_count > 0 ? "Ready for battery, RGB and performance" : "Plug in the 2.4G receiver");

    gtk_label_set_text(GTK_LABEL(ui->ready_pill), (ui->wired_count > 0 || ui->dongle_count > 0) ? "Ready" : "Waiting for device");
    gtk_label_set_text(GTK_LABEL(ui->battery_detail), ui->dongle_count > 0 ? "Query over the 2.4G receiver" : "Battery needs the 2.4G receiver");

    gtk_widget_set_sensitive(ui->sync_button, ui->wired_count > 0);
    gtk_widget_set_sensitive(ui->factory_reset_button, ui->wired_count > 0);
    gtk_widget_set_sensitive(ui->upload_image_button, ui->wired_count > 0 && ui->selected_image_path != NULL);
    gtk_widget_set_sensitive(ui->battery_button, ui->dongle_count > 0);
    gtk_widget_set_sensitive(ui->apply_rgb_button, ui->dongle_count > 0);
    gtk_widget_set_sensitive(ui->apply_performance_button, ui->dongle_count > 0);
    gtk_widget_set_sensitive(ui->restore_command_button, ui->dongle_count > 0);
    gtk_widget_set_sensitive(ui->game_mode_button, ui->dongle_count > 0);
}

static gboolean refresh_status(AulaLinuxUI *ui) {
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
        gtk_label_set_text(GTK_LABEL(ui->battery_value), "Unknown");
    }

    update_status_widgets(ui);
    return changed;
}

static void refresh_endpoints(AulaLinuxUI *ui, gboolean log_result) {
    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    aula_linux_refresh(buffer, (int)sizeof(buffer));
    gtk_text_buffer_set_text(ui->endpoint_buffer, buffer[0] == '\0' ? "No output." : buffer, -1);
    if (log_result) {
        append_log(ui, buffer[0] == '\0' ? "Rescan finished." : buffer);
    }
    refresh_status(ui);
}

static gboolean query_battery(AulaLinuxUI *ui, gboolean log_result) {
    if (ui->dongle_count <= 0) {
        ui->battery_percent = -1;
        gtk_label_set_text(GTK_LABEL(ui->battery_value), "Unknown");
        return FALSE;
    }

    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    aula_linux_query_battery(buffer, (int)sizeof(buffer));

    int percent = -1;
    gboolean ok = sscanf(buffer, "Battery: %d%%", &percent) == 1 && percent >= 0;
    if (ok) {
        char text[16];
        snprintf(text, sizeof(text), "%d%%", percent);
        gtk_label_set_text(GTK_LABEL(ui->battery_value), text);
        if (log_result || ui->battery_percent != percent) {
            append_log(ui, buffer[0] == '\0' ? "Battery updated." : buffer);
        }
        ui->battery_percent = percent;
        ui->last_battery_query_usec = g_get_monotonic_time();
        return TRUE;
    }

    gtk_label_set_text(GTK_LABEL(ui->battery_value), "Unknown");
    if (log_result) {
        append_log(ui, buffer[0] == '\0' ? "Battery query returned no output." : buffer);
    }
    ui->last_battery_query_usec = g_get_monotonic_time();
    return FALSE;
}

static gboolean poll_devices(gpointer user_data) {
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
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
    if (file == NULL) {
        if (error != NULL) {
            if (!g_error_matches(error, GTK_DIALOG_ERROR, GTK_DIALOG_ERROR_DISMISSED)) {
                append_log(ui, error->message);
            }
            g_error_free(error);
        }
        return;
    }

    char *path = g_file_get_path(file);
    if (path != NULL) {
        g_free(ui->selected_image_path);
        ui->selected_image_path = path;
        char *basename = g_path_get_basename(path);
        gtk_label_set_text(GTK_LABEL(ui->selected_image_label), basename != NULL ? basename : path);
        g_free(basename);
        append_log(ui, "Selected image for keyboard screen upload.");
        update_status_widgets(ui);
    }
    g_object_unref(file);
}

static void on_choose_image_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    GtkFileDialog *dialog = gtk_file_dialog_new();
    gtk_file_dialog_set_title(dialog, "Choose keyboard screen image");
    gtk_file_dialog_open(dialog, NULL, NULL, on_choose_image_done, ui);
    g_object_unref(dialog);
}

static void on_upload_image_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    if (ui->selected_image_path == NULL) {
        append_log(ui, "Select an image first.");
        return;
    }

    int fit = selected_index(ui->fit_mode, 0);
    int slot = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(ui->display_slot));
    unsigned char *stream = NULL;
    int stream_length = 0;
    char encode_error[512];
    encode_error[0] = '\0';
    if (!encode_display_image(ui->selected_image_path, fit, &stream, &stream_length, encode_error, sizeof(encode_error))) {
        append_log(ui, encode_error[0] == '\0' ? "Failed to encode image." : encode_error);
        return;
    }

    char encoded_message[96];
    snprintf(encoded_message, sizeof(encoded_message), "Encoded %u frame(s), %d byte stream.", (unsigned int)stream[0], stream_length);
    append_log(ui, encoded_message);

    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    aula_linux_upload_display(buffer, (int)sizeof(buffer), stream, stream_length, slot);
    append_log(ui, buffer[0] == '\0' ? "No output." : buffer);
    g_free(stream);
    refresh_status(ui);
}

static void on_sync_time_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    char buffer[8192];
    run_buffer_action(ui, aula_linux_sync_time, buffer, (int)sizeof(buffer));
    refresh_status(ui);
}

static void on_factory_reset_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    char buffer[8192];
    run_buffer_action(ui, aula_linux_factory_reset, buffer, (int)sizeof(buffer));
    refresh_status(ui);
}

static void on_apply_rgb_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    char buffer[8192];
    int mode = selected_index(ui->rgb_mode, 11);
    int brightness = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(ui->rgb_brightness));
    int speed = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(ui->rgb_speed));
    int direction = selected_index(ui->rgb_direction, 0);
    int colorful = gtk_switch_get_active(GTK_SWITCH(ui->rgb_colorful)) ? 1 : 0;
    int color = selected_color(ui->rgb_color);

    memset(buffer, 0, sizeof(buffer));
    aula_linux_apply_rgb(buffer, (int)sizeof(buffer), mode, brightness, speed, direction, colorful, color);
    append_log(ui, buffer[0] == '\0' ? "No output." : buffer);
    refresh_status(ui);
}

static int current_response_level(AulaLinuxUI *ui) {
    return selected_index(ui->response_level, 0) + 1;
}

static int current_sleep_time(AulaLinuxUI *ui) {
    return selected_index(ui->sleep_time, 1);
}

static void on_apply_performance_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    aula_linux_apply_performance(buffer, (int)sizeof(buffer), current_response_level(ui), current_sleep_time(ui));
    append_log(ui, buffer[0] == '\0' ? "No output." : buffer);
    refresh_status(ui);
}

static void on_restore_command_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    aula_linux_restore_command(buffer, (int)sizeof(buffer), current_response_level(ui), current_sleep_time(ui));
    append_log(ui, buffer[0] == '\0' ? "No output." : buffer);
    refresh_status(ui);
}

static void on_game_mode_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AulaLinuxUI *ui = (AulaLinuxUI *)user_data;
    char buffer[8192];
    ui->game_mode_enabled = !ui->game_mode_enabled;
    memset(buffer, 0, sizeof(buffer));
    aula_linux_set_game_mode(buffer, (int)sizeof(buffer), ui->game_mode_enabled ? 1 : 0, current_response_level(ui), current_sleep_time(ui));
    append_log(ui, buffer[0] == '\0' ? "No output." : buffer);
    gtk_button_set_label(GTK_BUTTON(ui->game_mode_button), ui->game_mode_enabled ? "Disable Game Mode" : "Enable Game Mode");
    refresh_status(ui);
}

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
        "window { background: #111617; color: #f4f2ed; }"
        ".page { padding: 24px; }"
        ".hero-title { font-size: 34px; font-weight: 900; color: #ffffff; }"
        ".subtitle, .muted { color: rgba(244,242,237,0.62); font-size: 12px; }"
        ".ready-pill { color: #6ee7a8; background: rgba(36, 146, 91, 0.16); border: 1px solid rgba(110,231,168,0.32); border-radius: 999px; padding: 8px 14px; font-weight: 700; }"
        ".status-card, .panel { background: rgba(255,255,255,0.075); border: 1px solid rgba(255,255,255,0.13); border-radius: 14px; padding: 16px; }"
        ".panel-title { font-size: 17px; font-weight: 800; color: #ffffff; }"
        ".eyebrow { color: rgba(244,242,237,0.58); font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.04em; }"
        ".status-value { font-size: 22px; font-weight: 900; color: #ffffff; }"
        ".icon-box { background: rgba(245,146,65,0.14); border-radius: 10px; padding: 9px; color: #f59a42; }"
        ".status-icon { background: rgba(47, 163, 138, 0.16); color: #65d6bd; }"
        ".accent-icon { background: rgba(245,146,65,0.15); color: #f59a42; }"
        ".setting-label { color: rgba(244,242,237,0.78); font-weight: 700; }"
        ".section-title { color: #ffffff; font-weight: 800; font-size: 14px; }"
        ".warning-box { background: rgba(245,146,65,0.10); border: 1px solid rgba(245,146,65,0.22); border-radius: 10px; padding: 12px; }"
        "button { border-radius: 9px; padding: 8px 12px; }"
        "button.suggested-action { background: #d97828; color: #ffffff; }"
        "textview, textview text { background: rgba(0,0,0,0.22); color: rgba(244,242,237,0.82); font-family: monospace; }";
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
    g_free(ui->selected_image_path);
    g_free(ui);
}

static void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;
    install_css();
    install_icon_search_path();

    AulaLinuxUI *ui = g_new0(AulaLinuxUI, 1);
    ui->battery_percent = -1;

    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Aula F75 Max Driver");
    gtk_window_set_icon_name(GTK_WINDOW(window), "aula-f75-max-driver");
    gtk_window_set_default_size(GTK_WINDOW(window), 1180, 820);

    GtkWidget *scroller = gtk_scrolled_window_new();
    gtk_window_set_child(GTK_WINDOW(window), scroller);

    GtkWidget *page = vbox_new(22);
    add_class(page, "page");
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), page);

    GtkWidget *header = hbox_new(18);
    GtkWidget *header_text = vbox_new(6);
    gtk_box_append(GTK_BOX(header_text), label_new("Aula F75 Max Driver", "hero-title"));
    gtk_box_append(GTK_BOX(header_text), label_new("Linux control surface for wired display tasks and 2.4G keyboard settings.", "subtitle"));
    gtk_box_append(GTK_BOX(header), header_text);
    ui->ready_pill = gtk_label_new("Waiting for device");
    add_class(ui->ready_pill, "ready-pill");
    gtk_widget_set_halign(ui->ready_pill, GTK_ALIGN_END);
    gtk_widget_set_valign(ui->ready_pill, GTK_ALIGN_CENTER);
    gtk_widget_set_hexpand(ui->ready_pill, FALSE);
    gtk_box_append(GTK_BOX(header), ui->ready_pill);
    gtk_box_append(GTK_BOX(page), header);

    GtkWidget *status_grid = gtk_grid_new();
    gtk_grid_set_column_spacing(GTK_GRID(status_grid), 14);
    gtk_grid_set_column_homogeneous(GTK_GRID(status_grid), TRUE);
    gtk_widget_set_hexpand(status_grid, TRUE);
    gtk_grid_attach(GTK_GRID(status_grid), make_status_card("Wired USB", "network-wired-symbolic", &ui->wired_value, &ui->wired_detail), 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(status_grid), make_status_card("2.4G Dongle", "network-wireless-symbolic", &ui->dongle_value, &ui->dongle_detail), 1, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(status_grid), make_status_card("Battery", "battery-good-symbolic", &ui->battery_value, &ui->battery_detail), 2, 0, 1, 1);
    gtk_label_set_text(GTK_LABEL(ui->battery_value), "Unknown");
    gtk_box_append(GTK_BOX(page), status_grid);

    GtkWidget *main_grid = gtk_grid_new();
    gtk_grid_set_column_spacing(GTK_GRID(main_grid), 18);
    gtk_grid_set_row_spacing(GTK_GRID(main_grid), 18);
    gtk_grid_set_column_homogeneous(GTK_GRID(main_grid), TRUE);
    gtk_widget_set_hexpand(main_grid, TRUE);
    gtk_box_append(GTK_BOX(page), main_grid);

    GtkWidget *wired_content = NULL;
    GtkWidget *wired_panel = make_panel("USB Screen Workflow", "Wired operations require the keyboard over USB-C", "video-display-symbolic", &wired_content);
    ui->sync_button = make_button("Sync Clock", "view-refresh-symbolic");
    gtk_widget_add_css_class(ui->sync_button, "suggested-action");
    g_signal_connect(ui->sync_button, "clicked", G_CALLBACK(on_sync_time_clicked), ui);
    gtk_box_append(GTK_BOX(wired_content), ui->sync_button);

    gtk_box_append(GTK_BOX(wired_content), label_new("Screen upload", "section-title"));

    GtkWidget *file_row = hbox_new(10);
    ui->choose_image_button = make_button("Choose File", "document-open-symbolic");
    g_signal_connect(ui->choose_image_button, "clicked", G_CALLBACK(on_choose_image_clicked), ui);
    gtk_box_append(GTK_BOX(file_row), ui->choose_image_button);
    ui->selected_image_label = label_new("No file selected", "muted");
    gtk_widget_set_hexpand(ui->selected_image_label, TRUE);
    gtk_box_append(GTK_BOX(file_row), ui->selected_image_label);
    gtk_box_append(GTK_BOX(wired_content), file_row);

    ui->display_slot = make_spin(1, 255, 1);
    ui->fit_mode = make_combo(fit_values, 3, 0);
    gtk_box_append(GTK_BOX(wired_content), setting_row("Slot", ui->display_slot));
    gtk_box_append(GTK_BOX(wired_content), setting_row("Fit", ui->fit_mode));

    ui->upload_image_button = make_button("Upload to Keyboard Screen", "go-down-symbolic");
    gtk_widget_add_css_class(ui->upload_image_button, "suggested-action");
    g_signal_connect(ui->upload_image_button, "clicked", G_CALLBACK(on_upload_image_clicked), ui);
    gtk_box_append(GTK_BOX(wired_content), ui->upload_image_button);

    ui->factory_reset_button = make_button("Factory Reset Keyboard", "edit-delete-symbolic");
    g_signal_connect(ui->factory_reset_button, "clicked", G_CALLBACK(on_factory_reset_clicked), ui);
    gtk_box_append(GTK_BOX(wired_content), ui->factory_reset_button);

    gtk_grid_attach(GTK_GRID(main_grid), wired_panel, 0, 0, 1, 1);

    GtkWidget *wireless_content = NULL;
    GtkWidget *wireless_panel = make_panel("2.4G Keyboard Control", "Battery, RGB, latency and game lockout settings", "input-keyboard-symbolic", &wireless_content);

    GtkWidget *battery_row = hbox_new(12);
    ui->battery_button = make_button("Query Battery", "view-refresh-symbolic");
    g_signal_connect(ui->battery_button, "clicked", G_CALLBACK(on_battery_clicked), ui);
    gtk_box_append(GTK_BOX(battery_row), ui->battery_button);
    gtk_box_append(GTK_BOX(wireless_content), battery_row);

    gtk_box_append(GTK_BOX(wireless_content), label_new("RGB lighting", "section-title"));
    ui->rgb_mode = make_combo(rgb_modes, (int)(sizeof(rgb_modes) / sizeof(rgb_modes[0])), 11);
    ui->rgb_brightness = make_spin(1, 5, 5);
    ui->rgb_speed = make_spin(1, 5, 3);
    ui->rgb_direction = make_combo(directions, 4, 0);
    ui->rgb_colorful = gtk_switch_new();
    gtk_switch_set_active(GTK_SWITCH(ui->rgb_colorful), TRUE);
    ui->rgb_color = gtk_color_button_new();
    GdkRGBA default_color = { 0.29, 0.56, 0.89, 1.0 };
    gtk_color_chooser_set_rgba(GTK_COLOR_CHOOSER(ui->rgb_color), &default_color);
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Mode", ui->rgb_mode));
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Brightness", ui->rgb_brightness));
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Speed", ui->rgb_speed));
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Direction", ui->rgb_direction));
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Colorful", ui->rgb_colorful));
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Fixed color", ui->rgb_color));
    ui->apply_rgb_button = make_button("Apply RGB Profile", "color-select-symbolic");
    gtk_widget_add_css_class(ui->apply_rgb_button, "suggested-action");
    g_signal_connect(ui->apply_rgb_button, "clicked", G_CALLBACK(on_apply_rgb_clicked), ui);
    gtk_box_append(GTK_BOX(wireless_content), ui->apply_rgb_button);

    gtk_box_append(GTK_BOX(wireless_content), label_new("Performance", "section-title"));
    ui->response_level = make_combo(responses, 5, 0);
    ui->sleep_time = make_combo(sleep_values, 4, 1);
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Response", ui->response_level));
    gtk_box_append(GTK_BOX(wireless_content), setting_row("Sleep", ui->sleep_time));

    GtkWidget *perf_actions = hbox_new(10);
    ui->apply_performance_button = make_button("Apply", "emblem-ok-symbolic");
    ui->restore_command_button = make_button("Restore Command", "edit-undo-symbolic");
    g_signal_connect(ui->apply_performance_button, "clicked", G_CALLBACK(on_apply_performance_clicked), ui);
    g_signal_connect(ui->restore_command_button, "clicked", G_CALLBACK(on_restore_command_clicked), ui);
    gtk_box_append(GTK_BOX(perf_actions), ui->apply_performance_button);
    gtk_box_append(GTK_BOX(perf_actions), ui->restore_command_button);
    gtk_box_append(GTK_BOX(wireless_content), perf_actions);

    ui->game_mode_button = gtk_button_new_with_label("Enable Game Mode");
    gtk_widget_add_css_class(ui->game_mode_button, "suggested-action");
    g_signal_connect(ui->game_mode_button, "clicked", G_CALLBACK(on_game_mode_clicked), ui);
    gtk_box_append(GTK_BOX(wireless_content), ui->game_mode_button);
    gtk_grid_attach(GTK_GRID(main_grid), wireless_panel, 1, 0, 1, 2);

    GtkWidget *endpoint_content = NULL;
    GtkWidget *endpoint_panel = make_panel("Detected HID Endpoints", "Diagnostic view for permissions and transport troubleshooting", "network-transmit-receive-symbolic", &endpoint_content);
    GtkWidget *rescan = make_button("Rescan", "view-refresh-symbolic");
    g_signal_connect(rescan, "clicked", G_CALLBACK(on_rescan_clicked), ui);
    gtk_box_append(GTK_BOX(endpoint_content), rescan);
    GtkWidget *endpoint_scroller = gtk_scrolled_window_new();
    gtk_widget_set_size_request(endpoint_scroller, -1, 220);
    GtkWidget *endpoint_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(endpoint_view), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(endpoint_view), TRUE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(endpoint_scroller), endpoint_view);
    ui->endpoint_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(endpoint_view));
    gtk_box_append(GTK_BOX(endpoint_content), endpoint_scroller);
    gtk_grid_attach(GTK_GRID(main_grid), endpoint_panel, 0, 1, 1, 1);

    GtkWidget *log_content = NULL;
    GtkWidget *log_panel = make_panel("Operation Log", "Latest command output", "utilities-terminal-symbolic", &log_content);
    GtkWidget *log_scroller = gtk_scrolled_window_new();
    gtk_widget_set_size_request(log_scroller, -1, 150);
    GtkWidget *log_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(log_view), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(log_view), TRUE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(log_scroller), log_view);
    ui->log_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(log_view));
    gtk_box_append(GTK_BOX(log_content), log_scroller);
    gtk_box_append(GTK_BOX(page), log_panel);

    append_log(ui, "Linux app started.");
    refresh_endpoints(ui, FALSE);
    if (ui->dongle_count > 0) {
        query_battery(ui, TRUE);
    }
    ui->refresh_timer_id = g_timeout_add_seconds(2, poll_devices, ui);

    g_object_set_data_full(G_OBJECT(window), "aula-ui", ui, destroy_ui);
    gtk_window_present(GTK_WINDOW(window));
}

int aula_linux_app_run(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("art.vitaly.aula-f75-max-driver", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
