import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linkguard/core/scan_engine.dart';
import 'package:linkguard/core/notification_policy.dart';
import 'package:linkguard/core/backend_client.dart';

void main() {
  final engine = ScanEngine.fromJson(
    File('assets/model.json').readAsStringSync(),
  );
  test('Dart features and scores agree with Python golden vectors', () {
    final vectors = jsonDecode(
      File('test/fixtures/parity_vectors.json').readAsStringSync(),
    ) as List;
    for (final item in vectors) {
      final actual = extractFeatures(item['url'] as String),
          expected = item['features'] as List;
      for (var i = 0; i < actual.length; i++) {
        expect(
          actual[i],
          closeTo((expected[i] as num).toDouble(), 1e-10),
          reason: 'feature $i for ${item['url']}',
        );
      }
      expect(
        engine.score(item['url'] as String),
        closeTo((item['score'] as num).toDouble(), 1e-10),
      );
    }
  });
  test('Malformed input never produces a safe-looking verdict', () {
    for (final url in [
      '',
      'javascript:alert(1)',
      'https://',
      'https://example.com/a b',
      'https://example.com/%ZZ',
      'https://example.com:99999',
      'https://example.com\\evil',
      'https://exa_mple.com',
      'https://-bad.com',
    ]) {
      expect(engine.scan(url).verdict, Verdict.unableToScan);
    }
  });
  test('Model contract is validated', () {
    final json = jsonDecode(
      File('assets/model.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    json['schema_version'] = 99;
    expect(() => ScanEngine.fromJson(jsonEncode(json)), throwsFormatException);
  });
  test('Balanced URL punctuation and IPv6 survive extraction', () {
    expect(
      extractUrls('Lihat (https://example.com/a(b)). https://[2001:db8::1]'),
      ['https://example.com/a(b)', 'https://[2001:db8::1]'],
    );
  });
  test('Dedup is bounded and expires', () {
    final cache = RecentScans(ttlMillis: 100, capacity: 2);
    expect(cache.claim('a', 'url', 0), isTrue);
    expect(cache.claim('a', 'url', 99), isFalse);
    expect(cache.claim('a', 'url', 100), isTrue);
    expect(cache.claim('b', 'url', 100), isTrue);
    expect(cache.claim('c', 'url', 100), isTrue);
    expect(cache.claim('a', 'url', 100), isTrue);
  });
  test('Backend unavailable returns unable, not no-threat', () async {
    final result = await BackendClient().scan(
      'http://127.0.0.1:1',
      'https://example.com',
    );
    expect(result.verdict, Verdict.unableToScan);
  });
}
