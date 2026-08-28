import 'package:flutter/material.dart';
import '../services/privacy_service.dart';

class LookupPage extends StatefulWidget {
  const LookupPage({super.key});

  @override
  State<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends State<LookupPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  PrivacyResult? _result;
  String? _error;

  // 支持的类型，仅作 tag 展示（自动检测，无需选择）
  final List<String> _types = const [
    'QQ号',
    '手机号',
    '证件号',
    '邮箱',
    '微博uid（加 @）',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _error = '请输入要查询的内容';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await PrivacyService.lookup(value);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '查询失败，请检查网络后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputCard(),
          const SizedBox(height: 16),
          _buildResultArea(),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支持的类型',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types
                  .map((t) => Chip(
                        label: Text(t),
                        labelStyle: const TextStyle(fontSize: 12),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '输入 QQ / 手机号 / 证件号 / 邮箱 / @微博uid',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_loading ? '查询中...' : '查询'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildMessage(_error!, isError: true);
    }

    if (_result == null) {
      return _buildMessage('输入内容后点击查询');
    }

    final r = _result!;
    if (!r.hasResults) {
      return _buildMessage('未查询到相关信息');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '查询结果',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const Divider(height: 20),
            if (r.names.isNotEmpty) _buildResultRow('姓名', r.names),
            if (r.nicknames.isNotEmpty) _buildResultRow('昵称', r.nicknames),
            if (r.phoneNumbers.isNotEmpty)
              _buildResultRow('手机号', r.phoneNumbers),
            if (r.idNumbers.isNotEmpty) _buildResultRow('证件号', r.idNumbers),
            if (r.qqNumbers.isNotEmpty) _buildResultRow('QQ号', r.qqNumbers),
            if (r.wbNumbers.isNotEmpty) _buildResultRow('微博UID', r.wbNumbers),
            if (r.passwords.isNotEmpty) _buildResultRow('密码', r.passwords),
            if (r.emails.isNotEmpty) _buildResultRow('邮箱', r.emails),
            if (r.addresses.isNotEmpty) _buildResultRow('地址', r.addresses),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, {bool isError = false}) {
    return Card(
      color: isError ? Colors.red.shade50 : Colors.grey.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isError ? Colors.red.shade700 : Colors.grey.shade700,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}