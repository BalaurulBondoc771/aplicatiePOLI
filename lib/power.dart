import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'power/power_controller.dart';
import 'power/power_state.dart';

class PowerPage extends StatefulWidget {
  const PowerPage({super.key});

  @override
  State<PowerPage> createState() => _PowerPageState();
}

class _PowerPageState extends State<PowerPage> {
  final PowerController _controller = PowerController();

  static const Color _bg = Color(0xFF050608);
  static const Color _panel = Color(0xFF1C1F25);
  static const Color _panelSoft = Color(0xFF2A2D33);
  static const Color _amber = Color(0xFFF7B21A);
  static const Color _muted = Color(0xFF767B86);
  static const Color _red = Color(0xFFB50014);

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PowerState>(
      stream: _controller.stateStream,
      initialData: _controller.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _controller.state;
        final body = Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            bottom: true,
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'POWER ESTIMATE',
                            style: TextStyle(
                              color: _amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${state.runtimeHours.toString().padLeft(2, '0')}:${state.runtimeMinsRemainder.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Color(0xFFDDE0E6),
                                  fontSize: 58,
                                  fontWeight: FontWeight.w900,
                                  height: 0.95,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'HRS',
                                  style: TextStyle(
                                    color: Color(0xFF7A7F89),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () => _controller.setBatterySaver(!state.batterySaverEnabled),
                            child: Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              color: _panel,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    state.batterySaverEnabled ? Icons.battery_charging_full : Icons.battery_alert,
                                    color: _amber,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    state.batterySaverEnabled
                                        ? 'EXTREME SAVING ACTIVE'
                                        : 'EXTREME SAVING OFF',
                                    style: const TextStyle(
                                      color: Color(0xFFDFE2E7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                          _settingCardCritical(state),
                          const SizedBox(height: 14),
                          _settingCardGray(state),
                          const SizedBox(height: 14),
                          _settingCardBluetooth(state),
                          if (state.lastAction != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              state.lastAction!,
                              style: const TextStyle(
                                color: Color(0xFFF7B21A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                          if (state.error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'POWER ERROR: ${state.error}',
                              style: const TextStyle(
                                color: Color(0xFFFF8A8A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Listener(
                            onPointerDown: (_) => _controller.startSosHold(),
                            onPointerUp: (_) => _controller.endSosHold(),
                            onPointerCancel: (_) => _controller.endSosHold(),
                            child: SizedBox(
                              width: double.infinity,
                              height: 96,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: _red,
                                        foregroundColor: Colors.white,
                                        shape: const RoundedRectangleBorder(),
                                      ),
                                      onPressed: () {},
                                      icon: const Icon(Icons.emergency_outlined, size: 28),
                                      label: Text(
                                        state.sendingSos
                                            ? 'SENDING EMERGENCY\nSOS'
                                            : 'ACTIVATE EMERGENCY\nSOS',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          height: 1.1,
                                          letterSpacing: 0.8,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      height: 7,
                                      color: const Color(0x33000000),
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: state.sosHoldProgress.clamp(0.0, 1.0),
                                        child: Container(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              state.sendingSos
                                  ? 'BROADCASTING LOCATION...'
                                  : 'HOLD 3 SECONDS TO BROADCAST LOCATION',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _bottomNav(context),
              ],
            ),
          ),
        );

        if (!state.grayscaleUiEnabled) {
          return body;
        }

        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: body,
        );
      },
    );
  }

  Widget _topBar() {
    return Container(
      height: 82,
      color: const Color(0xFF171A20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: const [
          Icon(Icons.navigation, color: _amber, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'BLACKOUT LINK',
              style: TextStyle(
                color: _amber,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacer(),
          Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 34),
        ],
      ),
    );
  }

  Widget _settingCardCritical(PowerState state) {
    return GestureDetector(
      onTap: _controller.killBackgroundApps,
      child: Container(
        width: double.infinity,
        height: 202,
        color: _panelSoft,
        child: Row(
          children: [
            Container(width: 6, color: _amber),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CRITICAL TASKS ONLY',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'KILL BACKGROUND\nAPPS',
                            style: TextStyle(
                              color: Color(0xFFDFE2E8),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'OPTIMIZES INTERNAL TASKS AND\nOPENS BATTERY SETTINGS WHEN\nAVAILABLE.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 56,
                      color: _amber,
                      padding: const EdgeInsets.all(6),
                      child: Align(
                        alignment: state.criticalTasksOnlyEnabled
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(width: 40, height: 42, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingCardGray(PowerState state) {
    return GestureDetector(
      onTap: () => _controller.setGrayscaleUi(!state.grayscaleUiEnabled),
      child: Container(
        width: double.infinity,
        height: 170,
        color: _panel,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'GRAYSCALE DISPLAY',
                    style: TextStyle(
                      color: Color(0xFFDFE2E8),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.brightness_2, color: Color(0xFF707580), size: 30),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  state.grayscaleUiEnabled ? 'OLED OPTIMIZED - ON' : 'OLED OPTIMIZED - OFF',
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 88,
                  height: 56,
                  color: const Color(0xFF4A4D53),
                  padding: const EdgeInsets.all(6),
                  child: Align(
                    alignment: state.grayscaleUiEnabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 40,
                      height: 42,
                      color: const Color(0xFF8B8B8B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingCardBluetooth(PowerState state) {
    return GestureDetector(
      onTap: () => _controller.setLowPowerBluetooth(!state.lowPowerBluetoothEnabled),
      child: Container(
        width: double.infinity,
        height: 160,
        color: _panelSoft,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 68,
              color: Colors.black,
              alignment: Alignment.center,
              child: const Icon(Icons.bluetooth, color: _amber, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOW POWER\nBLUETOOTH',
                    style: TextStyle(
                      color: Color(0xFFDFE2E8),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SCAN INTERVAL ${state.scanIntervalMs ~/ 1000}S ${state.lowPowerBluetoothEnabled ? '(LOW POWER)' : '(NORMAL)'}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 88,
              height: 56,
              color: _amber,
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: state.lowPowerBluetoothEnabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(width: 40, height: 42, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return Container(
      height: 86,
      color: const Color(0xFF080A0E),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'DASHBOARD',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.chat_outlined,
              label: 'CHAT',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.chat),
            ),
          ),
          const Expanded(
            child: _NavItem(
              icon: Icons.flash_on_outlined,
              label: 'POWER',
              active: true,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.warning_amber_rounded,
              label: 'SOS',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.sos),
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

  static const Color _activeAmber = Color(0xFFF7B21A);

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
          color: active ? _activeAmber : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? Colors.black : const Color(0xFF737885),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : const Color(0xFF737885),
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w800,
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
