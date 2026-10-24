package com.vitalyart.aulaf75maxdriver

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.DateFormat
import java.util.Date

@Composable
fun UpdatesCard(model: UpdatesViewModel) {
    val s by model.state.collectAsStateWithLifecycle()
    val install by model.installer.state.collectAsStateWithLifecycle()
    val uri = LocalUriHandler.current
    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.update_settings), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            Text(stringResource(R.string.update_title), style = MaterialTheme.typography.titleLarge)
            Text("${stringResource(R.string.update_current)}: ${BuildConfig.VERSION_NAME}", style = MaterialTheme.typography.bodySmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = !s.alpha, onClick = { if (s.alpha) model.setChannel(false) }, label = { Text("Stable") })
                FilterChip(selected = s.alpha, onClick = { if (!s.alpha) model.setChannel(true) }, label = { Text("Alpha") })
            }
            Text(stringResource(if (s.alpha) R.string.update_alpha else R.string.update_stable), style = MaterialTheme.typography.bodySmall)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.update_auto), modifier = Modifier.weight(1f))
                Switch(checked = s.automatic, onCheckedChange = model::setAutomatic)
            }
            install.error?.let { Text(stringResource(it), color = MaterialTheme.colorScheme.error) }
            if (install.downloading) {
                if (install.progress != null) LinearProgressIndicator(progress = { install.progress!! }, modifier = Modifier.fillMaxWidth())
                else LinearProgressIndicator(Modifier.fillMaxWidth())
                Text(stringResource(R.string.update_downloading))
                TextButton(onClick = model.installer::cancel) { Text(stringResource(R.string.update_cancel)) }
            }
            if (s.checking) { LinearProgressIndicator(Modifier.fillMaxWidth()); Text(stringResource(R.string.update_checking)) }
            else if (s.error) Text(stringResource(R.string.update_error), color = MaterialTheme.colorScheme.error)
            else if (s.release != null) {
                val r = s.release!!
                Text("${stringResource(R.string.update_available)}: ${r.tag}", style = MaterialTheme.typography.titleMedium)
                if (r.preview) Text(stringResource(R.string.update_preview), color = MaterialTheme.colorScheme.tertiary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { if (install.file != null) model.installer.requestInstall() else model.installer.download(r) }, enabled = !install.downloading) { Text(stringResource(if (install.file != null) R.string.update_install else R.string.update_action)) }
                    TextButton(onClick = { runCatching { uri.openUri(r.page) } }) { Text(stringResource(R.string.update_notes)) }
                }
            } else if (s.checked > 0) Text(stringResource(R.string.update_latest))
            if (s.checked > 0) Text("${stringResource(R.string.update_checked)}: ${DateFormat.getDateTimeInstance().format(Date(s.checked))}", style = MaterialTheme.typography.bodySmall)
            OutlinedButton(onClick = model::check, enabled = !s.checking) { Text(stringResource(R.string.update_check)) }
        }
    }
}

@Composable
fun UpdateBanner(model: UpdatesViewModel) {
    val s by model.state.collectAsStateWithLifecycle()
    val install by model.installer.state.collectAsStateWithLifecycle()
    val uri = LocalUriHandler.current
    val r = s.release
    if (r != null && s.dismissed != r.tag) Surface(color = MaterialTheme.colorScheme.secondaryContainer) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("${stringResource(R.string.update_available)}: ${r.tag}", Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { if (install.file != null) model.installer.requestInstall() else model.installer.download(r) }, enabled = !install.downloading) { Text(stringResource(if (install.file != null) R.string.update_install else R.string.update_action)) }
            TextButton(onClick = model::dismiss) { Text(stringResource(R.string.update_dismiss)) }
        }
    }
}
