/// 일기 댓글 1건.
class DiaryComment {
  const DiaryComment({
    required this.id,
    required this.author,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String authorId;
  final String text;
  final int createdAt;

  Map<String, dynamic> toMap() => {
    'author': author,
    'authorId': authorId,
    'text': text,
    'createdAt': createdAt,
  };

  factory DiaryComment.fromMap(Map<String, dynamic> m, {String? id}) =>
      DiaryComment(
        id:
            id ??
            m['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        author: m['author'] as String? ?? '',
        authorId: m['authorId'] as String? ?? '',
        text: m['text'] as String? ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}

/// 일기에 남긴 공감(구성원당 1개).
class DiaryReaction {
  const DiaryReaction({
    required this.userId,
    required this.author,
    required this.emoji,
  });
  final String userId;
  final String author;
  final String emoji;

  static const emojis = ['❤️', '👍', '😂', '🐶'];
}
