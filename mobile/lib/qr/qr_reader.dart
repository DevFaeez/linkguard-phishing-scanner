import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'qr_decoder.dart';

import '../core/scan_engine.dart';
import '../platform/device_bridge.dart';

/// Only explicit HTTP(S) QR destinations are eligible for the URL checker.
/// Wi-Fi credentials, payment commands and arbitrary text are never executed.
List<String> qrWebLinks(Iterable<String> values) {
  final links = <String>{};
  for (final value in values.take(32)) {
    final text = value.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) continue;
    try {
      parseUrl(text);
      links.add(text);
    } on FormatException {
      continue;
    }
  }
  return links.toList();
}

class QrReadException implements Exception {
  const QrReadException(this.message);
  final String message;
}

/// Gallery selection and pure Dart, on-device QR decoding. No camera is started.
class QrGalleryReader {
  QrGalleryReader({ImagePicker? picker, DeviceBridge? device})
    : _picker = picker ?? ImagePicker(),
      _device = device ?? DeviceBridge();
  final ImagePicker _picker;
  final DeviceBridge _device;

  Future<List<String>?> pick() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2560,
        maxHeight: 2560,
        requestFullMetadata: false,
      );
      if (image == null) return null;
      return await _read(image);
    } finally {
      await _device.cleanupQrImages();
    }
  }

  /// Android can recreate the app while its system photo picker is open.
  Future<List<String>?> recover() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.exception != null) {
        throw const QrReadException(
          'Gambar tidak dapat dibaca. Pilih gambar lain.',
        );
      }
      final image = lost.files?.firstOrNull;
      if (image != null) return await _read(image);
      return null;
    } finally {
      await _device.cleanupQrImages();
    }
  }

  Future<List<String>> _read(XFile image) async {
    try {
      if (await image.length() > 20 * 1024 * 1024) {
        throw const QrReadException(
          'Gambar terlalu besar. Pilih gambar yang lebih kecil.',
        );
      }
      return await compute(decodeQrImage, await image.readAsBytes());
    } finally {
      // Only copies in this app's cache are removed. Gallery originals are untouched.
      await _device.cleanupQrImages();
    }
  }
}
