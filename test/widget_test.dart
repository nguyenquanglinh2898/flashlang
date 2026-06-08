import 'package:flutter_test/flutter_test.dart';

import 'package:flash_lang/app.dart';
import 'package:flash_lang/services/notification_service.dart';

void main() {
  testWidgets('FlashLang app starts on Home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      FlashLangApp(notificationService: NotificationService.instance),
    );

    await tester.pump();

    expect(find.text('FlashLang'), findsOneWidget);
  });
}
