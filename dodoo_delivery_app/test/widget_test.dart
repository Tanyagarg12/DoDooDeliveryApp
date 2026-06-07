import 'package:dodoo_delivery_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Rider auth screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const DodooRiderApp());

    expect(find.text('DoDoo Rider'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Verify OTP only'), findsOneWidget);
  });
}
