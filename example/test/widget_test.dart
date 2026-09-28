import 'package:flutter_test/flutter_test.dart';
import 'package:jj_callkit_example/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录页可以打开', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const JJCallApp());
    await tester.pump();
    expect(find.text('登录'), findsWidgets);
    expect(find.text('账号'), findsOneWidget);
  });
}
