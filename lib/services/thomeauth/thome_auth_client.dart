import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'config.dart';
import 'crypto_utils.dart';
import 'json_canonicalizer.dart';

/// 会话信息
class ThomeSession {
  final String sessionId;
  final List<int> transportKey;
  final List<int> kamiKey;
  final SimplePublicKey ed25519Public;
  final int serverTime;

  ThomeSession({
    required this.sessionId,
    required this.transportKey,
    required this.kamiKey,
    required this.ed25519Public,
    required this.serverTime,
  });
}

/// 激活结果
class ActivateResult {
  final bool success;
  final String? kamiHash;
  final String? error;
  final int? realExpireHours;
  final bool isPermanent;
  final int? deviceLimit;

  ActivateResult({
    required this.success,
    this.kamiHash,
    this.error,
    this.realExpireHours,
    this.isPermanent = false,
    this.deviceLimit,
  });
}

/// 使用结果（验证卡密）
class UseResult {
  final bool valid;
  final String? error;
  final int? realRemainingSeconds;
  final bool isPermanent;
  final int? deviceCount;
  final int? deviceLimit;

  UseResult({
    required this.valid,
    this.error,
    this.realRemainingSeconds,
    this.isPermanent = false,
    this.deviceCount,
    this.deviceLimit,
  });
}

/// 公告
class ThomeAnnouncement {
  final int id;
  final String title;
  final String content;
  final String type;
  final int priority;
  final bool showOnce;
  final bool hasConditions;
  final String? startTime;
  final String? endTime;

  ThomeAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.showOnce,
    required this.hasConditions,
    this.startTime,
    this.endTime,
  });

  factory ThomeAnnouncement.fromJson(Map<String, dynamic> json) {
    return ThomeAnnouncement(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      priority: json['priority'] as int? ?? 0,
      showOnce: json['show_once'] as bool? ?? false,
      hasConditions: json['has_conditions'] as bool? ?? false,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
    );
  }
}

/// ThomeAuth 网络验证客户端
class ThomeAuthClient {
  final http.Client _http = http.Client();
  ThomeSession? _session;
  String? _apiKey;

  ThomeSession? get session => _session;

