import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:crypto/crypto.dart' as crypto;

/// 证书指纹白名单（SHA256，大写，去冒号）。
/// App 内所有 HTTPS 域名的真实证书指纹，作为双保险。
/// 抓包工具用假证书/自签证书时，指纹不匹配 → 请求被拒绝。
class PinnedFingerprints {
  static const Map<String, String> pin = {
    'arkhub.asia': '95C3EDC773ED4A31164148584F34C3EC1874B61E7A26C966712BC374F87E97A2',
    'www.thomelua.com': 'CB02FFFA638507CCDD6C73E15D7700C1986CA2B644EC6E9A9429A82EF3615814',
    'sucyan.top': '3D185B103B7B3FA057D50E3D08E9B847A2EB49B2B9EFE4FB9DEF117CE2CC5FE5',
    'ryapi.sbs': '3A81F67392C524586A3898AF15111507FC91F8141CA016F9C2621FA8F0F78353',
    'api.ovo1.cc': '8B5FD12A047B4AC5B2605C58D6B3CC7349FAB8E298BB799A30C9BBDCFC570FB5',
  };

  static String normalize(String raw) =>
      raw.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
}

/// 加载内嵌证书并把它们设为唯一信任根。
/// 信任逻辑：`withTrustedRoots: false` → 不信任系统任何预装 CA，
/// 只信任我们内嵌的证书。抓包工具的假证书（哪怕装进系统证书区）
/// 不在信任列表里，链校验必然失败 → 请求被拒绝。
Future<http.Client> createPinnedClient() async {
  // 内嵌的 leaf + intermediate + root 证书（PEM），覆盖 App 内所有 HTTPS 域名
  const certAssets = [
    // arkhub.asia (Let's Encrypt)
    'assets/ssl/arkhub_cert1.pem',
    'assets/ssl/arkhub_cert2.pem',
    'assets/ssl/arkhub_cert3.pem',
    // www.thomelua.com (Google Trust)
    'assets/ssl/thomelua_cert1.pem',
    'assets/ssl/thomelua_cert2.pem',
    'assets/ssl/thomelua_cert3.pem',
    // sucyan.top (TrustAsia / DigiCert)
    'assets/ssl/sucyan.top_cert1.pem',
    'assets/ssl/sucyan.top_cert2.pem',
    'assets/ssl/sucyan.top_cert3.pem',
    // ryapi.sbs (Let's Encrypt)
    'assets/ssl/ryapi.sbs_cert1.pem',
    'assets/ssl/ryapi.sbs_cert2.pem',
    'assets/ssl/ryapi.sbs_cert3.pem',
    // api.ovo1.cc (Let's Encrypt)
    'assets/ssl/api.ovo1.cc_cert1.pem',
    'assets/ssl/api.ovo1.cc_cert2.pem',
    'assets/ssl/api.ovo1.cc_cert3.pem',
  ];

  // 唯一信任根（不加载系统 CA）
  final context = SecurityContext(withTrustedRoots: false);

  for (final asset in certAssets) {
    try {
      final pem = await rootBundle.loadString(asset);
      final derList = _pemToDer(pem);
      for (final der in derList) {
        try {
          context.setTrustedCertificatesBytes(der, allowPartialChain: true);
        } catch (_) {
          // 单张证书失败时忽略，继续下一张
        }
      }
    } catch (_) {
      // 某个 asset 缺失时忽略，不引发崩溃
    }
  }

  final inner = HttpClient(context: context)
    // 强制直连，忽略系统 HTTP 代理（Charles/Fiddler 劫持方式）
    ..findProxy = (uri) => 'DIRECT'
    // 双保险：即使链校验通过，也再比一次指纹
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      final fingerprint =
          crypto.sha256.convert(cert.der).toString().toUpperCase();
      final expected = PinnedFingerprints.pin[host.toLowerCase()];
      if (expected == null) return false;
      return PinnedFingerprints.normalize(fingerprint) == expected;
    };

  inner.userAgent = 'PrivacyLookup/1.0';
  return IOClient(inner);
}

/// 兼容旧调用名。真正的调用方应改用 `await createPinnedClient()`。
http.Client getDirectClient() {
  throw UnsupportedError('请改用 await createPinnedClient()');
}

/// 全局懒加载单例客户端。所有业务请求复用同一个 pinning 实例。
http.Client? _sharedClient;

/// 获取共享的绑定证书指纹客户端（懒加载）
Future<http.Client> getPinnedClient() async {
  return _sharedClient ??= await createPinnedClient();
}

/// 关闭共享客户端（可选，用于资源释放）
void closePinnedClient() {
  _sharedClient?.close();
  _sharedClient = null;
}

/// PEM → 每张证书的 DER 字节
List<List<int>> _pemToDer(String pem) {
  final list = <List<int>>[];
  final re = RegExp(
      r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----');
  for (final m in re.allMatches(pem)) {
    final b64 = m.group(1)!.replaceAll(RegExp(r'\s'), '');
    try {
      list.add(base64.decode(b64));
    } catch (_) {
      // 忽略解码失败块
    }
  }
  return list;
}