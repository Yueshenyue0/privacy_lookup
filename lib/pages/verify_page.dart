import 'package:flutter/material.dart';
import '../services/verify_service.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _nameController = TextEditingController();
  final _idcardController = TextEditingController();
  bool _loading = false;
  VerifyResult? _result;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _idcardController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final name = _nameController.text.trim();
    final idcard = _idcardController.text.trim();
    if (name.isEmpty || idcard.isEmpty) {
      setState(() {
        _error = '请填写姓名和身份证号';
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
      final result = await VerifyService.verify(name, idcard);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '核验失败，请检查网络后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二要素核验'),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 12),
            _buildFormCard(),
            const SizedBox(height: 12),
            _buildResultArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '通过姓名 + 身份证号核验实名信息是否一致',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '填写信息',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '姓名',
                hintText: '请输入姓名',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idcardController,
              decoration: InputDecoration(
                labelText: '身份证号',
                hintText: '请输入18位身份证号',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _loading ? null : _verify,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user),
                label: Text(_loading ? '核验中...' : '开始核验'),
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
      return _buildMessage('填写信息后点击开始核验');
    }

    final r = _result!;
    final success = r.isSuccess;
    return Card(
      color: success
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.cancel,
                  color: success
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  success ? '核验通过' : '核验不通过',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: success
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildResultRow('姓名', r.name),
            _buildResultRow('身份证号', r.idcard),
            if (r.info.isNotEmpty) _buildResultRow('信息', r.info),
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
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, {bool isError = false}) {
    return Card(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : null,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          style: TextStyle(
            color: isError
                ? Theme.of(context).colorScheme.error
                : Colors.grey.shade700,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}