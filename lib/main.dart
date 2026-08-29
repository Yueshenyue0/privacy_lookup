import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_safety_info/device_safety_info.dart';
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
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> with WidgetsBindingObserver {
  final _info = DeviceSafetyInfo();
  bool _checking = true;
  bool _blocked = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时重新检测，保证"持续检测"
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    try {
      // 抓包工具特征：hook 框架(Frida/Xposed) + 调试器 + VPN
      final hooked = await _info.isHooked();
      final debugger = await _info.isDebuggerAttached();
      final vpn = await _info.isVPNCheck();

      if (hooked || debugger || vpn) {
        setState(() {
          _checking = false;
          _blocked = true;
          _message = [
            if (hooked) '检测到 Hook 框架 (Frida/Xposed)',
            if (debugger) '检测到调试器',
            if (vpn) '检测到 VPN 连接',
          ].join('\n');
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_blocked) {
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
                Text(_message,
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
    return const HomePage();
  }
}