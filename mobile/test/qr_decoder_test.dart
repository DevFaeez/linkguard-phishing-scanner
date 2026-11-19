import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:linkguard/qr/qr_decoder.dart';
import 'package:linkguard/qr/qr_reader.dart';

import 'qr_fixture.dart';

void main() {
  test('Gallery decodes PNG, rotated JPEG and inverted QR without network', () {
    const url = 'http://192.0.2.1/login';
    expect(decodeQrImage(qrPng(url)), [url]);
    expect(
      decodeQrImage(img.encodeJpg(img.copyRotate(qrPicture(url), angle: 90))),
      [url],
    );
    expect(decodeQrImage(qrPng(url, inverted: true)), [url]);
  });
  test('Camera decoder respects padded rows and pixel stride', () {
    final picture = qrPicture('https://example.com');
    final stride = picture.width * 2 + 32;
    final plane = Uint8List(stride * picture.height)
      ..fillRange(0, stride * picture.height, 255);
    for (final pixel in picture) {
      plane[pixel.y * stride + pixel.x * 2] = pixel.r.toInt();
    }
    expect(
      decodeQrFrame({
        'bytes': plane,
        'width': picture.width,
        'height': picture.height,
        'rowStride': stride,
        'pixelStride': 2,
      }),
      'https://example.com',
    );
    expect(
      decodeQrFrame({
        'bytes': Uint8List(3),
        'width': 100,
        'height': 100,
        'rowStride': 100,
        'pixelStride': 1,
      }),
      isNull,
    );
  });
  test(
    'No QR, malformed image and non-web QR never produce a web destination',
    () {
      expect(
        decodeQrImage(img.encodePng(img.Image(width: 120, height: 120))),
        isEmpty,
      );
      expect(
        () => decodeQrImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      const wifi = 'WIFI:T:WPA;S:Test;P:testpass;;';
      expect(decodeQrImage(qrPng(wifi)), [wifi]);
      expect(
        qrWebLinks([wifi, 'javascript:alert(1)', 'https://', 'example.com']),
        isEmpty,
      );
      expect(
        qrWebLinks([
          ' https://example.com ',
          'https://example.com',
          'http://192.0.2.1/login',
        ]),
        ['https://example.com', 'http://192.0.2.1/login'],
      );
    },
  );
}
