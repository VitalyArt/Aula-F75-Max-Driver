package com.vitalyart.aulaf75maxdriver

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URI

data class ReleaseVersion(val major: Int, val minor: Int, val patch: Int, val stage: Int, val sequence: Int): Comparable<ReleaseVersion> {
    override fun compareTo(other: ReleaseVersion): Int {
        val a = listOf(major, minor, patch, stage, sequence)
        val b = listOf(other.major, other.minor, other.patch, other.stage, other.sequence)
        return a.zip(b).firstOrNull { it.first != it.second }?.let { it.first.compareTo(it.second) } ?: 0
    }
    companion object {
        fun parse(value: String): ReleaseVersion? {
            val m = Regex("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-(alpha|beta|rc)\\.?([0-9]+))?(?:\\+[0-9A-Za-z.-]+)?$").matchEntire(value) ?: return null
            return ReleaseVersion(m.groupValues[1].toIntOrNull() ?: return null, m.groupValues[2].toIntOrNull() ?: return null, m.groupValues[3].toIntOrNull() ?: return null,
                mapOf("alpha" to 0, "beta" to 1, "rc" to 2)[m.groupValues[4]] ?: 3, if (m.groupValues[5].isEmpty()) 0 else m.groupValues[5].toIntOrNull() ?: return null)
        }
    }
}

data class UpdateRelease(val tag: String, val page: String, val download: String, val preview: Boolean, val digest: String? = null, val size: Long = 0)
object UpdatePolicy {
    fun isDue(automatic: Boolean, checking: Boolean, lastSuccess: Long, lastAttempt: Long, now: Long): Boolean =
        automatic && !checking && now - lastSuccess >= 86400000 && now - lastAttempt >= 3600000
    const val repository = "VitalyArt/Aula-F75-Max-Driver"
    fun trusted(value: String, asset: Boolean = false): Boolean = runCatching {
        val u = URI(value)
        u.scheme == "https" && u.host == "github.com" && u.userInfo == null && u.port == -1 &&
            u.path.startsWith("/$repository/releases/${if (asset) "download/" else "tag/"}")
    }.getOrDefault(false)
    fun newest(items: JSONArray, current: String, alpha: Boolean): UpdateRelease? {
        val installed = ReleaseVersion.parse(current) ?: return null
        return (0 until items.length()).mapNotNull { i ->
            val r = items.optJSONObject(i) ?: return@mapNotNull null
            val tag = r.optString("tag_name"); val v = ReleaseVersion.parse(tag) ?: return@mapNotNull null
            val preview = r.optBoolean("prerelease") || v.stage < 3
            val page = r.optString("html_url")
            if (r.optBoolean("draft") || v <= installed || (!alpha && preview) || !trusted(page)) return@mapNotNull null
            val assets = r.optJSONArray("assets") ?: return@mapNotNull null
            val asset = (0 until assets.length()).mapNotNull { assets.optJSONObject(it) }.firstOrNull {
                it.optString("name").startsWith("AulaF75MaxDriver-v") && it.optString("name").endsWith(".apk") && trusted(it.optString("browser_download_url"), true)
            } ?: return@mapNotNull null
            UpdateRelease(tag, page, asset.getString("browser_download_url"), preview, asset.optString("digest").takeIf { it.startsWith("sha256:") }, asset.optLong("size"))
        }.maxByOrNull { ReleaseVersion.parse(it.tag)!! }
    }
}

data class UpdateState(val alpha: Boolean = false, val automatic: Boolean = true, val checking: Boolean = false,
    val checked: Long = 0, val error: Boolean = false, val release: UpdateRelease? = null, val dismissed: String? = null)
