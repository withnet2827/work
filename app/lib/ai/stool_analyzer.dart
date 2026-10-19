import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/stool_log.dart';

/// AI가 사진을 보고 낸 참고용 의견.
class StoolAnalysis {
  const StoolAnalysis({
    required this.score,
    required this.color,
    required this.flags,
    required this.concern,
    required this.summary,
    required this.advice,
  });

  final int score; // 1~7
  final String color; // StoolLog.colors 중 하나
  final List<String> flags; // StoolLog.flagOptions 중 해당 항목
  final String concern; // 정상 | 관찰 | 병원 상담
  final String summary;
  final String advice;

  /// 목록과 기록에 저장할 한 줄 요약.
  String get note => 'AI 참고 의견(${concern.isEmpty ? '관찰' : concern}): $summary';

  /// 모델 응답(JSON 문자열)을 안전하게 해석한다. 값이 이상하면 허용 범위로 맞춘다.
  static StoolAnalysis? parse(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    s = s.substring(start, end + 1);
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final color = m['color'] as String? ?? '갈색';
      const concerns = ['정상', '관찰', '병원 상담'];
      final concern = m['concern'] as String? ?? '관찰';
      return StoolAnalysis(
        score: ((m['score'] as num?)?.toInt() ?? 3).clamp(1, 7),
        color: StoolLog.colors.contains(color) ? color : '갈색',
        flags: [
          for (final f in (m['flags'] as List? ?? const []))
            if (StoolLog.flagOptions.contains('$f')) '$f',
        ],
        concern: concerns.contains(concern) ? concern : '관찰',
        summary: (m['summary'] as String? ?? '').trim(),
        advice: (m['advice'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }
}

const _prompt = '''
당신은 반려견 건강 상담을 돕는 보조자입니다. 사진은 강아지의 대변입니다.
수의사가 아니므로 진단하지 말고, 사진에서 보이는 것만 근거로 일반적인 참고 의견을 주세요.
사진이 대변이 아니거나 너무 흐리면 summary에 그 사실을 쓰고 concern은 "관찰"로 하세요.

다음 JSON만 출력하세요(설명 문장 금지).
{
  "score": 1~7 정수(굳기. 1 아주 딱딱 / 2~3 이상적 / 4 부드러움 / 5 질음 / 6 죽처럼 퍼짐 / 7 물 같은 설사),
  "color": "갈색" | "주황·노랑" | "녹색" | "회색·흰색" | "붉은 피" | "검은색" 중 하나,
  "flags": ["점액","이물질","기생충","냄새 심함"] 중 사진에서 보이는 것만(없으면 빈 배열),
  "concern": "정상" | "관찰" | "병원 상담" 중 하나,
  "summary": "보이는 상태를 한국어 1~2문장으로",
  "advice": "집에서 살펴볼 점과 병원에 가야 하는 신호를 한국어 2~3문장으로. 진단 표현 금지."
}
검은색 변이나 붉은 피, 기생충이 보이면 concern은 "병원 상담"으로 하세요.
''';

/// 앱이 Firebase에 연결돼 있을 때만 AI 분석을 쓸 수 있다(로컬 모드에서는 사용 불가).
bool get stoolAiAvailable => Firebase.apps.isNotEmpty;

/// 대변 사진을 Gemini(Firebase AI Logic)로 분석한다. 실패하면 예외를 던진다.
Future<StoolAnalysis> analyzeStoolPhoto(String photoBase64) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.2,
    ),
  );
  final res = await model.generateContent([
    Content.multi([
      TextPart(_prompt),
      InlineDataPart('image/jpeg', base64Decode(photoBase64)),
    ]),
  ]);
  final parsed = StoolAnalysis.parse(res.text);
  if (parsed == null) {
    throw StateError('AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.');
  }
  return parsed;
}
