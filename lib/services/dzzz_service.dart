import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_client.dart';

class DzzzService {
  static const String apiBase = 'https://api.ovo1.cc/api/dzzz';
  static const String token = '623a6e46f19e42f97882c73050c862a7';

  /// 返回图片的 base64 数据（不含 data:image/png;base64, 前缀）
  static Future<String> query(String creditCode) async {
    final uri = Uri.parse(
      '$apiBase?token=$token&xydm=${Uri.encodeQueryComponent(creditCode)}',
    );
    final response = await (await getPinnedClient()).get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    // 接口返回的是 PNG 图片二进制
    final bytes = response.bodyBytes;
    return base64Encode(bytes);
  }
}