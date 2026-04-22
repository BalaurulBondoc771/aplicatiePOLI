import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'chat.dart';
import 'dashboard.dart';
import 'power.dart';
import 'sos.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blackout Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.dashboard,
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.chat) {
          final args = AppRoutes.chatArgsOf(settings.arguments);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ChatPage(initialArgs: args),
          );
        }
        return null;
      },
      routes: {
        AppRoutes.dashboard: (_) => const DashboardPage(),
        AppRoutes.power: (_) => const PowerPage(),
        AppRoutes.sos: (_) => const SosPage(),
      },
    );
  }
}
