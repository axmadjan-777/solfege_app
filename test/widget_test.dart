import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/app.dart';

void main() {
  testWidgets('App shows Supabase config error when not configured', (tester) async {
    await tester.pumpWidget(const SolfegeApp());
    await tester.pumpAndSettle();

    expect(find.text('Supabase не настроен'), findsOneWidget);
  });
}
