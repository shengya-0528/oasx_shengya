import 'package:get/get.dart';
import 'package:oasx/modules/home/models/taskitem_model.dart';

enum ScriptState {
  inactive,
  running,
  warning,
  updating,
  ;

  static ScriptState getState(dynamic value) {
    return switch (value) {
      0 => inactive,
      1 => running,
      2 => warning,
      3 => updating,
      _ => inactive,
    };
  }
}

class ScriptModel {
  String name;
  final state = ScriptState.updating.obs;
  final runningTask = TaskItemModel('', '', '').obs;
  final pendingTaskList = <TaskItemModel>[].obs;
  final waitingTaskList = <TaskItemModel>[].obs;
  /// 权威的每任务 scheduler.enable，来自后端 schedule 快照的 enables 字段。
  /// 与 running/pending/waiting 无关：失败账本或未来 next_run 的任务也如实记 true。
  final enabledTasks = <String, bool>{}.obs;

  ScriptModel(this.name);

  void update(
      {ScriptState? state,
      TaskItemModel? runningTask,
      List<TaskItemModel>? pendingTaskList,
      List<TaskItemModel>? waitingTaskList,
      Map<String, bool>? enabledTasks}) {
    if (state != null && this.state.value != state) this.state.value = state;
    if (runningTask != null && this.runningTask.value != runningTask) {
      this.runningTask.value = runningTask;
    }
    if (pendingTaskList != null) this.pendingTaskList.value = pendingTaskList;
    if (waitingTaskList != null) this.waitingTaskList.value = waitingTaskList;
    if (enabledTasks != null) this.enabledTasks.assignAll(enabledTasks);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state.toJson(),
        'runningTask': runningTask.toJson(),
        'pendingTaskList': pendingTaskList.toJson(),
        'waitingTaskList': waitingTaskList.toJson(),
        'enabledTasks': Map<String, bool>.from(enabledTasks)
      };
}
