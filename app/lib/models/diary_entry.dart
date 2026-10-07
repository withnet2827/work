import 'daily_log.dart';

/// 일기 한 편. 사진은 압축한 base64 문자열 목록.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    this.body = '',
    this.mood = '',
    this.author = '',
    this.photos = const [],
    this.walks = const [],
    this.feeds = const [],
    this.createdAt = 0,
    this.commentCount = 0,
    this.reactionCount = 0,
  });

  static const moods = ['😊', '🥰', '😴', '🤒', '😢', '🎉'];

  final String id;
  final String date; // yyyy-mm-dd
  final String body;
  final String mood;
  final String author;
  final List<String> photos;
  final List<WalkLog> walks; // 산책 기록(여러 번)
  final List<FeedLog> feeds; // 기본 급여 외 추가 급여
  final int createdAt; // millisecondsSinceEpoch
  final int commentCount; // 서버가 관리하는 집계값(저장 시 덮어쓰지 않음)
  final int reactionCount;

  DiaryEntry copyWith({
    String? date,
    String? body,
    String? mood,
    List<String>? photos,
    List<WalkLog>? walks,
    List<FeedLog>? feeds,
  }) => DiaryEntry(
    id: id,
    date: date ?? this.date,
    body: body ?? this.body,
    mood: mood ?? this.mood,
    author: author,
    photos: photos ?? this.photos,
    walks: walks ?? this.walks,
    feeds: feeds ?? this.feeds,
    createdAt: createdAt,
    commentCount: commentCount,
    reactionCount: reactionCount,
  );

  DiaryEntry withCounts({required int comments, required int reactions}) =>
      DiaryEntry(
        id: id,
        date: date,
        body: body,
        mood: mood,
        author: author,
        photos: photos,
        walks: walks,
        feeds: feeds,
        createdAt: createdAt,
        commentCount: comments,
        reactionCount: reactions,
      );

  /// 사진 제외 본문 정보(서버 문서용)
  Map<String, dynamic> toMeta() => {
    'date': date,
    'body': body,
    'mood': mood,
    'author': author,
    'createdAt': createdAt,
    'photoCount': photos.length,
    'walks': walks.map((e) => e.toMap()).toList(),
    'feeds': feeds.map((e) => e.toMap()).toList(),
  };

  Map<String, dynamic> toMap() => {'id': id, ...toMeta(), 'photos': photos};

  factory DiaryEntry.fromMap(
    Map<String, dynamic> m, {
    String? id,
    List<String>? photos,
  }) => DiaryEntry(
    id:
        id ??
        m['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    date: m['date'] as String? ?? '',
    body: m['body'] as String? ?? '',
    mood: m['mood'] as String? ?? '',
    author: m['author'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    commentCount: (m['commentCount'] as num?)?.toInt() ?? 0,
    reactionCount: (m['reactionCount'] as num?)?.toInt() ?? 0,
    photos: photos ?? List<String>.from(m['photos'] as List? ?? const []),
    walks: [
      for (final e in (m['walks'] as List? ?? const []))
        WalkLog.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
    feeds: [
      for (final e in (m['feeds'] as List? ?? const []))
        FeedLog.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
  );
}
