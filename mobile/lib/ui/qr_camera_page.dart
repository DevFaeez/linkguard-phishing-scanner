import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/device_bridge.dart';
import '../qr/qr_decoder.dart';
import 'app_copy.dart';
import 'design_system.dart';

CameraController _createQrCamera(CameraDescription description) =>
    CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

class QrCameraPage extends StatefulWidget {
  const QrCameraPage({
    super.key,
    this.loadCameras = availableCameras,
    this.createController = _createQrCamera,
  });
  final Future<List<CameraDescription>> Function() loadCameras;
  final CameraController Function(CameraDescription) createController;
  @override
  State<QrCameraPage> createState() => _QrCameraPageState();
}

class _QrCameraPageState extends State<QrCameraPage>
    with WidgetsBindingObserver {
  CameraController? camera;
  Future<void>? _releasing;
  bool _completed = false, _reading = false, _starting = false;
  bool _foreground = true,
      _hadPermission = false,
      _returningFromSettings = false;
  bool _torch = false;
  String? _error;
  int _session = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _release() async {
    _session++;
    final old = camera;
    camera = null;
    _torch = false;
    if (old != null) {
      try {
        _releasing = old.dispose().catchError((Object _) {});
        await _releasing;
      } catch (_) {
        /* Already released by Android. */
      }
    }
  }

  Future<void> _start() async {
    if (!mounted || _completed || _starting || !_foreground || camera != null) {
      return;
    }
    _starting = true;
    final ticket = _session;
    CameraController? created;
    await _releasing;
    if (mounted) setState(() => _error = null);
    try {
      final cameras = await widget.loadCameras().timeout(
        const Duration(seconds: 15),
      );
      if (cameras.isEmpty) throw CameraException('Unavailable', '');
      if (!mounted || _completed || !_foreground || ticket != _session) return;
      final description =
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.back)
              .firstOrNull ??
          cameras.first;
      created = widget.createController(description);
      await created.initialize().timeout(const Duration(seconds: 20));
      _hadPermission = true;
      if (!mounted || _completed || !_foreground || ticket != _session) {
        await created.dispose();
        return;
      }
      camera = created;
      await created.startImageStream(_frame);
      if (mounted) setState(() {});
    } on CameraException catch (error) {
      if (created == camera) {
        await _release();
      } else if (created != null) {
        try {
          unawaited(created.dispose().catchError((Object _) {}));
        } catch (_) {
          /* Initialization already failed. */
        }
      }
      if (mounted && !_completed) {
        setState(
          () => _error = error.code.startsWith('CameraAccess')
              ? 'Kebenaran kamera diperlukan'
              : 'Kamera belum tersedia',
        );
      }
    } catch (_) {
      if (created == camera) {
        await _release();
      } else if (created != null) {
        try {
          unawaited(created.dispose().catchError((Object _) {}));
        } catch (_) {
          /* Initialization already failed. */
        }
      }
      if (mounted && !_completed) {
        setState(() => _error = 'Kamera belum tersedia');
      }
    } finally {
      _starting = false;
      // A permission dialog temporarily makes the app inactive before initialization finishes.
      if (mounted &&
          _foreground &&
          !_completed &&
          _hadPermission &&
          camera == null &&
          _error == null) {
        unawaited(_start());
      }
    }
  }

  Future<void> _frame(CameraImage image) async {
    if (_reading ||
        _completed ||
        !_foreground ||
        image.planes.isEmpty ||
        DateTime.now().difference(_lastFrame).inMilliseconds < 450) {
      return;
    }
    _reading = true;
    _lastFrame = DateTime.now();
    final ticket = _session;
    try {
      final plane = image.planes.first;
      final value = await compute(decodeQrFrame, <String, Object>{
        'bytes': Uint8List.fromList(plane.bytes),
        'width': image.width,
        'height': image.height,
        'rowStride': plane.bytesPerRow,
        'pixelStride': plane.bytesPerPixel ?? 1,
      });
      if (value == null ||
          !mounted ||
          _completed ||
          !_foreground ||
          ticket != _session) {
        return;
      }
      _completed = true;
      await _release();
      if (mounted) Navigator.pop(context, [value]);
    } catch (_) {
      // A dropped or unsupported camera frame must not crash the scanner.
    } finally {
      _reading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_completed) return;
    if (_foreground && (_hadPermission || _returningFromSettings)) {
      _returningFromSettings = false;
      unawaited(_start());
    } else if (!_foreground) {
      unawaited(_release());
    }
  }

  Future<void> _settings() async {
    try {
      _returningFromSettings = true;
      await DeviceBridge().openAppSettings();
    } catch (_) {
      _returningFromSettings = false;
      if (mounted) {
        setState(
          () => _error = 'Tetapan Android tidak dapat dibuka. Cuba lagi.',
        );
      }
    }
  }

  @override
  void dispose() {
    _completed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_release());
    super.dispose();
  }

  Widget _errorPanel() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, size: 40, color: Lg.orange),
          const SizedBox(height: 16),
          AppText(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Benarkan kamera dalam tetapan telefon, atau kembali dan pilih QR dari galeri.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MainAction('Buka tetapan', onPressed: _settings),
          TextButton(
            onPressed: () async {
              await _release();
              await _start();
            },
            child: const AppText('Cuba lagi'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = camera;
    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Scan QR kamera',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            key: const Key('qr-torch'),
            tooltip: tr(context, 'Lampu suluh'),
            onPressed: controller == null || !controller.value.isInitialized
                ? null
                : () async {
                    try {
                      await controller.setFlashMode(
                        _torch ? FlashMode.off : FlashMode.torch,
                      );
                      if (mounted) setState(() => _torch = !_torch);
                    } catch (_) {
                      /* Optional on cameras without a flash. */
                    }
                  },
            icon: Icon(_torch ? Icons.flashlight_on : Icons.flashlight_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error != null
                  ? _errorPanel()
                  : controller == null || !controller.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: CameraPreview(
                              controller,
                              key: const Key('qr-camera-preview'),
                            ),
                          ),
                          IgnorePointer(
                            child: Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.72,
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white70,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Flexible(
              flex: 0,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppText(
                      'Halakan kamera pada QR. Link tidak akan dibuka secara automatik.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const AppText(
                      'Kamera berhenti selepas QR ditemui. Tiada gambar disimpan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Lg.muted),
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
}
