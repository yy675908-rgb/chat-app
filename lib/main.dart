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
    const slate = Color(0xFF4A6873);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: slate,
      brightness: Brightness.light,
      surface: const Color(0xFFFCFDFD),
    ).copyWith(
      primary: const Color(0xFF456875),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE4EEF1),
      onPrimaryContainer: const Color(0xFF213940),
      secondary: const Color(0xFF68787E),
      secondaryContainer: const Color(0xFFEDF1F2),
      onSecondaryContainer: const Color(0xFF2C393D),
      surface: const Color(0xFFFCFDFD),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF6F8F8),
      surfaceContainer: const Color(0xFFF0F3F4),
      surfaceContainerHigh: const Color(0xFFEBEFF0),
      surfaceContainerHighest: const Color(0xFFE5EAEC),
      onSurface: const Color(0xFF202426),
      onSurfaceVariant: const Color(0xFF687176),
      outline: const Color(0xFFD4DCDF),
      outlineVariant: const Color(0xFFE4E9EB),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '角色聊天',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F8F9),
        useMaterial3: true,
        fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
        splashFactory: InkRipple.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFCFDFD),
          foregroundColor: Color(0xFF202426),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFCFDFD),
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5EAEC),
          thickness: 0.7,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F3F4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE1E6E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xFF78929B),
              width: 1.2,
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF303537),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.light,
      home: const ChatScreen(),
    );
  }
}