class UpdatesViewModel(app: Application): AndroidViewModel(app) {
    val installer = APKUpdateInstaller(app, viewModelScope)
    private val prefs = app.getSharedPreferences("updates", 0)
    private val initialAlpha = prefs.getBoolean("alpha", (ReleaseVersion.parse(BuildConfig.VERSION_NAME)?.stage ?: 3) < 3)
    val state = MutableStateFlow(UpdateState(
        alpha = initialAlpha,
        automatic = prefs.getBoolean("automatic", true), checked = prefs.getLong("checked", 0), dismissed = prefs.getString("dismissed", null),
        release = runCatching { prefs.getString("releases", null)?.let { UpdatePolicy.newest(JSONArray(it), BuildConfig.VERSION_NAME, initialAlpha) } }.getOrNull()))
    private var job: Job? = null
    private val networkLock = Mutex()
    private var lastAttempt = 0L
    fun setChannel(alpha: Boolean) { installer.cancel(); prefs.edit().putBoolean("alpha", alpha).apply(); state.value = state.value.copy(alpha = alpha); check() }
    fun setAutomatic(value: Boolean) { prefs.edit().putBoolean("automatic", value).apply(); state.value = state.value.copy(automatic = value); if (value) checkIfDue() }
    fun dismiss() { val tag = state.value.release?.tag; prefs.edit().putString("dismissed", tag).apply(); state.value = state.value.copy(dismissed = tag) }
    fun checkIfDue() { if (UpdatePolicy.isDue(state.value.automatic, state.value.checking, state.value.checked, lastAttempt, System.currentTimeMillis())) check() }
    fun check() {
        if (installer.state.value.downloading) return
        installer.cancel()
        job?.cancel()
        lastAttempt = System.currentTimeMillis()
        val alpha = state.value.alpha
        state.value = state.value.copy(checking = true, error = false, release = null)
        job = viewModelScope.launch {
            try {
                val items = networkLock.withLock { withContext(Dispatchers.IO) { fetch() } }
                ensureActive()
                if (state.value.alpha != alpha) return@launch
                val now = System.currentTimeMillis(); prefs.edit().putLong("checked", now).apply()
                state.value = state.value.copy(checking = false, checked = now, release = UpdatePolicy.newest(items, BuildConfig.VERSION_NAME, alpha))
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { state.value = state.value.copy(checking = false, error = true) }
        }
    }
    private suspend fun fetch(): JSONArray {
        check(System.currentTimeMillis() >= prefs.getLong("retry", 0))
        var next: String? = "https://api.github.com/repos/${UpdatePolicy.repository}/releases?per_page=100"
        val visited = mutableSetOf<String>(); val result = JSONArray()
        while (next != null) {
            currentCoroutineContext().ensureActive()
            val address = next
            val url = URL(address)
            check(visited.add(address) && url.protocol == "https" && url.host == "api.github.com" && url.path == "/repos/${UpdatePolicy.repository}/releases")
            val cache = prefs.getString("page.$address", null)?.let(::JSONObject)
            val conn = url.openConnection() as HttpURLConnection
            try {
                conn.connectTimeout = 20000; conn.readTimeout = 20000
                conn.setRequestProperty("Accept", "application/vnd.github+json")
                conn.setRequestProperty("User-Agent", "AulaF75MaxDriver")
                cache?.optString("etag")?.takeIf { it.isNotEmpty() }?.let { conn.setRequestProperty("If-None-Match", it) }
                val page = when (conn.responseCode) {
                    304 -> cache ?: error("No cached page")
                    200 -> JSONObject().put("data", conn.inputStream.bufferedReader().use { it.readText() })
                        .put("etag", conn.getHeaderField("ETag") ?: "")
                        .put("next", conn.getHeaderField("Link")?.split(",")?.firstOrNull { it.contains("rel=\"next\"") }?.substringBefore(">")?.trim()?.removePrefix("<") ?: "")
                    else -> {
                        if (conn.responseCode in listOf(403,429)) {
                            val reset = (conn.getHeaderField("X-RateLimit-Reset")?.toLongOrNull() ?: 0) * 1000
                            val header = conn.getHeaderField("Retry-After") ?: ""
                            val date = runCatching { java.text.SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss z", java.util.Locale.US).parse(header)?.time }.getOrNull()
                            val wait = header.toLongOrNull()?.times(1000) ?: date?.minus(System.currentTimeMillis()) ?: 60000
                            prefs.edit().putLong("retry", maxOf(reset, System.currentTimeMillis() + wait)).apply()
                        }
                        error("HTTP ${conn.responseCode}")
                    }
                }
                val array = JSONArray(page.getString("data"))
                for (i in 0 until array.length()) result.put(array.get(i))
                prefs.edit().putString("page.$address", page.toString()).apply()
                next = page.optString("next").takeIf { it.isNotEmpty() }
            } finally { conn.disconnect() }
        }
        prefs.edit().putString("releases", result.toString()).apply()
        return result
    }
}
