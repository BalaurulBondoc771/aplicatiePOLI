import 'package:blackoutapp/app_routes.dart';
import 'package:blackoutapp/chat/chat_controller.dart';
import 'package:blackoutapp/chat/chat_session_dto.dart';
import 'package:blackoutapp/dashboard/dashboard_controller.dart';
import 'package:blackoutapp/permissions/permissions_state.dart';
import 'package:blackoutapp/power/power_controller.dart';
import 'package:blackoutapp/sos/sos_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel chatMethod = MethodChannel('blackout_link/chat');
  const MethodChannel meshMethod = MethodChannel('blackout_link/mesh');
  const MethodChannel systemMethod = MethodChannel('blackout_link/system');
  const MethodChannel powerMethod = MethodChannel('blackout_link/power');
  const MethodChannel sosMethod = MethodChannel('blackout_link/sos');
  const MethodChannel locationMethod = MethodChannel('blackout_link/location');

  const List<String> eventChannelNames = <String>[
    'blackout_link/chat/incoming',
    'blackout_link/chat/connection',
    'blackout_link/mesh/peers',
    'blackout_link/system/status',
    'blackout_link/power/state',
    'blackout_link/sos/state',
    'blackout_link/location/updates',
  ];

  setUp(() {
    for (final String name in eventChannelNames) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (MethodCall call) async {
        if (call.method == 'listen' || call.method == 'cancel') {
          return null;
        }
        return null;
      });
    }
  });

  tearDown(() {
    chatMethod.setMockMethodCallHandler(null);
    meshMethod.setMockMethodCallHandler(null);
    systemMethod.setMockMethodCallHandler(null);
    powerMethod.setMockMethodCallHandler(null);
    sosMethod.setMockMethodCallHandler(null);
    locationMethod.setMockMethodCallHandler(null);
    for (final String name in eventChannelNames) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('dashboard controller maps channel payload into state', () async {
    systemMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'getStatus') {
        return <String, dynamic>{
          'state': 'operational',
          'bluetoothEnabled': true,
          'permissionsMissing': false,
          'batteryAvailable': true,
          'batteryPercent': 81,
          'locationAvailable': true,
          'nodesActive': 3,
          'meshRadiusKm': 0.9,
          'btRangeKm': 0.9,
          'signalState': 'optimal',
          'staleScanResults': false,
          'peersAvailable': true,
        };
      }
      return <String, dynamic>{};
    });

    powerMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'getSettings') {
        return <String, dynamic>{'batterySaverEnabled': true};
      }
      return <String, dynamic>{};
    });

    meshMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'startScan') {
        return <String, dynamic>{'ok': true};
      }
      return <String, dynamic>{};
    });

    final controller = DashboardController();
    await controller.init();

    expect(controller.state.loading, isFalse);
    expect(controller.state.batteryPercent, 81);
    expect(controller.state.batterySaverEnabled, isTrue);
    expect(controller.state.meshStats.nodesActive, 3);
    controller.dispose();
  });

  test('chat controller updates draft and sends message', () async {
    chatMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'sendMessage') {
        return <String, dynamic>{
          'status': 'SENT',
          'messageId': 'remote-1',
          'createdAt': 123,
        };
      }
      return <String, dynamic>{};
    });

    final controller = ChatController();
    await controller.init(
      ChatRouteArgs(
        session: ChatSessionDto.standby(peerId: 'peer-1', peerName: 'Peer 1'),
      ),
    );

    controller.updateDraft('hello from test');
    await controller.sendDraft();

    expect(controller.state.draft, '');
    expect(controller.state.messages.length, 1);
    expect(controller.state.messages.first.status, 'SENT');
    controller.dispose();
  });

  testWidgets('sos hold cancelled before 3s does not send', (WidgetTester tester) async {
    var sendCount = 0;

    locationMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'observeLocationUpdates') {
        return <String, dynamic>{'ok': true};
      }
      return <String, dynamic>{
        'ok': true,
        'latitude': 1.0,
        'longitude': 2.0,
        'accuracyMeters': 5.0,
        'timestamp': 10,
        'isStale': false,
        'isFallback': false,
        'gpsEnabled': true,
        'permissionGranted': true,
        'source': 'gps',
      };
    });

    sosMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'sendSos') {
        sendCount++;
        return <String, dynamic>{'ok': true};
      }
      return <String, dynamic>{};
    });

    final controller = SosController();
    controller.init();

    controller.startHold();
    await tester.pump(const Duration(milliseconds: 1200));
    controller.endHold();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(sendCount, 0);
    controller.dispose();
  });

  testWidgets('sos hold complete triggers send', (WidgetTester tester) async {
    var sendCount = 0;

    locationMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'observeLocationUpdates') {
        return <String, dynamic>{'ok': true};
      }
      return <String, dynamic>{
        'ok': true,
        'latitude': 1.0,
        'longitude': 2.0,
        'accuracyMeters': 5.0,
        'timestamp': 10,
        'isStale': false,
        'isFallback': false,
        'gpsEnabled': true,
        'permissionGranted': true,
        'source': 'gps',
      };
    });

    sosMethod.setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'sendSos') {
        sendCount++;
        return <String, dynamic>{
          'ok': true,
          'sosAlertId': 's1',
          'sentCount': 1,
          'deliveredCount': 1,
          'failedCount': 0,
          'timestamp': 123,
          'location': <String, dynamic>{'latitude': 1.0, 'longitude': 2.0},
          'source': 'gps',
        };
      }
      return <String, dynamic>{};
    });

    final controller = SosController();
    controller.init();

    controller.startHold();
    await tester.pump(const Duration(milliseconds: 3200));

    expect(sendCount, 1);
    expect(controller.state.isSending, isFalse);
    controller.dispose();
  });

  test('power controller toggle updates local state', () async {
    powerMethod.setMockMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'getPowerSettings':
          return <String, dynamic>{
            'batterySaverEnabled': false,
            'lowPowerBluetoothEnabled': false,
            'grayscaleUiEnabled': false,
            'criticalTasksOnlyEnabled': false,
            'sosActive': false,
            'scanIntervalMs': 1000,
          };
        case 'getRuntimeEstimate':
          return <String, dynamic>{'minutes': 120, 'runtimeLabel': '02:00'};
        case 'setBatterySaver':
          return <String, dynamic>{
            'batterySaverEnabled': true,
            'lowPowerBluetoothEnabled': false,
            'grayscaleUiEnabled': false,
            'criticalTasksOnlyEnabled': false,
            'sosActive': false,
            'scanIntervalMs': 1000,
          };
      }
      return <String, dynamic>{};
    });

    final controller = PowerController();
    await controller.init();
    await controller.setBatterySaver(true);

    expect(controller.state.batterySaverEnabled, isTrue);
    controller.dispose();
  });

  test('permissions banner logic covers missing permissions', () {
    const state = PermissionsState(
      bluetoothScan: 'denied',
      bluetoothConnect: 'granted',
      fineLocation: 'granted',
      microphone: 'not_required',
      bluetoothEnabled: true,
      locationServiceEnabled: true,
      requestInProgress: false,
      lastError: null,
    );

    expect(state.canUseMeshActions, isFalse);
    expect(state.toBannerMessage(), contains('Permissions missing'));
  });
}
