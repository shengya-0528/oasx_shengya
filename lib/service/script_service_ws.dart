part of 'script_service.dart';

extension ScriptServiceWsX on ScriptService {
  Future<void> connectScript(String name) async {
    if (!scriptModelMap.containsKey(name)) {
      addScriptModel(name);
    }
    wsService.removeAllListeners(name);
    final client = await wsService.connect(
      name: name,
      listener: (mg) => wsListener(mg, name),
    );
    client.status.listen(
      (wsStatus) => scriptModelMap[name]?.update(state: wsStatus.scriptState),
    );
  }

  Future<void> startScript(String name) async {
    if (!scriptModelMap.containsKey(name)) return;
    if (isRunning(name)) return;
    await connectScript(name);
    await wsService.send(name, 'start');
  }

  void wsListener(dynamic message, String name) {
    if (message is! String) {
      printError(info: 'Websocket push data is not of type string and map');
      return;
    }
    if (!message.startsWith('{') || !message.endsWith('}')) {
      return;
    }
    final data = jsonDecode(message) as Map<String, dynamic>;
    if (data.containsKey('state')) {
      scriptModelMap[name]!.update(state: ScriptState.getState(data['state']));
      return;
    }
    if (!data.containsKey('schedule')) {
      return;
    }

    final schedule = data['schedule'] as Map<String, dynamic>;
    final run = schedule['running'] as Map;
    final pending = schedule['pending'] as List<dynamic>;
    final waiting = schedule['waiting'] as List<dynamic>;
    final runningTask = run.isNotEmpty
        ? TaskItemModel(name, run['name'], run['next_run'])
        : TaskItemModel.empty();
    final pendingList = pending
        .map((e) => TaskItemModel(name, e['name'], e['next_run']))
        .toList();
    final waitingList = waiting
        .map((e) => TaskItemModel(name, e['name'], e['next_run']))
        .toList();

    // 权威 enable：优先用后端下发的 enables 映射。旧后端没有该字段时
    // 退回从 running/pending/waiting 推断，保证向后兼容。
    Map<String, bool>? enables;
    final rawEnables = schedule['enables'];
    if (rawEnables is Map) {
      enables = <String, bool>{};
      rawEnables.forEach((key, value) {
        var flag = false;
        if (value is bool) {
          flag = value;
        } else if (value is num) {
          flag = value != 0;
        } else if (value is String) {
          flag = value.toLowerCase() == 'true' || value == '1';
        }
        enables![key.toString()] = flag;
      });
    } else {
      final inferred = <String, bool>{};
      for (final task in [runningTask, ...pendingList, ...waitingList]) {
        final taskName = task.taskName.value.trim();
        if (taskName.isNotEmpty) inferred[taskName] = true;
      }
      enables = inferred;
    }

    scriptModelMap[name]!.update(
      runningTask: runningTask,
      pendingTaskList: pendingList,
      waitingTaskList: waitingList,
      enabledTasks: enables,
    );
  }

  Future<void> stopScript(String name) async {
    if (!scriptModelMap.containsKey(name)) return;
    await wsService.send(name, 'stop');
  }
}