  /// 建立会话
  Future<ThomeSession> createSession() async {
    // 1. 生成临时 X25519 密钥对
    final clientKey = await ThomeAuthCrypto.generateEphemeralKey();
    final clientPublicHex = ThomeAuthCrypto.hexEncode(
        (await clientKey.extractPublicKey()).bytes);

    // 2. 计算 K_init
    final serverPublic = ThomeAuthCrypto.publicKeyFromHex(
        ThomeAuthConfig.x25519PublicKey);
    final sharedInit = await ThomeAuthCrypto.ecdh(clientKey, serverPublic);
    final kInit = await ThomeAuthCrypto.hkdfNoSalt(
        sharedInit, 'k9Xp2mWqR7vLnJ4cYbA8dFe3H');

    // 3. 加密内层数据（api_key + timestamp + nonce + device_fingerprint）
    final nonce = _randomHex(32);
    final innerData = jsonEncode({
      'api_key': ThomeAuthConfig.apiKey,
      'timestamp': ThomeAuthCrypto.timestampMs(),
      'nonce': nonce,
      'device_fingerprint': _deviceFingerprint(),
    });
    final encryptedInner = await ThomeAuthCrypto.chacha20EncryptHex(
        innerData, kInit);

    // 4. 发送会话建立请求
    final resp = await _http.post(
      Uri.parse('${ThomeAuthConfig.baseUrl}/session'),
      headers: {'Content-Type': 'application/json', 'Charset': 'UTF-8'},
      body: jsonEncode({
        'app_id': ThomeAuthConfig.appId,
        'ephemeral_public_key': clientPublicHex,
        'encrypted_data': encryptedInner,
      }),
    );
    final respJson = jsonDecode(utf8.decode(resp.bodyBytes))
        as Map<String, dynamic>;
    if (respJson['code'] != 0) {
      throw Exception('会话建立失败: ${respJson['code']} - ${respJson['data']}');
    }

    // 5. 验证外层 Ed25519 签名
    final signatureHex = respJson['signature'] as String;
    final dataJson = respJson['data'] as Map<String, dynamic>;
    final canonical = canonicalizeJson({
      'code': respJson['code'],
      'data': dataJson,
    });
    final pub = ThomeAuthCrypto.ed25519PublicFromHex(
        ThomeAuthConfig.ed25519PublicKey);
    final sigOk = await ThomeAuthCrypto.ed25519Verify(
        utf8.encode(canonical),
        ThomeAuthCrypto.hexDecode(signatureHex),
        pub);
    if (!sigOk) {
      throw Exception('响应签名验证失败，可能存在中间人攻击');
    }

    // 6. 用 K_init 解密响应数据
    final encryptedData = dataJson['encrypted_data'] as String;
    final decryptedStr = await ThomeAuthCrypto.chacha20DecryptHex(
        encryptedData, kInit);
    final sessionData = jsonDecode(decryptedStr) as Map<String, dynamic>;

    // 7. 校验 Ed25519 公钥一致性
    final returnedPub = sessionData['ed25519_public_key'] as String;
    if (returnedPub != ThomeAuthConfig.ed25519PublicKey) {
      throw Exception('公钥不匹配，可能存在中间人攻击');
    }

    // 8. 验证临时公钥签名（server_eph + client_eph hex 拼接）
    final serverEphHex = sessionData['server_ephemeral_public'] as String;
    final ephSig = sessionData['ephemeral_signature'] as String;
    final signContent = serverEphHex + clientPublicHex;
    final ephOk = await ThomeAuthCrypto.ed25519Verify(
        utf8.encode(signContent),
        ThomeAuthCrypto.hexDecode(ephSig),
        pub);
    if (!ephOk) {
      throw Exception('临时公钥签名验证失败');
    }

    // 9. 计算 K_session
    final serverEphPublic = ThomeAuthCrypto.publicKeyFromHex(serverEphHex);
    final sharedSession = await ThomeAuthCrypto.ecdh(
        clientKey, serverEphPublic);
    final kSession = await ThomeAuthCrypto.hkdfNoSalt(
        sharedSession, 'T5uZsG6wN1xKfQ9jMrC0hBv4P');

    // 10. 派生 transport_key 和 kami_key
    final transportKey = await ThomeAuthCrypto.hkdf(kSession,
        'xQ4vN9bK2wRj',
        salt: utf8.encode('aR3nV8kLpW5mX2qYjF7d'));
    final kamiKey = await ThomeAuthCrypto.hkdf(kSession,
        'yF7gL4vD9kR2xNq',
        salt: utf8.encode('zE6cH1pT8sW3mJ5nR'));

    // 11. 用 transport_key 解密 encrypted_session 验证一致性
    final encryptedSession = sessionData['encrypted_session'] as String;
    final sessionDetailStr = await ThomeAuthCrypto.chacha20DecryptHex(
        encryptedSession, transportKey);
    final sessionDetail = jsonDecode(sessionDetailStr) as Map<String, dynamic>;
    if (sessionDetail['session_id'] != sessionData['session_id']) {
      throw Exception('会话一致性校验失败');
    }

    _session = ThomeSession(
      sessionId: sessionData['session_id'] as String,
      transportKey: transportKey,
      kamiKey: kamiKey,
      ed25519Public: pub,
      serverTime: sessionDetail['server_time'] as int? ?? 0,
    );
    _apiKey = ThomeAuthConfig.apiKey;
    return _session!;
  }

  /// 激活卡密
  Future<ActivateResult> activate(String kami) async {
    final s = await _ensureSession();
    final encryptedKami = await ThomeAuthCrypto.chacha20EncryptHex(
        kami, s.kamiKey);
    final reqData = jsonEncode({
      'encrypted_kami': encryptedKami,
      'timestamp': ThomeAuthCrypto.timestampMs(),
    });
    final encryptedReq = await ThomeAuthCrypto.chacha20EncryptHex(
        reqData, s.transportKey);
    final encryptedApiKey = await ThomeAuthCrypto.chacha20EncryptHex(
        _apiKey!, s.transportKey);

    final resp = await _post(s, '/activate', encryptedReq, encryptedApiKey);
    final decrypted = await _decryptAndVerify(resp, s);

    // 外层解密
    final outer = jsonDecode(decrypted) as Map<String, dynamic>;
    if (outer['status'] != 'success') {
      return ActivateResult(success: false, error: outer['status'] as String?);
    }
    // 解密内层 encrypted_result
    final encryptedResult = outer['encrypted_result'] as String;
    final innerStr = await ThomeAuthCrypto.chacha20DecryptHex(
        encryptedResult, s.transportKey);
    final inner = jsonDecode(innerStr) as Map<String, dynamic>;
    if (inner['success'] == true) {
      return ActivateResult(
        success: true,
        kamiHash: inner['kami_hash'] as String?,
        realExpireHours: inner['real_expire_hours'] as int?,
        isPermanent: inner['is_permanent'] as bool? ?? false,
        deviceLimit: inner['device_limit'] as int?,
      );
    }
    return ActivateResult(
        success: false, error: inner['error'] as String?);
  }

