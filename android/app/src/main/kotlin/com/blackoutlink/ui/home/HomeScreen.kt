package com.blackoutlink.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.blackoutlink.domain.model.HomeUiState
import com.blackoutlink.domain.model.PeerDevice
import com.blackoutlink.domain.model.PeerStatus
import com.blackoutlink.domain.model.SystemState

private val BgBlack = Color(0xFF050505)
private val CardDark = Color(0xFF141414)
private val AccentYellow = Color(0xFFF5B323)
private val DangerRed = Color(0xFFB30000)
private val SoftGray = Color(0xFF8A8A8A)
private val TextWhite = Color(0xFFF3F3F3)

@Composable
fun HomeScreen(
    onOpenChat: () -> Unit,
    onOpenPower: () -> Unit,
    onOpenSos: () -> Unit,
    vm: HomeViewModel = viewModel()
) {
    val uiState by vm.uiState.collectAsState()
    val showSosDialog = remember { mutableStateOf(false) }

    SurfaceContainer {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(vertical = 20.dp)
        ) {
            item { Header() }
            item { StatusSection(uiState) }

            item {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    StatCard(
                        title = "BATTERY",
                        value = "${uiState.batteryPercent}",
                        suffix = "%",
                        valueColor = AccentYellow,
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        title = "RUNTIME",
                        value = "${(uiState.batteryPercent.coerceIn(0, 100) / 10)}",
                        suffix = "H",
                        valueColor = TextWhite,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            item { SectionTitle("MISSION CRITICAL ACTIONS") }
            item {
                PrimaryActionCard(
                    title = "START OFFLINE CHAT",
                    subtitle = "COMMS ENCRYPTED",
                    onClick = onOpenChat
                )
            }
            item {
                BatterySaverCard(
                    enabled = uiState.batterySaverEnabled,
                    onToggle = {
                        vm.onToggleBatterySaver()
                        onOpenPower()
                    }
                )
            }
            item { MeshNodesCard(uiState) }
            item {
                SosCard(
                    onActivateSos = {
                        vm.onActivateSos()
                        showSosDialog.value = true
                    }
                )
            }

            item { SectionTitle("NETWORK PEERS") }
            items(uiState.peers) { peer -> PeerCard(peer) }
            item { BottomSpacer() }
        }
    }

    if (showSosDialog.value) {
        AlertDialog(
            onDismissRequest = { showSosDialog.value = false },
            title = { Text("Confirm SOS") },
            text = { Text("Transmit emergency beacon to trusted peers?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showSosDialog.value = false
                        onOpenSos()
                    }
                ) {
                    Text("Proceed")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSosDialog.value = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun SurfaceContainer(content: @Composable () -> Unit) {
    androidx.compose.material3.Surface(
        modifier = Modifier.fillMaxSize(),
        color = BgBlack
    ) {
        content()
    }
}

@Composable
private fun Header() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "BLACKOUT LINK",
            color = AccentYellow,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.ExtraBold
        )
        Text(
            text = "MVP",
            color = TextWhite,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun StatusSection(uiState: HomeUiState) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "SYSTEM STATUS",
            color = SoftGray,
            style = MaterialTheme.typography.labelLarge
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = when (uiState.systemState) {
                SystemState.OPERATIONAL -> "OPERATIONAL"
                SystemState.DEGRADED -> "DEGRADED"
                SystemState.OFFLINE -> "OFFLINE"
            },
            color = TextWhite,
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.ExtraBold
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = "Bluetooth: ${if (uiState.isBluetoothEnabled) "ON" else "OFF"}",
            color = if (uiState.isBluetoothEnabled) AccentYellow else SoftGray,
            style = MaterialTheme.typography.bodyLarge
        )
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    suffix: String,
    valueColor: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.height(130.dp),
        shape = RoundedCornerShape(0.dp),
        colors = CardDefaults.cardColors(containerColor = CardDark)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Text(text = title, color = SoftGray, style = MaterialTheme.typography.labelLarge)
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = value,
                    color = valueColor,
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.ExtraBold
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = suffix,
                    color = SoftGray,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        color = SoftGray,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.Bold
    )
}

@Composable
private fun PrimaryActionCard(
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(0.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFF0C35A))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = subtitle,
                    color = Color.Black,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = title,
                    color = Color.Black,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.ExtraBold
                )
            }
            Text(
                text = "GO",
                color = Color.Black,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun BatterySaverCard(
    enabled: Boolean,
    onToggle: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(0.dp),
        colors = CardDefaults.cardColors(containerColor = CardDark)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "BATTERY SAVER",
                    color = TextWhite,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = if (enabled) "BLACKOUT MODE ON" else "BLACKOUT MODE OFF",
                    color = SoftGray,
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            Switch(
                checked = enabled,
                onCheckedChange = { onToggle() }
            )
        }
    }
}

@Composable
private fun MeshNodesCard(uiState: HomeUiState) {
    Card(
        shape = RoundedCornerShape(0.dp),
        colors = CardDefaults.cardColors(containerColor = CardDark)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = "MESH NODES",
                color = TextWhite,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Detected: ${uiState.meshStats.detected}",
                color = SoftGray,
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = "Active: ${uiState.meshStats.active} | Trusted: ${uiState.meshStats.trusted}",
                color = SoftGray,
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = "Relay-capable: ${uiState.meshStats.relayCapable}",
                color = SoftGray,
                style = MaterialTheme.typography.bodyMedium
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .background(Color(0xFF0B0B0B))
            )
        }
    }
}

@Composable
private fun SosCard(onActivateSos: () -> Unit) {
    Card(
        onClick = onActivateSos,
        shape = RoundedCornerShape(0.dp),
        colors = CardDefaults.cardColors(containerColor = DangerRed)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp, horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "ACTIVATE SOS BEACON",
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.ExtraBold
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "HOLD TO TRANSMIT LOCATION",
                color = Color(0xFFFFD0D0),
                style = MaterialTheme.typography.labelLarge
            )
        }
    }
}

@Composable
private fun PeerCard(peer: PeerDevice) {
    Card(
        shape = RoundedCornerShape(0.dp),
        colors = CardDefaults.cardColors(containerColor = CardDark)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = peer.name,
                    color = TextWhite,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = when (peer.status) {
                        PeerStatus.CONNECTED -> "CONNECTED"
                        PeerStatus.SCANNING -> "SCANNING"
                        PeerStatus.LOST -> "LOST"
                    },
                    color = when (peer.status) {
                        PeerStatus.CONNECTED -> AccentYellow
                        PeerStatus.SCANNING -> SoftGray
                        PeerStatus.LOST -> Color.Red
                    },
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            Text(
                text = "${peer.rssi} dBm",
                color = SoftGray,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
private fun BottomSpacer() {
    Spacer(modifier = Modifier.height(80.dp))
}
