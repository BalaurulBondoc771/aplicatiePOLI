import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'power/power_controller.dart';
import 'power/power_state.dart';
import 'widgets/app_bottom_nav.dart';

class PowerPage extends StatefulWidget {
  const PowerPage({super.key});

  @override
  State<PowerPage> createState() => _PowerPageState();
}

class _PowerPageState extends State<PowerPage> with WidgetsBindingObserver {
  final PowerController _controller = PowerController();

  static const Color _bg = Color(0xFF050608);
  static const Color _panel = Color(0xFF1C1F25);
  static const Color _panelSoft = Color(0xFF2A2D33);
  static const Color _amber = Color(0xFFF7B21A);
  static const Color _muted = Color(0xFF767B86);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        return Scaffold(
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
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    state.runtimeLabel,
                                    style: const TextStyle(
                                      color: Color(0xFFDDE0E6),
                                      fontSize: 58,
                                      fontWeight: FontWeight.w900,
                                      height: 0.95,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      'LEFT',
                                      style: TextStyle(
                                        color: Color(0xFF7A7F89),
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _batterySaverRow(state),
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
      },
    );
  }

  Widget _topBar() {
    return Container(
      height: 82,
      color: const Color(0xFF171A20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: _amber, size: 21),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'BLACKOUT LINK',
              style: TextStyle(
                color: _amber,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
            child: const Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 34),
          ),
        ],
      ),
    );
  }

  Widget _batterySaverRow(PowerState state) {
    return GestureDetector(
      onTap: () => _controller.setBatterySaver(!state.batterySaverEnabled),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final toggleWidth = compact ? 76.0 : 88.0;
          final toggleHeight = compact ? 40.0 : 48.0;
          final knobSize = compact ? 28.0 : 36.0;
          return Container(
            height: compact ? 92 : 96,
            color: _panelSoft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.battery_charging_full, color: _amber, size: compact ? 22 : 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATTERY SAVER',
                        style: TextStyle(
                          color: const Color(0xFFE8EAEE),
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 18 : 20,
                          letterSpacing: 0.2,
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'EXTEND MESH UPTIME',
                        style: TextStyle(
                          color: const Color(0xFF9EA3AD),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 12,
                          letterSpacing: compact ? 0.6 : 0.8,
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: toggleWidth,
                  height: toggleHeight,
                  color: state.batterySaverEnabled ? _amber : const Color(0xFF4A4D53),
                  padding: const EdgeInsets.all(6),
                  child: Align(
                    alignment: state.batterySaverEnabled ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(width: knobSize, height: knobSize, color: Colors.black),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _settingCardCritical(PowerState state) {
    return GestureDetector(
      onTap: _controller.toggleCriticalTasksOnly,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 202),
        color: _panelSoft,
        child: Row(
          children: [
            Container(width: 6, color: _amber),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 370;
                    final toggle = Container(
                      width: compact ? 76 : 88,
                      height: compact ? 44 : 56,
                      color: state.criticalTasksOnlyEnabled ? _amber : const Color(0xFF4A4D53),
                      padding: const EdgeInsets.all(6),
                      child: Align(
                        alignment: state.criticalTasksOnlyEnabled
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: compact ? 28 : 40,
                          height: compact ? 28 : 42,
                          color: Colors.black,
                        ),
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CRITICAL TASKS ONLY',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'KILL BACKGROUND APPS',
                            style: TextStyle(
                              color: Color(0xFFDFE2E8),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'OPTIMIZES INTERNAL TASKS AND OPENS\nBATTERY SETTINGS WHEN AVAILABLE.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(alignment: Alignment.centerRight, child: toggle),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'CRITICAL TASKS ONLY',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'KILL BACKGROUND APPS',
                                style: TextStyle(
                                  color: Color(0xFFDFE2E8),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
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
                        const SizedBox(width: 12),
                        toggle,
                      ],
                    );
                  },
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
                      fontSize: 22,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 360;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 88,
                          height: 56,
                          color: state.grayscaleUiEnabled ? _amber : const Color(0xFF4A4D53),
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
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.grayscaleUiEnabled ? 'OLED OPTIMIZED - ON' : 'OLED OPTIMIZED - OFF',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 88,
                      height: 56,
                      color: state.grayscaleUiEnabled ? _amber : const Color(0xFF4A4D53),
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingCardBluetooth(PowerState state) {
    return GestureDetector(
      onTap: () => _controller.setLowPowerBluetooth(!state.lowPowerBluetoothEnabled),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 370;
          final toggle = Container(
            width: compact ? 76 : 88,
            height: compact ? 44 : 56,
            color: state.lowPowerBluetoothEnabled ? _amber : const Color(0xFF4A4D53),
            padding: const EdgeInsets.all(6),
            child: Align(
              alignment: state.lowPowerBluetoothEnabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: compact ? 28 : 40,
                height: compact ? 28 : 42,
                color: Colors.black,
              ),
            ),
          );

          return Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140),
            color: _panelSoft,
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                      Text(
                        'LOW POWER BLUETOOTH',
                        style: TextStyle(
                          color: const Color(0xFFDFE2E8),
                          fontSize: compact ? 17 : 19,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SCAN INTERVAL ${state.scanIntervalMs ~/ 1000}S ${state.lowPowerBluetoothEnabled ? '(LOW POWER)' : '(NORMAL)'}',
                        style: TextStyle(
                          color: _muted,
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: compact ? 0.5 : 0.8,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (compact) ...[
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: toggle),
                      ],
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  toggle,
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return const AppBottomNav(currentRoute: AppRoutes.power);
  }
}
