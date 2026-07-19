package com.vitalyart.aulaf75maxdriver

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Keyboard
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Usb
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.res.stringResource

private enum class AulaDestination(@StringRes val label: Int, val icon: ImageVector) {
    CONTROL(R.string.tab_control, Icons.Outlined.Bolt),
    DISPLAY(R.string.tab_display, Icons.Outlined.Image),
    DEVICE(R.string.tab_device, Icons.Outlined.Settings)
}

@Composable
fun AulaApp(viewModel: AulaViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val availableLanguages = viewModel.availableLanguages
    var destination by remember { mutableStateOf(AulaDestination.CONTROL) }
    var showResetDialog by remember { mutableStateOf(false) }
    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri?.let(viewModel::setSelectedImage)
    }

    if (showResetDialog) {
        ResetDialog(
            onDismiss = { showResetDialog = false },
            onConfirm = {
                showResetDialog = false
                viewModel.factoryReset()
            }
        )
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = Color.Transparent,
        topBar = {
            AppHeader(
                state = state,
                availableLanguages = availableLanguages,
                onRefresh = viewModel::refresh,
                onLanguageSelected = viewModel::setLanguage,
                onRequestPermission = viewModel::requestUsbPermission
            )
        },
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)) {
                AulaDestination.entries.forEach { item ->
                    NavigationBarItem(
                        selected = destination == item,
                        onClick = { destination = item },
                        icon = { Icon(item.icon, contentDescription = null) },
                        label = { Text(stringResource(item.label)) }
                    )
                }
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            MaterialTheme.colorScheme.background,
                            MaterialTheme.colorScheme.background,
                            Color(0xFF21180D)
                        )
                    )
                )
                .padding(padding)
        ) {
            when (destination) {
                AulaDestination.CONTROL -> ControlScreen(state, viewModel)
                AulaDestination.DISPLAY -> DisplayScreen(
                    state = state,
                    onSlotChanged = viewModel::setSlot,
                    onFitModeChanged = viewModel::setFitMode,
                    onPickFile = { filePicker.launch("image/*") },
                    onUpload = viewModel::uploadSelectedImage
                )
                AulaDestination.DEVICE -> DeviceScreen(
                    state = state,
                    onQueryBattery = viewModel::queryBattery,
                    onSyncTime = viewModel::syncTime,
                    onReset = { showResetDialog = true }
                )
            }
        }
    }
}

