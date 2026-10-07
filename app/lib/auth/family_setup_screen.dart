import 'package:flutter/material.dart';

import 'family.dart';

/// 처음 로그인한 사용자: 새 가족을 만들거나 초대 코드로 참여한다.
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({
    super.key,
    required this.uid,
    required this.service,
    required this.onDone,
    required this.onSignOut,
  });
  final String uid;
  final FamilyService service;
  final ValueChanged<Family> onDone;
  final VoidCallback onSignOut;

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final _name = TextEditingController(text: '치오네 가족');
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Family?> Function() job, String notFound) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final f = await job();
      if (f == null) {
        _error = notFound;
      } else {
        widget.onDone(f);
        return;
      }
    } catch (e) {
      _error = '처리하지 못했습니다. $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 설정'),
        actions: [
          TextButton(onPressed: widget.onSignOut, child: const Text('로그아웃')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text('처음 시작하는 분', style: text.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '가족 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || _name.text.trim().isEmpty
                    ? null
                    : () => _run(
                        () => widget.service.create(
                          _name.text.trim(),
                          widget.uid,
                        ),
                        '',
                      ),
                child: const Text('새 가족 만들기'),
              ),
              const Divider(height: 48),
              Text('가족이 이미 만들었다면', style: text.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '초대 코드 (6자리)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.service.join(_code.text, widget.uid),
                        '초대 코드를 찾을 수 없습니다.',
                      ),
                child: const Text('초대 코드로 참여'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
