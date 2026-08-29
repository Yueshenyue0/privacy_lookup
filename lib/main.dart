import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:advanced_root_detection/advanced_root_detection.dart';
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
  StreamSubscription<Threat>? _threatSub;
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
    // 1) 首次启动立刻检测
    try {
      final report = await _shield.performCheck(SecurityConfig(
        android: const AndroidConfig(),
        ios: const IOSConfig(),
      ));
      if (report.isRuntimeManipulated || report.isDebuggerAttached) {
        _block('检测到 Hook 或调试器');
        return;
      }
    } catch (_) {}

    setState(() => _initialCheckDone = true);

    // 2) 启动实时流监控（事件驱动，无需轮询间隔）
    //    threatStream 在检测到威胁时立刻推送事件
    _threatSub = _shield.threatStream.listen((threat) {
      if (threat.category == ThreatCategory.runtimeManipulation ||
          threat.category == ThreatCategory.debuggerAttached) {
        _block('检测到 ${threat.category == ThreatCategory.runtimeManipulation ? 'Hook 框架' : '调试器'}');
      }
    });

    // 3) 启动后台定期检测（1秒间隔，确保无遗漏）
    await _shield.startMonitoring(const SecurityConfig(
      monitoringInterval: Duration(seconds: 1),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回到前台时也立即检测
    if (state == AppLifecycleState.resumed) {
      _quickCheck();
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