@Composable
private fun AppHeader(
    state: AulaUiState,
    availableLanguages: List<AppLanguage>,
    onRefresh: () -> Unit,
    onLanguageSelected: (String) -> Unit,
    onRequestPermission: () -> Unit
) {
    var languageMenuExpanded by remember { mutableStateOf(false) }
    val selectedLanguage = availableLanguages.firstOrNull { it.code == state.selectedLanguageCode }
        ?: availableLanguages.first()
    Surface(color = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f), tonalElevation = 2.dp) {
        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
            val compact = maxWidth < 520.dp
            if (compact) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier.size(40.dp).clip(RoundedCornerShape(14.dp))
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Outlined.Keyboard, null, tint = MaterialTheme.colorScheme.primary)
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            stringResource(R.string.app_name),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            stringResource(R.string.app_subtitle),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Box {
                        IconButton(onClick = { languageMenuExpanded = true }) {
                            Icon(Icons.Outlined.Language, null, tint = MaterialTheme.colorScheme.primary)
                        }
                        DropdownMenu(
                            expanded = languageMenuExpanded,
                            onDismissRequest = { languageMenuExpanded = false }
                        ) {
                            availableLanguages.forEach { language ->
                                DropdownMenuItem(
                                    text = {
                                        Text("${language.flag} ${stringResource(language.titleResId)}")
                                    },
                                    onClick = {
                                        languageMenuExpanded = false
                                        onLanguageSelected(language.code)
                                    }
                                )
                            }
                        }
                    }
                    IconButton(onClick = onRefresh, enabled = !state.isWorking) {
                        Icon(Icons.Outlined.Refresh, stringResource(R.string.refresh), tint = MaterialTheme.colorScheme.onSurface)
                    }
                    if (!state.usbPermissionGranted) {
                        IconButton(onClick = onRequestPermission, enabled = !state.isWorking) {
                            Icon(Icons.Outlined.Usb, stringResource(R.string.grant_access), tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier.size(42.dp).clip(RoundedCornerShape(14.dp))
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Outlined.Keyboard, null, tint = MaterialTheme.colorScheme.primary)
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            stringResource(R.string.app_name),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            stringResource(R.string.app_subtitle),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    Box {
                        OutlinedButton(onClick = { languageMenuExpanded = true }) {
                            Icon(Icons.Outlined.Language, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = "${selectedLanguage.flag} ${stringResource(selectedLanguage.titleResId)}",
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        DropdownMenu(
                            expanded = languageMenuExpanded,
                            onDismissRequest = { languageMenuExpanded = false }
                        ) {
                            availableLanguages.forEach { language ->
                                DropdownMenuItem(
                                    text = {
                                        Text("${language.flag} ${stringResource(language.titleResId)}")
                                    },
                                    onClick = {
                                        languageMenuExpanded = false
                                        onLanguageSelected(language.code)
                                    }
                                )
                            }
                        }
                    }
                    IconButton(onClick = onRefresh, enabled = !state.isWorking) {
                        Icon(Icons.Outlined.Refresh, stringResource(R.string.refresh), tint = MaterialTheme.colorScheme.onSurface)
                    }
                    if (!state.usbPermissionGranted) {
                        IconButton(onClick = onRequestPermission, enabled = !state.isWorking) {
                            Icon(Icons.Outlined.Usb, stringResource(R.string.grant_access), tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ScreenColumn(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        content()
    }
}

@Composable
private fun ControlScreen(state: AulaUiState, viewModel: AulaViewModel) {
    ScreenColumn {
        ConnectionSummary(state)
        LightingCard(state, viewModel)
        PerformanceCard(state, viewModel)
    }
}

@Composable
private fun ConnectionSummary(state: AulaUiState) {
    val permissionText = stringResource(if (state.usbPermissionGranted) R.string.permission_ready else R.string.permission_needed)
    PremiumCard(accent = MaterialTheme.colorScheme.primary) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                modifier = Modifier.size(48.dp).clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.primaryContainer), contentAlignment = Alignment.Center
            ) { Icon(Icons.Outlined.Security, null, tint = MaterialTheme.colorScheme.primary) }
            Column(modifier = Modifier.weight(1f)) {
                Text(permissionText, style = MaterialTheme.typography.titleMedium)
                Text(
                    stringResource(if (state.isWorking) R.string.working else R.string.idle),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            AssistChip(onClick = {}, label = { Text(if (state.isWorking) stringResource(R.string.working) else stringResource(R.string.idle)) })
        }
        Spacer(Modifier.height(14.dp))
        BoxWithConstraints {
            val wide = maxWidth >= 620.dp
            if (wide) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ConnectionMetric(Modifier.weight(1f), R.string.wired, state.endpoints.count { it.vendorID == AulaConstants.wiredVendorID }.toString(),
                    if (state.endpoints.any { it.vendorID == AulaConstants.wiredVendorID }) R.string.detected else R.string.not_visible)
                ConnectionMetric(Modifier.weight(1f), R.string.receiver, state.endpoints.count { it.vendorID == AulaConstants.dongleVendorID }.toString(),
                    if (state.endpoints.any { it.vendorID == AulaConstants.dongleVendorID }) R.string.detected else R.string.not_visible)
                BatteryMetric(Modifier.weight(1f), state.batteryPercent)
            } else Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ConnectionMetric(Modifier.fillMaxWidth(), R.string.wired, state.endpoints.count { it.vendorID == AulaConstants.wiredVendorID }.toString(),
                    if (state.endpoints.any { it.vendorID == AulaConstants.wiredVendorID }) R.string.detected else R.string.not_visible)
                ConnectionMetric(Modifier.fillMaxWidth(), R.string.receiver, state.endpoints.count { it.vendorID == AulaConstants.dongleVendorID }.toString(),
                    if (state.endpoints.any { it.vendorID == AulaConstants.dongleVendorID }) R.string.detected else R.string.not_visible)
                BatteryMetric(Modifier.fillMaxWidth(), state.batteryPercent)
            }
        }
    }
}

@Composable
private fun ConnectionMetric(modifier: Modifier, @StringRes title: Int, value: String, @StringRes status: Int) {
    Surface(modifier = modifier, color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(14.dp)) {
            Text(stringResource(title), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.headlineMedium)
            Text(stringResource(status), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
        }
    }
}

@Composable
private fun BatteryMetric(modifier: Modifier, percent: Int?) {
    val status = when (percent) { null -> R.string.unknown; in 0..20 -> R.string.battery_low; in 21..50 -> R.string.battery_medium; else -> R.string.battery_good }
    ConnectionMetric(modifier, R.string.battery, percent?.let { "$it%" } ?: "--", status)
}

@Composable
private fun LightingCard(state: AulaUiState, viewModel: AulaViewModel) {
    PremiumCard {
        CardTitle(R.string.lighting, R.string.lighting_description, Icons.Outlined.Bolt)
        Spacer(Modifier.height(16.dp))
        LightingModeSelector(selected = state.rgbMode, onSelected = viewModel::setRgbMode)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StepperControl(R.string.brightness, state.rgbBrightness, 1..5, viewModel::setRgbBrightness, Modifier.weight(1f))
            StepperControl(R.string.speed, state.rgbSpeed, 1..5, viewModel::setRgbSpeed, Modifier.weight(1f))
        }
        Spacer(Modifier.height(14.dp))
        Text(stringResource(R.string.direction), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        DirectionSelector(selected = state.rgbDirection, onSelected = viewModel::setRgbDirection)
        Spacer(Modifier.height(10.dp))
        Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(16.dp)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.colorful), modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                Switch(checked = state.rgbColorful, onCheckedChange = viewModel::setRgbColorful)
            }
        }
        Spacer(Modifier.height(10.dp))
        ColorPalette(selected = state.rgbColor, enabled = !state.rgbColorful, onSelected = { viewModel.setRgbColor("%06X".format(it)) })
        Spacer(Modifier.height(14.dp))
        Button(onClick = viewModel::applyRgb, enabled = !state.isWorking, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.apply_lighting)) }
    }
}

