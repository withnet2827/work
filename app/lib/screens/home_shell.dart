import 'package:flutter/material.dart';

import '../backup/backup_service.dart';
import '../backup/file_download.dart';
import '../backup/file_pick.dart';
import '../backup/restore_service.dart';
import '../data/diary_store.dart';
import '../data/record_store.dart';
import '../data/profile_store.dart';
import '../data/visit_store.dart';
import '../models/diary_entry.dart';
import '../models/health_record.dart';
import '../models/weight_log.dart';
import '../models/visit.dart';
import '../models/week_stats.dart';
import '../models/pet_profile.dart';
import '../widgets_pet_avatar.dart';
import 'diary_screen.dart';
import 'profile_edit_screen.dart';
import 'health_screen.dart';
import 'visit_actions.dart';
import 'week_stats_card.dart';
import 'visits_screen.dart';
import 'diary_edit_screen.dart' show todayString;
import 'profile_screen.dart';

/// 가족 공유 모드에서 앱바 메뉴에 보여줄 정보.
class FamilyInfo {
  const FamilyInfo({
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    required this.userLabel,
    this.userId = 'local',
    required this.onSignOut,
  });
  final String name;
  final String inviteCode;
  final int memberCount;
  final String userLabel;
  final String userId;
  final VoidCallback onSignOut;
}

