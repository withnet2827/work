import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/attachment.dart';

/// 사진 확대 보기. 좌우로 넘기며 핀치로 확대, 삭제 가능.
class AttachmentViewerScreen extends StatefulWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.attachments,
    required this.initialIndex,
    required this.onDelete,
    this.canDelete = true,
  });
  final List<Attachment> attachments;
  final int initialIndex;
  final ValueChanged<Attachment> onDelete;
  final bool canDelete;

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  late final PageController _page = PageController(
    initialPage: widget.initialIndex,
  );
  late List<Attachment> _items = List.of(widget.attachments);
  late int _index = widget.initialIndex;

  Future<void> _delete() async {
    final target = _items[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.onDelete(target);
    if (_items.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _items = _items.where((e) => e.id != target.id).toList();
      if (_index >= _items.length) _index = _items.length - 1;
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = _items[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${cur.label}${cur.date.isEmpty ? '' : '  ${cur.date}'}  (${_index + 1}/${_items.length})',
        ),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _page,
        itemCount: _items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.memory(
              base64Decode(_items[i].photoBase64),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
