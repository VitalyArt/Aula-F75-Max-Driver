package com.vitalyart.aulaf75maxdriver

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class AulaUiState(
    val endpoints: List<HIDEndpointInfo> = emptyList(),
    val logs: List<String> = emptyList(),
    val isWorking: Boolean = false,
    val selectedLanguageCode: String = AndroidLanguageManager.systemLanguageCode,
    val slot: Int = 1,
    val fitMode: ScreenFitMode = ScreenFitMode.CONTAIN,
    val progress: DisplayUploadProgress = DisplayUploadProgress(0, 0),
    val batteryPercent: Int? = null,
    val rgbMode: Int = 11,
    val rgbBrightness: Int = 5,
    val rgbSpeed: Int = 3,
    val rgbDirection: Int = 0,
    val rgbColor: Int = 0x3366ff,
    val rgbColorful: Boolean = true,
    val keyResponseLevel: Int = 1,
    val sleepTime: Int = 1,
    val gameModeEnabled: Boolean = false,
    val usbPermissionGranted: Boolean = false,
    val receiverPermissionGranted: Boolean = false,
    val wiredPermissionGranted: Boolean = false,
    val displayUploadError: String? = null,
    val profiles: List<LightingProfile> = emptyList(),
    val selectedProfileId: String? = null,
    val lastAppliedLighting: LightingSettings? = null,
    val lightingError: String? = null,
    val selectedImageUri: Uri? = null,
    val selectedImageName: String? = null
) {
    val lighting get() = LightingSettings(rgbMode, rgbBrightness, rgbSpeed, rgbDirection, rgbColorful, rgbColor)
    val isReceiverConnected get() = endpoints.any {
        it.vendorID == AulaConstants.dongleVendorID && it.productID == AulaConstants.dongleProductID
    }
    val isWiredConnected get() = endpoints.any {
        it.vendorID == AulaConstants.wiredVendorID && it.productID == AulaConstants.wiredProductID
    }
    val canUploadDisplay get() = !isWorking && isWiredConnected && wiredPermissionGranted && selectedImageUri != null
    val canApplyLighting get() = !isWorking && receiverPermissionGranted && isReceiverConnected
    val hasUnsavedLighting get() = hasUnsavedLighting(lighting, lastAppliedLighting, profiles.find { it.id == selectedProfileId }?.settings)
}

class AulaViewModel(application: Application) : AndroidViewModel(application) {
    private val appContext = application.applicationContext
    private val profileStore = LightingProfileStore(appContext.getSharedPreferences("lighting", 0))
    private val backend = AndroidAulaBackend(appContext)
    private val permissionController = UsbPermissionController(appContext) {
        refresh()
    }

    private val _state = MutableStateFlow(
        AulaUiState(
            profiles = profileStore.load(),
            usbPermissionGranted = permissionController.hasPermissionForAnyAulaDevice(),
            receiverPermissionGranted = permissionController.hasReceiverPermission(),
            wiredPermissionGranted = permissionController.hasWiredPermission(),
            selectedLanguageCode = AndroidLanguageManager.loadLanguageCode(appContext)
        )
    )
    val state: StateFlow<AulaUiState> = _state.asStateFlow()
    val availableLanguages: List<AppLanguage> = AndroidLanguageManager.availableLanguages

    private var batteryJob: Job? = null
    private var selectedImageUri: Uri? = null

    init {
        refresh()
    }

    override fun onCleared() {
        super.onCleared()
        batteryJob?.cancel()
        permissionController.close()
    }

    fun refresh() {
        viewModelScope.launch(Dispatchers.IO) {
            val endpoints = backend.scanEndpoints()
            val permissionGranted = permissionController.hasPermissionForAnyAulaDevice()
            val battery = if (permissionGranted && endpoints.any { it.vendorID == AulaConstants.dongleVendorID }) {
                runCatching { backend.queryBattery() }.getOrNull()
            } else {
                null
            }
            _state.update { current ->
                current.copy(
                    endpoints = endpoints,
                    batteryPercent = battery ?: current.batteryPercent,
                    usbPermissionGranted = permissionGranted,
                    receiverPermissionGranted = permissionController.hasReceiverPermission(),
                    wiredPermissionGranted = permissionController.hasWiredPermission()
                )
            }
            restartBatteryPolling(permissionGranted, endpoints)
            log(
                if (endpoints.isEmpty()) {
                    "No Aula device is visible."
                } else {
                    "Detected ${endpoints.size} endpoint(s)."
                }
            )
        }
    }

    fun requestUsbPermission() {
        if (!permissionController.requestPermissionForFirstAulaDevice()) {
            log("No Aula USB device found to request permission for.")
        } else {
            log("USB permission requested.")
        }
    }

