import 'package:character_chat_app/models/character_profile.dart';
import 'package:character_chat_app/models/provider_profile.dart';
import 'package:character_chat_app/widgets/chat_picker_sheets.dart';
import 'package:character_chat_app/widgets/group_conversation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const provider = ProviderProfile(
    id: 'provider',
    name: 'Provider',
    protocol: ProviderProtocol.openAiCompatible,
    baseUrl: 'https://example.com/v1',
    models: ['model-a'],
    selectedModel: 'model-a',
  );

  testWidgets('model picker returns manage action after the sheet closes', (
    tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final resultFuture = showChatModelPickerSheet(
      context: pageContext,
      providers: const [provider],
      selectedProvider: provider,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('管理供应商'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isA<ManageProvidersSelection>());
  });

  testWidgets('model picker returns the selected model', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final resultFuture = showChatModelPickerSheet(
      context: pageContext,
      providers: const [provider],
      selectedProvider: provider,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('model-a'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result, isA<ChatModelSelection>());
    expect((result! as ChatModelSelection).choice.model, 'model-a');
  });

  testWidgets('group sheet returns chosen members and title after closing', (
    tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
    final characters = [
      CharacterProfile.lin(DateTime.utc(2026, 1, 1)),
      CharacterProfile.newCharacter(DateTime.utc(2026, 1, 2)),
    ];
    final resultFuture = showGroupConversationSheet(
      context: pageContext,
      characters: characters,
      moodForCharacter: (_) => '',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我的群聊');
    await tester.tap(find.text('创建群聊').last);
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.title, '我的群聊');
    expect(result?.participantIds, characters.map((item) => item.id).toList());
    expect(tester.takeException(), isNull);
  });
}
