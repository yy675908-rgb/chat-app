import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CharacterChatApp());
}

class CharacterChatApp extends StatelessWidget {
  const CharacterChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2F4741);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '角色聊天',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F6F2),
        ),
        scaffoldBackgroundColor: const Color(0xFFEDEBE6),
        useMaterial3: true,
        fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
        splashFactory: InkRipple.splashFactory,
      ),
      home: const ChatScreen(),
    );
  }
}
