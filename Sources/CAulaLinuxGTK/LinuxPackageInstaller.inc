/* PackageKit owns privilege elevation and package transactions. No shell or sudo. */
extern void aula_updates_install_finished(int success);
typedef struct {
    gint refs;
    GDBusConnection *bus;
    char *transaction;
    char *file;
    guint subscription, timeout;
    gboolean finished, failed;
} AulaPackageInstall;
static AulaPackageInstall *package_ref(AulaPackageInstall *job) { g_atomic_int_inc(&job->refs); return job; }
static void package_unref(gpointer data) {
    AulaPackageInstall *job=data;
    if(g_atomic_int_dec_and_test(&job->refs)) {
        g_clear_object(&job->bus); g_free(job->transaction); g_free(job->file); g_free(job);
    }
}
static void package_finish(AulaPackageInstall *job,int result) {
    if(job->finished) return;
    job->finished=TRUE;
    if(job->subscription) { g_dbus_connection_signal_unsubscribe(job->bus,job->subscription); job->subscription=0; }
    if(job->timeout) { g_source_remove(job->timeout); job->timeout=0; }
    aula_updates_install_finished(result);
}
static gboolean package_timeout(gpointer data) {
    AulaPackageInstall *job=package_ref(data);
    package_finish(job,FALSE); package_unref(job); return G_SOURCE_REMOVE;
}
static void package_signal(GDBusConnection *bus,const char *sender,const char *path,const char *interface,const char *signal,GVariant *parameters,gpointer data) {
    AulaPackageInstall *job=package_ref(data);
    if(!strcmp(signal,"ErrorCode")) job->failed=TRUE;
    else if(!strcmp(signal,"Finished")) {
        guint exit_code, runtime;
        g_variant_get(parameters,"(uu)",&exit_code,&runtime);
        package_finish(job,exit_code==1 && !job->failed);
    }
    package_unref(job);
}
static void package_install_reply(GObject *source,GAsyncResult *result,gpointer data) {
    AulaPackageInstall *job=data; GError *error=NULL;
    GVariant *reply=g_dbus_connection_call_finish(G_DBUS_CONNECTION(source),result,&error);
    if(!reply) package_finish(job,FALSE);
    if(reply) g_variant_unref(reply);
    g_clear_error(&error); package_unref(job);
}
static void package_hints_reply(GObject *source,GAsyncResult *result,gpointer data) {
    AulaPackageInstall *job=data; GError *error=NULL;
    GVariant *reply=g_dbus_connection_call_finish(G_DBUS_CONNECTION(source),result,&error);
    if(!reply) package_finish(job,FALSE);
    else if(!job->finished) {
        const char *files[]={job->file,NULL};
        g_dbus_connection_call(job->bus,"org.freedesktop.PackageKit",job->transaction,"org.freedesktop.PackageKit.Transaction","InstallFiles",
            g_variant_new("(t^as)",(guint64)0,files),NULL,G_DBUS_CALL_FLAGS_ALLOW_INTERACTIVE_AUTHORIZATION,300000,NULL,package_install_reply,package_ref(job));
    }
    if(reply) g_variant_unref(reply);
    g_clear_error(&error); package_unref(job);
}
static void package_created(GObject *source,GAsyncResult *result,gpointer data) {
    AulaPackageInstall *job=data; GError *error=NULL;
    GVariant *reply=g_dbus_connection_call_finish(G_DBUS_CONNECTION(source),result,&error);
    if(!reply) package_finish(job,g_error_matches(error,G_DBUS_ERROR,G_DBUS_ERROR_SERVICE_UNKNOWN) ? -1 : 0);
    else if(!job->finished) {
        const char *path; g_variant_get(reply,"(&o)",&path); job->transaction=g_strdup(path);
        job->subscription=g_dbus_connection_signal_subscribe(job->bus,"org.freedesktop.PackageKit","org.freedesktop.PackageKit.Transaction",NULL,path,NULL,G_DBUS_SIGNAL_FLAGS_NONE,package_signal,package_ref(job),package_unref);
        const char *hints[]={"interactive=true",NULL};
        g_dbus_connection_call(job->bus,"org.freedesktop.PackageKit",path,"org.freedesktop.PackageKit.Transaction","SetHints",
            g_variant_new("(^as)",hints),NULL,G_DBUS_CALL_FLAGS_NONE,30000,NULL,package_hints_reply,package_ref(job));
    }
    if(reply) g_variant_unref(reply);
    g_clear_error(&error); package_unref(job);
}
static void package_bus_ready(GObject *source,GAsyncResult *result,gpointer data) {
    AulaPackageInstall *job=data; GError *error=NULL;
    job->bus=g_bus_get_finish(result,&error);
    if(!job->bus) package_finish(job,-1);
    else if(!job->finished) g_dbus_connection_call(job->bus,"org.freedesktop.PackageKit","/org/freedesktop/PackageKit","org.freedesktop.PackageKit","CreateTransaction",NULL,
        G_VARIANT_TYPE("(o)"),G_DBUS_CALL_FLAGS_NONE,30000,NULL,package_created,package_ref(job));
    g_clear_error(&error); package_unref(job);
}
static void start_package_install(const char *file) {
    AulaPackageInstall *job=g_new0(AulaPackageInstall,1); job->refs=1; job->file=g_strdup(file);
    job->timeout=g_timeout_add_seconds_full(G_PRIORITY_DEFAULT,600,package_timeout,package_ref(job),package_unref);
    g_bus_get(G_BUS_TYPE_SYSTEM,NULL,package_bus_ready,job);
}
