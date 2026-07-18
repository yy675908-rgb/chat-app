import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CharacterChatApp());
}

class CharacterChatApp extends StatelessWidget {
  const CharacterChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF27483D);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '角色聊天',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          brightness: Brightness.light,
          surface: const Color(0xFFFFFCF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F1EB),
        useMaterial3: true,
        fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
        splashFactory: InkRipple.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF3F1EB),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
