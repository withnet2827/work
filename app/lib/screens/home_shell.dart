import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../models/pet_profile.dart';
import 'profile_edit_screen.dart';
import 'profile_screen.dart';

/// 하단 탭 4개: 홈 · 일기 · 병원/미용 · 프로필
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final ProfileStore store;

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
    widget.store.load().then((p) {
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    });
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<PetProfile>(
      MaterialPageRoute(builder: (_) => ProfileEditScreen(initial: _profile)),
    );
    if (result == null) return;
    await widget.store.save(result);
    if (mounted) setState(() => _profile = result);
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
      ProfileScreen(profile: _profile, onEdit: _edit),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('${_profile.name} 데일리')),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '일기'),
          NavigationDestination(icon: Icon(Icons.local_hospital_outlined), selectedIcon: Icon(Icons.local_hospital), label: '병원·미용'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: '프로필'),
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
                const CircleAvatar(radius: 44, child: Icon(Icons.pets, size: 44)),
                const SizedBox(height: 12),
                Text(profile.name, style: Theme.of(context).textTheme.headlineSmall),
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