@Composable
private fun LightingModeSelector(selected: Int, onSelected: (Int) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.mode), modifier = Modifier.weight(1f))
            Text(rgbModeLabel(selected), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            (0..19).forEach { mode ->
                DropdownMenuItem(text = { Text(rgbModeLabel(mode)) }, onClick = { onSelected(mode); expanded = false })
            }
        }
    }
}

@Composable
private fun StepperControl(@StringRes title: Int, value: Int, range: IntRange, onValueChanged: (Int) -> Unit, modifier: Modifier = Modifier) {
    Surface(modifier = modifier, color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(horizontal = 10.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(stringResource(title), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { onValueChanged(value - 1) }, enabled = value > range.first) { Icon(Icons.Outlined.Remove, null) }
                Text(value.toString(), style = MaterialTheme.typography.titleLarge, modifier = Modifier.width(28.dp), maxLines = 1)
                IconButton(onClick = { onValueChanged(value + 1) }, enabled = value < range.last) { Icon(Icons.Outlined.Add, null) }
            }
        }
    }
}

@Composable
private fun DirectionSelector(selected: Int, onSelected: (Int) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        (0..3).forEach { direction ->
            FilterChip(selected = selected == direction, onClick = { onSelected(direction) }, label = { Text(directionLabel(direction)) })
        }
    }
}

@Composable
private fun ColorPalette(selected: Int, enabled: Boolean, onSelected: (Int) -> Unit) {
    val colors = listOf(0xFF3366FF.toInt(), 0xFF00BFA5.toInt(), 0xFF6ECB63.toInt(), 0xFFFFC857.toInt(), 0xFFFF7043.toInt(), 0xFFE85D9E.toInt(), 0xFFB388FF.toInt(), 0xFFF5F5F5.toInt())
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.fixed_color), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
            colors.forEach { color ->
                val isSelected = selected == color
                Surface(onClick = { onSelected(color) }, enabled = enabled, shape = RoundedCornerShape(14.dp), color = Color(color), border = if (isSelected) androidx.compose.foundation.BorderStroke(3.dp, MaterialTheme.colorScheme.onSurface) else null, modifier = Modifier.size(38.dp)) {}
            }
        }
    }
}

