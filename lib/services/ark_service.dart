import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_client.dart';

/// ARK 后端服务：读取 config.txt（功能开关）和 gg.txt（公告）
/// 请求失败会无限重试，直到成功。
class ArkService {
  static const String baseUrl = 'https://arkhub.asia';
  static const Duration retryDelay = Duration(milliseconds: 2000);

  /// 使用绑定证书指纹的客户端（懒加载，异步初始化）
  static http.Client? _clientCache;

  static Future<http.Client> _getClient() async {
    _clientCache ??= await createPinnedClient();
    return _clientCache!;
  }

  /// 检查单个请求是否成功
  static bool _isOk(http.Response resp) => resp.statusCode == 200;

  /// 无限重试 GET，按行取内容
  static Future<String> _retryGetBody(String path) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final client = await _getClient();
        final resp = await client
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 10));
        if (_isOk(resp)) {
          return utf8.decode(resp.bodyBytes);
        }
        // 非 200，等待后重试
        await Future.delayed(retryDelay);
      } catch (_) {
        // 网络异常，等待后重试
        await Future.delayed(retryDelay);
      }
    }
  }

  /// 读取 config.txt，返回 'true'=功能开启, 其它=禁止
  /// 无限重试直到请求成功
  static Future<String> fetchConfig() async {
    final text = await _retryGetBody('/config.txt');
    return text.trim().toLowerCase();
  }

  /// 读取 gg.txt 公告内容（标题 + 图片直链）
  /// 无限重试直到请求成功
  static Future<String> fetchAnnouncementRaw() async {
    final text = await _retryGetBody('/gg.txt');
    return text.trim();
  }

  /// 解析公告文本
  /// 标题写死为"公告"；第一行为正文内容，后续解析图片
  static ArkAnnouncement parseAnnouncement(String text) {
    final lines = text.split('\n');
    // 第一行是正文内容
    final content = lines.first.trim().replaceAll('\r', '');

    String? imageUrl;
    // 匹配 "图片直链"=<url>
    final urlPattern = RegExp(
        r'["“”]?(?:图片直链|image|img|url|image_url)["“”]?\s*=\s*(\S+)',
        caseSensitive: false);
    for (final line in lines) {
      final m = urlPattern.firstMatch(line);
      if (m != null) {
        imageUrl = m.group(1)?.trim();
        if (imageUrl != null) break;
      }
    }
    return ArkAnnouncement(title: '公告', content: content, imageUrl: imageUrl);
  }
}

/// ARK 公告数据模型
/// title 固定为"公告"（客户端写死），content 为 gg.txt 正文
class ArkAnnouncement {
  final String title;
  final String content;
  final String? imageUrl;

  ArkAnnouncement({
    this.title = '公告',
    required this.content,
    this.imageUrl,
  });
}