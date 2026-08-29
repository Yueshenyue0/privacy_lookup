import 'dart:io';
import 'package:flutter/material.dart';
import 'package:anti_hook_vpn/anti_hook_vpn.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const PrivacyLookupApp());
}

class PrivacyLookupApp extends StatelessWidget {
  const PrivacyLookupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '信息工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const StartupGate(),
    );
  }
}

/// 启动入口：检测 VPN/代理/Frida 后提示用户
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _checking = true;
  bool _blocked = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    try {
      final vpn = await AntiHookVpn.isVpnConnected();
      final proxy = await AntiHookVpn.isProxyEnabled();
      final frida = await AntiHookVpn.isFridaDetected();

      if (vpn || proxy || frida) {
        setState(() {
          _checking = false;
          _blocked = true;
          _message = [
            if (vpn) '检测到 VPN 连接',
            if (proxy) '检测到代理设置',
            if (frida) '检测到 Frida 调试',
          ].join('、');
        });
        return;
      }
    } catch (_) {}

    setState(() => _checking = false);
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
                const Icon(Icons.security_warning,
                    size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  '检测到异常环境',
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _message,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => exit(0),
                  child: const Text('退出应用'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const HomePage();
  }
}