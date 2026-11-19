// Synthetic reserved destinations only. Does not visit any URL.
import 'dart:io';

import 'package:image/image.dart' as img;

import '../test/qr_fixture.dart';

void main(List<String> args) {
  final folder = Directory(args.single)..createSync(recursive: true);
  final values = {
    '01-example.png': 'https://example.com',
    '02-suspicious.png': 'http://192.0.2.1/login',
    '03-non-web.png': 'WIFI:T:WPA;S:Test;P:testpass;;',
  };
  for (final entry in values.entries) {
    File('${folder.path}/${entry.key}').writeAsBytesSync(qrPng(entry.value));
  }
  File('${folder.path}/04-no-qr.png')
      .writeAsBytesSync(img.encodePng(img.Image(width: 500, height: 500)));
  final scene = img.Image(width: 1920, height: 1080);
  img.fill(scene, color: img.ColorRgb8(255, 255, 255));
  final qr = img.copyResize(
    qrPicture('http://192.0.2.1/login'),
    width: 320,
    interpolation: img.Interpolation.nearest,
  );
  for (final x in [0, 400, 800, 1200, 1600]) {
    for (final y in [0, 360, 720]) {
      img.compositeImage(scene, qr, dstX: x, dstY: y);
    }
  }
  File('${folder.path}/camera-feed.png').writeAsBytesSync(img.encodePng(scene));
}
