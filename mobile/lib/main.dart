import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'core/scan_engine.dart';
import 'core/notification_policy.dart';
import 'ui/linkguard_app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/Manrope-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'DM Serif Display',
    ], await rootBundle.loadString('assets/fonts/DMSerifDisplay-OFL.txt'));
  });
  runApp(const LinkGuardApp());
}

/// Independent background isolate: no HTTP requests, history or raw text logging.
@pragma('vm:entry-point')
void notificationMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('my.linkguard/background');
  try {
    final engine = ScanEngine.fromJson(
      await rootBundle.loadString('assets/model.json'),
    );
    final recent = RecentScans();
    final clock = Stopwatch()..start();
    channel.setMethodCallHandler((call) async {
      if (call.method != 'scanNotification') throw MissingPluginException();
      final args = Map<String, dynamic>.from(call.arguments as Map);
      var suspicious = false;
      for (final url in extractUrls(args['text'] as String)) {
        if (!recent.claim(
          args['source'] as String,
          url,
          clock.elapsedMilliseconds,
        )) {
          continue;
        }
        if (engine.scan(url).verdict == Verdict.suspicious) suspicious = true;
      }
      return {'suspicious': suspicious};
    });
    await channel.invokeMethod<void>('ready');
  } catch (_) {
    await channel.invokeMethod<void>('unavailable');
  }
}
