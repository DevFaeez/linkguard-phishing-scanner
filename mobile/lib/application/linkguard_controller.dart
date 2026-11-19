import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/backend_client.dart';
import '../core/scan_engine.dart';
import '../platform/device_bridge.dart';

/// Application state independent of screen layout. No URLs or messages are persisted.
class LinkGuardController extends ChangeNotifier with WidgetsBindingObserver {
  LinkGuardController({
    DeviceBridge? device,
    BackendClient? backend,
    Future<ScanEngine> Function()? loadEngine,
  }) : device = device ?? DeviceBridge(),
       _readEngine = loadEngine ?? _readBundledEngine,
       backend = backend ?? BackendClient() {
    _lastEndpoint = endpoint.text;
    input.addListener(_edited);
    endpoint.addListener(_edited);
    WidgetsBinding.instance.addObserver(this);
    ready = _initialize();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_foreground) unawaited(refresh());
    });
  }

  final DeviceBridge device;
  final BackendClient backend;
  final Future<ScanEngine> Function() _readEngine;
  static Future<ScanEngine> _readBundledEngine() async =>
      ScanEngine.fromJson(await rootBundle.loadString('assets/model.json'));
  final input = TextEditingController();
  final endpoint = TextEditingController(
    text: const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://10.0.2.2:18786',
    ),
  );
  late final Future<void> ready;
  Timer? _poll;
  bool _disposed = false, _foreground = true, _refreshing = false;
  bool _flowActive = false, _warningAttempted = false;
  String _lastInput = '', _lastEndpoint = '';
  Completer<void>? _refreshDone;
  int _generation = 0;
  Map<String, dynamic> status = {};
  ScanEngine? engine;
  ScanResult? result;
  bool loading = true, scanning = false, setupBusy = false, online = false;
  String? inputNotice, statusNotice;

  String get language => status['language'] == 'en' ? 'en' : 'ms';
  Future<bool> setLanguage(String value) async {
    if (!const ['ms', 'en'].contains(value)) return false;
    return update({'language': value});
  }

  bool flag(String key) => status[key] == true;
  Set<String> get selected =>
      Set<String>.from(status['selected'] as List? ?? []);
  bool get hasSelection => flag('allApps') || selected.isNotEmpty;
  bool get protected =>
      flag('enabled') &&
      flag('consent') &&
      flag('access') &&
      flag('warnings') &&
      hasSelection &&
      flag('connected') &&
      flag('engineReady') &&
      statusNotice == null;
  bool get connecting =>
      flag('enabled') &&
      flag('access') &&
      flag('warnings') &&
      hasSelection &&
      !protected &&
      statusNotice == null;
  bool get needsSetup =>
      !flag('consent') || !flag('access') || !flag('warnings') || !hasSelection;

  Future<void> _initialize() async {
    await loadModel();
    await refresh();
  }

  Future<void> loadModel() async {
    loading = true;
    _changed();
    try {
      engine = await _readEngine();
    } catch (_) {
      engine = null;
    }
    if (_disposed) return;
    loading = false;
    _changed();
  }

  void _edited() {
    if (input.text == _lastInput && endpoint.text == _lastEndpoint) return;
    _lastInput = input.text;
    _lastEndpoint = endpoint.text;
    _invalidateScan();
  }

  void _invalidateScan() {
    // A verdict must never remain visible for a different URL, including during an API call.
    _generation++;
    scanning = false;
    result = null;
    inputNotice = null;
    _changed();
  }

  void clearResult() => _invalidateScan();

  void setNotice(String message) {
    inputNotice = message;
    _changed();
  }

  void useServer(bool value) {
    if (online != value) {
      online = value;
      _invalidateScan();
    }
  }

  Future<void> scan({String? text}) async {
    if (text != null) input.text = text;
    if (input.text.trim().isEmpty) {
      setNotice('Salin satu link dahulu, kemudian tampal di sini.');
      return;
    }
    if (scanning) return;
    final url = input.text;
    final ticket = ++_generation;
    scanning = true;
    result = null;
    inputNotice = null;
    _changed();
    final answer = online
        ? await backend.scan(endpoint.text, url)
        : engine?.scan(url) ??
              ScanResult.unavailable(
                'Semakan belum tersedia. Cuba muatkan semula.',
              );
    if (_disposed || ticket != _generation) return;
    result = answer;
    scanning = false;
    _changed();
  }

  Future<void> refresh({bool continueFlow = true, bool force = false}) async {
    if (_disposed) return;
    while (_refreshing) {
      await _refreshDone?.future;
      if (!force || _disposed) return;
    }
    _refreshing = true;
    final completed = Completer<void>();
    _refreshDone = completed;
    try {
      final fresh = await device.status();
      if (_disposed) return;
      if (jsonEncode(fresh) != jsonEncode(status) || statusNotice != null) {
        status = fresh;
        statusNotice = null;
        _changed();
      }
    } catch (_) {
      if (!_disposed) {
        statusNotice = 'Status perlindungan belum dapat disahkan.';
        _changed();
      }
    } finally {
      _refreshing = false;
      completed.complete();
    }
    // Never reopen an access screen after denial. Only advance once access was granted.
    if (!_disposed &&
        continueFlow &&
        _flowActive &&
        !setupBusy &&
        flag('access') &&
        _foreground) {
      unawaited(advanceSetup());
    }
  }

  Future<bool> update(Map<String, dynamic> values) async {
    try {
      await device.update(values);
      await refresh(continueFlow: false, force: true);
      return true;
    } catch (_) {
      if (!_disposed) {
        statusNotice = 'Perubahan belum dapat disimpan. Cuba lagi.';
        _changed();
      }
      return false;
    }
  }

  Future<void> acceptConsent() async {
    final values = <String, dynamic>{'consent': true, 'setupPending': true};
    // The disclosure explicitly says all apps; preserve a previous custom selection.
    if (!hasSelection) values['allApps'] = true;
    await update(values);
  }

  Future<void> advanceSetup({bool userInitiated = false}) async {
    if (setupBusy || _disposed) return;
    if (userInitiated) {
      _flowActive = true;
      _warningAttempted = false;
    }
    setupBusy = true;
    statusNotice = null;
    _changed();
    try {
      await refresh(continueFlow: false);
      if (!flag('consent')) {
        _flowActive = false;
        return;
      }
      if (!hasSelection) {
        _flowActive = false;
        statusNotice = 'Pilih sekurang-kurangnya satu app untuk diperiksa.';
        return;
      }
      await update({'setupPending': true});
      if (!flag('access')) {
        await device.openAccess(); // Continue after the user returns, not before consent.
        return;
      }
      if (!flag('warnings')) {
        if (_warningAttempted) {
          _flowActive = false;
          return;
        }
        _warningAttempted = true;
        await device.requestWarnings();
        await refresh(continueFlow: false);
        if (!flag('warnings')) {
          _flowActive = false;
          statusNotice =
              'Amaran belum dibenarkan. Anda boleh sambung apabila bersedia.';
          return;
        }
      }
      final saved = await update({'enabled': true, 'setupPending': false});
      if (saved) _flowActive = false;
    } catch (_) {
      _flowActive = false;
      statusNotice = 'Tetapan Android tidak dapat dibuka. Cuba lagi.';
    } finally {
      setupBusy = false;
      _changed();
    }
  }

  Future<void> pause() async {
    _flowActive = false;
    await update({'enabled': false, 'setupPending': false});
  }

  Future<void> configureApps({
    required bool allApps,
    required Set<String> selected,
  }) async {
    final values = <String, dynamic>{
      'allApps': allApps,
      'selected': selected.toList(),
    };
    if (!allApps && selected.isEmpty) {
      _flowActive = false;
      values['enabled'] = false;
      values['setupPending'] = false;
    }
    await update(values);
  }

  Future<void> reset() async {
    _flowActive = false;
    await update({
      'enabled': false,
      'consent': false,
      'allApps': false,
      'selected': <String>[],
      'setupPending': false,
    });
    online = false;
    input.clear();
    result = null;
    inputNotice = null;
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(refresh());
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    input.removeListener(_edited);
    endpoint.removeListener(_edited);
    input.dispose();
    endpoint.dispose();
    super.dispose();
  }
}
