import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 获取强制直连的 HTTP 客户端
///
/// `findProxy = (uri) => 'DIRECT'` —— 绕过系统 HTTP 代理（Charles/Fiddler 劫持方式）
/// 代理抓包工具就是靠系统代理劫持流量的，强制直连后它们无法再拦截请求。
http.Client getDirectClient() {
  final inner = HttpClient()
    // 最关键的一行！强制直连，忽略系统代理
    ..findProxy = (uri) => 'DIRECT'
    ..userAgent = 'PrivacyLookup/1.0';
  return http.IOClient(inner);
}
