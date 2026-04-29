import 'package:flutter/material.dart';

import '../app_routes.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentRoute,
  });

  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      color: const Color(0xFF090B10),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.grid_view,
              label: 'DASHBOARD',
              active: currentRoute == AppRoutes.dashboard,
              onTap: currentRoute == AppRoutes.dashboard
                  ? null
                  : () => Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.chat,
              label: 'CHAT',
              active: currentRoute == AppRoutes.chat,
              onTap: currentRoute == AppRoutes.chat
                  ? null
                  : () => Navigator.of(context).pushReplacementNamed(AppRoutes.chat),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.flash_on,
              label: 'POWER',
              active: currentRoute == AppRoutes.power,
              onTap: currentRoute == AppRoutes.power
                  ? null
                  : () => Navigator.of(context).pushReplacementNamed(AppRoutes.power),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.warning,
              label: 'SOS',
              active: currentRoute == AppRoutes.sos,
              onTap: currentRoute == AppRoutes.sos
                  ? null
                  : () => Navigator.of(context).pushReplacementNamed(AppRoutes.sos),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF7B21A) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.black : const Color(0xFF737885), size: 21),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : const Color(0xFF737885),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
