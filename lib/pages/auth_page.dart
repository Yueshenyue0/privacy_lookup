import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/thomeauth/thome_auth_client.dart';
import '../services/thomeauth/announcement_dialog.dart';

/// 网络验证页面
/// 未激活/卡密过期时展示，要求用户输入卡密
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.client, this.onPassed});

  final ThomeAuthClient client;

  /// 激活验证通过后的回调
  final VoidCallback? onPassed;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _kamiController = TextEditingController();
  bool _loading = false;
  String? _status;
  bool _valid = false;
  String? _kamiHash;
  String? _expireInfo;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  @override
  void dispose() {
    _kamiController.dispose();
    super.dispose();
  }

  /// 检查本地保存的卡密是否仍有效
  Future<void> _checkSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final kamiHash = prefs.getString('kami_hash');
    if (kamiHash == null || kamiHash.isEmpty) return;

    setState(() => _loading = true);
    try {
      final result = await widget.client.use(kamiHash);
      if (result.valid) {
        setState(() {
          _valid = true;
          _kamiHash = kamiHash;
          _status = '卡密有效';
          _expireInfo = result.isPermanent
              ? '永久有效'
              : '剩余 ${_fmtDuration(result.realRemainingSeconds ?? 0)}';
        });
        // 验证通过后拉取公告
        _loadAnnouncements();
        return;
      } else {
        setState(() {
          _status = result.error ?? '卡密无效，请重新激活';
        });
      }
    } catch (e) {
      setState(() => _status = '验证失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 激活卡密
  Future<void> _activate() async {
    final kami = _kamiController.text.trim();
    if (kami.isEmpty) {
      setState(() => _status = '请输入卡密');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await widget.client.activate(kami);
      if (result.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kami_hash', result.kamiHash ?? '');
        setState(() {
          _valid = true;
          _kamiHash = result.kamiHash;
          _status = '激活成功';
          _expireInfo = result.isPermanent
              ? '永久有效'
              : '有效期 ${result.realExpireHours ?? 0} 小时';
        });
        _loadAnnouncements();
        // 通知上层验证通过
        widget.onPassed?.call();
      } else {
        setState(() => _status = _mapError(result.error ?? '激活失败'));
      }
    } catch (e) {
      setState(() => _status = '激活失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 加载公告并弹窗
  Future<void> _loadAnnouncements() async {
    try {
      final announcements = await widget.client.getAnnouncements();
      if (!mounted) return;
      await AnnouncementDialog.show(context, announcements);
    } catch (_) {
      // 公告加载失败不影响使用
    }
  }

  String _mapError(String error) {
    switch (error) {
      case 'kami_not_found_or_used':
        return '卡密不存在或已被使用';
      case 'kami_expired_or_not_found':
        return '卡密已过期或不存在';
      default:
        return error;
    }
  }

  String _fmtDuration(int seconds) {
    if (seconds < 0) return '永久';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h小时$m分';
    return '$m分钟';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('卡密验证'), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _valid ? Icons.verified_rounded : Icons.lock_rounded,
                  size: 64,
                  color: _valid ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _valid ? '验证通过' : '请输入卡密激活',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                if (_expireInfo != null) ...[
                  const SizedBox(height: 8),
                  Text(_expireInfo!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.green)),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 8),
                  Text(_status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _valid ? Colors.green : Colors.red)),
                ],
                const SizedBox(height: 24),
                if (!_valid) ...[
                  TextField(
                    controller: _kamiController,
                    decoration: const InputDecoration(
                      labelText: '卡密',
                      hintText: '请输入您的卡密',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key_rounded),
                    ),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _activate,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('激活'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: () {
                      widget.onPassed?.call();
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('进入应用'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}