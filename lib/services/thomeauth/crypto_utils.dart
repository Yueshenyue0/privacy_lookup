import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// ThomeAuth 加密工具
class ThomeAuthCrypto {
  ThomeAuthCrypto._();

  static final _chacha20 = Chacha20.poly1305Aead();

  // ─── Hex 工具 ──────────────────────────────────────────────────────────────

  static Uint8List hexDecode(String hex) {
    if (hex.length % 2 != 0) {
      throw FormatException('Hex 字符串长度必须为偶数: $hex');
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static String hexEncode(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ─── X25519 密钥交换 ───────────────────────────────────────────────────────

  /// 生成临时 X25519 密钥对
  static Future<SimpleKeyPairData> generateEphemeralKey() async {
    final x25519 = X25519();
    final keyPair = await x25519.newKeyPair();
    final keyPairData = await keyPair.extract();
    return keyPairData as SimpleKeyPairData;
  }

  /// 从 hex 公钥构建 X25519 公钥
  static SimplePublicKey publicKeyFromHex(String hex) {
    return SimplePublicKey(hexDecode(hex), type: KeyPairType.x25519);
  }

  /// ECDH：计算共享密钥（从临时私钥字节 + 远端公钥）
  static Future<List<int>> ecdh(
      SimpleKeyPairData localPrivate, SimplePublicKey remotePublic) async {
    final x25519 = X25519();
    final shared = await x25519.sharedSecretKey(
      keyPair: localPrivate,
      remotePublicKey: remotePublic,
    );
    return await shared.extractBytes();
  }

  // ─── HKDF-SHA256 密钥派生 ──────────────────────────────────────────────────

  /// HKDF 派生
  /// ThomeAuth 的 HKDF: IKM=输入, salt→nonce, info→info
  static Future<Uint8List> hkdf(List<int> ikm, String info,
      {List<int>? salt, int length = 32}) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: length,
    );
    final result = await hkdf.deriveKey(
      secretKey: SecretKeyData(Uint8List.fromList(ikm)),
      nonce: salt ?? const [],
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await result.extractBytes());
  }

  /// 带空 salt 的 HKDF（用 32 字节全零)
  static Future<Uint8List> hkdfNoSalt(List<int> ikm, String info,
      {int length = 32}) async {
    return hkdf(ikm, info, salt: Uint8List(32), length: length);
  }

  // ─── ChaCha20-Poly1305 AEAD ────────────────────────────────────────────────

  /// ChaCha20-Poly1305 加密
  static Future<Uint8List> chacha20Encrypt(
      List<int> plaintext, List<int> key) async {
    final secretKey = SecretKeyData(Uint8List.fromList(key));
    final nonce = _generateNonce();
    final secretBox = await _chacha20.encrypt(
      Uint8List.fromList(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    // 拼接格式：nonce(12) || ciphertext(N) || mac(16)
    final result = Uint8List(12 + secretBox.cipherText.length + 16);
    result.setRange(0, 12, nonce);
    result.setRange(12, 12 + secretBox.cipherText.length, secretBox.cipherText);
    result.setRange(12 + secretBox.cipherText.length, result.length,
        secretBox.mac.bytes);
    return result;
  }

  /// ChaCha20-Poly1305 解密
  static Future<Uint8List> chacha20Decrypt(
      List<int> data, List<int> key) async {
    if (data.length < 28) {
      throw FormatException('加密数据长度不足');
    }
    final nonce = data.sublist(0, 12);
    final cipherText = data.sublist(12, data.length - 16);
    final mac = data.sublist(data.length - 16);
    final secretKey = SecretKeyData(Uint8List.fromList(key));
    final secretBox = SecretBox(
      Uint8List.fromList(cipherText),
      nonce: Uint8List.fromList(nonce),
      mac: Mac(Uint8List.fromList(mac)),
    );
    final result = await _chacha20.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(result);
  }

  /// ChaCha20 加密结果转 hex 字符串
  static Future<String> chacha20EncryptHex(
      String plaintext, List<int> key) async {
    final result = await chacha20Encrypt(utf8.encode(plaintext), key);
    return hexEncode(result);
  }

  /// ChaCha20 hex 解密
  static Future<String> chacha20DecryptHex(
      String hexData, List<int> key) async {
    final result = await chacha20Decrypt(hexDecode(hexData), key);
    return utf8.decode(result);
  }

  static Uint8List _generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(12, (_) => random.nextInt(256)));
  }

  // ─── Ed25519 签名验证 ──────────────────────────────────────────────────────

  /// 从 hex 公钥构建 Ed25519 公钥
  static SimplePublicKey ed25519PublicFromHex(String hex) {
    return SimplePublicKey(hexDecode(hex), type: KeyPairType.ed25519);
  }

  /// 验证 Ed25519 签名
  static Future<bool> ed25519Verify(
      List<int> message, List<int> signature, SimplePublicKey publicKey) async {
    final ed25519 = Ed25519();
    return ed25519.verify(
      message,
      signature: Signature(
        Uint8List.fromList(signature),
        publicKey: publicKey,
      ),
    );
  }

  // ─── 时间戳 ─────────────────────────────────────────────────────────────────

  /// 毫秒级时间戳
  static int timestampMs() => DateTime.now().millisecondsSinceEpoch;

  /// 秒级时间戳
  static int timestampSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}