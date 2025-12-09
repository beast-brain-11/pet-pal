// Basic PetPal widget test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:petpal/main.dart';

void main() {
  testWidgets('PetPal app initializes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const ProviderScope(child: PetPalApp()));

    // The app should build without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
