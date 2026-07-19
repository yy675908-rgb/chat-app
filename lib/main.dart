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
    const ink = Color(0xFF192426);
    const mist = Color(0xFFF4F6F5);
    const teal = Color(0xFF3F6B70);
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      surface: const Color(0xFFFBFCFA),
    ).copyWith(
      primary: teal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDDEBEC),
      onPrimaryContainer: const Color(0xFF17383C),
      secondary: const Color(0xFF62777A),
      secondaryContainer: const Color(0xFFE8EEEE),
      onSecondaryContainer: const Color(0xFF2A3B3E),
      surface: const Color(0xFFFBFCFA),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F9F8),
      surfaceContainer: const Color(0xFFF0F3F2),
      surfaceContainerHigh: const Color(0xFFE9EEEC),
      surfaceContainerHighest: const Color(0xFFE2E8E6),
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF667174),
      outline: const Color(0xFFCBD4D2),
      outlineVariant: const Color(0xFFE1E7E5),
      error: const Color(0xFFBA4B4B),
    );

    final base = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      useMaterial3: true,
      fontFamilyFallback: const [
        'PingFang SC',
        'Noto Sans CJK SC',
        'Microsoft YaHei',
      ],
      splashFactory: InkRipple.splashFactory,
    );

    final readableTextTheme = base.textTheme
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          titleLarge: const TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(color: ink, fontSize: 15.5, height: 1.5),
          bodyMedium: const TextStyle(color: ink, fontSize: 14, height: 1.45),
          labelLarge: const TextStyle(
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '林间',
      themeMode: ThemeMode.light,
      theme: base.copyWith(
        textTheme: readableTextTheme,
        primaryTextTheme: readableTextTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFBFCFA),
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 72,
          titleSpacing: 8,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFBFCFA),
          surfaceTintColor: Colors.transparent,
          width: 304,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          ),
        ),
        cardTheme: CardThemeData(
          color: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: scheme.onSurfaceVariant,
          textColor: ink,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: scheme.outlineVariant,
          thickness: 0.8,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          floatingLabelStyle: const TextStyle(
            color: teal,
            fontWeight: FontWeight.w600,
          ),
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: teal, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: scheme.error),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            highlightColor: scheme.primaryContainer.withValues(alpha: 0.55),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 1,
          highlightElevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFBFCFA),
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: Color(0xFFFBFCFA),
          modalBarrierColor: Color(0x520F1D1F),
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          textStyle: const TextStyle(color: ink, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(
              scheme.surfaceContainerLowest,
            ),
            foregroundColor: const WidgetStatePropertyAll(ink),
          ),
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          textStyle: TextStyle(color: ink, fontSize: 14),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: teal,
          selectionHandleColor: teal,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF263234),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          insetPadding: const EdgeInsets.all(14),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: scheme.onPrimaryContainer,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: scheme.surfaceContainer,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}
