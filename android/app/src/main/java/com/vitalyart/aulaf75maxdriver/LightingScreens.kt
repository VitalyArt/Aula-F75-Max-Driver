package com.vitalyart.aulaf75maxdriver

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape

@Composable
internal fun HomeScreen(state: AulaUiState, model: AulaViewModel, lighting: () -> Unit, display: () -> Unit) {
    ScreenColumn {
        StagePanel {
            Text("Aula F75 Max", style = MaterialTheme.typography.headlineMedium)
            KeyboardStage(state.lastAppliedLighting ?: LightingSettings(mode = 0))
        }
        ConnectionSummary(state)
        ProfilesPanel(state, model, compact = true)
        OutlinedButton(onClick = lighting, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.lighting)) }
        OutlinedButton(onClick = display, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.tab_display)) }
    }
}

/** Rows wrap with available width and font scale without nesting a scrolling grid. */
@Composable
private fun AdaptiveTiles(minWidth: Int, count: Int, content: @Composable (Int) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val fontScale = androidx.compose.ui.platform.LocalDensity.current.fontScale
        val columns = (maxWidth.value / (minWidth * fontScale)).toInt().coerceAtLeast(1)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            (0 until count).chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { index -> Box(Modifier.weight(1f)) { content(index) } }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
internal fun EffectGrid(state: AulaUiState, onSelected: (Int) -> Unit) {
    AdaptiveTiles(88, 20) { mode ->
        val selected = state.rgbMode == mode
        Surface(onClick = { onSelected(mode) }, shape = RoundedCornerShape(9.dp),
            color = if(selected) MaterialTheme.colorScheme.primaryContainer else androidx.compose.ui.graphics.Color.Transparent,
            border = if(selected) BorderStroke(2.dp,MaterialTheme.colorScheme.primary) else null,
            modifier = Modifier.fillMaxWidth().semantics { this.selected = selected }) {
            Column(Modifier.padding(6.dp).heightIn(min = 64.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(5.dp)) {
                EffectSwatch(state.lighting.copy(mode = mode), Modifier.fillMaxWidth().height(34.dp))
                Text(rgbModeLabel(mode), style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
internal fun ProfilesPanel(state: AulaUiState, model: AulaViewModel, compact: Boolean = false) {
    var pending by remember { mutableStateOf<LightingProfile?>(null) }
    var deleting by remember { mutableStateOf<LightingProfile?>(null) }
    var naming by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf<LightingProfile?>(null) }
    var name by remember { mutableStateOf("") }
    val selected = state.profiles.find { it.id == state.selectedProfileId }
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.lighting_profiles),style = MaterialTheme.typography.titleLarge)
            if(state.profiles.isEmpty()) Text(stringResource(R.string.profiles_empty))
            AdaptiveTiles(145, state.profiles.size) { index ->
                val profile=state.profiles[index]
                val active=profile.id==state.selectedProfileId
                Surface(onClick = { if(state.hasUnsavedLighting) pending=profile else model.selectProfile(profile) },
                    shape = RoundedCornerShape(8.dp),
                    color = if(active) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                    border = if(active) BorderStroke(1.dp,MaterialTheme.colorScheme.primary) else null,
                    modifier = Modifier.fillMaxWidth().semantics { this.selected = active }) {
                    Row(Modifier.heightIn(min=48.dp).padding(10.dp),verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        EffectSwatch(profile.settings,Modifier.width(32.dp).height(24.dp))
                        Text(profile.name,style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            if(!compact) {
                OutlinedButton(onClick = {name="";renaming=null;naming=true},modifier=Modifier.fillMaxWidth()) {Text(stringResource(R.string.profile_save_new))}
                if(selected!=null) {
                    OutlinedButton(onClick = {model.updateProfile(selected)},enabled = selected.settings!=state.lighting,modifier=Modifier.fillMaxWidth()) {Text(stringResource(R.string.profile_update))}
                    Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick={renaming=selected;name=selected.name;naming=true},modifier=Modifier.weight(1f)) {Text(stringResource(R.string.profile_rename))}
                        TextButton(onClick={deleting=selected},modifier=Modifier.weight(1f)) {Text(stringResource(R.string.profile_delete),color=MaterialTheme.colorScheme.error)}
                    }
                }
            }
        }
    }
    if(naming) AlertDialog(onDismissRequest={naming=false},title={Text(stringResource(if(renaming==null) R.string.profile_save_new else R.string.profile_rename))},
        text={OutlinedTextField(value=name,onValueChange={name=it},label={Text(stringResource(R.string.profile_name))},singleLine=true)},
        dismissButton={TextButton(onClick={naming=false}) {Text(stringResource(R.string.cancel))}},
        confirmButton={TextButton(enabled=name.isNotBlank(),onClick={renaming?.let {model.renameProfile(it,name)} ?: model.saveProfile(name);naming=false}) {Text(stringResource(R.string.profile_save))}})
    if(pending!=null) AlertDialog(onDismissRequest={pending=null},title={Text(stringResource(R.string.profile_discard))},
        dismissButton={TextButton(onClick={pending=null}) {Text(stringResource(R.string.cancel))}},
        confirmButton={TextButton(onClick={pending?.let(model::selectProfile);pending=null}) {Text(stringResource(R.string.profile_switch))}})
    if(deleting!=null) AlertDialog(onDismissRequest={deleting=null},title={Text(stringResource(R.string.profile_delete_confirm))},text={Text(deleting!!.name)},
        dismissButton={TextButton(onClick={deleting=null}) {Text(stringResource(R.string.cancel))}},
        confirmButton={TextButton(onClick={deleting?.let(model::deleteProfile);deleting=null}) {Text(stringResource(R.string.profile_delete))}})
}
