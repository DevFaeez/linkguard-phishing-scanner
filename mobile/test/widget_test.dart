import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkguard/application/linkguard_controller.dart';
import 'package:linkguard/core/backend_client.dart';
import 'package:linkguard/core/scan_engine.dart';
import 'package:linkguard/platform/device_bridge.dart';
import 'package:linkguard/ui/linkguard_app.dart';
import 'package:linkguard/qr/qr_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> state;
  late List<String> calls;
  String? clipboard, shared;
  bool grantWarnings = true;
  setUp(() {
    state = {
      'enabled': false,
      'consent': false,
      'allApps': false,
      'selected': <String>[],
      'access': false,
      'warnings': false,
      'connected': false,
      'engineReady': false,
      'setupPending': false,
    };
    calls = [];
    clipboard = null;
    shared = null;
    grantWarnings = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceBridge.channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'status':
              return Map<String, dynamic>.from(state);
            case 'update':
              state.addAll(Map<String, dynamic>.from(call.arguments as Map));
              return null;
            case 'consumeShare':
              final value = shared;
              shared = null;
              return value;
            case 'openAccess':
              state['access'] = true;
              return null;
            case 'requestWarnings':
              state['warnings'] = grantWarnings;
              if (grantWarnings) {
                state['connected'] = true;
                state['engineReady'] = true;
              }
              return grantWarnings;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return clipboard == null ? null : {'text': clipboard};
          }
          return null;
        });
  });
  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double scale = 1,
    QrGalleryReader? qrReader,
  }) async {
    await t.binding.setSurfaceSize(size);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      t.platformDispatcher.clearTextScaleFactorTestValue();
      await t.binding.setSurfaceSize(null);
    });
    final controller = LinkGuardController(
      loadEngine: () async =>
          ScanEngine.fromJson(File('assets/model.json').readAsStringSync()),
    );
    await t.pumpWidget(
      LinkGuardApp(
        controller: controller,
        qrReader: qrReader ?? _FakeQrReader(),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> visible(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  Future<void> protect(WidgetTester t) async {
    await t.tap(find.byKey(const Key('nav-protection')));
    await t.pumpAndSettle();
  }

  void active() => state.addAll({
    'enabled': true,
    'consent': true,
    'allApps': true,
    'access': true,
    'warnings': true,
    'connected': true,
    'engineReady': true,
  });

  testWidgets('Home offers one action, with no server controls', (t) async {
    await mount(t, size: const Size(360, 800));
    expect(find.text('Tampal & semak'), findsOneWidget);
    expect(find.byKey(const Key('scan-action')).hitTestable(), findsOneWidget);
    expect(find.textContaining('backend'), findsNothing);
    expect(find.byKey(const Key('backend-endpoint')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('One tap pastes and scans', (t) async {
    clipboard = 'https://example.com';
    await mount(t);
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.text('Tiada tanda bahaya\ndikesan.'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
  });
  testWidgets('Typed suspicious link gives a plain warning without raw score', (
    t,
  ) async {
    await mount(t);
    await t.enterText(
      find.byKey(const Key('url-input')),
      'http://192.0.2.1/login',
    );
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.text('Jangan buka dahulu.'), findsOneWidget);
    expect(find.textContaining('Skor model:'), findsNothing);
  });
  testWidgets('Editing a URL removes its previous verdict', (t) async {
    await mount(t);
    final input = t
        .widget<TextField>(find.byKey(const Key('url-input')))
        .controller!;
    input.text = 'https://example.com';
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('scan-verdict')), findsOneWidget);
    input.selection = const TextSelection.collapsed(offset: 2);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('scan-verdict')), findsOneWidget);
    input.text = 'http://192.0.2.1/login';
    await t.pumpAndSettle();
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
  });
  testWidgets('Empty clipboard explains the next action', (t) async {
    await mount(t);
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.textContaining('Papan klip kosong'), findsOneWidget);
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
  });
  testWidgets('Several pasted links require a deliberate choice', (t) async {
    clipboard = 'https://example.com and http://192.0.2.1/login';
    await mount(t);
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.text('Link yang mana?'), findsOneWidget);
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
    await t.tap(find.text('https://example.com'));
    await t.pumpAndSettle();
    expect(find.text('Tiada tanda bahaya\ndikesan.'), findsOneWidget);
  });
  testWidgets('Android Share is scanned without another tap', (t) async {
    shared = 'http://192.0.2.1/login';
    await mount(t);
    expect(find.text('Jangan buka dahulu.'), findsOneWidget);
  });
  testWidgets('Invalid input never receives a harmless verdict', (t) async {
    await mount(t);
    await t.enterText(
      find.byKey(const Key('url-input')),
      'javascript:alert(1)',
    );
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.text('Cuba semak semula.'), findsOneWidget);
    expect(find.text('Tiada tanda bahaya\ndikesan.'), findsNothing);
  });
  testWidgets('Consent cancellation does not open Android settings', (t) async {
    await mount(t);
    await protect(t);
    await visible(t, find.byKey(const Key('setup-action')));
    await t.tap(find.byKey(const Key('setup-action')));
    await t.pumpAndSettle();
    await visible(t, find.text('Bukan sekarang'));
    await t.tap(find.text('Bukan sekarang'));
    await t.pumpAndSettle();
    expect(state['consent'], isFalse);
    expect(
      calls.where((c) => c == 'openAccess' || c == 'requestWarnings'),
      isEmpty,
    );
  });
  testWidgets('Setup continues automatically after granting Android access', (
    t,
  ) async {
    await mount(t);
    await protect(t);
    await visible(t, find.byKey(const Key('setup-action')));
    await t.tap(find.byKey(const Key('setup-action')));
    await t.pumpAndSettle();
    await visible(t, find.text('Setuju & teruskan'));
    await t.tap(find.text('Setuju & teruskan'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(state['consent'], isTrue);
    expect(state['enabled'], isTrue);
    expect(state['allApps'], isTrue);
    expect(state['setupPending'], isFalse);
    expect(calls.where((c) => c == 'openAccess').length, 1);
    expect(calls.where((c) => c == 'requestWarnings').length, 1);
    expect(find.text('Perlindungan aktif'), findsOneWidget);
  });
  testWidgets('Denied permission does not cause a repeated prompt', (t) async {
    state.addAll({'consent': true, 'allApps': true, 'access': true});
    grantWarnings = false;
    await mount(t);
    await protect(t);
    await visible(t, find.byKey(const Key('setup-action')));
    await t.tap(find.byKey(const Key('setup-action')));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 8));
    await t.pumpAndSettle();
    expect(state['enabled'], isFalse);
    expect(calls.where((c) => c == 'requestWarnings').length, 1);
    expect(find.text('Perlindungan aktif'), findsNothing);
  });
  testWidgets('Revoked access cannot retain active status', (t) async {
    active();
    await mount(t);
    await protect(t);
    expect(find.text('Perlindungan aktif'), findsOneWidget);
    state['access'] = false;
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.text('Perlindungan aktif'), findsNothing);
    expect(find.text('Benarkan akses notifikasi'), findsOneWidget);
  });
  testWidgets('Pause and resume do not repeat granted permissions', (t) async {
    active();
    await mount(t);
    await protect(t);
    await visible(t, find.byKey(const Key('pause-protection')));
    await t.tap(find.byKey(const Key('pause-protection')));
    await t.pumpAndSettle();
    expect(state['enabled'], isFalse);
    await t.tap(find.byKey(const Key('setup-action')));
    await t.pumpAndSettle();
    expect(state['enabled'], isTrue);
    expect(
      calls.where((c) => c == 'openAccess' || c == 'requestWarnings'),
      isEmpty,
    );
  });
  testWidgets('Choosing no apps pauses protection', (t) async {
    active();
    await mount(t);
    await protect(t);
    await visible(t, find.byKey(const Key('choose-apps')));
    await t.tap(find.byKey(const Key('choose-apps')));
    await t.pumpAndSettle();
    await t.tap(find.text('Semua app'));
    await t.pumpAndSettle();
    expect(state['allApps'], isFalse);
    expect(state['enabled'], isFalse);
    expect(find.textContaining('Tiada app dipilih'), findsOneWidget);
  });
  testWidgets('Advanced server mode still requires explicit consent', (
    t,
  ) async {
    await mount(t);
    await t.tap(find.byKey(const Key('open-settings')));
    await t.pumpAndSettle();
    await visible(t, find.text('Pilihan lanjutan'));
    await t.tap(find.text('Pilihan lanjutan'));
    await t.pumpAndSettle();
    await visible(t, find.text('Semakan melalui pelayan'));
    await t.tap(find.text('Semakan melalui pelayan'));
    await t.pumpAndSettle();
    expect(find.text('Hantar link ke pelayan anda?'), findsOneWidget);
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('backend-endpoint')), findsNothing);
  });
  testWidgets('Small phone with enlarged text stays usable', (t) async {
    await mount(t, size: const Size(320, 640), scale: 1.6);
    expect(t.takeException(), isNull);
    await protect(t);
    expect(t.takeException(), isNull);
    await visible(t, find.byKey(const Key('setup-action')));
    await t.tap(find.byKey(const Key('setup-action')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await visible(t, find.text('Setuju & teruskan'));
    expect(find.text('Setuju & teruskan').hitTestable(), findsOneWidget);
  });
  testWidgets(
    'Language switches immediately, persists and preserves scan state',
    (t) async {
      await mount(t);
      clipboard = 'https://example.com';
      await t.tap(find.byKey(const Key('scan-action')));
      await t.pumpAndSettle();
      expect(find.text('Tiada tanda bahaya\ndikesan.'), findsOneWidget);
      await t.tap(find.byKey(const Key('open-settings')));
      await t.pumpAndSettle();
      await t.tap(find.text('English'));
      await t.pumpAndSettle();
      expect(state['language'], 'en');
      expect(find.text('Settings'), findsOneWidget);
      expect(
        find.text('Your language choice is saved on this phone.'),
        findsOneWidget,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('No warning signs\nfound.'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.bySemanticsLabel('Check link tab'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await mount(t);
      expect(find.text('Paste & check'), findsOneWidget);
      expect(find.text('linkguard'), findsNothing);
      expect(find.bySemanticsLabel('LinkGuard'), findsOneWidget);
      await t.tap(find.byKey(const Key('open-settings')));
      await t.pumpAndSettle();
      await t.tap(find.text('Bahasa Melayu'));
      await t.pumpAndSettle();
      expect(state['language'], 'ms');
      expect(find.text('Tetapan'), findsOneWidget);
    },
  );

  testWidgets('English consent and server disclosure remain explicit', (
    t,
  ) async {
    state['language'] = 'en';
    await mount(t);
    await protect(t);
    await visible(t, find.byKey(const Key('setup-action')));
    await t.tap(find.byKey(const Key('setup-action')));
    await t.pumpAndSettle();
    expect(find.text('You decide\nwhat is read.'), findsOneWidget);
    await visible(t, find.text('Not now'));
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(calls, isNot(contains('openAccess')));
    await t.tap(find.byKey(const Key('open-settings')));
    await t.pumpAndSettle();
    await visible(t, find.text('Advanced options'));
    await t.tap(find.text('Advanced options'));
    await t.pumpAndSettle();
    await visible(t, find.text('Check using a server'));
    await t.tap(find.text('Check using a server'));
    await t.pumpAndSettle();
    expect(find.text('Send this link to your server?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('backend-endpoint')), findsNothing);
  });

  testWidgets(
    'English layout works with enlarged text and translated reasons',
    (t) async {
      state['language'] = 'en';
      await mount(t, size: const Size(320, 640), scale: 1.6);
      clipboard = 'http://192.0.2.1/login';
      await t.scrollUntilVisible(
        find.byKey(const Key('scan-action')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('scan-action')));
      await t.pumpAndSettle();
      expect(find.text('Wait before opening.'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Why this result?'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Why this result?'));
      await t.pumpAndSettle();
      expect(
        find.text('The address uses an IP instead of a domain name.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('open-settings')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('language-picker')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Gallery QR requires confirmation then uses on-device scan', (
    t,
  ) async {
    final reader = _FakeQrReader()..values = ['http://192.0.2.1/login'];
    await mount(t, qrReader: reader);
    final controller = t
        .widget<LinkGuardApp>(find.byType(LinkGuardApp))
        .controller!;
    controller.useServer(true);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('qr-gallery')));
    await t.pumpAndSettle();
    expect(find.text('Semak link QR'), findsOneWidget);
    expect(find.text('http://192.0.2.1/login'), findsOneWidget);
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
    await t.tap(find.byKey(const Key('confirm-qr')));
    await t.pumpAndSettle();
    expect(find.text('Jangan buka dahulu.'), findsOneWidget);
    expect(find.text('192.0.2.1'), findsOneWidget);
    expect(controller.online, isFalse);
  });
  testWidgets('Cancelled QR selection clears old verdict without scanning', (
    t,
  ) async {
    final reader = _FakeQrReader();
    await mount(t, qrReader: reader);
    clipboard = 'https://example.com';
    await t.tap(find.byKey(const Key('scan-action')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('scan-verdict')), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const Key('qr-gallery')),
      -180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(find.byKey(const Key('qr-gallery')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
    expect(find.byKey(const Key('confirm-qr')), findsNothing);
  });
  testWidgets('No QR and non-web QR have clear errors without a safe verdict', (
    t,
  ) async {
    final reader = _FakeQrReader()..values = [];
    await mount(t, qrReader: reader);
    await t.tap(find.byKey(const Key('qr-gallery')));
    await t.pumpAndSettle();
    expect(find.textContaining('Tiada QR ditemui.'), findsOneWidget);
    reader.values = ['WIFI:T:WPA;S:Private;P:secret;;'];
    await t.tap(find.byKey(const Key('qr-gallery')));
    await t.pumpAndSettle();
    expect(find.textContaining('QR ini tidak mengandungi'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
  });
  testWidgets('English QR confirmation can be cancelled with enlarged text', (
    t,
  ) async {
    state['language'] = 'en';
    final reader = _FakeQrReader()..values = ['https://example.com'];
    await mount(t, qrReader: reader, size: const Size(320, 640), scale: 1.6);
    await t.scrollUntilVisible(
      find.byKey(const Key('qr-gallery')),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(find.byKey(const Key('qr-gallery')));
    await t.pumpAndSettle();
    expect(find.text('Check QR link'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Cancel'));
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
  });
  testWidgets('Recovered picker result asks before scanning', (t) async {
    final reader = _FakeQrReader()..recovered = ['https://example.com'];
    await mount(t, qrReader: reader);
    expect(find.byKey(const Key('confirm-qr')), findsOneWidget);
    expect(find.byKey(const Key('scan-verdict')), findsNothing);
    await t.tap(find.byKey(const Key('confirm-qr')));
    await t.pumpAndSettle();
    expect(find.text('Tiada tanda bahaya\ndikesan.'), findsOneWidget);
  });

  testWidgets('A delayed server response cannot label a different URL', (
    t,
  ) async {
    final backend = _DelayedBackend();
    final c = LinkGuardController(
      backend: backend,
      loadEngine: () async =>
          ScanEngine.fromJson(File('assets/model.json').readAsStringSync()),
    );
    await t.pump();
    c.useServer(true);
    c.input.text = 'https://example.com';
    final pending = c.scan();
    c.input.text = 'http://192.0.2.1/login';
    backend.response.complete(
      const ScanResult(Verdict.noThreatDetected, 'example.com', 0.01, ['test']),
    );
    await pending;
    expect(c.result, isNull);
    expect(c.scanning, isFalse);
    c.dispose();
  });
}

class _DelayedBackend extends BackendClient {
  final response = Completer<ScanResult>();
  @override
  Future<ScanResult> scan(String endpoint, String url) => response.future;
}

class _FakeQrReader extends QrGalleryReader {
  List<String>? values, recovered;
  @override
  Future<List<String>?> pick() async => values;
  @override
  Future<List<String>?> recover() async => recovered;
}
