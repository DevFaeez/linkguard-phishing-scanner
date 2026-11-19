import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'scan_engine.dart';

class BackendClient {
  Future<ScanResult> scan(String endpoint, String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      parseUrl(url);
      final base = Uri.parse(endpoint.trim());
      final localDebug =
          kDebugMode &&
          ['10.0.2.2', '127.0.0.1', 'localhost'].contains(base.host);
      if ((base.scheme != 'https' && !(localDebug && base.scheme == 'http')) ||
          base.userInfo.isNotEmpty ||
          base.hasQuery ||
          base.hasFragment ||
          base.host.isEmpty) {
        throw const FormatException(
          'Backend memerlukan HTTPS (HTTP localhost untuk debug sahaja).',
        );
      }
      final request = await client
          .postUrl(base.resolve('/v1/scan'))
          .timeout(const Duration(seconds: 4));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'url': url}));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode != 200) {
        throw const HttpException('Backend menolak permintaan.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 4))) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) {
          throw const FormatException('Respons terlalu besar.');
        }
      }
      return ScanResult.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      return ScanResult.unavailable(
        'Backend tidak tersedia atau respons tidak sah. Pemeriksaan online tidak berjaya; tiada keputusan selamat diberikan.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
