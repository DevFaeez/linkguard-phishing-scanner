import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkguard/ui/qr_camera_page.dart';

const lens = CameraDescription(
  name: 'test',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

class DeniedCamera extends CameraController {
  DeniedCamera() : super(lens, ResolutionPreset.medium, enableAudio: false);
  final pending = Completer<void>();
  bool released = false;
  @override
  Future<void> initialize() => pending.future;
  @override
  Future<void> dispose() async {
    released = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
    'Permission denial while inactive produces a recoverable error on return',
    (t) async {
      final denied = DeniedCamera();
      await t.pumpWidget(
        MaterialApp(
          home: QrCameraPage(
            loadCameras: () async => [lens],
            createController: (_) => denied,
          ),
        ),
      );
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      denied.pending.completeError(CameraException('CameraAccessDenied', ''));
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('Camera permission needed'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(denied.released, isTrue);
      await t.pumpWidget(const SizedBox());
    },
  );
}
