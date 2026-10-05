import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/widgets/linkable_text.dart';

void main() {
  testWidgets('a mention exposes a clickable username callback', (
    tester,
  ) async {
    String? tappedUsername;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkableText(
            text: 'Salut @alice et #entraide',
            onMentionTap: (username) => tappedUsername = username,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final rootSpan = richText.text as TextSpan;
    final mentionSpan = rootSpan.children!.whereType<TextSpan>().firstWhere(
      (span) => span.text == '@alice',
    );
    final hashtagSpan = rootSpan.children!.whereType<TextSpan>().firstWhere(
      (span) => span.text == '#entraide',
    );

    expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    expect(hashtagSpan.recognizer, isNull);

    (mentionSpan.recognizer! as TapGestureRecognizer).onTap!();
    expect(tappedUsername, 'alice');
  });
}
