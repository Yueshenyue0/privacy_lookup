import 'dart:convert';
import 'package:http/http.dart' as http;

class PrivacyResult {
  final String names;
  final String nicknames;
  final String phoneNumbers;
  final String idNumbers;
  final String qqNumbers;
  final String wbNumbers;
  final String passwords;
  final String emails;
  final String addresses;

  PrivacyResult({
    required this.names,
    required this.nicknames,
    required this.phoneNumbers,
    required this.idNumbers,
    required this.qqNumbers,
    required this.wbNumbers,
    required this.passwords,
    required this.emails,
    required this.addresses,
  });

  bool get hasResults =>
      names.isNotEmpty ||
      nicknames.isNotEmpty ||
      phoneNumbers.isNotEmpty ||
      idNumbers.isNotEmpty ||
      qqNumbers.isNotEmpty ||
      wbNumbers.isNotEmpty ||
      passwords.isNotEmpty ||
      emails.isNotEmpty ||
      addresses.isNotEmpty;

  factory PrivacyResult.fromJson(Map<String, dynamic> json) {
    String str(dynamic v) => v == null ? '' : v.toString();
    return PrivacyResult(
      names: str(json['names']),
      nicknames: str(json['nicknames']),
      phoneNumbers: str(json['phone_numbers']),
      idNumbers: str(json['id_numbers']),
      qqNumbers: str(json['qq_numbers']),
      wbNumbers: str(json['wb_numbers']),
      passwords: str(json['passwords']),
      emails: str(json['emails']),
      addresses: str(json['addresses']),
    );
  }
}

class PrivacyService {
  static const String apiBase = 'https://sucyan.top/api/privacy.php';

  static Future<PrivacyResult> lookup(String value) async {
    final uri = Uri.parse('$apiBase?value=${Uri.encodeQueryComponent(value)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('数据格式异常');
    }

    return PrivacyResult.fromJson(decoded);
  }
}