package com.vitalyart.aulaf75maxdriver

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    private val viewModel: AulaViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        AndroidLanguageManager.applyLanguage(AndroidLanguageManager.loadLanguageCode(this))
        super.onCreate(savedInstanceState)
        setContent {
            AulaTheme {
                AulaApp(viewModel = viewModel)
            }
        }
    }
}
