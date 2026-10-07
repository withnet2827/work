import 'package:flutter/material.dart';

import 'data/profile_store.dart';
import 'screens/home_shell.dart';

void main() => runApp(ChioApp(store: LocalProfileStore()));

class ChioApp extends StatelessWidget {
  const ChioApp({super.key, required this.store});
  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorSchemeSeed: const Color(0xFFE59A4F),
      useMaterial3: true,
    );
    return MaterialApp(
      title: '치오 데일리',
      debugShowCheckedModeBanner: false,
      theme: base,
      home: HomeShell(store: store),
    );
  }
}