    fun setSlot(value: Int) {
        _state.update { it.copy(slot = value.coerceIn(1, 255)) }
    }

    fun setFitMode(mode: ScreenFitMode) {
        _state.update { it.copy(fitMode = mode) }
    }

    fun setRgbMode(value: Int) {
        _state.update { it.copy(rgbMode = value.coerceIn(0, 19)) }
    }

    fun setRgbBrightness(value: Int) {
        _state.update { it.copy(rgbBrightness = value.coerceIn(1, 5)) }
    }

    fun setRgbSpeed(value: Int) {
        _state.update { it.copy(rgbSpeed = value.coerceIn(1, 5)) }
    }

    fun setRgbDirection(value: Int) {
        _state.update { it.copy(rgbDirection = value.coerceIn(0, 3)) }
    }

    fun setRgbColor(hex: String) {
        val sanitized = hex.trim().removePrefix("#").ifBlank { "3366ff" }
        val parsed = sanitized.toIntOrNull(16) ?: return
        _state.update { it.copy(rgbColor = parsed.coerceIn(0, 0xffffff)) }
    }

    fun setRgbColorful(value: Boolean) {
        _state.update { it.copy(rgbColorful = value) }
    }

    fun setKeyResponseLevel(value: Int) {
        _state.update { it.copy(keyResponseLevel = value.coerceIn(1, 5)) }
    }

    fun setSleepTime(value: Int) {
        _state.update { it.copy(sleepTime = value.coerceIn(0, 3)) }
    }

    fun setGameModeEnabled(value: Boolean) {
        _state.update { it.copy(gameModeEnabled = value) }
    }

    fun setLanguage(languageCode: String) {
        val normalized = if (languageCode.isBlank()) AndroidLanguageManager.systemLanguageCode else languageCode
        if (_state.value.selectedLanguageCode == normalized) {
            return
        }
        AndroidLanguageManager.saveLanguageCode(appContext, normalized)
        AndroidLanguageManager.applyLanguage(normalized)
        _state.update { it.copy(selectedLanguageCode = normalized) }
    }

    fun setSelectedImage(uri: Uri) {
        selectedImageUri = uri
        _state.update {
            it.copy(selectedImageName = displayNameFor(uri), selectedImageUri = uri,
                displayUploadError = null, progress = DisplayUploadProgress(0, 0))
        }
        log("Selected ${displayNameFor(uri)}.")
    }

    fun uploadSelectedImage() {
        if (state.value.isWorking) return
        val uri = selectedImageUri
        if (uri == null) {
            log("Select an image or GIF first.")
            return
        }

        if (!state.value.canUploadDisplay) return
        val targetSlot = state.value.slot
        val targetFit = state.value.fitMode
        _state.update { it.copy(displayUploadError = null, progress = DisplayUploadProgress(0, 0)) }
        setWorking(true)
        viewModelScope.launch {
            log("Encoding ${displayNameFor(uri)}...")
            try {
                val encoded = withContext(Dispatchers.IO) {
                    DisplayEncoder.encodeImage(appContext, uri, targetFit)
                }
                updateProgress(DisplayUploadProgress(0, encoded.chunkCount))
                log("Encoded ${encoded.frameCount} frame(s), ${encoded.chunkCount} chunk(s).")
                withContext(Dispatchers.IO) {
                    backend.uploadDisplayStream(encoded.data, targetSlot) { progress ->
                        updateProgress(progress)
                    }
                }
                log("Uploaded ${encoded.frameCount} frame(s) to slot $targetSlot.")
            } catch (error: Throwable) {
                _state.update { it.copy(displayUploadError = error.message ?: error::class.java.simpleName) }
                log("Error: ${error.message ?: error::class.java.simpleName}")
            } finally {
                setWorking(false)
                refresh()
            }
        }
    }

    fun syncTime() {
        runOperation("Syncing keyboard clock...") {
            backend.syncTime()
            "Keyboard clock synced."
        }
    }

    fun queryBattery() {
        runOperation("Querying battery...") {
            val percent = backend.queryBattery()
            if (percent != null) {
                _state.update { it.copy(batteryPercent = percent) }
                "Battery: $percent%."
            } else {
                "Battery query sent, but no percentage report was received."
            }
        }
    }

    fun selectProfile(profile: LightingProfile) {
        val s = profile.settings
        _state.update { it.copy(selectedProfileId = profile.id, rgbMode = s.mode, rgbBrightness = s.brightness,
            rgbSpeed = s.speed, rgbDirection = s.direction, rgbColorful = s.colorful, rgbColor = s.color) }
        if (state.value.canApplyLighting) applyRgb()
    }

