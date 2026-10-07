import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pet_profile.dart';
import '../widgets_pet_avatar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.initial});
  final PetProfile initial;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late bool _neutered;
  String _gender = '';
  String _photo = '';

  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _neutered = p.neutered;
    _gender = p.gender;
    _photo = p.photoBase64;
    _c = {
      'name': TextEditingController(text: p.name),
      'birthDate': TextEditingController(text: p.birthDate),
      'adoptionDate': TextEditingController(text: p.adoptionDate),
      'breed': TextEditingController(text: p.breed),
      'registrationNo': TextEditingController(text: p.registrationNo),
      'allergies': TextEditingController(text: p.allergies),
      'notes': TextEditingController(text: p.notes),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _date(String? v) {
    if (v == null || v.isEmpty) return null;
    if (!_dateRe.hasMatch(v) || DateTime.tryParse(v) == null) {
      return 'yyyy-mm-dd 형식으로 입력';
    }
    return null;
  }

  Future<void> _pickDate(String key) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_c[key]!.text) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (d == null) return;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    setState(() => _c[key]!.text = '${d.year}-$m-$day');
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _photo = base64Encode(bytes));
  }

  void _photoMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () {
                Navigator.pop(c);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(c);
                _pickPhoto(ImageSource.camera);
              },
            ),
            if (_photo.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('사진 삭제'),
                onTap: () {
                  Navigator.pop(c);
                  setState(() => _photo = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    String t(String k) => _c[k]!.text.trim();
    Navigator.of(context).pop(
      widget.initial.copyWith(
        name: t('name'),
        gender: _gender,
        neutered: _neutered,
        birthDate: t('birthDate'),
        adoptionDate: t('adoptionDate'),
        breed: t('breed'),
        registrationNo: t('registrationNo'),
        allergies: t('allergies'),
        notes: t('notes'),
        photoBase64: _photo,
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool date = false,
    int lines = 1,
    TextInputType? type,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[key],
        maxLines: lines,
        keyboardType: type,
        readOnly: date,
        onTap: date ? () => _pickDate(key) : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: date ? const Icon(Icons.calendar_today) : null,
        ),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return '필수 항목입니다';
          return date ? _date(v) : null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        actions: [TextButton(onPressed: _save, child: const Text('저장'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _photoMenu,
                child: Stack(
                  children: [
                    PetAvatar(
                      profile: widget.initial.copyWith(photoBase64: _photo),
                      radius: 56,
                    ),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.camera_alt, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _field('name', '이름', required: true),
            DropdownButtonFormField<String>(
              initialValue: _gender.isEmpty ? null : _gender,
              decoration: const InputDecoration(
                labelText: '성별',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '수컷', child: Text('수컷')),
                DropdownMenuItem(value: '암컷', child: Text('암컷')),
              ],
              onChanged: (v) => _gender = v ?? '',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('중성화 완료'),
              value: _neutered,
              onChanged: (v) => setState(() => _neutered = v),
            ),
            _field('birthDate', '생년월일', date: true),
            _field('adoptionDate', '입양일', date: true),
            _field('breed', '견종'),
            _field('registrationNo', '동물등록번호', type: TextInputType.number),
            _field('allergies', '알레르기', lines: 2),
            _field('notes', '특이사항', lines: 3),
          ],
        ),
      ),
    );
  }
}
