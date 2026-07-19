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
    primary = Color(0xFFFFB74D),
    onPrimary = Color(0xFF2A1700),
    primaryContainer = Color(0xFF593700),
    onPrimaryContainer = Color(0xFFFFDDB3),
    secondary = Color(0xFF8ED1C6),
    onSecondary = Color(0xFF003731),
    tertiary = Color(0xFFC8B6FF),
    background = Color(0xFF10100E),
    onBackground = Color(0xFFE9E3D9),
    surface = Color(0xFF1A1A17),
    surfaceVariant = Color(0xFF25251F),
    onSurface = Color(0xFFE9E3D9),
    onSurfaceVariant = Color(0xFFCBC6BA),
    outline = Color(0xFF938F85),
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
        content = content
    )
}