@Composable
private fun rgbModeLabel(mode: Int): String = stringResource(
    listOf(R.string.rgb_off, R.string.rgb_static, R.string.rgb_single_on, R.string.rgb_single_off, R.string.rgb_glittering, R.string.rgb_falling, R.string.rgb_colourful, R.string.rgb_breath, R.string.rgb_spectrum, R.string.rgb_outward, R.string.rgb_scrolling, R.string.rgb_rolling, R.string.rgb_rotating, R.string.rgb_explode, R.string.rgb_launch, R.string.rgb_ripples, R.string.rgb_flowing, R.string.rgb_pulsating, R.string.rgb_tilt, R.string.rgb_shuttle)[mode.coerceIn(0, 19)]
)

@Composable
private fun directionLabel(direction: Int): String = stringResource(
    listOf(R.string.direction_right, R.string.direction_down, R.string.direction_left, R.string.direction_up)[direction.coerceIn(0, 3)]
)

@Composable
private fun PerformanceCard(state: AulaUiState, viewModel: AulaViewModel) {
    PremiumCard {
        CardTitle(R.string.performance, R.string.performance_description, Icons.Outlined.Build)
        Spacer(Modifier.height(16.dp))
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            ChoiceSection(
                label = stringResource(R.string.response),
                values = (1..5).toList(),
                selected = state.keyResponseLevel,
                onSelected = viewModel::setKeyResponseLevel,
                labelForValue = { value -> value.toString() }
            )
            ChoiceSection(
                label = stringResource(R.string.sleep),
                values = (0..3).toList(),
                selected = state.sleepTime,
                onSelected = viewModel::setSleepTime,
                labelForValue = { value -> value.toString() }
            )
        }
        Spacer(Modifier.height(8.dp))
        Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(16.dp)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.game_mode), modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                Switch(checked = state.gameModeEnabled, onCheckedChange = viewModel::setGameModeEnabled)
            }
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(onClick = viewModel::syncTime, enabled = !state.isWorking, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.sync_time)) }
            Button(onClick = viewModel::applyPerformance, enabled = !state.isWorking, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.apply_performance)) }
        }
        Spacer(Modifier.height(10.dp))
        OutlinedButton(onClick = viewModel::setGameMode, enabled = !state.isWorking, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.game_mode)) }
    }
}

@Composable
private fun ChoiceSection(
    label: String,
    values: List<Int>,
    selected: Int,
    onSelected: (Int) -> Unit,
    labelForValue: (Int) -> String
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            values.forEach { value ->
                FilterChip(
                    selected = selected == value,
                    onClick = { onSelected(value) },
                    label = { Text(labelForValue(value)) }
                )
            }
        }
    }
}

@Composable
private fun DisplayScreen(state: AulaUiState, onSlotChanged: (Int) -> Unit, onFitModeChanged: (ScreenFitMode) -> Unit, onPickFile: () -> Unit, onUpload: () -> Unit) {
    ScreenColumn {
        PremiumCard(accent = MaterialTheme.colorScheme.tertiary) {
            CardTitle(R.string.display_upload, R.string.display_description, Icons.Outlined.Image)
            Spacer(Modifier.height(20.dp))
            Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(20.dp), modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(Icons.Outlined.Image, null, modifier = Modifier.size(42.dp), tint = MaterialTheme.colorScheme.tertiary)
                    Text(state.selectedImageName ?: stringResource(R.string.no_image), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    OutlinedButton(onClick = onPickFile) { Text(stringResource(R.string.choose_file)) }
                }
            }
            Spacer(Modifier.height(16.dp))
            NumberField(R.string.slot, state.slot, onSlotChanged, 1..255, Modifier.fillMaxWidth())
            Spacer(Modifier.height(14.dp))
            Text(stringResource(R.string.fit_mode), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ScreenFitMode.entries.forEach { mode ->
                    FilterChip(selected = state.fitMode == mode, onClick = { onFitModeChanged(mode) }, label = { Text(fitModeLabel(mode)) })
                }
            }
            if (state.progress.totalChunks > 0) {
                Spacer(Modifier.height(12.dp))
                LinearProgressIndicator(progress = { state.progress.fraction.toFloat() }, modifier = Modifier.fillMaxWidth())
                Text(stringResource(R.string.upload_progress, state.progress.sentChunks, state.progress.totalChunks), style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(16.dp))
            Button(onClick = onUpload, enabled = !state.isWorking && state.selectedImageName != null, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.upload_image)) }
        }
    }
}

