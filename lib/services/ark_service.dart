import 'dart:convert';
import 'package:http/http.dart' as http;

/// ARK 后端服务：读取 config.txt（功能开关）和 gg.txt（公告）
class ArkService {
  static const String baseUrl = 'https://arkhub.asia';

  /// 读取 config.txt，返回 true=功能开启, false=功能禁止
  /// 默认返回 true（请求失败时不阻断功能）
  static Future<bool> isFeatureEnabled() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/config.txt'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final text = utf8.decode(resp.bodyBytes).trim();
        // 忽略大小写，"true" 才为开启
        return text.toLowerCase() == 'true';
      }
      return true; // 请求异常时默认不阻断
    } catch (_) {
      return true;
    }
  }

  /// 读取 gg.txt，返回公告内容
  /// 结构示例：
  /// ```text
  /// 测试公告
  /// "图片直链"=<图片地址>
  /// ```
  /// 第一行 = 标题，后续解析出图片链接
  static Future<ArkAnnouncement?> fetchAnnouncement() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/gg.txt'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final text = utf8.decode(resp.bodyBytes).trim();
      if (text.isEmpty) return null;
      return _parseAnnouncement(text);
    } catch (_) {
      return null;
    }
  }

  /// 解析公告文本
  static ArkAnnouncement _parseAnnouncement(String text) {
    final lines = text.split('\n');
    // 第一行是标题（去掉可能的 \r）
    final title = lines.first.trim().replaceAll('\r', '');

    String? imageUrl;
    // 在后续行中查找 "图片直链"=<url> 或 "<字段>"=<url>
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

    return ArkAnnouncement(title: title, imageUrl: imageUrl);
  }
}

/// ARK 公告数据模型
class ArkAnnouncement {
  final String title;
  final String? imageUrl;

  ArkAnnouncement({required this.title, this.imageUrl});
}