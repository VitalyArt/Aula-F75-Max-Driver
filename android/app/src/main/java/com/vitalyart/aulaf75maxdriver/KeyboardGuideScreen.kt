package com.vitalyart.aulaf75maxdriver

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun KeyboardGuideScreen() {
    var mode by rememberSaveable { mutableStateOf("windows") }
    val uriHandler = LocalUriHandler.current
    ScreenColumn {
        Text(stringResource(R.string.guide_title), style = MaterialTheme.typography.headlineSmall)
        Text(stringResource(R.string.guide_intro), style = MaterialTheme.typography.titleMedium)
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.guide_mode), fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    listOf("windows" to "Windows", "mac" to "Mac").forEach { (value, label) ->
                        FilterChip(selected = mode == value, onClick = { mode = value }, label = { Text(label) })
                    }
                }
                Text(stringResource(R.string.guide_mode_note), style = MaterialTheme.typography.bodyMedium)
            }
        }
        guideGroups.forEach { group ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stringResource(group.title), style = MaterialTheme.typography.titleMedium)
                    Text(stringResource(group.note), style = MaterialTheme.typography.bodyMedium,
                        color = if (group.title == R.string.guide_reset_section) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant)
                    group.entries.filter { it.mode == "all" || it.mode == mode }.forEachIndexed { index, entry ->
                        if (index > 0) HorizontalDivider()
                        GuideRow(entry)
                    }
                }
            }
        }
        TextButton(onClick = { uriHandler.openUri(GUIDE_MANUAL_URL) }) {
            Text(stringResource(R.string.guide_manual))
        }
    }
}

@Composable
private fun GuideRow(entry: GuideEntry) {
    val action = if (entry.action == 0) entry.fallback else stringResource(entry.action)
    val hold = if (entry.hold) stringResource(R.string.guide_hold) else ""
    val knob = stringResource(R.string.guide_knob)
    val spoken = entry.keys.joinToString(" + ") { if (it == "Knob") knob else it } + ": " + action + if (hold.isEmpty()) "" else ". $hold"
    BoxWithConstraints(Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = spoken }) {
        val keys: @Composable () -> Unit = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                entry.keys.forEachIndexed { index, key ->
                    if (index > 0) Text("+", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    KeyboardKeycap(key, key == "Knob")
                }
            }
        }
        val description: @Composable () -> Unit = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(action)
                if (entry.hold) Text(hold, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (maxWidth >= 480.dp) {
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.width(160.dp)) { keys() }
                Box(Modifier.weight(1f)) { description() }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { keys(); description() }
        }
    }
}

/** A decorative key, using the Home preview's cap dimensions and palette. */
@Composable
internal fun KeyboardKeycap(label: String, isKnob: Boolean = false) {
    val width = if (isKnob) 48.dp else maxOf(48, label.length * 10 + 22).dp
    Box(Modifier.size(width, 48.dp), contentAlignment = Alignment.Center) {
        if (isKnob) {
            Box(Modifier.fillMaxSize().clip(CircleShape).background(
                Brush.radialGradient(listOf(Color(0xff6b6b6b), Color(0xff1f1f1f)), radius = 100f)), contentAlignment = Alignment.Center) {
                Text("◉", color = Color.White, fontSize = 24.sp)
            }
        } else {
            Box(Modifier.fillMaxSize().clip(RoundedCornerShape(7.dp)).background(
                Brush.verticalGradient(listOf(KeycapPalette.skirtTop, KeycapPalette.skirtBottom))))
            Box(Modifier.fillMaxSize().padding(start = 5.dp, end = 5.dp, top = 3.dp, bottom = 9.dp)
                .clip(RoundedCornerShape(5.dp)).background(Brush.verticalGradient(listOf(KeycapPalette.faceTop, KeycapPalette.faceBottom))),
                contentAlignment = Alignment.Center) {
                Text(label, color = Color(0xff2e2e2e), fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }
        }
    }
}

internal object KeycapPalette {
    val skirtTop = Color(0xffa8a8a8)
    val skirtBottom = Color(0xff808080)
    val faceTop = Color(0xffdbdbdb)
    val faceBottom = Color(0xffbdbdbd)
}
