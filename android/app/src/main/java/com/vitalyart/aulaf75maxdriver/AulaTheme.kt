package com.vitalyart.aulaf75maxdriver

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val DarkColors = darkColorScheme(
    primary = Color(0xFF79AFFF),
    onPrimary = Color(0xFF071C35),
    primaryContainer = Color(0xFF233C5C),
    onPrimaryContainer = Color(0xFFD4E4FF),
    secondary = Color(0xFF8ED1C6),
    onSecondary = Color(0xFF003731),
    tertiary = Color(0xFFC8B6FF),
    background = Color(0xFF242424),
    onBackground = Color(0xFFECECEC),
    surface = Color(0xFF303030),
    surfaceVariant = Color(0xFF3A3A3A),
    onSurface = Color(0xFFECECEC),
    onSurfaceVariant = Color(0xFFBDBDBD),
    outline = Color(0xFF767676),
    error = Color(0xFFFFB4AB),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6)
)

private val AulaTypography = androidx.compose.material3.Typography(
    headlineMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = 28.sp, letterSpacing = (-0.5).sp),
    titleLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold, fontSize = 22.sp),
    titleMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold, fontSize = 16.sp),
    labelLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = 14.sp, letterSpacing = 0.3.sp)
)

@Composable
fun AulaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColors,
        typography = AulaTypography,
        content = {
            androidx.compose.runtime.CompositionLocalProvider(
                androidx.compose.material3.LocalContentColor provides DarkColors.onBackground,
                content = content
            )
        }
    )
}
