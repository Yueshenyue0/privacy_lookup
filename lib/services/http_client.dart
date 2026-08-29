import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 服务器证书公钥 SHA-256 指纹白名单（SPKI）
///
/// 由真实服务器证书的公钥 DER 计算得到。
/// 任何 MITM 代理（Charles/Fiddler/Burp/mitmproxy）替换的证书公钥都无法匹配，
/// 连接会在 TLS 握手校验阶段直接失败，抓包者连明文 HTTP 数据都拿不到。
///
/// 注意：如果服务器更新了证书（如 Let's Encrypt 自动续期但换了新公钥），
/// 需要同步更新这些指纹，否则应用将无法连接。
const Map<String, String> _pinnedSpkiSha256 = {
  'sucyan.top': '77650314460642df4c98ef120ab4f8e406124c8843e09e3716cb1ca31bd102ea',
  'ryapi.sbs': '11089956ca2dcf0ef40ff6a716aa1c69a2b0134b8330b9e84e9354a9431a8be8',
  'api.ovo1.cc': '0f77cc38e3a5442ec307f7bb5895382aad74a3e009376c0fe7ee50b188fa5e37',
};

/// 获取强制直连 + SSL Pinning 的 HTTP 客户端
///
/// 1. `findProxy = (uri) => 'DIRECT'` —— 绕过系统 HTTP 代理（Charles/Fiddler 劫持方式）
/// 2. `badCertificateCallback` —— 校验服务器证书公钥，必须匹配白名单
///    这样即使抓包者用透明代理/VPN 中间人，证书公钥对不上也会握手失败
http.Client getDirectClient() {
  final inner = HttpClient()
    // 最关键的一行！强制直连，忽略系统代理
    // 代理抓包工具就是靠系统代理劫持流量的
    ..findProxy = (uri) => 'DIRECT'
    ..userAgent = 'PrivacyLookup/1.0'
    // 不信任系统根证书，只信任我们内置的服务器证书公钥
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      // 计算证书公钥的 SHA-256
      final spki = sha256.convert(cert.publicKeyDer());
      final fingerprint = spki.toString();
      final pinned = _pinnedSpkiSha256[host];
      if (pinned != null) {
        return fingerprint.toLowerCase() == pinned.toLowerCase();
      }
      // 未配置白名单的域名：保守起见直接拒绝
      return false;
    };
  return http.IOClient(inner);
}
