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
    val selectedImageName: String? = null
)

class AulaViewModel(application: Application) : AndroidViewModel(application) {
    private val appContext = application.applicationContext
    private val backend = AndroidAulaBackend(appContext)
    private val permissionController = UsbPermissionController(appContext) {
        refresh()
    }

    private val _state = MutableStateFlow(
        AulaUiState(
            usbPermissionGranted = permissionController.hasPermissionForAnyAulaDevice(),
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
                    usbPermissionGranted = permissionGranted
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
        _state.update { it.copy(rgbMode = value.coerceIn(0, 31)) }
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
            it.copy(selectedImageName = displayNameFor(uri))
        }
        log("Selected ${displayNameFor(uri)}.")
    }

    fun uploadSelectedImage() {
        val uri = selectedImageUri
        if (uri == null) {
            log("Select an image or GIF first.")
            return
        }

        val targetSlot = state.value.slot
        val targetFit = state.value.fitMode
        viewModelScope.launch {
            setWorking(true)
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

    fun applyRgb() {
        val current = state.value
        runOperation("Applying RGB lighting...") {
            backend.applyRGB(
                mode = current.rgbMode,
                brightness = current.rgbBrightness,
                speed = current.rgbSpeed,
                direction = current.rgbDirection,
                colorful = current.rgbColorful,
                color = current.rgbColor
            )
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

    private fun runOperation(startMessage: String, block: () -> String) {
        viewModelScope.launch {
            setWorking(true)
            log(startMessage)
            try {
                val result = withContext(Dispatchers.IO) { block() }
                log(result)
            } catch (error: Throwable) {
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
