import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokerly/ui/screens/home_screen.dart';
import 'package:pokerly/ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: PokerlyApp()));
}

class PokerlyApp extends StatelessWidget {
  const PokerlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokerly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
