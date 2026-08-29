import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advanced_root_detection/advanced_root_detection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pages/home_page.dart';
import 'pages/auth_page.dart';
import 'services/thomeauth/thome_auth_client.dart';
import 'services/thomeauth/announcement_dialog.dart';

/// 全局导航 Key：用它弹窗 / 跳转，不依赖任何页面 context，
/// 只要 App 起来就能在最顶层弹出公告，彻底避开"context 挂载时机"问题。
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

/// 全局安全监控包裹层，独立于页面导航，覆盖整个 App 生命周期
class SecurityWrapper extends StatefulWidget {
  const SecurityWrapper({super.key});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  final _shield = AdvanceRootDetection();
  final _connectivity = Connectivity();
  final _authClient = ThomeAuthClient();
  StreamSubscription<Threat>? _threatSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _initialCheckDone = false;
  bool _blocked = false;
  bool _authPassed = false;
  String _blockReason = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSecurity();
  }

  Future<void> _initSecurity() async {
    // 开启 VPN 检测（抓包工具多为 VPN 实现）+ 最短监控间隔
    const config = SecurityConfig(
      android: AndroidConfig(checkVpn: true),
      ios: IOSConfig(),
      monitoringInterval: Duration(seconds: 5),
    );

    // 1) 首次启动立刻检测
    try {
      final report = await _shield.performCheck(config);
      if (report.isRuntimeManipulated ||
          report.isDebuggerAttached ||
          report.isPrivilegedAccess) {
        _block('检测到 Hook/调试器/Root');
        return;
      }
      // VPN 检测（checkVpn 开启后出现在报告里）
      final vpnThreat = report.detectedThreats
          .where((t) => t.category == ThreatCategory.analysisEnvironment ||
              t.description.toLowerCase().contains('vpn'))
          .toList();
      if (vpnThreat.isNotEmpty) {
        _block('检测到 VPN/抓包环境');
        return;
      }
    } catch (_) {}

    setState(() => _initialCheckDone = true);

    // 2) 系统级实时 VPN 监听：VPN 一开启立刻回调（秒级），不等轮询
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.vpn)) {
        _block('检测到 VPN 连接（抓包环境）');
      }
    });
    // 启动时也检查一次当前是否有 VPN
    _checkConnectivityOnce();

    // 3) 实时流监控：订阅后，检测到的威胁事件会推送过来
    _threatSub = _shield.threatStream.listen((threat) {
      final cat = threat.category;
      if (cat == ThreatCategory.runtimeManipulation ||
          cat == ThreatCategory.debuggerAttached ||
          cat == ThreatCategory.privilegedAccess ||
          cat == ThreatCategory.analysisEnvironment) {
        _block('检测到异常环境: ${threat.description}');
      }
    });

    // 4) 后台定期检测（原生端最小间隔 5 秒，作为兜底）
    await _shield.startMonitoring(config);

    // 5) 网络验证：检查本地是否已有有效卡密
    await _verifyAuth();
  }

  /// 网络验证：本地有卡密则验证，无则进激活页
  Future<void> _verifyAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kamiHash = prefs.getString('kami_hash');
      if (kamiHash == null || kamiHash.isEmpty) {
        // 无卡密 → 保持 _authPassed=false，build 显示 AuthPage
        return;
      }
      // 有卡密 → 验证是否有效
      final result = await _authClient.use(kamiHash);
      if (result.valid) {
        setState(() => _authPassed = true);
        // 等 UI 完成 build 后再拉公告并弹窗
        await Future.delayed(const Duration(milliseconds: 600));
        await _loadAnnouncements();
      }
      // 卡密失效 → 保持 _authPassed=false，build 显示 AuthPage
    } catch (e) {
      // 网络错误时，允许进入（下次启动再验证）
      setState(() => _authPassed = true);
    }
  }

  /// 拉取公告并弹窗（验证通过后调用）
  Future<void> _loadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kamiHash = prefs.getString('kami_hash');
      debugPrint('[ThomeAuth] 开始拉取公告, kamiHash=${kamiHash ?? "null"}');
      final announcements = await _authClient.getAnnouncements(kamiHash: kamiHash);
      debugPrint('[ThomeAuth] 拉取到 ${announcements.length} 条公告');
      if (announcements.isEmpty) {
        debugPrint('[ThomeAuth] 公告列表为空，不弹窗');
        return;
      }
      // 用全局 navigatorKey 弹窗，不依赖当前 context
      await AnnouncementDialog.showViaKey(announcements);
      debugPrint('[ThomeAuth] 公告弹窗已触发');
    } catch (e, st) {
      debugPrint('[ThomeAuth] 公告拉取异常: $e\n$st');
    }
  }

  void _onAuthPassed() {
    if (mounted) {
      setState(() => _authPassed = true);
    }
  }

  Future<void> _checkConnectivityOnce() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.vpn)) {
        _block('检测到 VPN 连接（抓包环境）');
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回到前台时也立即检测
    if (state == AppLifecycleState.resumed) {
      _quickCheck();
      _checkConnectivityOnce();
    }
  }

  Future<void> _quickCheck() async {
    try {
      final safe = await _shield.verifyBeforeSensitiveOp();
      if (!safe) {
        _block('检测到异常环境');
      }
    } catch (_) {}
  }

  void _block(String reason) {
    if (_blocked) return; // 防止重复弹窗
    _blocked = true;
    _blockReason = reason;

    // 用全局对话框覆盖所有页面，不管当前在哪个功能页
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('检测到异常环境'),
              ],
            ),
            content: Text(_blockReason),
            actions: [
              FilledButton(
                onPressed: () => exit(0),
                child: const Text('退出应用'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _threatSub?.cancel();
    _connSub?.cancel();
    _shield.stopMonitoring();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) {
      // 阻断页（如果 dialog 还没弹出或已被关闭，兜底）
      return Scaffold(
        appBar: AppBar(title: const Text('安全检测')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('检测到异常环境',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_blockReason,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: () => exit(0), child: const Text('退出应用')),
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