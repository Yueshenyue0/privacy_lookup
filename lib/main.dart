import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:advanced_root_detection/advanced_root_detection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const _AppWithGate());
}

class _AppWithGate extends StatelessWidget {
  const _AppWithGate();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '信息工具',
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
  StreamSubscription<Threat>? _threatSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _initialCheckDone = false;
  bool _blocked = false;
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
    return const HomePage();
  }
}