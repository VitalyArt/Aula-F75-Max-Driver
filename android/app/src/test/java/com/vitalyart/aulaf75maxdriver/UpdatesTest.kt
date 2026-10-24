package com.vitalyart.aulaf75maxdriver

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONArray
import org.json.JSONObject

class UpdatesTest {
    @Test fun installerRejectsUnrelatedAndOlderPackages() {
        val trusted = setOf("release-key")
        assertTrue(APKUpdateValidation.matches("app", "app", 1, 2, trusted, trusted))
        assertFalse(APKUpdateValidation.matches("app", "other", 1, 2, trusted, trusted))
        assertFalse(APKUpdateValidation.matches("app", "app", 2, 2, trusted, trusted))
        assertFalse(APKUpdateValidation.matches("app", "app", 3, 2, trusted, trusted))
        assertFalse(APKUpdateValidation.matches("app", "app", 1, 2, trusted, setOf("other-key")))
        assertFalse(APKUpdateValidation.matches("app", "app", 1, 2, emptySet(), emptySet()))
        assertTrue(APKUpdateValidation.matchesDigest("sha256:abcd", "ABCD"))
        assertFalse(APKUpdateValidation.matchesDigest("sha256:abcd", "1234"))
    }
    @Test fun schedule() {
        val now = 200000000L
        assertTrue(UpdatePolicy.isDue(true, false, now - 86400000, now - 3600000, now))
        assertFalse(UpdatePolicy.isDue(true, false, now - 86399999, 0, now))
        assertFalse(UpdatePolicy.isDue(false, false, 0, 0, now))
        assertFalse(UpdatePolicy.isDue(true, true, 0, 0, now))
        assertFalse(UpdatePolicy.isDue(true, false, 0, now, now))
    }
    @Test fun versions() {
        val versions = listOf("0.2.0-alpha.1", "0.2.0-beta.1", "0.2.0-rc2", "0.2.0-rc10", "0.2.0", "0.3.0").map { ReleaseVersion.parse(it)!! }
        assertEquals(versions, versions.sorted())
        assertEquals(ReleaseVersion.parse("v0.2.0-rc1"), ReleaseVersion.parse("0.2.0-rc.1"))
        assertEquals(ReleaseVersion.parse("0.2.0+dev.sha"), ReleaseVersion.parse("0.2.0"))
        assertNull(ReleaseVersion.parse("1.2.3-unknown1"))
    }
    private fun release(tag: String, preview: Boolean = false, draft: Boolean = false, suffix: String = ".apk") = JSONObject()
        .put("tag_name", tag).put("draft", draft).put("prerelease", preview)
        .put("html_url", "https://github.com/${UpdatePolicy.repository}/releases/tag/$tag")
        .put("assets", JSONArray().put(JSONObject().put("name", "AulaF75MaxDriver-$tag$suffix")
            .put("browser_download_url", "https://github.com/${UpdatePolicy.repository}/releases/download/$tag/app$suffix")))
    @Test fun selection() {
        val items = JSONArray().put(release("v0.2.0")).put(release("v0.3.0-rc1", true)).put(release("v9.0.0", draft = true)).put(release("v8.0.0", suffix = ".dmg"))
        assertEquals("v0.2.0", UpdatePolicy.newest(items, "0.1.0", false)?.tag)
        assertEquals("v0.3.0-rc1", UpdatePolicy.newest(items, "0.1.0", true)?.tag)
        assertNull(UpdatePolicy.newest(items, "0.3.0-rc1", false))
        assertNull(UpdatePolicy.newest(items, "0.3.0-rc1", true))
        assertEquals("v0.2.0", UpdatePolicy.newest(items, "0.2.0-rc1", false)?.tag)
    }
    @Test fun links() {
        assertFalse(UpdatePolicy.trusted("https://github.com/evil/repo/releases/tag/v1.0.0"))
        assertFalse(UpdatePolicy.trusted("http://github.com/${UpdatePolicy.repository}/releases/tag/v1.0.0"))
    }
}
