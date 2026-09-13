import 'package:core_photo/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app pumps with Core Photo title', (tester) async {
    await tester.pumpWidget(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:9'));
    expect(find.text('Core Photo'), findsWidgets); // AppBar + body
  });
}