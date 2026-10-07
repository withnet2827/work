import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../models/pet_profile.dart';
import '../widgets_pet_avatar.dart';
import 'profile_edit_screen.dart';
import 'profile_screen.dart';

/// 가족 공유 모드에서 앱바 메뉴에 보여줄 정보.
class FamilyInfo {
  const FamilyInfo({
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    required this.userLabel,
    required this.onSignOut,
  });
  final String name;
  final String inviteCode;
  final int memberCount;
  final String userLabel;
  final VoidCallback onSignOut;
}

/// 하단 탭 4개: 홈 · 일기 · 병원/미용 · 프로필
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, this.familyInfo});
  final ProfileStore store;
  final FamilyInfo? familyInfo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  PetProfile _profile = const PetProfile();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = <Widget>[
      _HomeTab(profile: _profile),
      const _ComingSoon(title: '일기', note: '다음 단계(1-B)에서 만듭니다.'),
      const _ComingSoon(title: '병원·미용', note: '그 다음 단계(1-C)에서 만듭니다.'),
      ProfileScreen(profile: _profile, onEdit: _edit, onChanged: _update),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${_profile.name} 데일리'),
        actions: [
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
        onDestinationSelected: (i) => setState(() => _tab = i),
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
  const _HomeTab({required this.profile});
  final PetProfile profile;

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
      ],
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.note});
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('$title\n$note', textAlign: TextAlign.center));
}
