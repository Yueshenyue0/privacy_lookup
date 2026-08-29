/// ThomeAuth 网络验证配置
/// 在 ThomeAuth 开发者后台获取
class ThomeAuthConfig {
  ThomeAuthConfig._();

  /// 应用 ID
  static const int appId = 690;

  /// 应用密钥（仅用于会话建立时加密传输）
  static const String apiKey =
      '7f826d37f7a8c05ff433a4dca131525e17fbd8e75d6937a1c6e0b3c2b22ce7d7';

  /// X25519 静态公钥（客户端写死，用于 ECDH 建立会话）
  static const String x25519PublicKey =
      '8244da39e745c19a253271ae0266af94c23170789f3b3ded5cc8e18889de850a';

  /// Ed25519 验签公钥（客户端写死，用于响应验签防中间人）
  static const String ed25519PublicKey =
      '86a468456260aca79a98283651604220eacd6b8d9b64b5727b6c450018c319f1';

  /// API 基础地址
  static const String baseUrl = 'https://www.thomelua.com/thomeauth/api/v2';
}
