import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_client.dart';

class VerifyResult {
  final String status;
  final String info;
  final String name;
  final String idcard;

  VerifyResult({
    required this.status,
    required this.info,
    required this.name,
    required this.idcard,
  });

  bool get isSuccess => status == 'success' || status == 'ok' || status == '1';

  factory VerifyResult.fromJson(Map<String, dynamic> json) {
    String str(dynamic v) => v == null ? '' : v.toString();
    return VerifyResult(
      status: str(json['status']),
      info: str(json['info']),
      name: str(json['name']),
      idcard: str(json['idcard']),
    );
  }
}

class VerifyService {
  static const String apiBase = 'https://ryapi.sbs/API/eys.php';
  static const String apiKey = 'ranyu888';

  static Future<VerifyResult> verify(String name, String idcard) async {
    final uri = Uri.parse(
        '$apiBase?name=${Uri.encodeQueryComponent(name)}&idcard=${Uri.encodeQueryComponent(idcard)}&key=$apiKey');
    final response = await getDirectClient().get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('数据格式异常');
    }

    return VerifyResult.fromJson(decoded);
  }
}