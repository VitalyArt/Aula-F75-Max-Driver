package com.vitalyart.aulaf75maxdriver

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

data class AppLanguage(
    val code: String,
    val flag: String,
    val titleResId: Int
)

object AndroidLanguageManager {
    const val systemLanguageCode = "system"

    private const val prefsName = "aula_android_settings"
    private const val languageCodeKey = "app.language.code"

    val availableLanguages: List<AppLanguage> = listOf(
        AppLanguage(systemLanguageCode, "🌐", R.string.language_system),
        AppLanguage("en", "🇺🇸", R.string.language_english),
        AppLanguage("ru", "🇷🇺", R.string.language_russian)
    )

    fun loadLanguageCode(context: Context): String {
        return context.applicationContext
            .getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(languageCodeKey, systemLanguageCode)
            ?: systemLanguageCode
    }

    fun saveLanguageCode(context: Context, languageCode: String) {
        context.applicationContext
            .getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(languageCodeKey, languageCode)
            .apply()
    }

    fun applyLanguage(languageCode: String) {
        val tags = if (languageCode == systemLanguageCode) "" else languageCode
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tags))
    }
}
