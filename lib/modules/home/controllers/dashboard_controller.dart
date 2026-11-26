import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/models/config_drag_payload.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/service/locale_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';
import 'package:oasx/utils/time_utils.dart';
import 'package:oasx/modules/args/index.dart';
import 'package:oasx/modules/server/index.dart';

part 'dashboard_controller_linking.dart';
part 'dashboard_controller_drag_copy.dart';
part 'dashboard_controller_layout.dart';
part 'dashboard_controller_startup.dart';
part 'dashboard_controller_workspace.dart';

/// Abstracts dashboard persistence so tests can avoid platform storage.
abstract class HomeDashboardStorage {
  /// Reads one persisted value.
  dynamic read(String key);

  /// Writes one persisted value.
  void write(String key, dynamic value);
}

/// Default storage backed by GetStorage.
class GetStorageHomeDashboardStorage implements HomeDashboardStorage {
  /// Creates one GetStorage-backed adapter.
  GetStorageHomeDashboardStorage() : _storage = GetStorage();

  /// Underlying persistent store.
  final GetStorage _storage;

  @override
  dynamic read(String key) {
    return _storage.read(key);
  }

  @override
  void write(String key, dynamic value) {
    _storage.write(key, value);
  }
}

/// Defines the visible dashboard health state for a script.
enum HomeScriptStateFilter { all, running, abnormal, stopped, offline }

/// Defines the visible page when the workbench collapses to a single pane.
enum HomeWorkbenchPage { scripts, workspace }

/// Defines the visible home workbench tab for the active script.
enum HomeWorkbenchTab { status, tasks, logs, stats, analysis, assets }

/// Returns whether the tab belongs to the right desktop sidebar.
bool isHomeWorkbenchSidebarTab(HomeWorkbenchTab value) {
  return value == HomeWorkbenchTab.stats ||
      value == HomeWorkbenchTab.logs ||
      value == HomeWorkbenchTab.analysis ||
      value == HomeWorkbenchTab.assets;
}

/// Records which workbench tab opened the task parameter editor.
enum HomeTaskParameterEntrySource { overview, tasks }

/// Defines the task catalog filter shown in the active script workspace.
enum HomeTaskCatalogFilter { all, enabled, disabled }

/// Defines the active bulk quick schedule operation, if any.
enum HomeBulkQuickScheduleMode { none, runNow, waitNow }

/// Describes how a bulk quick schedule request finished.
enum HomeBulkQuickScheduleResult { completed, failed, skipped, timedOut }

/// Returns the visible workbench tabs for the active layout mode.
List<HomeWorkbenchTab> resolveHomeWorkbenchTabs(HomeWorkbenchLayoutMode mode) {
  if (mode == HomeWorkbenchLayoutMode.threePane) {
    return const [HomeWorkbenchTab.status, HomeWorkbenchTab.tasks];
  }
  return const [
    HomeWorkbenchTab.status,
    HomeWorkbenchTab.tasks,
    HomeWorkbenchTab.logs,
    HomeWorkbenchTab.stats,
    HomeWorkbenchTab.analysis,
  ];
}

/// Returns the visible right-sidebar tabs for the active layout mode.
List<HomeWorkbenchTab> resolveHomeWorkbenchSidebarTabs(
  HomeWorkbenchLayoutMode mode,
) {
  if (mode != HomeWorkbenchLayoutMode.threePane) {
    return const [];
  }
  return const [
    HomeWorkbenchTab.logs,
    HomeWorkbenchTab.stats,
    HomeWorkbenchTab.analysis,
    HomeWorkbenchTab.assets,
  ];
}

class HomeDashboardController extends GetxController {
  HomeDashboardController({HomeDashboardStorage? storage})
    : _storage = storage ?? GetStorageHomeDashboardStorage();

  final HomeDashboardStorage _storage;
  static bool _hasCheckedStartupConnection = false;
  Worker? _workspaceSyncWorker;
  final controlScriptList = <String>[].obs;
  final isBatchSwitching = false.obs;

  /// Current bulk quick schedule state for the active config workbench.
  final bulkQuickScheduleMode = HomeBulkQuickScheduleMode.none.obs;
  final isStartupChecking = false.obs;
  final isStartupConnectionFailed = false.obs;
  final isStartupAutoDeploying = false.obs;
  final startupLoadingMessage = ''.obs;
  final isLinkModeEnabled = false.obs;
  final linkedScriptList = <String>[].obs;
  final searchQuery = ''.obs;
  final stateFilter = HomeScriptStateFilter.all.obs;
  final activeScriptName = ''.obs;
  final selectedScriptList = <String>[].obs;
  final workbenchPage = HomeWorkbenchPage.scripts.obs;
  final workbenchCollectionWidth = kHomeWorkbenchDefaultCollectionWidth.obs;
  final workbenchSplitRatio = kHomeWorkbenchDefaultSplitRatio.obs;
  final workbenchLayoutMode = HomeWorkbenchLayoutMode.singlePane.obs;
  final activeWorkbenchTab = HomeWorkbenchTab.status.obs;
  final _lastPrimaryWorkbenchTab = HomeWorkbenchTab.status.obs;
  final activeWorkbenchSidebarTab = HomeWorkbenchTab.logs.obs;
  final taskCatalogFilter = HomeTaskCatalogFilter.all.obs;
  final activeTaskName = ''.obs;
  final activeDragPayload = Rxn<ConfigDragPayload>();
  final pendingDragCopyTargets = <String>[].obs;
  final _taskParameterEntrySource = Rxn<HomeTaskParameterEntrySource>();
  final _taskAvailabilityCache = <String, bool>{};

