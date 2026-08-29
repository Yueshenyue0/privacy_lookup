import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home_page.dart';
import 'pages/auth_page.dart';
import 'services/thomeauth/thome_auth_client.dart';
import 'services/ark_service.dart';
import 'services/ark_announcement_dialog.dart';

/// 全局导航 Key：用它弹窗 / 跳转，不依赖任何页面 context，
/// 只要 App 起来就能在最顶层弹出公告。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const _AppWithGate());
}

class _AppWithGate extends StatelessWidget {
  const _AppWithGate();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '信息工具',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const SecurityWrapper(),
    );
  }
}

/// 全局包裹层：负责 config 开关 + 网络验证 + 公告
class SecurityWrapper extends StatefulWidget {
  const SecurityWrapper({super.key});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> {
  final _authClient = ThomeAuthClient();
  bool _configLoaded = false;
  bool _configAllowed = false;
  bool _authPassed = false;
  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) 先拉 config.txt（功能开关），无限重试直到成功。返回前功能不可用。
    final configText = await ArkService.fetchConfig();
    final allowed = configText == 'true';
    setState(() {
      _configAllowed = allowed;
      _configLoaded = true;
    });
    debugPrint('[ARK] config.txt 功能开关 = $allowed ($configText)');

    if (!allowed) {
      // 功能禁用，build 显示禁用页
      setState(() => _initialCheckDone = true);
      return;
    }

    // 2) 网络验证
    await _verifyAuth();
  }

  /// 网络验证：本地有卡密则验证，无则进激活页
  Future<void> _verifyAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kamiHash = prefs.getString('kami_hash');
      if (kamiHash == null || kamiHash.isEmpty) {
        // 无卡密 → 保持 _authPassed=false，build 显示 AuthPage
        setState(() => _initialCheckDone = true);
        return;
      }
      // 有卡密 → 验证是否有效
      final result = await _authClient.use(kamiHash);
      if (result.valid) {
        setState(() {
          _authPassed = true;
          _initialCheckDone = true;
        });
        // 验证通过后拉公告
        await _loadAnnouncements();
      } else {
        // 卡密失效 → 保持 _authPassed=false
        setState(() => _initialCheckDone = true);
      }
    } catch (e) {
      // 网络错误时，允许进入（下次启动再验证）
      setState(() {
        _authPassed = true;
        _initialCheckDone = true;
      });
    }
  }

  /// 拉取 ARK 公告并弹窗
  Future<void> _loadAnnouncements() async {
    try {
      final raw = await ArkService.fetchAnnouncementRaw();
      final announcement = ArkService.parseAnnouncement(raw);
      if (announcement == null) return;
      debugPrint('[ARK] 公告内容=${announcement.content}, 图片=${announcement.imageUrl}');
      await ArkAnnouncementDialog.show(announcement);
      debugPrint('[ARK] 公告弹窗已触发');
    } catch (e, st) {
      debugPrint('[ARK] 公告加载异常: $e\n$st');
    }
  }

  void _onAuthPassed() {
    if (mounted) {
      setState(() => _authPassed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      // config.txt 尚未返回：阻塞，显示加载页，功能不可用
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在检查服务...'),
            ],
          ),
        ),
      );
    }
    // config.txt = false → 功能禁用页
    if (!_configAllowed) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('功能已禁用',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('该功能暂不可用，请联系管理员',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }
    if (!_initialCheckDone) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // 网络验证未通过 → 显示验证页
    if (!_authPassed) {
      return AuthPage(client: _authClient, onPassed: _onAuthPassed);
    }
    return const HomePage();
  }
}