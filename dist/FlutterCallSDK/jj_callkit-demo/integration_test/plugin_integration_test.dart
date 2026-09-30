import 'package:flutter_test/flutter_test.dart';
import 'package:jj_callkit/jj_callkit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('error description is available without a call', () {
    expect(JJCallKit.errorDescription(-302), isNotEmpty);
  });
}
