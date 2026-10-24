package com.vitalyart.aulaf75maxdriver

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/** Downloads into private cache. Android remains responsible for validating and installing the APK. */
data class APKInstallState(
    val downloading: Boolean = false,
    val progress: Float? = null,
    val file: File? = null,
    val pendingInstall: File? = null,
    val error: Int? = null
)

object APKUpdateValidation {
    fun matches(installedPackage: String, incomingPackage: String, installedCode: Long, incomingCode: Long,
                installedSigners: Set<String>, incomingSigners: Set<String>): Boolean =
        installedPackage == incomingPackage && incomingCode > installedCode && installedSigners.isNotEmpty() && installedSigners == incomingSigners

    fun matchesDigest(expected: String?, actual: String): Boolean =
        expected == null || (expected.startsWith("sha256:") && expected.removePrefix("sha256:").equals(actual, ignoreCase = true))
}

class APKUpdateInstaller(private val context: Context, private val scope: CoroutineScope) {
    val state = MutableStateFlow(APKInstallState())
    private var job: Job? = null
    fun cancel() {
        job?.cancel()
        state.value = APKInstallState()
    }
    fun consumeRequest() { state.value = state.value.copy(pendingInstall = null) }
    fun installationError(message: Int) { state.value = state.value.copy(error = message, pendingInstall = null) }
    fun requestInstall() { state.value.file?.takeIf { it.isFile }?.let { state.value = state.value.copy(pendingInstall = it, error = null) } }
    fun download(release: UpdateRelease) {
        if (state.value.downloading) return
        val previous = job
        previous?.cancel()
        state.value = APKInstallState(downloading = true)
        job = scope.launch {
            previous?.join()
            ensureActive()
            var completed: File? = null
            try {
                completed = withContext(Dispatchers.IO) { downloadAndVerify(release) }
                ensureActive()
                state.value = APKInstallState(file = completed, pendingInstall = completed)
            } catch (e: CancellationException) { completed?.delete(); throw e }
            catch (e: Exception) { state.value = APKInstallState(error = if (e is SecurityException) R.string.update_invalid_package else R.string.update_install_failed) }
        }
    }
    private suspend fun downloadAndVerify(release: UpdateRelease): File {
        check(UpdatePolicy.trusted(release.download, true))
        val directory = File(context.cacheDir, "updates").apply { mkdirs() }
        directory.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 7L * 86400000 }?.forEach { it.delete() }
        val partial = File.createTempFile("update-", ".part", directory)
        var connection: HttpURLConnection? = null
        try {
            var address = release.download
            for (redirect in 0..5) {
                val url = URL(address)
                check(url.protocol == "https" && url.host in setOf("github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"))
                connection = (url.openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false; connectTimeout = 20000; readTimeout = 30000
                    setRequestProperty("User-Agent", "AulaF75MaxDriver")
                }
                if (connection.responseCode in listOf(301,302,303,307,308)) {
                    address = URL(url, connection.getHeaderField("Location") ?: error("Missing redirect")).toString()
                    connection.disconnect(); connection = null
                } else break
            }
            val response = connection ?: error("Too many redirects")
            check(response.responseCode == 200)
            val total = response.contentLengthLong
            val limit = 512L * 1024 * 1024
            check(total <= limit && release.size <= limit)
            val digest = MessageDigest.getInstance("SHA-256")
            var received = 0L
            response.inputStream.use { input -> partial.outputStream().use { output ->
                val buffer = ByteArray(65536)
                while (true) {
                    currentCoroutineContext().ensureActive()
                    val count = input.read(buffer)
                    if (count < 0) break
                    received += count
                    check(received <= limit)
                    output.write(buffer, 0, count); digest.update(buffer, 0, count)
                    state.value = state.value.copy(progress = if (total > 0) (received.toFloat() / total).coerceIn(0f, 1f) else null)
                }
            } }
            check((total <= 0 || received == total) && (release.size <= 0 || received == release.size))
            val actualDigest = digest.digest().joinToString("") { "%02x".format(it) }
            if (!APKUpdateValidation.matchesDigest(release.digest, actualDigest)) throw SecurityException("Digest mismatch")
            val pm = context.packageManager
            val current = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val incoming = pm.getPackageArchiveInfo(partial.absolutePath, PackageManager.GET_SIGNING_CERTIFICATES) ?: throw SecurityException("Invalid APK")
            fun signers(info: android.content.pm.PackageInfo) = info.signingInfo?.apkContentsSigners?.map {
                MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).joinToString("") { b -> "%02x".format(b) }
            }?.toSet() ?: emptySet()
            if (!APKUpdateValidation.matches(current.packageName, incoming.packageName, current.longVersionCode, incoming.longVersionCode, signers(current), signers(incoming)) ||
                ReleaseVersion.parse(incoming.versionName ?: "") != ReleaseVersion.parse(release.tag)) throw SecurityException("Incompatible APK")
            currentCoroutineContext().ensureActive()
            val ready = File(directory, "${partial.nameWithoutExtension}.apk")
            check(partial.renameTo(ready))
            return ready
        } finally { connection?.disconnect(); partial.delete() }
    }
    fun permissionIntent() = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
    fun installIntent(file: File): Intent {
        check(file.canonicalFile.parentFile == File(context.cacheDir, "updates").canonicalFile)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", file)
        return Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
}
