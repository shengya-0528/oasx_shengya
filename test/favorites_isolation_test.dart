import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/common/models/storage_key.dart';

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

  late _MemoryStorage storage;
  late HomeDashboardController dashboard;
  final storeKey = StorageKey.homeFavoriteTaskNames.name;

  setUp(() {
    Get.testMode = true;
    storage = _MemoryStorage();
    dashboard = Get.put<HomeDashboardController>(_OfflineDashboard(storage));
    dashboard.initFavorites();
  });
  tearDown(() => Get.reset());

  test('favorites of different scripts are independent', () {
    dashboard.activeScriptName.value = 'oas1';
    dashboard.toggleFavoriteTask('Orochi', scriptName: 'oas1');
    dashboard.toggleFavoriteTask('Duel', scriptName: 'oas1');

    expect(dashboard.favoriteTaskNames, contains('Orochi'));
    expect(dashboard.favoriteTaskNames, contains('Duel'));

    dashboard.activeScriptName.value = 'oas3';
    expect(dashboard.favoriteTaskNames, isEmpty);

    dashboard.toggleFavoriteTask('Chess', scriptName: 'oas3');
    expect(dashboard.favoriteTaskNames, contains('Chess'));
    expect(dashboard.favoriteTaskNames, isNot(contains('Orochi')));

    dashboard.activeScriptName.value = 'oas1';
    expect(dashboard.favoriteTaskNames, contains('Orochi'));
    expect(dashboard.favoriteTaskNames, contains('Duel'));
    expect(dashboard.favoriteTaskNames, isNot(contains('Chess')));

    final decoded = jsonDecode(storage.values[storeKey] as String) as Map;
    expect(decoded['oas1'], contains('Orochi'));
    expect(decoded['oas3'], contains('Chess'));
  });

  test('toggling a row uses its own source script, not the stale active script', () {
    dashboard.activeScriptName.value = 'oas1';
    // The row belongs to oas3 while the active script is still oas1.
    dashboard.toggleFavoriteTask('Ninja', scriptName: 'oas3');

    expect(dashboard.favoriteTaskNames, isNot(contains('Ninja')));
    final decoded = jsonDecode(storage.values[storeKey] as String) as Map;
    expect(decoded['oas3'], contains('Ninja'));
    expect(decoded['oas1'], isNull);
  });

  test('legacy flat list migrates into the first active script on switch', () {
    Get.reset();
    Get.testMode = true;
    storage.values[storeKey] = jsonEncode(['Orochi', 'Duel']);
    dashboard = Get.put<HomeDashboardController>(_OfflineDashboard(storage));
    dashboard.initFavorites();

    dashboard.activeScriptName.value = 'oas1';
    expect(dashboard.favoriteTaskNames, contains('Orochi'));
    expect(dashboard.favoriteTaskNames, contains('Duel'));

    final decoded = jsonDecode(storage.values[storeKey] as String) as Map;
    expect(decoded['oas1'], contains('Orochi'));

    dashboard.activeScriptName.value = 'oas3';
    expect(dashboard.favoriteTaskNames, isEmpty);
  });
}
