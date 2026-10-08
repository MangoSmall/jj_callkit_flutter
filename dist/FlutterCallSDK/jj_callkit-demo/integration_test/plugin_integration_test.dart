import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jj_callkit/jj_callkit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('error description is available without a call', (tester) async {
    expect(JJCallKit.errorDescription(-302), isNotEmpty);
  });
}
