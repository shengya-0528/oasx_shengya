import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';

/// Drives the income (资产) panel for the active script.
class HomeIncomeController extends GetxController {
  /// Compare baselines offered by the panel header, in menu order.
  static const List<int> compareDayOptions = <int>[1, 3, 7];

  /// Dashboard controller used to resolve the active script.
  final HomeDashboardController dashboardController =
      Get.find<HomeDashboardController>();

  /// Every date that has an income snapshot for the active script.
  final availableDateKeys = <String>[].obs;

  /// Date currently selected in the header control.
  final selectedDateKey = ''.obs;

  /// Snapshot currently rendered by the panel.
  final income = Rxn<ScriptIncomeDay>();

  /// Baseline rule of the rendered change: `1` / `3` / `7` days before.
  final compareDays = 1.obs;

  /// Whether the available dates list is loading.
  final datesLoading = false.obs;

  /// Whether one selected-date snapshot request is loading.
  final incomeLoading = false.obs;

  /// Latest user-visible error message.
  final lastErrorMessage = ''.obs;

  /// Worker that keeps the panel bound to the active script.
  Worker? _dashboardWorker;

  /// Script currently bound by the panel.
  String _boundScriptName = '';

  /// Sequence used to invalidate stale date-list work.
  int _bindingRevision = 0;

  /// Sequence used to invalidate stale day work.
  int _dayRevision = 0;

  /// Whether the panel is waiting for any request.
  bool get isLoading => datesLoading.value || incomeLoading.value;

  /// Fetches every date that has an income snapshot.
  ///
  /// Overridden by tests so the panel can be driven without a live backend.
  Future<ScriptIncomeDateList> fetchDates(String scriptName) {
    return ApiClient().getScriptIncomeDates(scriptName);
  }

  /// Fetches one day snapshot with the given compare baseline.
  ///
  /// Overridden by tests so the panel can be driven without a live backend.
  Future<ScriptIncomeDay> fetchDay(
    String scriptName,
    String dateKey, {
    int compareDays = 1,
  }) {
    return ApiClient().getScriptIncomeDay(
      scriptName,
      dateKey,
      compareDays: compareDays,
    );
  }

  @override
  void onInit() {
    _dashboardWorker = ever<String>(
      dashboardController.activeScriptName,
      (_) => unawaited(syncIncomeBinding()),
    );
    unawaited(syncIncomeBinding());
    super.onInit();
  }

  @override
  void onClose() {
    _dashboardWorker?.dispose();
    _dashboardWorker = null;
    super.onClose();
  }

  /// Binds the panel to the active script, reloading when it changed.
  Future<void> syncIncomeBinding() async {
    final scriptName = dashboardController.activeScriptName.value.trim();
    if (scriptName.isEmpty) {
      _bindingRevision++;
      _dayRevision++;
      _boundScriptName = '';
      availableDateKeys.clear();
      selectedDateKey.value = '';
      income.value = null;
      lastErrorMessage.value = '';
      return;
    }
    if (_boundScriptName == scriptName && availableDateKeys.isNotEmpty) {
      return;
    }
    _boundScriptName = scriptName;
    await _loadDates(scriptName, keepSelection: false);
  }

  /// Reloads the date list and the selected day, keeping the day when it exists.
  ///
  /// Named `reload` instead of `refresh` on purpose: `GetxController` already
  /// defines `refresh()` as a notifier broadcast, so overriding it would break
  /// the reactive plumbing for every listener of this controller.
  Future<void> reload() async {
    final scriptName = dashboardController.activeScriptName.value.trim();
    if (scriptName.isEmpty) {
      return;
    }
    _boundScriptName = scriptName;
    await _loadDates(scriptName, keepSelection: true);
  }

  /// Selects one date and loads its snapshot.
  void selectDate(String dateKey) {
    final key = dateKey.trim();
    if (key.isEmpty) {
      return;
    }
    selectedDateKey.value = key;
    unawaited(_loadSelectedDay());
  }

  /// Switches the change baseline (`1` / `3` / `7` days before) and reloads
  /// only the day, because the date list does not depend on it.
  void selectCompareDays(int days) {
    final normalized = compareDayOptions.contains(days) ? days : 1;
    if (compareDays.value == normalized) {
      return;
    }
    compareDays.value = normalized;
    unawaited(_loadSelectedDay());
  }

  /// Loads the available dates, then the selected day.
  Future<void> _loadDates(
    String scriptName, {
    required bool keepSelection,
  }) async {
    final revision = ++_bindingRevision;
    datesLoading.value = true;
    lastErrorMessage.value = '';
    try {
      final list = await fetchDates(scriptName);
      if (revision != _bindingRevision || scriptName != _boundScriptName) {
        return;
      }
      availableDateKeys.assignAll(list.dates);
      final previous = selectedDateKey.value;
      if (keepSelection && list.dates.contains(previous)) {
        selectedDateKey.value = previous;
      } else {
        selectedDateKey.value = list.dates.isEmpty ? '' : list.dates.first;
      }
      if (selectedDateKey.value.isEmpty) {
        income.value = null;
        return;
      }
    } catch (error) {
      if (revision != _bindingRevision) {
        return;
      }
      availableDateKeys.clear();
      selectedDateKey.value = '';
      income.value = null;
      lastErrorMessage.value = _describeError(error);
      return;
    } finally {
      if (revision == _bindingRevision) {
        datesLoading.value = false;
      }
    }
    await _loadSelectedDay();
  }

  /// Loads the snapshot of the currently selected date.
  Future<void> _loadSelectedDay() async {
    final scriptName = _boundScriptName;
    final dateKey = selectedDateKey.value.trim();
    if (scriptName.isEmpty || dateKey.isEmpty) {
      income.value = null;
      return;
    }
    final revision = ++_dayRevision;
    incomeLoading.value = true;
    lastErrorMessage.value = '';
    try {
      final day = await fetchDay(
        scriptName,
        dateKey,
        compareDays: compareDays.value,
      );
      if (revision != _dayRevision || scriptName != _boundScriptName) {
        return;
      }
      income.value = day;
    } catch (error) {
      if (revision != _dayRevision) {
        return;
      }
      income.value = null;
      lastErrorMessage.value = _describeError(error);
    } finally {
      if (revision == _dayRevision) {
        incomeLoading.value = false;
      }
    }
  }

  /// Strips the exception prefix so the panel can render the backend hint.
  String _describeError(Object error) {
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }
}
