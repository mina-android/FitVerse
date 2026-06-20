import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitverse/app.dart';

void main() {
  testWidgets('FitVerse app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FitVerseApp());

    // Verify the app starts without crashing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
