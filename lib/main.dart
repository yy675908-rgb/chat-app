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
    const seed = Color(0xFF786F9F);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '角色聊天',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF6F3F1),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F3F1),
        useMaterial3: true,
        fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
      ),
      home: const ChatScreen(),
    );
  }
}
