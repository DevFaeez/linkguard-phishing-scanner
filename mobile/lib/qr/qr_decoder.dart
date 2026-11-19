import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

String? _decodeSource(LuminanceSource source) {
  for (final candidate in [source, source.invert()]) {
    try {
      return QRCodeReader()
          .decode(BinaryBitmap(HybridBinarizer(candidate)))
          .text;
    } catch (_) {
      // No readable QR in this frame; the camera may try a later frame.
    }
  }
  return null;
}

/// Runs in a worker isolate. Handles padded Y rows and interleaved pixel strides.
String? decodeQrFrame(Map<String, Object> frame) {
  final bytes = frame['bytes']! as Uint8List;
  final width = frame['width']! as int, height = frame['height']! as int;
  final rowStride = frame['rowStride']! as int;
  final pixelStride = frame['pixelStride']! as int;
  if (width < 1 ||
      height < 1 ||
      width * height > 2000000 ||
      pixelStride < 1 ||
      rowStride < width * pixelStride ||
      bytes.length < (height - 1) * rowStride + (width - 1) * pixelStride + 1) {
    return null;
  }
  final packed = Int8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      packed[y * width + x] = bytes[y * rowStride + x * pixelStride];
    }
  }
  return _decodeSource(_QrLuma(packed, width, height));
}

/// Gallery files are bounded and decoded off the UI isolate. Nothing is uploaded.
List<String> decodeQrImage(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (decoder == null || info == null || info.width * info.height > 16000000) {
    throw const FormatException('Unsupported or oversized image');
  }
  final image = decoder.decodeFrame(0);
  if (image == null) throw const FormatException('Invalid image');
  final packed = Int8List(image.width * image.height);
  for (final pixel in image) {
    packed[pixel.y * image.width + pixel.x] =
        (pixel.r.toInt() + 2 * pixel.g.toInt() + pixel.b.toInt()) ~/ 4;
  }
  final text = _decodeSource(_QrLuma(packed, image.width, image.height));
  return text == null ? [] : [text];
}

class _QrLuma extends LuminanceSource {
  _QrLuma(this.bytes, super.width, super.height);
  final Int8List bytes;
  @override
  Int8List getMatrix() => bytes;
  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) throw RangeError.index(y, bytes);
    final result = row != null && row.length >= width ? row : Int8List(width);
    result.setRange(0, width, bytes, y * width);
    return result;
  }
}
