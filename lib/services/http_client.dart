import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 获取直连的 HTTP 客户端（无任何证书固定/网络检测）。
/// 只做纯 HTTPS 请求，不做指纹校验，代码混淆负责防护。
http.Client getDirectClient() {
  final inner = HttpClient()
    // 可选：强制直连，绕过系统 HTTP 代理（提高网络稳定性，但不做安全检测）
    ..findProxy = (uri) => 'DIRECT';
  inner.userAgent = 'PrivacyLookup/1.0';
  return IOClient(inner);
}

/// 兼容异步调用名：直接复用 getDirectClient
Future<http.Client> getPinnedClient() async => getDirectClient();