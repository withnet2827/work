import 'package:flutter/material.dart';

import '../models/place.dart';

class PlaceEditScreen extends StatefulWidget {
  const PlaceEditScreen({super.key, this.initial});
  final Place? initial;

  @override
  State<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends State<PlaceEditScreen> {
  final _form = GlobalKey<FormState>();
  late String _category = widget.initial?.category ?? Place.categories.first;
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _memo = TextEditingController(text: widget.initial?.memo);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(Place(
      id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      attachments: widget.initial?.attachments ?? const [],
      category: _category,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      memo: _memo.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? '장소 추가' : '장소 수정'),
        actions: [TextButton(onPressed: _save, child: const Text('저장'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '구분', border: OutlineInputBorder()),
              items: [for (final c in Place.categories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => _category = v ?? _category,
            ),
            gap,
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null,
            ),
            gap,
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '전화', border: OutlineInputBorder()),
            ),
            gap,
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: '주소 (지도 검색에 사용)',
                helperText: '주소를 비우면 이름으로 지도를 검색합니다',
                border: OutlineInputBorder(),
              ),
            ),
            gap,
            TextFormField(
              controller: _memo,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '예) 진료 시간, 담당 선생님, 주차 정보',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
