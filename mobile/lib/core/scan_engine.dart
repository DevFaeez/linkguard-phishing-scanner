import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:punycoder/punycoder.dart';

const featureNames = [
  'url_length',
  'host_length',
  'path_length',
  'query_length',
  'digit_ratio',
  'dot_count',
  'hyphen_count',
  'at_count',
  'percent_count',
  'subdomain_count',
  'is_ip',
  'is_https',
  'has_punycode',
  'has_unicode',
  'query_count',
  'slash_count',
  'entropy',
  'suspicious_token_count',
];
const _tokens = [
  'login',
  'verify',
  'secure',
  'account',
  'update',
  'password',
  'wallet',
  'confirm',
];

class ParsedUrl {
  const ParsedUrl(
    this.url,
    this.host,
    this.path,
    this.query,
    this.scheme,
    this.hasUserInfo,
  );
  final String url, host, path, query, scheme;
  final bool hasUserInfo;
}

ParsedUrl parseUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty ||
      raw.runes.length > 4096 ||
      raw.contains('\\') ||
      RegExp(r'\s', unicode: true).hasMatch(raw) ||
      raw.runes.any((c) => c < 32 || c == 127) ||
      RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(raw)) {
    throw const FormatException('Unsupported URL');
  }
  final candidate = raw.contains('://') ? raw : 'https://$raw';
  // Preserve raw encoded and Unicode components: Uri.path would decode/re-encode them.
  final match = RegExp(
    r'^([a-zA-Z][a-zA-Z0-9+.-]*)://([^/?#]*)([^?#]*)(?:\?([^#]*))?(?:#.*)?$',
  ).firstMatch(candidate);
  if (match == null) throw const FormatException('Invalid URL');
  final scheme = match[1]!.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    throw const FormatException('Unsupported scheme');
  }
  final authority = match[2]!;
  final server = authority.split('@').last;
  String host;
  String? port;
  if (server.startsWith('[')) {
    final close = server.indexOf(']');
    if (close < 1) throw const FormatException('Invalid IPv6');
    host = server.substring(1, close).toLowerCase();
    if (!host.contains(':') ||
        InternetAddress.tryParse(host)?.type != InternetAddressType.IPv6) {
      throw const FormatException('Invalid IPv6');
    }
    final tail = server.substring(close + 1);
    if (tail.isNotEmpty && !tail.startsWith(':')) {
      throw const FormatException('Invalid authority');
    }
    port = tail.isEmpty ? null : tail.substring(1);
  } else {
    if (':'.allMatches(server).length > 1) {
      throw const FormatException('Unbracketed IPv6');
    }
    host = server
        .split(':')
        .first
        .toLowerCase()
        .replaceFirst(RegExp(r'\.+$'), '');
    port = server.contains(':')
        ? server.substring(server.indexOf(':') + 1)
        : null;
    final ascii = domainToAscii(host, validate: false);
    if (ascii.length > 253 ||
        ascii
            .split('.')
            .any(
              (label) =>
                  !RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')
                      .hasMatch(label),
            )) {
      throw const FormatException('Invalid domain');
    }
  }
  if (host.isEmpty) throw const FormatException('Empty domain');
  if (port != null && port.isNotEmpty) {
    if (!RegExp(r'^[0-9]+$').hasMatch(port)) {
      throw const FormatException('Invalid port');
    }
    final number = int.tryParse(port);
    if (number == null || number < 1 || number > 65535) {
      throw const FormatException('Invalid port');
    }
  }
  return ParsedUrl(
    candidate,
    host,
    match[3]!,
    match[4] ?? '',
    scheme,
    authority.contains('@'),
  );
}

List<double> extractFeatures(String input) {
  final parsed = parseUrl(input);
  final url = parsed.url, host = parsed.host, query = parsed.query;
  final points = url.runes.toList();
  final n = points.length;
  final counts = <int, int>{};
  for (final point in points) {
    counts[point] = (counts[point] ?? 0) + 1;
  }
  final entropy = counts.values.fold(0.0, (sum, count) {
    final p = count / n;
    return sum - p * math.log(p) / math.ln2;
  });
  double count(String character) => character.allMatches(url).length.toDouble();
  double flag(bool condition) => condition ? 1 : 0;
  return [
    n.toDouble(),
    host.runes.length.toDouble(),
    parsed.path.runes.length.toDouble(),
    query.runes.length.toDouble(),
    points.where((p) => p >= 48 && p <= 57).length / n,
    count('.'),
    count('-'),
    count('@'),
    count('%'),
    math.max(0, host.split('.').length - 2).toDouble(),
    flag(
      host.contains(':') || RegExp(r'^[0-9]+(?:\.[0-9]+){3}$').hasMatch(host),
    ),
    flag(parsed.scheme == 'https'),
    flag(host.split('.').any((label) => label.startsWith('xn--'))),
    flag(points.any((point) => point > 127)),
    query.isEmpty ? 0 : '&'.allMatches(query).length + 1.0,
    count('/'),
    entropy,
    _tokens
        .where((token) => url.toLowerCase().contains(token))
        .length
        .toDouble(),
  ];
}

