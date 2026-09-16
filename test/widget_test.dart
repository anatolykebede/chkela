import 'package:chkela/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ChkelaApp(),
      ),
    );

    expect(find.text('LEADERBOARD'), findsOneWidget);
    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
  });
}
