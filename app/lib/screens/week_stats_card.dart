import 'package:flutter/material.dart';

import '../models/week_stats.dart';

/// 홈 화면의 '최근 7일' 요약 카드.
class WeekStatsCard extends StatelessWidget {
  const WeekStatsCard({super.key, required this.stats});
  final WeekStats stats;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최근 7일', style: text.titleMedium),
            const SizedBox(height: 8),
            if (stats.isEmpty)
              const Text('일기에 산책·추가 급여를 기록하면 여기에 요약이 나와요.')
            else ...[
              Text(
                '🚶 산책 ${stats.walkCount}회 · 총 ${stats.walkMinutes}분'
                '${stats.feedCount > 0 ? '   🍖 추가 급여 ${stats.feedCount}건' : ''}',
              ),
              const SizedBox(height: 4),
              Text(
                '💩 정상 ${stats.poopNormal}'
                ' · 이상 ${stats.poopAbnormal}'
                '${stats.poopNone > 0 ? ' · 없음 ${stats.poopNone}' : ''}',
                style: stats.poopAbnormal > 0
                    ? text.bodyMedium?.copyWith(color: scheme.error)
                    : null,
              ),
              if (stats.poopAbnormal > 0)
                Text(
                  '무름·설사·딱딱함이 있었어요. 계속되면 병원 상담을 권해요.',
                  style: text.bodySmall,
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in stats.days)
                      Expanded(
                        child: _Bar(
                          label: _weekdays[DateTime.parse(d.date).weekday - 1],
                          minutes: d.minutes,
                          ratio: stats.maxMinutes == 0
                              ? 0
                              : d.minutes / stats.maxMinutes,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.minutes, required this.ratio});
  final String label;
  final int minutes;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(minutes > 0 ? '$minutes' : '', style: small),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: minutes > 0 ? (4 + 52 * ratio) : 3,
          decoration: BoxDecoration(
            color: minutes > 0 ? scheme.primary : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: small),
      ],
    );
  }
}
