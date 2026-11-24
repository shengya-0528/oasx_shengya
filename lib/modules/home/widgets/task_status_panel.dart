import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/widgets/task_status_row.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Renders the overview task list for the active config workbench.
class TaskStatusPanel extends StatefulWidget {
  const TaskStatusPanel({
    super.key,
    required this.controller,
    required this.scriptModel,
    required this.canQuickScheduleTask,
    required this.onSetNextRun,
    required this.onQuickRun,
    required this.onQuickWait,
    required this.onEditTask,
    this.compact = false,
  });

  final HomeDashboardController controller;
  final ScriptModel scriptModel;
  final bool Function(String taskName) canQuickScheduleTask;
  final Future<void> Function(String taskName, String nextRun) onSetNextRun;
  final Future<void> Function(String taskName) onQuickRun;
  final Future<void> Function(String taskName, String nextRun) onQuickWait;
  final Future<void> Function(String taskName) onEditTask;
  final bool compact;

  @override
  State<TaskStatusPanel> createState() => _TaskStatusPanelState();
}

class _TaskStatusPanelState extends State<TaskStatusPanel> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _hiddenTaskIds = <String>{};

  @override
  void didUpdateWidget(covariant TaskStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptModel.name == widget.scriptModel.name) {
      return;
    }
    _clearLocalState();
    _scrollTaskListToTop();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dragPayload = widget.controller.activeDragPayload.value;
      final quickScheduleLocked = widget.controller.isBulkQuickScheduling;
      final rawTasks = _collectTasks(widget.scriptModel);
      _pruneHiddenTaskIds(rawTasks);
      final visibleTasks = rawTasks
          .where((task) => !_hiddenTaskIds.contains(task.rowId))
          .toList();
      return Column(
        children: [
          Expanded(
            child: visibleTasks.isEmpty
                ? Center(child: Text(I18n.homeNoTask.tr))
                : ListView.separated(
                    key: const PageStorageKey<String>('home-task-status-list'),
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: visibleTasks.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: widget.compact ? 4 : 10),
                    itemBuilder: (context, index) {
                      final task = visibleTasks[index];
                      return Obx(
                        () => TaskStatusRow(
                          key: ValueKey(task.rowId),
                          controller: widget.controller,
                          sourceScriptName: widget.scriptModel.name,
                          task: task,
                          canQuickSchedule: widget.canQuickScheduleTask(
                            task.name,
                          ),
                          canQuickWait: true,
                          quickScheduleLocked: quickScheduleLocked,
                          onSetNextRun: widget.onSetNextRun,
                          onQuickRun: widget.onQuickRun,
                          onQuickWait: widget.onQuickWait,
                          onEditTask: widget.onEditTask,
                          onDisableTask: _disableTask,
                          onDismissed: _markTaskHidden,
                          dragEnabled: widget.controller.canUseDesktopDragCopy,
                          swipeEnabled: !_isSwipeDisabled(task),
                          activeDragPayload: dragPayload,
                          compact: widget.compact,
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }

  /// Collects the current overview task snapshot from the active script model.
  ///
  /// Every pending and waiting task the backend reports is kept, including the
  /// ones scheduled for tomorrow or later; they are merged into a single time
  /// ordered queue so the whole upcoming plan stays visible.
  List<TaskStatusViewData> _collectTasks(ScriptModel model) {
    final running = <TaskStatusViewData>[];
    final runningName = model.runningTask.value.taskName.value.trim();
    if (runningName.isNotEmpty) {
      running.add(
        TaskStatusViewData(
          rowId: 'running::$runningName',
          name: runningName,
          type: TaskStatusType.running,
        ),
      );
    }
    final queued = <TaskStatusViewData>[
      for (final entry in model.pendingTaskList.indexed)
        if (entry.$2.taskName.value.trim().isNotEmpty)
          TaskStatusViewData(
            rowId: 'pending::${entry.$1}::${entry.$2.taskName.value.trim()}::'
                '${entry.$2.nextRun.value.trim()}',
            name: entry.$2.taskName.value.trim(),
            type: TaskStatusType.pending,
            timeText: entry.$2.nextRun.value.trim(),
          ),
      for (final entry in model.waitingTaskList.indexed)
        if (entry.$2.taskName.value.trim().isNotEmpty)
          TaskStatusViewData(
            rowId: 'waiting::${entry.$1}::${entry.$2.taskName.value.trim()}::'
                '${entry.$2.nextRun.value.trim()}',
            name: entry.$2.taskName.value.trim(),
            type: TaskStatusType.waiting,
            timeText: entry.$2.nextRun.value.trim(),
          ),
    ];
    queued.sort((a, b) {
      final left = DateTime.tryParse(a.timeText);
      final right = DateTime.tryParse(b.timeText);
      if (left == null && right == null) {
        return a.name.compareTo(b.name);
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return left.compareTo(right);
    });
    return [...running, ...queued];
  }

  /// Requests disabling one overview task across the current linker scope.
  Future<bool> _disableTask(String taskName) {
    return widget.controller.toggleTaskEnabled(
      scriptName: widget.scriptModel.name,
      taskName: taskName,
      enable: false,
    );
  }

  /// Returns whether the overview row must reject left-swipe interaction.
  bool _isSwipeDisabled(TaskStatusViewData task) {
    return widget.scriptModel.state.value == ScriptState.running &&
        task.type == TaskStatusType.running;
  }

  /// Records one task that already finished its left-slide removal animation.
  void _markTaskHidden(String rowId) {
    setState(() {
      _hiddenTaskIds.add(rowId);
    });
  }

  /// Clears local hidden-row state when the active config changes.
  void _clearLocalState() {
    _hiddenTaskIds.clear();
  }

  void _scrollTaskListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  /// Releases optimistic hidden rows once the backend snapshot no longer emits them.
  void _pruneHiddenTaskIds(List<TaskStatusViewData> tasks) {
    final activeIds = tasks.map((task) => task.rowId).toSet();
    final staleIds = _hiddenTaskIds
        .where((rowId) => !activeIds.contains(rowId))
        .toList();
    if (staleIds.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || staleIds.isEmpty) {
        return;
      }
      setState(() {
        _hiddenTaskIds.removeAll(staleIds);
      });
    });
  }
}
