import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:crypto/crypto.dart' as crypto;

/// 证书指纹白名单（SHA256，大写，去冒号）。
/// arkhub.asia 和 www.thomelua.com 的真实证书指纹。
/// 抓包工具用假证书/自签证书时，指纹不匹配 → 请求被拒绝。
class PinnedFingerprints {
  static const Map<String, String> pin = {
    'arkhub.asia': '95C3EDC773ED4A31164148584F34C3EC1874B61E7A26C966712BC374F87E97A2',
    'www.thomelua.com': 'CB02FFFA638507CCDD6C73E15D7700C1986CA2B644EC6E9A9429A82EF3615814',
  };

  /// 规范化：去掉冒号、转大写
  static String normalize(String raw) =>
      raw.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
}

/// 创建绑定证书指纹 + 强制直连的 HTTP 客户端
/// - 强制直连（findProxy=DIRECT）绕过系统 HTTP 代理
/// - 严格校验证书 SHA256 指纹，不符合则拒绝（防止中间人抓包）
http.Client createPinnedClient() {
  final inner = HttpClient()
    // 强制直连，忽略系统 HTTP 代理（Charles/Fiddler 劫持方式）
    ..findProxy = (uri) => 'DIRECT'
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      // 计算握手证书的真实 SHA256 指纹
      final der = cert.der;
      final fingerprint = crypto.sha256.convert(der).toString().toUpperCase();
      final expected = PinnedFingerprints.pin[host.toLowerCase()];
      // 没有该域名的 pin → 不拦截（放行）
      if (expected == null) return false;
      // 比对指纹，匹配才放行
      return PinnedFingerprints.normalize(fingerprint) == expected;
    };

  inner.userAgent = 'PrivacyLookup/1.0';
  return IOClient(inner);
}

/// 兼容旧调用名（简单直连客户端）
http.Client getDirectClient() => createPinnedClient();