@Composable
private fun DeviceScreen(state: AulaUiState, onQueryBattery: () -> Unit, onSyncTime: () -> Unit, onReset: () -> Unit) {
    ScreenColumn {
        PremiumCard {
            CardTitle(R.string.device_diagnostics, R.string.endpoint_description, Icons.Outlined.Usb)
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(onClick = onQueryBattery, enabled = !state.isWorking, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.battery)) }
                OutlinedButton(onClick = onSyncTime, enabled = !state.isWorking, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.sync_time)) }
            }
            Spacer(Modifier.height(14.dp))
            if (state.endpoints.isEmpty()) Text(stringResource(R.string.no_endpoints), color = MaterialTheme.colorScheme.onSurfaceVariant)
            else state.endpoints.forEach { endpoint ->
                Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Column(Modifier.padding(14.dp)) {
                        Text(endpoint.role, style = MaterialTheme.typography.titleMedium)
                        Text(endpoint.product, style = MaterialTheme.typography.bodySmall)
                        Text(endpoint.summary, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        PremiumCard {
            CardTitle(R.string.activity_log, R.string.no_logs, Icons.Outlined.Settings)
            Spacer(Modifier.height(12.dp))
            Text(if (state.logs.isEmpty()) stringResource(R.string.no_logs) else state.logs.joinToString("\n"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        PremiumCard(accent = MaterialTheme.colorScheme.error) {
            CardTitle(R.string.danger_zone, R.string.reset_description, Icons.Outlined.Security)
            Spacer(Modifier.height(14.dp))
            Button(onClick = onReset, enabled = !state.isWorking, colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error, contentColor = MaterialTheme.colorScheme.onError), modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.factory_reset)) }
        }
    }
}

@Composable
private fun PremiumCard(accent: Color = MaterialTheme.colorScheme.primary, content: @Composable () -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(24.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(18.dp)) {
            Box(Modifier.fillMaxWidth().height(3.dp).clip(RoundedCornerShape(4.dp)).background(accent))
            Spacer(Modifier.height(16.dp))
            content()
        }
    }
}

@Composable
private fun CardTitle(@StringRes title: Int, @StringRes description: Int, icon: ImageVector) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
        Column {
            Text(stringResource(title), style = MaterialTheme.typography.titleLarge)
            Text(stringResource(description), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun NumberField(@StringRes label: Int, value: Int, onValueChanged: (Int) -> Unit, range: IntRange, modifier: Modifier = Modifier) {
    OutlinedTextField(value = value.toString(), onValueChange = { it.toIntOrNull()?.coerceIn(range)?.let(onValueChanged) }, label = { Text(stringResource(label)) }, singleLine = true, modifier = modifier)
}

@Composable
private fun fitModeLabel(mode: ScreenFitMode): String = stringResource(
    when (mode) {
        ScreenFitMode.CONTAIN -> R.string.fit_contain
        ScreenFitMode.COVER -> R.string.fit_cover
        ScreenFitMode.STRETCH -> R.string.fit_stretch
    }
)

@Composable
private fun ResetDialog(onDismiss: () -> Unit, onConfirm: () -> Unit) {
    AlertDialog(onDismissRequest = onDismiss, title = { Text(stringResource(R.string.reset_title)) }, text = { Text(stringResource(R.string.reset_message)) }, dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }, confirmButton = { TextButton(onClick = onConfirm) { Text(stringResource(R.string.confirm_reset), color = MaterialTheme.colorScheme.error) } })
}
