import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/dzzz_service.dart';

class DzzzPage extends StatefulWidget {
  const DzzzPage({super.key});

  @override
  State<DzzzPage> createState() => _DzzzPageState();
}

class _DzzzPageState extends State<DzzzPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _imageBase64;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入统一社会信用代码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _imageBase64 = null;
    });

    try {
      final b64 = await DzzzService.query(code);
      setState(() {
        _imageBase64 = b64;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('电子营业执照查询'),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '统一社会信用代码',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '请输入18位统一社会信用代码',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _query(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _query,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(_loading ? '查询中...' : '查询'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildMessage(_error!)
            else if (_imageBase64 != null)
              _buildImageCard()
            else
              _buildMessage('输入信用代码后点击查询'),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(_imageBase64!),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '电子营业执照',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
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