    fun saveProfile(name: String) {
        if (name.isBlank()) return
        val profile = LightingProfile(java.util.UUID.randomUUID().toString(), name.trim(), state.value.lighting)
        changeProfiles(state.value.profiles + profile)
        _state.update { it.copy(selectedProfileId = profile.id) }
    }

    fun updateProfile(profile: LightingProfile) = changeProfiles(state.value.profiles.map {
        if (it.id == profile.id) it.copy(settings = state.value.lighting) else it
    })

    fun renameProfile(profile: LightingProfile, name: String) {
        if (name.isBlank()) return
        changeProfiles(state.value.profiles.map { if (it.id == profile.id) it.copy(name = name.trim()) else it })
    }

    fun deleteProfile(profile: LightingProfile) {
        changeProfiles(state.value.profiles.filterNot { it.id == profile.id })
        _state.update { if (it.selectedProfileId == profile.id) it.copy(selectedProfileId = null) else it }
    }

    private fun changeProfiles(profiles: List<LightingProfile>) {
        profileStore.save(profiles)
        _state.update { it.copy(profiles = profiles) }
    }

    fun applyRgb() {
        if (!state.value.canApplyLighting) return
        val current = state.value
        _state.update { it.copy(lightingError = null) }
        runOperation("Applying RGB lighting...", onFailure = { error ->
            _state.update { it.copy(lightingError = error.message ?: error::class.java.simpleName) }
        }) {
            backend.applyRGB(
                mode = current.rgbMode,
                brightness = current.rgbBrightness,
                speed = current.rgbSpeed,
                direction = current.rgbDirection,
                colorful = current.rgbColorful,
                color = current.rgbColor
            )
            _state.update { it.copy(lastAppliedLighting = current.lighting) }
            val colorText = if (current.rgbColorful) "Colorful" else "#%06X".format(current.rgbColor)
            "RGB set: Mode ${current.rgbMode} B${current.rgbBrightness} S${current.rgbSpeed} Direction ${current.rgbDirection} $colorText."
        }
    }

    fun applyPerformance() {
        val current = state.value
        runOperation("Applying keyboard performance settings...") {
            backend.applyPerformance(current.keyResponseLevel, current.sleepTime)
            "Performance set: Level ${current.keyResponseLevel}, sleep ${current.sleepTime}."
        }
    }

    fun setGameMode() {
        val current = state.value
        runOperation(if (current.gameModeEnabled) "Enabling Game Mode..." else "Disabling Game Mode...") {
            backend.setGameMode(current.gameModeEnabled, current.keyResponseLevel, current.sleepTime)
            if (current.gameModeEnabled) "Game Mode enabled." else "Game Mode disabled."
        }
    }

    fun factoryReset() {
        runOperation("Starting factory reset...") {
            val messages = mutableListOf<String>()
            backend.factoryReset { message ->
                messages += message
                log(message)
            }
            messages += "Factory reset complete."
            messages.joinToString("\n")
        }
    }

    private fun runOperation(startMessage: String, onFailure: (Throwable) -> Unit = {}, block: () -> String) {
        if (state.value.isWorking) return
        setWorking(true)
        viewModelScope.launch {
            log(startMessage)
            try {
                val result = withContext(Dispatchers.IO) { block() }
                log(result)
            } catch (error: Throwable) {
                onFailure(error)
                log("Error: ${error.message ?: error::class.java.simpleName}")
            } finally {
                setWorking(false)
                refresh()
            }
        }
    }

    private fun restartBatteryPolling(permissionGranted: Boolean, endpoints: List<HIDEndpointInfo>) {
        batteryJob?.cancel()
        if (!permissionGranted || endpoints.none { it.vendorID == AulaConstants.dongleVendorID }) {
            return
        }

        batteryJob = viewModelScope.launch(Dispatchers.IO) {
            while (true) {
                delay(300_000)
                runCatching {
                    backend.queryBattery()
                }.onSuccess { percent ->
                    if (percent != null) {
                        _state.update { it.copy(batteryPercent = percent) }
                    }
                }
            }
        }
    }

    private fun updateProgress(progress: DisplayUploadProgress) {
        _state.update { it.copy(progress = progress) }
    }

    private fun setWorking(value: Boolean) {
        _state.update { it.copy(isWorking = value) }
    }

    private fun log(message: String) {
        _state.update { current ->
            val logs = (current.logs + message).takeLast(200)
            current.copy(logs = logs)
        }
    }

    private fun displayNameFor(uri: Uri): String {
        val resolver: ContentResolver = appContext.contentResolver
        resolver.query(uri, null, null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) {
                val name = cursor.getString(column)
                if (!name.isNullOrBlank()) {
                    return name
                }
            }
        }
        return uri.lastPathSegment ?: "selected image"
    }
}
