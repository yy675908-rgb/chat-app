import 'dart:async';
import 'dart:convert';

import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/chat_message.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/screens/chat_screen.dart';
import 'package:character_chat_app/services/ai_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const provider = ProviderProfile(
    id: 'test',
    name: 'Test',
    protocol: ProviderProtocol.openAiCompatible,
    baseUrl: 'https://example.com/v1',
    models: ['model'],
    selectedModel: 'model',
  );

  setUp(() {
    final character = CharacterProfile.lin(DateTime.utc(2026))
        .copyWith(greeting: '你好');
    SharedPreferences.setMockInitialValues({
      'character_profiles_v2': jsonEncode([character.toJson()]),
      'selected_character_v2': character.id,
      'providers_v2': jsonEncode([provider.toJson()]),
      'selected_provider_v2': provider.id,
      'auto_memory_enabled_v1': false,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'read' ? 'test-key' : null,
        );
  });

  Future<void> openChat(
    WidgetTester tester,
    List<_ControlledReply> services,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          replyServiceFactory: () {
            final service = _ControlledReply();
            services.add(service);
            return service;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets(
    'sending during generation is retained and receives the next reply',
    (tester) async {
      final services = <_ControlledReply>[];
      await openChat(tester, services);
      await send(tester, '第一句话');
      expect(services.length, 1);
      await send(tester, '第二句话');
      expect(services.length, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      services.first.finish('第一条回复');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(services.length, 2);
      expect(services.last.history.map((m) => m.text), contains('第二句话'));
      expect(services.last.history.map((m) => m.text), contains('第一条回复'));
      services.last.finish('第二条回复');
      await tester.pumpAndSettle();
      expect(find.byTooltip('停止当前回复'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stop cancels queued generation and a later send starts normally',
    (tester) async {
      final services = <_ControlledReply>[];
      await openChat(tester, services);
      await send(tester, '先说一句');
      await send(tester, '追加一句');
      await tester.tap(find.byTooltip('停止当前回复'));
      await tester.pumpAndSettle();
      expect(services.length, 1);
      expect(find.byTooltip('停止当前回复'), findsNothing);
      await send(tester, '重新开始');
      expect(services.length, 2);
      services.last.finish('重新收到');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'top character button opens the picker and keyboard keeps the composer visible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await openChat(tester, <_ControlledReply>[]);
      await tester.tap(find.byKey(const ValueKey('chat-character-switch')));
      await tester.pumpAndSettle();
      expect(find.text('切换角色'), findsOneWidget);
      expect(find.text('添加新角色'), findsOneWidget);
      Navigator.of(tester.element(find.text('切换角色'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byType(TextField)).dy,
        lessThanOrEqualTo(480),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _ControlledReply extends AiChatService {
  final _events = StreamController<AiStreamEvent>();
  List<ChatMessage> history = const [];

  @override
  Stream<AiStreamEvent> streamEvents({
    required ProviderProfile provider,
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    double temperature = 0.85,
    int contextTokenBudget = 0,
  }) {
    this.history = history;
    return _events.stream;
  }

  void finish(String text) {
    _events.add(
      AiStreamEvent(kind: AiStreamEventKind.content, text: '$text\n[[心绪:平静]]'),
    );
    unawaited(_events.close());
  }

  @override
  void close() {
    unawaited(_events.close());
    super.close();
  }
}
