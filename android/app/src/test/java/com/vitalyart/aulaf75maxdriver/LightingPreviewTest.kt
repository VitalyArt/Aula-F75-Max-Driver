package com.vitalyart.aulaf75maxdriver

import android.content.SharedPreferences
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test

class LightingPreviewTest {
    @Test fun keyboardMatchesDesktopGeometry() {
        val keys = KeyboardLayout.keys
        assertEquals(80, keys.size)
        assertEquals(keys.size, keys.map {it.id}.distinct().size)
        assertTrue(keys.all {it.x>=0 && it.y>=0 && it.x+it.width<=16f && it.y+1<=6.4f})
        assertEquals(6.25f,keys.first {it.id=="Space"}.width)
        assertTrue(keys.first {it.id=="Enter"}.light)
        assertTrue(keys.first {it.id=="Left"}.y>keys.first {it.id=="Space"}.y)
        keys.forEachIndexed {i,a -> keys.drop(i+1).forEach {b ->
            assertFalse("${a.id} overlaps ${b.id}",a.x<b.x+b.width && a.x+a.width>b.x && a.y<b.y+1 && a.y+1>b.y)
        }}
    }
    @Test fun allEffectsAreDeterministicAndBounded() {
        for(mode in 0..19) for(t in listOf(0.0,1.7,9.0)) {
            val settings=LightingSettings(mode=mode)
            val c=LightingEffectRenderer.color(settings,0.31,0.6,t)
            assertEquals(c,LightingEffectRenderer.color(settings,0.31,0.6,t))
            assertTrue(listOf(c.r,c.g,c.b).all {it.isFinite() && it in 0.0..1.0})
        }
        assertEquals(PreviewRGB(0.0,0.0,0.0),LightingEffectRenderer.color(LightingSettings(mode=0),0.3,0.4,3.0))
    }
    @Test fun settingsAffectThePreview() {
        val s=LightingSettings(mode=11)
        fun c(s: LightingSettings)=LightingEffectRenderer.color(s,0.2,0.3,1.7)
        assertNotEquals(c(s),c(s.copy(speed=1)))
        assertNotEquals(c(s),c(s.copy(direction=2)))
        assertNotEquals(c(s),c(s.copy(colorful=false,color=0xff0000)))
        assertEquals(c(s).scaled(0.2),c(s.copy(brightness=1)))
        assertEquals(PreviewRGB(1.0,0.0,0.0),c(s.copy(mode=1,colorful=false,color=0xff0000)))
    }
    @Test fun editsAndApplicationAvailability() {
        val s=LightingSettings()
        assertFalse(hasUnsavedLighting(s,null,null))
        assertTrue(hasUnsavedLighting(s.copy(speed=1),null,null))
        assertFalse(hasUnsavedLighting(s,s,null))
        assertFalse(hasUnsavedLighting(s,null,s))
        assertFalse(AulaUiState().canApplyLighting)
        assertFalse(AulaUiState(usbPermissionGranted=true).canApplyLighting)
        val receiver = HIDEndpointInfo("receiver", AulaConstants.dongleVendorID, AulaConstants.dongleProductID,
            AulaConstants.wirelessCommandUsagePage, 0x61, 64, 64, 0, "Aula", "USB")
        val ready = AulaUiState(endpoints = listOf(receiver), usbPermissionGranted = true, receiverPermissionGranted = true)
        assertTrue(ready.canApplyLighting)
        assertFalse(ready.copy(isWorking = true).canApplyLighting)
        assertFalse(ready.copy(receiverPermissionGranted = false).canApplyLighting)
        assertFalse(ready.copy(endpoints = emptyList()).canApplyLighting)
        assertFalse(ready.isWiredConnected)
        assertFalse(ready.canUploadDisplay)
        val wired = receiver.copy(vendorID = AulaConstants.wiredVendorID, productID = AulaConstants.wiredProductID)
        val wiredState = AulaUiState(endpoints = listOf(wired), wiredPermissionGranted = true)
        assertTrue(wiredState.isWiredConnected)
        assertFalse(wiredState.canApplyLighting)
        assertFalse(wiredState.canUploadDisplay) // no image selected
        assertFalse(wiredState.copy(endpoints = emptyList()).isWiredConnected)
        // Applied snapshots are independent from the controls.
        val edited=AulaUiState(rgbSpeed=1,lastAppliedLighting=s)
        assertTrue(edited.hasUnsavedLighting)
        assertFalse(edited.copy(lastAppliedLighting=edited.lighting).hasUnsavedLighting)
    }
    @Test fun profilePersistenceRetainsEmptyAndHandlesCorruption() {
        val values=mutableMapOf<String,String?>()
        lateinit var editor: SharedPreferences.Editor
        editor=Proxy.newProxyInstance(javaClass.classLoader,arrayOf(SharedPreferences.Editor::class.java)) {_,method,args ->
            when(method.name) {
                "putString" -> {values[args!![0] as String]=args[1] as String?;editor}
                "apply" -> null
                "commit" -> true
                else -> editor
            }
        } as SharedPreferences.Editor
        val preferences=Proxy.newProxyInstance(javaClass.classLoader,arrayOf(SharedPreferences::class.java)) {_,method,args ->
            when(method.name) {
                "contains" -> values.containsKey(args!![0])
                "getString" -> values[args!![0]] ?: args[1]
                "edit" -> editor
                else -> null
            }
        } as SharedPreferences
        val store=LightingProfileStore(preferences)
        val starters=store.load()
        assertEquals(listOf("Rainbow Wave","Calm Breath","Off"),starters.map {it.name})
        assertEquals(starters,LightingProfileStore(preferences).load())
        val custom=LightingProfile("custom","Desk",LightingSettings(colorful=false,color=0x123456))
        store.save(starters+custom)
        assertEquals(custom,store.load().last())
        val renamed=custom.copy(name="Night",settings=custom.settings.copy(brightness=2))
        store.save(listOf(renamed))
        assertEquals(listOf(renamed),store.load())
        store.save(emptyList())
        assertTrue(LightingProfileStore(preferences).load().isEmpty())
        values["lighting.profiles.v1"]="corrupted"
        assertTrue(store.load().isEmpty())
    }
}
