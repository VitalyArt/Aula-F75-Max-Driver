#ifndef CAULA_LINUX_GTK_H
#define CAULA_LINUX_GTK_H

void aula_linux_report_upload_progress(void *context, int sent, int total);

int aula_linux_app_run(int argc, char **argv);
void aula_linux_load_language(char *buffer, int capacity);
void aula_linux_store_language(const char *language_code);

#endif
