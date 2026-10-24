package com.vitalyart.aulaf75maxdriver

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun UpdateInstallCoordinator(model: UpdatesViewModel, canInstall: Boolean) {
    val context = LocalContext.current
    val state by model.installer.state.collectAsStateWithLifecycle()
    val currentCanInstall by rememberUpdatedState(canInstall)
    val installer = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { }
    fun openInstaller() {
        val file = model.installer.state.value.file ?: return
        if (!currentCanInstall) { model.installer.requestInstall(); return }
        runCatching { installer.launch(model.installer.installIntent(file)) }
            .onFailure { model.installer.installationError(R.string.update_install_failed) }
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        if (context.packageManager.canRequestPackageInstalls()) openInstaller()
        else model.installer.installationError(R.string.update_install_permission)
    }
    LaunchedEffect(state.pendingInstall, canInstall) {
        if (state.pendingInstall != null && canInstall) {
            model.installer.consumeRequest()
            if (context.packageManager.canRequestPackageInstalls()) openInstaller()
            else runCatching { permission.launch(model.installer.permissionIntent()) }
                .onFailure { model.installer.installationError(R.string.update_install_permission) }
        }
    }
}
