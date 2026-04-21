package com.blackoutlink.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.blackoutlink.ui.chat.ChatScreen
import com.blackoutlink.ui.home.HomeScreen
import com.blackoutlink.ui.power.PowerScreen
import com.blackoutlink.ui.sos.SosScreen

sealed class BlackoutDestination(val route: String, val label: String) {
    data object Home : BlackoutDestination("home", "Home")
    data object Chat : BlackoutDestination("chat", "Chat")
    data object Power : BlackoutDestination("power", "Power")
    data object Sos : BlackoutDestination("sos", "SOS")
}

@Composable
fun BlackoutApp() {
    val navController = rememberNavController()
    val destinations = listOf(
        BlackoutDestination.Home,
        BlackoutDestination.Chat,
        BlackoutDestination.Power,
        BlackoutDestination.Sos
    )

    Scaffold(
        bottomBar = {
            val navBackStackEntry = navController.currentBackStackEntryAsState().value
            val currentDestination = navBackStackEntry?.destination

            NavigationBar {
                destinations.forEach { destination ->
                    NavigationBarItem(
                        selected = currentDestination
                            ?.hierarchy
                            ?.any { it.route == destination.route } == true,
                        onClick = {
                            navController.navigate(destination.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        label = { Text(text = destination.label) },
                        icon = {}
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = BlackoutDestination.Home.route,
            modifier = Modifier.padding(padding)
        ) {
            composable(BlackoutDestination.Home.route) {
                HomeScreen(
                    onOpenChat = { navController.navigate(BlackoutDestination.Chat.route) },
                    onOpenPower = { navController.navigate(BlackoutDestination.Power.route) },
                    onOpenSos = { navController.navigate(BlackoutDestination.Sos.route) }
                )
            }
            composable(BlackoutDestination.Chat.route) {
                ChatScreen()
            }
            composable(BlackoutDestination.Power.route) {
                PowerScreen()
            }
            composable(BlackoutDestination.Sos.route) {
                SosScreen()
            }
        }
    }
}