/// 하단 탭 4개: 홈 · 일기 · 병원/미용 · 프로필
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.store,
    this.diaryStore,
    this.visitStore,
    this.weightStore,
    this.healthStore,
    this.familyInfo,
  });
  final ProfileStore store;
  final DiaryStore? diaryStore;
  final VisitStore? visitStore;
  final RecordStore<WeightLog>? weightStore;
  final RecordStore<HealthRecord>? healthStore;
  final FamilyInfo? familyInfo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final DiaryStore _diaryStore = widget.diaryStore ?? LocalDiaryStore();
  late final VisitStore _visitStore = widget.visitStore ?? LocalVisitStore();
  late final RecordStore<WeightLog> _weightStore =
      widget.weightStore ??
      LocalRecordStore<WeightLog>(
        key: 'weights_v1',
        toMap: (e) => e.toMap(),
        fromMap: WeightLog.fromMap,
        idOf: (e) => e.id,
      );
  late final RecordStore<HealthRecord> _healthStore =
      widget.healthStore ??
      LocalRecordStore<HealthRecord>(
        key: 'health_v1',
        toMap: (e) => e.toMap(),
        fromMap: HealthRecord.fromMap,
        idOf: (e) => e.id,
      );
  List<HealthRecord> _health = [];
  int _healthNonce = 0; // 홈에서 접종 일정을 눌러 들어올 때마다 올려 건강 탭을 접종 화면으로 연다
  List<Visit> _visits = [];
  List<DiaryEntry> _entries = [];
  PetProfile _profile = const PetProfile();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _loadVisits() async {
    try {
      final v = await _visitStore.load();
      if (mounted) setState(() => _visits = v);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('방문 기록을 불러오지 못했습니다. $e')));
      }
    }
  }

  Future<void> _loadHealth() async {
    try {
      final h = await _healthStore.load();
      if (mounted) setState(() => _health = h);
    } catch (_) {
      // 홈의 일정 표시는 보조 정보라 실패해도 건강 탭에서 오류를 보여준다.
    }
  }

  Future<void> _loadEntries() async {
    try {
      final e = await _diaryStore.load();
      if (mounted) setState(() => _entries = e);
    } catch (_) {
      // 요약은 보조 정보라 실패해도 조용히 넘어간다(일기 탭에서 오류를 보여준다).
    }
  }

  Future<void> _reload() async {
    _loadVisits();
    _loadEntries();
    _loadHealth();
    try {
      final p = await widget.store.load();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('불러오지 못했습니다. $e')));
    }
  }

  Future<void> _runExport(Future<void> Function() job) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('파일을 만드는 중입니다...')));
    try {
      await job();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('내려받기를 시작했습니다. 다운로드 폴더를 확인하세요.')),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('내보내지 못했습니다. $e')));
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    BackupPreview preview;
    try {
      final text = await pickTextFile();
      if (text == null) return; // 선택 취소
      preview = parseBackup(text);
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일을 읽지 못했습니다. $e')));
      return;
    }
    if (!mounted) return;
    var includeProfile = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('백업 복원'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview.exportedAt.isNotEmpty)
                Text(
                  '백업 시각: ${preview.exportedAt.split('.').first.replaceFirst('T', ' ')}',
                ),
              const SizedBox(height: 8),
              Text(
                '일기 ${preview.diary}편 · 방문 ${preview.visits}건\n체중 ${preview.weights}건 · 접종·예방약 ${preview.health}건',
              ),
              const SizedBox(height: 8),
              const Text(
                '같은 기록은 백업 내용으로 덮어쓰고, 없는 기록은 추가해요. 지금 있는 기록을 지우지는 않아요.',
              ),
              if (preview.hasProfile)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('프로필도 백업 내용으로 바꾸기'),
                  subtitle: const Text('현재 프로필이 덮어씌워져요'),
                  value: includeProfile,
                  onChanged: (v) => setD(() => includeProfile = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: preview.total == 0 && !includeProfile
                  ? null
                  : () => Navigator.pop(c, true),
              child: const Text('복원'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('복원 중입니다. 잠시만 기다려 주세요...'),
        duration: Duration(minutes: 5),
      ),
    );
    try {
      final r = await restoreBackup(
        preview: preview,
        includeProfile: includeProfile,
        saveProfile: (p) async => _update(p),
        diaryStore: _diaryStore,
        visitStore: _visitStore,
        weightStore: _weightStore,
        healthStore: _healthStore,
      );
      await _loadVisits();
      await _loadEntries();
      await _loadHealth();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '복원했어요. 일기 ${r.diary} · 방문 ${r.visits} · 체중 ${r.weights} · 접종 ${r.health}'
              '${r.skipped > 0 ? ' (읽지 못한 항목 ${r.skipped}건 건너뜀)' : ''}',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('복원하지 못했습니다. $e')));
    }
  }

  void _showBackup() {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('전체 백업 (JSON)'),
              subtitle: const Text('프로필·일기·방문 기록과 사진·댓글을 한 파일로'),
              onTap: () {
                Navigator.pop(c);
                _runExport(() async {
                  final json = await buildBackupJson(
                    profile: _profile,
                    diaryStore: _diaryStore,
                    visitStore: _visitStore,
                    weightStore: _weightStore,
                    healthStore: _healthStore,
                  );
                  await downloadTextFile(
                    backupFileName('chio-backup', 'json'),
                    json,
                    mime: 'application/json',
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('방문·지출 표 (CSV)'),
              subtitle: const Text('엑셀에서 바로 열 수 있어요'),
              onTap: () {
                Navigator.pop(c);
                _runExport(() async {
                  final visits = await _visitStore.load();
                  await downloadTextFile(
                    backupFileName('chio-visits', 'csv'),
                    visitsCsv(visits),
                    mime: 'text/csv',
                  );
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('백업 파일에서 복원'),
              subtitle: const Text('내려받은 JSON 백업을 현재 기록에 합쳐요 (기존 기록은 지우지 않아요)'),
              onTap: () {
                Navigator.pop(c);
                _restore();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFamily() {
    final f = widget.familyInfo!;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(f.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('로그인: ${f.userLabel}'),
            Text('구성원: ${f.memberCount}명'),
            const SizedBox(height: 16),
            const Text('가족 초대 코드'),
            SelectableText(
              f.inviteCode,
              style: Theme.of(c).textTheme.headlineMedium,
            ),
            const Text('가족이 로그인한 뒤 이 코드를 입력하면 같은 기록을 함께 봅니다.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              f.onSignOut();
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<PetProfile>(
      MaterialPageRoute(builder: (_) => ProfileEditScreen(initial: _profile)),
    );
    if (result == null) return;
    await _update(result);
  }

  Future<void> _update(PetProfile p) async {
    try {
      await widget.store.save(p);
    } catch (_) {
      // 브라우저 저장 용량 초과 등. 화면 값은 바꾸지 않고 안내한다.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 공간이 부족해 저장하지 못했습니다. 사진을 줄여 주세요.')),
        );
      }
      return;
    }
    if (mounted) setState(() => _profile = p);
  }

  VisitActions get _visitActions => VisitActions(
    store: _visitStore,
    places: _profile.places,
    authorName: widget.familyInfo?.userLabel.isNotEmpty == true
        ? widget.familyInfo!.userLabel
        : '나',
    onChanged: _loadVisits,
    onAddPlace: (p) =>
        _update(_profile.copyWith(places: [..._profile.places, p])),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final authorName = widget.familyInfo?.userLabel.isNotEmpty == true
        ? widget.familyInfo!.userLabel
        : '나';
    final pages = <Widget>[
      _HomeTab(
        profile: _profile,
        upcoming: upcomingVisits(_visits, todayString()),
        actions: _visitActions,
        stats: WeekStats.from(_entries, DateTime.now()),
        dueHealth: HealthRecord.due(_health, DateTime.now(), withinDays: 14),
        onOpenHealth: () => setState(() {
          _healthNonce++;
          _tab = 3;
        }),
      ),
      DiaryScreen(
        store: _diaryStore,
        authorName: authorName,
        userId: widget.familyInfo?.userId ?? 'local',
      ),
      VisitsScreen(
        store: _visitStore,
        visits: _visits,
        places: _profile.places,
        authorName: authorName,
        onChanged: _loadVisits,
        onAddPlace: (p) =>
            _update(_profile.copyWith(places: [..._profile.places, p])),
      ),
      HealthScreen(
        key: ValueKey('health-$_healthNonce'),
        initialTab: _healthNonce == 0 ? 0 : 1,
        weightStore: _weightStore,
        healthStore: _healthStore,
        authorName: authorName,
        onHealthChanged: _loadHealth,
      ),
      ProfileScreen(profile: _profile, onEdit: _edit, onChanged: _update),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${_profile.name} 데일리'),
        actions: [
          IconButton(
            onPressed: _showBackup,
            icon: const Icon(Icons.download_outlined),
            tooltip: '백업·복원',
          ),
          if (widget.familyInfo != null) ...[
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
            ),
            IconButton(
              onPressed: _showFamily,
              icon: const Icon(Icons.group),
              tooltip: '가족',
            ),
          ],
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 0) _loadEntries(); // 일기에서 쓴 기록을 홈 요약에 반영
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '일기',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital),
            label: '병원·미용',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: '건강',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.profile,
    required this.upcoming,
    required this.actions,
    required this.stats,
    required this.dueHealth,
    required this.onOpenHealth,
  });
  final PetProfile profile;
  final List<Visit> upcoming;
  final VisitActions actions;
  final WeekStats stats;
  final List<HealthRecord> dueHealth;
  final VoidCallback onOpenHealth;

  @override
  Widget build(BuildContext context) {
    final days = profile.daysTogether();
    final age = profile.ageText();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                PetAvatar(profile: profile, radius: 52),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (age.isNotEmpty) Text(age),
                if (days != null) Text('함께한 지 $days일째'),
              ],
            ),
          ),
        ),
        WeekStatsCard(stats: stats),
        if (dueHealth.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              '접종·예방약 일정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final r in dueHealth.take(3))
            Card(
              child: ListTile(
                onTap: onOpenHealth,
                leading: const Icon(Icons.vaccines_outlined),
                title: Text(r.title),
                subtitle: Text('예정 ${r.nextDate}'),
                trailing: Text(
                  ddayText(r.nextDate, DateTime.now()),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        ],
        if (upcoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              '다가오는 예약',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final v in upcoming.take(3))
            Card(
              child: ListTile(
                onTap: () => actions.showSheet(context, v),
                leading: Icon(
                  v.type == '미용'
                      ? Icons.content_cut
                      : Icons.local_hospital_outlined,
                ),
                title: Text(v.placeName.isEmpty ? v.type : v.placeName),
                subtitle: Text(
                  '${v.date}${v.time.isEmpty ? '' : ' ${v.time}'}',
                ),
                trailing: Text(
                  ddayText(v.date, DateTime.now()),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
