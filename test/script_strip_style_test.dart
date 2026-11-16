import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/config/theme.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/widgets/config_state_indicator.dart';

void main() {
  test('design colors keep the requested hex values', () {
    expect(scriptTabActiveBorderColor.toARGB32(), 0xFF5C93ED);
    expect(scriptErrorColor.toARGB32(), 0xFFFE0356);
  });

  testWidgets('abnormal script state paints the error dot red', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfigStateIndicator(
            state: HomeScriptStateFilter.abnormal,
            size: 16,
          ),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, scriptErrorColor);
    expect(icon.size, 16);
    final box = tester.getSize(find.byType(ConfigStateIndicator));
    expect(box, const Size(28, 28));
  });

  testWidgets('stopped script state stays neutral grey', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfigStateIndicator(state: HomeScriptStateFilter.stopped),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, Colors.grey);
  });
}