  /// Favorites grouped by script name, persisted as one JSON object.
  final RxMap<String, List<String>> _favoritesByScript =
      <String, List<String>>{}.obs;

  /// Favorites of the currently displayed script.
  ///
  /// Kept in sync with [activeScriptName] so catalog widgets can simply read
  /// `.contains(...)` inside Obx and stay reactive across script switches.
  final favoriteTaskNames = <String>[].obs;
  Worker? _favoriteMirrorWorker;

  /// Legacy global favorites from pre-isolation builds; migrated into the
  /// first script that becomes active so existing picks are not lost.
  List<String>? _pendingLegacyFavorites;

  /// Consecutive "wait now" clicks per task, so repeated clicks stack.
  final quickWaitClicks = <String, QuickWaitClick>{};

  ScriptService get _scriptService => Get.find<ScriptService>();

  @override
  void onInit() {
    _loadSelection();
    initFavorites();
    _loadWorkbenchCollectionWidth();
    _loadWorkbenchSplitRatio();
    syncWorkspaceState();
    _workspaceSyncWorker = everAll(
      [_scriptService.scriptOrderList, _scriptService.scriptModelMap],
      (_) {
        syncWorkspaceState();
      },
    );
    super.onInit();
  }

  @override
  void onClose() {
    _workspaceSyncWorker?.dispose();
    _workspaceSyncWorker = null;
    _favoriteMirrorWorker?.dispose();
    _favoriteMirrorWorker = null;
    super.onClose();
  }

  void setControlScripts(Iterable<String> scripts) {
    final normalized =
        scripts.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
          ..sort();
    controlScriptList.value = normalized;
    _storage.write(
      StorageKey.homeControlScriptList.name,
      jsonEncode(controlScriptList.toList()),
    );
  }

  void _loadSelection() {
    final raw = _storage.read(StorageKey.homeControlScriptList.name);
    if (raw == null) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      setControlScripts(decoded.map((e) => e.toString()));
    } catch (_) {}
  }

  /// Loads persisted favorites and wires the active-script mirror. Kept as a
  /// separate method so offline tests can initialize favorites without running
  /// the full production [onInit].
  void initFavorites() {
    _loadFavorites();
    _syncFavoriteMirror();
    _favoriteMirrorWorker?.dispose();
    _favoriteMirrorWorker = ever(
      activeScriptName,
      (_) => _syncFavoriteMirror(),
    );
  }

  /// Loads persisted favorites. The current format is a JSON object keyed by
  /// script name; legacy builds stored a bare JSON list, which is kept as
  /// [_pendingLegacyFavorites] and migrated into the first active script.
  void _loadFavorites() {
    final raw = _storage.read(StorageKey.homeFavoriteTaskNames.name);
    if (raw is! String || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is! List) {
            return;
          }
          final names = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            _favoritesByScript[key.toString()] = names;
          }
        });
        return;
      }
      if (decoded is List) {
        _pendingLegacyFavorites = decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } catch (_) {}
  }

  /// Mirrors the active script's favorites into [favoriteTaskNames] so catalog
  /// widgets reading `.contains(...)` inside Obx stay reactive on switch.
  void _syncFavoriteMirror() {
    final script = activeScriptName.value.trim();
    if (script.isEmpty) {
      favoriteTaskNames.clear();
      return;
    }
    var names = _favoritesByScript[script];
    if (names == null && _pendingLegacyFavorites != null) {
      names = List<String>.from(_pendingLegacyFavorites!);
      _favoritesByScript[script] = names;
      _pendingLegacyFavorites = null;
      _persistFavorites();
    }
    favoriteTaskNames.assignAll(names ?? const <String>[]);
  }

  /// Persists the whole per-script favorites map as one JSON object.
  void _persistFavorites() {
    _storage.write(
      StorageKey.homeFavoriteTaskNames.name,
      jsonEncode(Map<String, List<String>>.from(_favoritesByScript)),
    );
  }

  /// Adds or removes one task from [scriptName]'s favorites group and persists.
  /// The catalog passes its own source script so a favorite always lands on the
  /// script the row belongs to, never on a stale active-script value.
  void toggleFavoriteTask(String taskName, {String? scriptName}) {
    final name = taskName.trim();
    if (name.isEmpty) {
      return;
    }
    final script = (scriptName ?? activeScriptName.value).trim();
    if (script.isEmpty) {
      return;
    }
    final next = List<String>.from(_favoritesByScript[script] ?? const <String>[]);
    if (!next.remove(name)) {
      next.add(name);
    }
    _favoritesByScript[script] = next;
    _persistFavorites();
    if (script == activeScriptName.value.trim()) {
      favoriteTaskNames.assignAll(next);
    }
  }

  bool isAllControlScriptsRunning() {
    final scripts = validControlScripts;
    if (scripts.isEmpty) {
      return false;
    }
    return scripts.every(
      (name) =>
          _scriptService.scriptModelMap.containsKey(name) &&
          _scriptService.isRunning(name),
    );
  }

  Future<void> toggleAllControlScripts(bool enable) async {
    if (isBatchSwitching.value) {
      return;
    }
    final scripts = validControlScripts;
    if (scripts.isEmpty) {
      return;
    }

    isBatchSwitching.value = true;
    try {
      if (enable) {
        for (final name in scripts) {
          await _scriptService.startScript(name);
        }
      } else {
        for (final name in scripts) {
          await _scriptService.stopScript(name);
        }
      }
    } finally {
      isBatchSwitching.value = false;
    }
  }

  List<String> get validControlScripts => controlScriptList
      .where((name) => _scriptService.scriptModelMap.containsKey(name))
      .toList();

  int get validControlScriptCount => validControlScripts.length;
}
