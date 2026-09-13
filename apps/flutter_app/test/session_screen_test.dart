import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('session screen exists and has create button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Session')),
          body: ListView(
            children: [
              TextField(key: const Key('date'), decoration: const InputDecoration(labelText: 'Date')),
              TextField(key: const Key('operator'), decoration: const InputDecoration(labelText: 'Operator')),
              TextField(key: const Key('site'), decoration: const InputDecoration(labelText: 'Site')),
              ElevatedButton(onPressed: () {}, child: const Text('Create')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('date')), findsOneWidget);
    expect(find.byKey(const Key('operator')), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });
}
