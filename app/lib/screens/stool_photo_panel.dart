import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../ai/stool_analyzer.dart';
import '../util/photo_compress.dart';

/// 사진 추가 + (선택) 대변 AI 분석 패널. 산책 기록·추가 급여 입력창에서 같이 쓴다.
/// 사진이 바뀌면 [onPhotoChanged], 분석이 끝나면 [onAnalysis], 결과 적용을 누르면 [onApply]를 부른다.
class StoolPhotoPanel extends StatefulWidget {
  const StoolPhotoPanel({
    super.key,
    required this.photo,
    required this.onPhotoChanged,
    this.showAi = false,
    this.onAnalysis,
    this.onApply,
    this.label = '사진 추가',
  });

  final String photo; // base64(없으면 빈 문자열)
  final ValueChanged<String> onPhotoChanged;
  final bool showAi; // true면 'AI로 사진 분석' 버튼을 보여 준다(대변 사진용)
  final ValueChanged<StoolAnalysis>? onAnalysis;
  final ValueChanged<StoolAnalysis>? onApply;
  final String label;

  @override
  State<StoolPhotoPanel> createState() => _StoolPhotoPanelState();
}

class _StoolPhotoPanelState extends State<StoolPhotoPanel> {
  StoolAnalysis? _analysis;
  bool _analyzing = false;
  String? _error;

  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (x == null) return;
    // 일기 문서가 커지지 않도록 작게 줄인다(약 100KB).
    final b64 = compressPhoto(await x.readAsBytes(), targetChars: 140000);
    if (!mounted) return;
    setState(() {
      _analysis = null;
      _error = null;
    });
    widget.onPhotoChanged(b64);
  }

  Future<void> _analyze() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final a = await analyzeStoolPhoto(widget.photo);
      if (!mounted) return;
      setState(() => _analysis = a);
      widget.onAnalysis?.call(a);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              (isQuotaError(e)
                  ? 'AI 무료 사용량을 오늘 다 썼어요. 내일 다시 시도해 주세요.\n'
                  : 'AI 분석에 실패했어요. 잠시 뒤 다시 시도해 주세요.\n') +
              '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final photo = widget.photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (photo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(photo),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 72, height: 72),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(photo.isEmpty ? widget.label : '사진 바꾸기'),
            ),
            if (photo.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    _analysis = null;
                    _error = null;
                  });
                  widget.onPhotoChanged('');
                },
                icon: const Icon(Icons.close),
                tooltip: '사진 지우기',
              ),
          ],
        ),
        if (widget.showAi && photo.isNotEmpty && stoolAiAvailable) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _analyzing ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_analyzing ? '분석 중...' : 'AI로 사진 분석'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '사진이 구글 AI(Gemini)로 전송돼 분석돼요. 참고용이며 진단이 아니에요.',
              style: text.bodySmall,
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        if (_analysis case final a?)
          Card(
            margin: const EdgeInsets.only(top: 8),
            color: a.concern == '병원 상담'
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI 참고 의견 · ${a.concern}', style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '점수 ${a.score} · ${a.color}'
                    '${a.flags.isEmpty ? '' : ' · ${a.flags.join(', ')}'}',
                  ),
                  if (a.summary.isNotEmpty) Text(a.summary),
                  if (a.advice.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.advice, style: text.bodySmall),
                  ],
                  if (widget.onApply != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => widget.onApply!(a),
                        child: const Text('이 결과를 배변 기록에 적용'),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
