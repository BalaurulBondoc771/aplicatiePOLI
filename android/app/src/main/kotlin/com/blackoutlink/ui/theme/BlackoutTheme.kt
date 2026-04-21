package com.blackoutlink.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val BlackoutColors = darkColorScheme(
    primary = Color(0xFFF5B323),
    onPrimary = Color.Black,
    background = Color(0xFF050505),
    onBackground = Color(0xFFF3F3F3),
    surface = Color(0xFF141414),
    onSurface = Color(0xFFF3F3F3),
    error = Color(0xFFB30000)
)

@Composable
fun BlackoutTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = BlackoutColors,
        content = content
    )
}
