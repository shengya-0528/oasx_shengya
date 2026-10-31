import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/controllers/income_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';

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

class _FakeIncome extends HomeIncomeController {
  /// Snapshots served per day key.
  final Map<String, ScriptIncomeDay> days = {};

  /// Dates served by the fake backend, newest first.
  List<String> dates = const [];

  /// Failure thrown by every request when set.
  Object? failure;

  /// Number of date-list requests served.
  int dateCalls = 0;

  /// Number of day requests served.
  int dayCalls = 0;

  /// Baseline of the latest day request.
  int lastCompareDays = 1;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<ScriptIncomeDateList> fetchDates(String scriptName) async {
    dateCalls++;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return ScriptIncomeDateList(scriptName: scriptName, dates: dates);
  }

  @override
  Future<ScriptIncomeDay> fetchDay(
    String scriptName,
    String dateKey, {
    int compareDays = 1,
  }) async {
    dayCalls++;
    lastCompareDays = compareDays;
    final error = failure;
    if (error != null) {
      throw error;
    }
    final day = days[dateKey];
    if (day == null) {
      throw Exception('No income snapshot on $dateKey');
    }
    return day;
  }
}

ScriptIncomeDay day(
  String dateKey, {
  int gold = 0,
  int? delta,
  int? deltaFirst,
  int compareDays = 1,
}) {
  return ScriptIncomeDay.fromJson({
    'script_name': 'oas1',
    'date': dateKey,
    'first_dt': '$dateKey 03:00:00',
    'compare_days': compareDays,
    'items': [
      {
        'name': 'gold',
        'value': gold,
        'delta': delta,
        'delta_first': deltaFirst,
      },
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MemoryStorage storage;
  late HomeDashboardController dashboard;
  late _FakeIncome income;

  setUp(() {
    Get.testMode = true;
    storage = _MemoryStorage();
    dashboard = Get.put<HomeDashboardController>(_OfflineDashboard(storage));
    income = _FakeIncome();
    Get.put<HomeIncomeController>(income);
  });
  tearDown(() => Get.reset());

  test('binding loads the newest date of the active script', () async {
    income.dates = ['2026-10-18', '2026-10-17'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 120, deltaFirst: 20);
    dashboard.activeScriptName.value = 'oas1';

    await income.syncIncomeBinding();

    expect(income.availableDateKeys, ['2026-10-18', '2026-10-17']);
    expect(income.selectedDateKey.value, '2026-10-18');
    expect(income.income.value?.itemFor('gold')?.value, 120);
    expect(income.income.value?.itemFor('gold')?.deltaFirst, 20);
    expect(income.income.value?.itemFor('gold')?.hasValue, isTrue);
    expect(income.lastErrorMessage.value, isEmpty);
    expect(income.isLoading, isFalse);
  });

  test('no active config clears the panel', () async {
    income.dates = ['2026-10-18'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 5);
    dashboard.activeScriptName.value = 'oas1';
    await income.syncIncomeBinding();

    dashboard.activeScriptName.value = '';
    await income.syncIncomeBinding();

    expect(income.availableDateKeys, isEmpty);
    expect(income.selectedDateKey.value, isEmpty);
    expect(income.income.value, isNull);
    expect(income.lastErrorMessage.value, isEmpty);
  });

  test(
    'a failing backend surfaces its message instead of stale rows',
    () async {
      income.failure = Exception('Config not found: oas9');
      dashboard.activeScriptName.value = 'oas9';

      await income.syncIncomeBinding();

      expect(income.income.value, isNull);
      expect(income.lastErrorMessage.value, 'Config not found: oas9');
      expect(income.availableDateKeys, isEmpty);
      expect(income.isLoading, isFalse);
    },
  );

  test('selecting a date reloads only the day', () async {
    income.dates = ['2026-10-18', '2026-10-17'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 120);
    income.days['2026-10-17'] = day('2026-10-17', gold: 99);
    dashboard.activeScriptName.value = 'oas1';
    await income.syncIncomeBinding();
    expect(income.dateCalls, 1);

    income.selectDate('2026-10-17');
    await Future<void>.delayed(Duration.zero);

    expect(income.dateCalls, 1);
    expect(income.selectedDateKey.value, '2026-10-17');
    expect(income.income.value?.itemFor('gold')?.value, 99);
  });

  test('refresh keeps the selected date when it still exists', () async {
    income.dates = ['2026-10-18', '2026-10-17'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 120);
    income.days['2026-10-17'] = day('2026-10-17', gold: 99);
    dashboard.activeScriptName.value = 'oas1';
    await income.syncIncomeBinding();
    income.selectDate('2026-10-17');
    await Future<void>.delayed(Duration.zero);

    income.dates = ['2026-10-17'];
    await income.reload();

    expect(income.selectedDateKey.value, '2026-10-17');
    expect(income.income.value?.itemFor('gold')?.value, 99);
  });

  test('compare baseline starts at one day and reloads only the day', () async {
    income.dates = ['2026-10-18'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 120, delta: -30);
    dashboard.activeScriptName.value = 'oas1';
    await income.syncIncomeBinding();

    expect(income.compareDays.value, 1);
    expect(income.lastCompareDays, 1);

    income.selectCompareDays(7);
    await Future<void>.delayed(Duration.zero);

    expect(income.compareDays.value, 7);
    expect(income.lastCompareDays, 7);
    // 日期列表与基准无关，切基准不该重拉它
    expect(income.dateCalls, 1);
    expect(income.dayCalls, 2);
  });

  test('an unsupported baseline falls back to one day', () async {
    income.dates = ['2026-10-18'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 120);
    dashboard.activeScriptName.value = 'oas1';
    await income.syncIncomeBinding();

    income.selectCompareDays(30);
    await Future<void>.delayed(Duration.zero);

    expect(income.compareDays.value, 1);
    expect(income.lastCompareDays, 1);
  });

  test('a vanished date falls back to the newest one', () async {
    income.dates = ['2026-10-18', '2026-10-17'];
    income.days['2026-10-18'] = day('2026-10-18', gold: 120);
    income.days['2026-10-17'] = day('2026-10-17', gold: 99);
    dashboard.activeScriptName.value = 'oas1';
    await income.syncIncomeBinding();
    income.selectDate('2026-10-17');
    await Future<void>.delayed(Duration.zero);

    income.dates = ['2026-10-18'];
    await income.reload();

    expect(income.selectedDateKey.value, '2026-10-18');
    expect(income.income.value?.itemFor('gold')?.value, 120);
  });
}
