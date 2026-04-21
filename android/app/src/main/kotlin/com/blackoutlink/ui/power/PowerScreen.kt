package com.blackoutlink.ui.power

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun PowerScreen(
    batterySaverEnabled: Boolean,
    estimatedRuntimeHours: Int,
    scanIntervalMs: Long,
    onBatterySaverChanged: (Boolean) -> Unit,
    onScanIntervalChanged: (Long) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("POWER", style = MaterialTheme.typography.headlineMedium)
        Text("Estimated runtime: ${estimatedRuntimeHours}h", style = MaterialTheme.typography.bodyLarge)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("Blackout Mode")
            Switch(
                checked = batterySaverEnabled,
                onCheckedChange = onBatterySaverChanged
            )
        }

        Text("Mesh scan interval: ${scanIntervalMs} ms")
        Slider(
            value = scanIntervalMs.toFloat(),
            onValueChange = { onScanIntervalChanged(it.toLong()) },
            valueRange = 1000f..10000f
        )
    }
}
