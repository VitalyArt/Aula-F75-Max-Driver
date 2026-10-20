package com.vitalyart.aulaf75maxdriver

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** The explicit empty array is retained, so deleting all starters survives restart. */
class LightingProfileStore(private val preferences: SharedPreferences) {
    fun load(): List<LightingProfile> {
        if (!preferences.contains(KEY)) return starters().also(::save)
        return runCatching {
            val array = JSONArray(preferences.getString(KEY, "[]"))
            List(array.length()) { index ->
                val item = array.getJSONObject(index)
                val s = item.getJSONObject("settings")
                LightingProfile(item.getString("id"), item.getString("name"), LightingSettings(
                    s.getInt("mode").coerceIn(0,19), s.getInt("brightness").coerceIn(1,5),
                    s.getInt("speed").coerceIn(1,5), s.getInt("direction").coerceIn(0,3),
                    s.getBoolean("colorful"), s.getInt("color") and 0xffffff))
            }
        }.getOrDefault(emptyList())
    }
    fun save(profiles: List<LightingProfile>) {
        val array = JSONArray()
        profiles.forEach { p ->
            val s = p.settings
            array.put(JSONObject().put("id",p.id).put("name",p.name).put("settings",
                JSONObject().put("mode",s.mode).put("brightness",s.brightness).put("speed",s.speed)
                    .put("direction",s.direction).put("colorful",s.colorful).put("color",s.color)))
        }
        preferences.edit().putString(KEY,array.toString()).apply()
    }
    companion object {
        private const val KEY = "lighting.profiles.v1"
        fun starters() = listOf(
            LightingProfile(UUID.randomUUID().toString(),"Rainbow Wave",LightingSettings(11,4,3,0,true,0x007aff)),
            LightingProfile(UUID.randomUUID().toString(),"Calm Breath",LightingSettings(7,3,2,0,false,0x007aff)),
            LightingProfile(UUID.randomUUID().toString(),"Off",LightingSettings(0,1,1,0,true,0x007aff)))
    }
}

fun hasUnsavedLighting(current: LightingSettings, applied: LightingSettings?, selected: LightingSettings?): Boolean =
    current != applied && current != selected && !(applied == null && selected == null && current == LightingSettings())
