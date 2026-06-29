#include "CAulaLinuxGTK.h"

#include <gtk/gtk.h>
#include <stdio.h>
#include <string.h>

extern void aula_linux_refresh(char *buffer, int capacity);
extern void aula_linux_query_battery(char *buffer, int capacity);
extern void aula_linux_sync_time(char *buffer, int capacity);
extern void aula_linux_apply_rgb(char *buffer, int capacity);
extern void aula_linux_apply_performance(char *buffer, int capacity);
extern void aula_linux_game_mode_off(char *buffer, int capacity);

typedef struct {
    GtkTextBuffer *log_buffer;
} AulaLinuxUI;

static void append_log(AulaLinuxUI *ui, const char *message) {
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(ui->log_buffer, &end);
    gtk_text_buffer_insert(ui->log_buffer, &end, message, -1);
    gtk_text_buffer_insert(ui->log_buffer, &end, "\n", -1);
}

static void run_action(AulaLinuxUI *ui, void (*action)(char *, int)) {
    char buffer[8192];
    memset(buffer, 0, sizeof(buffer));
    action(buffer, (int)sizeof(buffer));
    append_log(ui, buffer[0] == '\0' ? "No output." : buffer);
}

static void on_refresh_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    run_action((AulaLinuxUI *)user_data, aula_linux_refresh);
}

static void on_battery_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    run_action((AulaLinuxUI *)user_data, aula_linux_query_battery);
}

static void on_sync_time_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    run_action((AulaLinuxUI *)user_data, aula_linux_sync_time);
}

static void on_rgb_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    run_action((AulaLinuxUI *)user_data, aula_linux_apply_rgb);
}

static void on_performance_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    run_action((AulaLinuxUI *)user_data, aula_linux_apply_performance);
}

static void on_game_mode_off_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    run_action((AulaLinuxUI *)user_data, aula_linux_game_mode_off);
}

static GtkWidget *make_button(const char *title, GCallback callback, AulaLinuxUI *ui) {
    GtkWidget *button = gtk_button_new_with_label(title);
    gtk_widget_set_hexpand(button, TRUE);
    g_signal_connect(button, "clicked", callback, ui);
    return button;
}

static void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    AulaLinuxUI *ui = g_new0(AulaLinuxUI, 1);

    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Aula F75 Max Driver");
    gtk_window_set_default_size(GTK_WINDOW(window), 920, 680);

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
    gtk_widget_set_margin_top(box, 18);
    gtk_widget_set_margin_bottom(box, 18);
    gtk_widget_set_margin_start(box, 18);
    gtk_widget_set_margin_end(box, 18);
    gtk_window_set_child(GTK_WINDOW(window), box);

    GtkWidget *title = gtk_label_new("Aula F75 Max Driver for Linux");
    gtk_widget_add_css_class(title, "title-1");
    gtk_box_append(GTK_BOX(box), title);

    GtkWidget *subtitle = gtk_label_new("Native GTK Linux app using hidapi/hidraw. Install the udev rule before running device commands.");
    gtk_label_set_wrap(GTK_LABEL(subtitle), TRUE);
    gtk_box_append(GTK_BOX(box), subtitle);

    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 10);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 10);
    gtk_box_append(GTK_BOX(box), grid);

    gtk_grid_attach(GTK_GRID(grid), make_button("Refresh endpoints", G_CALLBACK(on_refresh_clicked), ui), 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), make_button("Query battery", G_CALLBACK(on_battery_clicked), ui), 1, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), make_button("Sync display clock", G_CALLBACK(on_sync_time_clicked), ui), 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), make_button("Apply default RGB", G_CALLBACK(on_rgb_clicked), ui), 1, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), make_button("Performance level 1", G_CALLBACK(on_performance_clicked), ui), 0, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), make_button("Game mode off", G_CALLBACK(on_game_mode_off_clicked), ui), 1, 2, 1, 1);

    GtkWidget *scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_box_append(GTK_BOX(box), scrolled);

    GtkWidget *text_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(text_view), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(text_view), TRUE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), text_view);
    ui->log_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));

    append_log(ui, "Linux app started.");
    run_action(ui, aula_linux_refresh);

    g_object_set_data_full(G_OBJECT(window), "aula-ui", ui, g_free);
    gtk_window_present(GTK_WINDOW(window));
}

int aula_linux_app_run(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("art.vitaly.aula-f75-max-driver", G_APPLICATION_FLAGS_NONE);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
