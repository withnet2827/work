import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_config.dart';
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

/// 어떤 빌드가 실행 중인지 오류 화면에서 확인하기 위한 표시.
const appBuildTag = 'b1019-lite';

/// 사용할 Gemini 모델. 오류 문구에 "no longer available"이 나오면 이 값만 최신 이름으로 바꾸면 된다.
const stoolAiModel = 'gemini-3.5-flash-lite';

/// 순서대로 시도할 모델. 앞 모델의 무료 사용량이 끝났거나 쓸 수 없으면 다음 모델로 넘어간다.
/// 목록의 이름은 콘솔/오류 문구에 나온 것으로 바꿔 쓰면 된다.
const stoolAiModels = [
  stoolAiModel, // 무료 하루 500회
  'gemini-3.1-flash-lite', // 무료 하루 500회
  'gemini-3.8-flash', // 무료 하루 20회(최후 수단)
];

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

/// 서버가 잠시 바쁜 경우(503 등): 기다렸다가 같은 모델로 다시 시도하면 되는 오류.
bool _isBusy(Object e) {
  final m = '$e'.toLowerCase();
  return e is TimeoutException ||
      m.contains('503') ||
      m.contains('unavailable') ||
      m.contains('deadline') ||
      m.contains('overloaded');
}

/// 이 모델은 지금 쓸 수 없는 경우(무료 사용량 초과 429, 모델 없음 등): 다음 모델을 시도한다.
bool _isModelUnusable(Object e) {
  final m = '$e'.toLowerCase();
  return m.contains('429') ||
      m.contains('quota') ||
      m.contains('resource_exhausted') ||
      m.contains('no longer available') ||
      m.contains('not found') ||
      m.contains('404');
}

/// 무료 사용량을 모두 쓴 오류인가(안내 문구용).
bool isQuotaError(Object e) {
  final m = '$e'.toLowerCase();
  return m.contains('429') ||
      m.contains('quota') ||
      m.contains('resource_exhausted');
}

GenerativeModel _modelFor(String name) => FirebaseAI.googleAI(
  // 앱 체크를 켠 경우에만 토큰을 함께 보낸다(키가 비어 있으면 앱 체크를 켜지 않았으므로 null).
  appCheck: FirebaseConfig.recaptchaSiteKey.isNotEmpty
      ? FirebaseAppCheck.instance
      : null,
).generativeModel(
  model: name,
  generationConfig: GenerationConfig(
    responseMimeType: 'application/json',
    temperature: 0.2,
  ),
);

/// 대변 사진을 Gemini(Firebase AI Logic)로 분석한다. 실패하면 예외를 던진다.
/// - 서버가 바쁘면(503 등) 잠시 기다렸다가 같은 모델로 최대 3번 시도한다.
/// - 무료 사용량 초과·모델 없음이면 다음 모델로 넘어간다(같은 오류를 반복 호출하지 않는다).
Future<StoolAnalysis> analyzeStoolPhoto(String photoBase64) async {
  final content = [
    Content.multi([
      TextPart(_prompt),
      InlineDataPart('image/jpeg', base64Decode(photoBase64)),
    ]),
  ];
  const waits = [Duration(seconds: 3), Duration(seconds: 8)];
  Object? lastError;
  for (final name in stoolAiModels) {
    final model = _modelFor(name);
    for (var attempt = 0; ; attempt++) {
      try {
        final res = await model
            .generateContent(content)
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw TimeoutException(
                '45초 안에 응답이 없어요. 앱 체크(reCAPTCHA) 설정이나 네트워크를 확인해 주세요.',
              ),
            );
        final parsed = StoolAnalysis.parse(res.text);
        if (parsed == null) {
          throw StateError('AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.');
        }
        return parsed;
      } catch (e) {
        lastError = e;
        if (_isModelUnusable(e)) break; // 다음 모델로
        if (attempt >= waits.length || !_isBusy(e)) rethrow;
        await Future<void>.delayed(waits[attempt]);
      }
    }
  }
  throw lastError ?? StateError('AI 분석에 실패했습니다.');
}
