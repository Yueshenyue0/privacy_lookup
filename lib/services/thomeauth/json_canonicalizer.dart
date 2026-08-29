/// JSON 规范化算法（用于 Ed25519 签名验证）
/// 参考 ThomeAuth API 文档的 JSON 规范化规则
library json_canonicalizer;

import 'dart:convert';

/// 将 JSON 数据按 ThomeAuth 规范序列化（用于 Ed25519 签名验证）
String canonicalizeJson(dynamic data) {
  if (data == null) return 'null';
  if (data is bool) return data ? 'true' : 'false';
  if (data is num) {
    if (data is int || data == data.floorToDouble()) {
      return '${data.toInt()}';
    }
    // 最短精确浮点表示
    final s = data.toString();
    return s;
  }
  if (data is String) {
    return '"${_escapeString(data)}"';
  }
  if (data is List) {
    final items = data.map((e) => canonicalizeJson(e)).join(',');
    return '[$items]';
  }
  if (data is Map) {
    final keys = (data.keys.cast<String>().toList())
      ..sort((a, b) => a.compareTo(b));
    final pairs = keys.map((k) {
      return '"${_escapeString(k)}":${canonicalizeJson(data[k])}';
    }).join(',');
    return '{$pairs}';
  }
  return 'null';
}

String _escapeString(String s) {
  final buf = StringBuffer();
  for (final c in s.runes) {
    if (c == 0x5c) {
      buf.write('\\\\');
    } else if (c == 0x22) {
      buf.write('\\"');
    } else if (c == 0x0a) {
      buf.write('\\n');
    } else if (c == 0x0d) {
      buf.write('\\r');
    } else if (c == 0x09) {
      buf.write('\\t');
    } else if (c == 0x08) {
      buf.write('\\b');
    } else if (c == 0x0c) {
      buf.write('\\f');
    } else if (c >= 0x00 && c <= 0x1f) {
      buf.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
    } else {
      buf.write(String.fromCharCode(c));
    }
  }
  return buf.toString();
}

/// 从 JSON Map 中移除指定字段并规范化序列化
String canonicalizeWithoutField(Map<String, dynamic> json, String field) {
  final copy = Map<String, dynamic>.from(json);
  copy.remove(field);
  return canonicalizeJson(copy);
}