enum Verdict { suspicious, noThreatDetected, unableToScan }

class ScanResult {
  const ScanResult(
    this.verdict,
    this.domain,
    this.score,
    this.reasons, {
    this.source = 'Peranti',
  });
  final Verdict verdict;
  final String domain, source;
  final double? score;
  final List<String> reasons;
  static ScanResult unavailable(String message) =>
      ScanResult(Verdict.unableToScan, '', null, [message]);
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final verdict = switch (json['verdict']) {
      'SUSPICIOUS' => Verdict.suspicious,
      'NO_THREAT_DETECTED' => Verdict.noThreatDetected,
      'UNABLE_TO_SCAN' => Verdict.unableToScan,
      _ => throw const FormatException('Invalid verdict'),
    };
    final score = (json['score'] as num?)?.toDouble();
    if (score != null && (!score.isFinite || score < 0 || score > 1)) {
      throw const FormatException('Invalid score');
    }
    if (json['research_only'] != true) {
      throw const FormatException('Unexpected model status');
    }
    return ScanResult(
      verdict,
      json['domain'] as String,
      score,
      (json['reasons'] as List).cast<String>(),
      source: 'Backend Python',
    );
  }
}

class ScanEngine {
  ScanEngine.fromJson(String text) {
    final model = jsonDecode(text) as Map<String, dynamic>;
    if (model['schema_version'] != 1 ||
        jsonEncode(model['feature_names']) != jsonEncode(featureNames) ||
        model['research_only'] != true) {
      throw const FormatException('Unsupported model');
    }
    List<double> values(String key) =>
        (model[key] as List).map((n) => (n as num).toDouble()).toList();
    mean = values('mean');
    scale = values('scale');
    coefficients = values('coefficients');
    intercept = (model['intercept'] as num).toDouble();
    threshold = (model['threshold'] as num).toDouble();
    version = model['model_version'] as String;
    if ([mean, scale, coefficients].any(
          (v) => v.length != featureNames.length || v.any((n) => !n.isFinite),
        ) ||
        scale.any((n) => n <= 0) ||
        !intercept.isFinite ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 1.000001) {
      throw const FormatException('Corrupt model');
    }
  }
  late final List<double> mean, scale, coefficients;
  late final double intercept, threshold;
  late final String version;
  double score(String url) {
    final values = extractFeatures(url);
    var z = intercept;
    for (var i = 0; i < values.length; i++) {
      z += (values[i] - mean[i]) / scale[i] * coefficients[i];
    }
    return 1 / (1 + math.exp(-z.clamp(-700, 700)));
  }

  ScanResult scan(String url) {
    try {
      final parsed = parseUrl(url), values = extractFeatures(url);
      final value = score(url), reasons = <String>[];
      if (value >= threshold) {
        reasons.add('Gabungan ciri URL melepasi ambang model eksperimen.');
      }
      if (values[10] == 1) {
        reasons.add('Alamat menggunakan IP, bukan nama domain.');
      }
      if (parsed.hasUserInfo) {
        reasons.add('URL mengandungi bahagian pengguna sebelum domain (@).');
      }
      if (values[12] == 1 || values[13] == 1) {
        reasons.add(
          'URL menggunakan punycode atau aksara bukan ASCII; semak ejaan domain.',
        );
      }
      if (values[11] == 0) reasons.add('Sambungan HTTP tidak disulitkan.');
      if (reasons.isEmpty) {
        reasons.add('Tiada petunjuk khusus daripada semakan URL setempat.');
      }
      return ScanResult(
        value >= threshold ? Verdict.suspicious : Verdict.noThreatDetected,
        parsed.host,
        value,
        reasons,
      );
    } catch (_) {
      return ScanResult.unavailable(
        'URL tidak sah atau tidak disokong. Hanya HTTP/HTTPS sehingga 4096 aksara diterima.',
      );
    }
  }
}
