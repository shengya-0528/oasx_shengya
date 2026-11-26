import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/taskitem_model.dart';

class _MemoryStorage implements HomeDashboardStorage {
  final values = <String, dynamic>{};
  @override
  dynamic read(String key) => values[key];
  @override
  void write(String key, dynamic value) => values[key] = value;
}

class _OfflineDashboard extends HomeDashboardController {
  _OfflineDashboard(HomeDashboardStorage storage) : super(storage: storage);
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeDashboardController dashboard;

  setUp(() {
    Get.testMode = true;
    dashboard = Get.put<HomeDashboardController>(_OfflineDashboard(_MemoryStorage()));
  });
  tearDown(() => Get.reset());

  test('enabledTaskNamesFor reads authoritative enables, not schedule membership', () {
    final model = ScriptModel('oas1');
    // Authoritative config: AreaBoss + Orochi on, Duel off.
    model.update(enabledTasks: {
      'AreaBoss': true,
      'Duel': false,
      'Orochi': true,
    });
    // The schedule snapshot says Duel is running and Whatever is pending;
    // neither fact may flip the checked state.
    model.update(
      runningTask: TaskItemModel('oas1', 'Duel', '2026-01-01 00:00:00'),
      pendingTaskList: [
        TaskItemModel('oas1', 'Whatever', '2026-01-01 00:00:00'),
      ],
    );

    final enabled = dashboard.enabledTaskNamesFor(model);
    expect(enabled, contains('AreaBoss'));
    expect(enabled, contains('Orochi'));
    expect(enabled, isNot(contains('Duel')));
    expect(enabled, isNot(contains('Whatever')));
  });

  test('authoritative enables are isolated per script and survive update', () {
    final a = ScriptModel('oas1');
    final b = ScriptModel('oas3');
    a.update(enabledTasks: {'AreaBoss': true});
    b.update(enabledTasks: {'Duel': true});

    a.update(enabledTasks: {'AreaBoss': false});
    expect(a.enabledTasks['AreaBoss'], isFalse);
    expect(b.enabledTasks['Duel'], isTrue);
    expect(dashboard.enabledTaskNamesFor(a), isEmpty);
    expect(dashboard.enabledTaskNamesFor(b), contains('Duel'));
  });

  test('update leaves enables untouched when not supplied', () {
    final model = ScriptModel('oas1');
    model.update(enabledTasks: {'AreaBoss': true});
    model.update(state: ScriptState.running);
    expect(model.enabledTasks['AreaBoss'], isTrue);
  });
}