  /// 使用卡密（验证是否有效）
  Future<UseResult> use(String kamiHash) async {
    final s = await _ensureSession();
    final reqData = jsonEncode({
      'kami_hash': kamiHash,
      'timestamp': ThomeAuthCrypto.timestampMs(),
    });
    final encryptedReq = await ThomeAuthCrypto.chacha20EncryptHex(
        reqData, s.transportKey);
    final encryptedApiKey = await ThomeAuthCrypto.chacha20EncryptHex(
        _apiKey!, s.transportKey);

    final resp = await _post(s, '/use', encryptedReq, encryptedApiKey);
    final decrypted = await _decryptAndVerify(resp, s);
    final outer = jsonDecode(decrypted) as Map<String, dynamic>;
    if (outer['status'] != 'success') {
      return UseResult(valid: false, error: outer['status'] as String?);
    }
    final encryptedResult = outer['encrypted_result'] as String;
    final innerStr = await ThomeAuthCrypto.chacha20DecryptHex(
        encryptedResult, s.transportKey);
    final inner = jsonDecode(innerStr) as Map<String, dynamic>;
    if (inner['valid'] == true) {
      return UseResult(
        valid: true,
        realRemainingSeconds: inner['real_remaining_seconds'] as int?,
        isPermanent: inner['is_permanent'] as bool? ?? false,
        deviceCount: inner['device_count'] as int?,
        deviceLimit: inner['device_limit'] as int?,
      );
    }
    return UseResult(valid: false, error: inner['error'] as String?);
  }

  /// 获取公告
  Future<List<ThomeAnnouncement>> getAnnouncements() async {
    final s = await _ensureSession();
    final reqData = jsonEncode({
      'announcement_id': 0,
      'timestamp': ThomeAuthCrypto.timestampMs(),
    });
    final encryptedReq = await ThomeAuthCrypto.chacha20EncryptHex(
        reqData, s.transportKey);
    final encryptedApiKey = await ThomeAuthCrypto.chacha20EncryptHex(
        _apiKey!, s.transportKey);

    final resp = await _post(s, '/announcements', encryptedReq, encryptedApiKey);
    final decrypted = await _decryptAndVerify(resp, s);
    final outer = jsonDecode(decrypted) as Map<String, dynamic>;
    if (outer['status'] != 'success') {
      return [];
    }
    final innerData = outer['data'] as Map<String, dynamic>? ?? {};
    final list = innerData['announcements'] as List<dynamic>? ?? [];
    return list
        .map((e) => ThomeAnnouncement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── 私有工具 ──────────────────────────────────────────────────────────────

  Future<ThomeSession> _ensureSession() async {
    if (_session != null) return _session!;
    return createSession();
  }

  Future<http.Response> _post(ThomeSession s, String path,
      String encryptedData, String encryptedApiKey) async {
    return _http.post(
      Uri.parse('${ThomeAuthConfig.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'X-Encrypted-Api-Key': encryptedApiKey,
        'X-Encrypted-Data': encryptedData,
        'X-Session-Id': s.sessionId,
        'X-Crypto-Version': '2',
      },
    );
  }

  /// 解密并验证响应
  Future<String> _decryptAndVerify(
      http.Response resp, ThomeSession s) async {
    final respJson = jsonDecode(utf8.decode(resp.bodyBytes))
        as Map<String, dynamic>;
    if (respJson['code'] != 0) {
      throw Exception('请求失败: ${respJson['code']}');
    }
    // 验签
    final signatureHex = respJson['signature'] as String;
    final dataJson = respJson['data'] as Map<String, dynamic>;
    final canonical = canonicalizeJson({
      'code': respJson['code'],
      'data': dataJson,
    });
    final sigOk = await ThomeAuthCrypto.ed25519Verify(
        utf8.encode(canonical),
        ThomeAuthCrypto.hexDecode(signatureHex),
        s.ed25519Public);
    if (!sigOk) {
      throw Exception('响应签名验证失败');
    }
    final encryptedData = dataJson['encrypted_data'] as String;
    return ThomeAuthCrypto.chacha20DecryptHex(encryptedData, s.transportKey);
  }

  String _randomHex(int length) {
    final rand = _Random();
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(rand.nextInt(16).toRadixString(16));
    }
    return buf.toString();
  }

  String _deviceFingerprint() {
    // 用设备信息生成稳定指纹（后续可改用 device_info_plus）
    return 'android-${ThomeAuthCrypto.hexEncode(
        Uint8List.fromList(
            utf8.encode('device-${_stableDeviceId()}')))
        .substring(0, 32)}';
  }

  String _stableDeviceId() {
    // TODO: 接入 device_info_plus 的 AndroidId/设备唯一标识
    return 'unknown-device';
  }

  void dispose() {
    _http.close();
  }
}