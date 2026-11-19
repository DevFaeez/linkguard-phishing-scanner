import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

img.Image qrPicture(String value, {bool inverted = false}) {
  final matrix = Encoder.encode(value, ErrorCorrectionLevel.m).matrix!;
  const scale = 8, border = 4;
  final picture = img.Image(
    width: (matrix.width + border * 2) * scale,
    height: (matrix.height + border * 2) * scale,
  );
  img.fill(
    picture,
    color: img.ColorRgb8(
      inverted ? 0 : 255,
      inverted ? 0 : 255,
      inverted ? 0 : 255,
    ),
  );
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      final v = inverted ? 255 : 0;
      img.fillRect(
        picture,
        x1: (x + border) * scale,
        y1: (y + border) * scale,
        x2: (x + border + 1) * scale - 1,
        y2: (y + border + 1) * scale - 1,
        color: img.ColorRgb8(v, v, v),
      );
    }
  }
  return picture;
}

Uint8List qrPng(String value, {bool inverted = false}) =>
    img.encodePng(qrPicture(value, inverted: inverted));
