/// 장소(병원·미용실 등)에 붙이는 사진. 영수증, 진료기록, 미용 전·후 등.
class Attachment {
  const Attachment({
    required this.id,
    required this.photoBase64,
    this.label = '기타',
    this.date = '',
  });

  static const labels = ['영수증', '진료기록', '검사결과', '미용 전', '미용 후', '기타'];

  final String id;
  final String photoBase64; // 축소본. 드라이브 연동 후 파일 ID로 교체 예정
  final String label;
  final String date; // yyyy-mm-dd

  Map<String, dynamic> toMap() => {
    'id': id,
    'photoBase64': photoBase64,
    'label': label,
    'date': date,
  };

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
    id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    photoBase64: m['photoBase64'] as String? ?? '',
    label: m['label'] as String? ?? '기타',
    date: m['date'] as String? ?? '',
  );
}
