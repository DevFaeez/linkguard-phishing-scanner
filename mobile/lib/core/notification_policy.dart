import 'dart:convert';

import 'package:crypto/crypto.dart';

List<String> extractUrls(String text) {
  final input = text.length > 32768 ? text.substring(0, 32768) : text;
  final seen = <String>{};
  for (final match in RegExp(
    'https?://[^\\s<>"\']+',
    caseSensitive: false,
  ).allMatches(input)) {
    var url = match[0]!.replaceFirst(RegExp(r'[.,;!]+$'), '');
    for (final pair in [('(', ')'), ('[', ']'), ('{', '}')]) {
      while (url.endsWith(pair.$2) &&
          pair.$2.allMatches(url).length > pair.$1.allMatches(url).length) {
        url = url.substring(0, url.length - 1);
      }
    }
    if (url.runes.length <= 4096) seen.add(url);
    if (seen.length >= 10) break;
  }
  return seen.toList();
}

class RecentScans {
  RecentScans({this.ttlMillis = 300000, this.capacity = 256});
  final int ttlMillis, capacity;
  final _seen = <String, int>{};
  bool claim(String source, String url, int now) {
    final key = sha256.convert(utf8.encode('$source\u0000$url')).toString();
    _seen.removeWhere((_, time) => now - time >= ttlMillis);
    if (_seen.containsKey(key)) return false;
    while (_seen.length >= capacity) {
      _seen.remove(_seen.keys.first);
    }
    _seen[key] = now;
    return true;
  }
}
