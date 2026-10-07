import 'package:flutter/material.dart';

import '../data/record_store.dart';
import '../models/health_record.dart';
import '../models/place.dart';
import '../models/weight_log.dart';
import 'health_section.dart';
import 'weight_section.dart';

/// 건강 탭: 체중 / 접종·예방약.
class HealthScreen extends StatefulWidget {
  const HealthScreen({
    super.key,
    required this.weightStore,
    required this.healthStore,
    required this.authorName,
    required this.onHealthChanged,
    this.initialTab = 0,
    this.places = const [],
  });
  final RecordStore<WeightLog> weightStore;
  final RecordStore<HealthRecord> healthStore;
  final String authorName;
  final VoidCallback onHealthChanged;
  final int initialTab; // 0 체중, 1 접종·예방약
  final List<Place> places; // 프로필에 등록된 장소(기본 병원 초기값용)

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.monitor_weight_outlined),
                label: Text('체중'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.vaccines_outlined),
                label: Text('접종·예방약'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: _tab == 0
              ? WeightSection(
                  store: widget.weightStore,
                  authorName: widget.authorName,
                )
              : HealthSection(
                  store: widget.healthStore,
                  authorName: widget.authorName,
                  onChanged: widget.onHealthChanged,
                  places: widget.places,
                ),
        ),
      ],
    );
  }
}
