part of args;

const _activityBattles = <String, String>{
  'rich_man': '大富翁',
  'exp_encounter': '遭遇战',
  'ap': '体力',
  'pass': '门票简单',
  'pass_hard': '门票困难',
  'ap100': '百体',
  'boss': '首领boss',
  'fakegod': '伪神',
};

class ActivitySettingsGroups extends StatefulWidget {
  const ActivitySettingsGroups({
    super.key,
    required this.args,
    required this.script,
    required this.task,
    required this.groupNames,
  });
  final Args args;
  final String script;
  final String task;
  final List<String> groupNames;

  @override
  State<ActivitySettingsGroups> createState() => _ActivitySettingsGroupsState();
}

class _ActivitySettingsGroupsState extends State<ActivitySettingsGroups> {
  String _soul = 'rich_man';
  String _battle = 'rich_man';

  @override
  void didUpdateWidget(covariant ActivitySettingsGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.script != widget.script || oldWidget.task != widget.task) {
      _soul = 'rich_man';
      _battle = 'rich_man';
    }
  }

  ExpansionTileItem section(
    String group,
    String title,
    List<Widget> children, {
    String? selection,
    ValueChanged<String>? onSelected,
    Map<String, String> options = _activityBattles,
  }) {
    return ExpansionTileItem(
      key: ValueKey('activity-${widget.script}-$title'),
      initiallyExpanded: true,
      isHasTopBorder: false,
      isHasBottomBorder: false,
      backgroundColor: widget.args._groupBackgroundColor(
        context,
        widget.script,
        widget.task,
        group,
      ),
      borderRadius: BorderRadius.circular(10),
      title: Row(
        children: [
          if (widget.args.groupDraggable)
            widget.args._buildGroupDragHandle(
              context,
              widget.script,
              widget.task,
              group,
            ),
          Text(title),
          if (selection != null) ...[
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: '选择具体任务',
              initialValue: selection,
              onSelected: onSelected,
              itemBuilder: (context) => options.entries
                  .map(
                    (entry) => PopupMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(options[selection] ?? selection),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      children: children,
    );
  }

  List<Widget> children(String group) => widget.args._children(
    groupName: group,
    selectedScript: widget.script,
    selectedTask: widget.task,
  );

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ArgsController>();
    final battleOptions = Map<String, String>.fromEntries(
      _activityBattles.entries.where(
        (entry) => widget.groupNames.contains('${entry.key}_battle_conf'),
      ),
    );
    if (!battleOptions.containsKey(_battle) && battleOptions.isNotEmpty) {
      _battle = battleOptions.keys.first;
    }
    final sections = <ExpansionTileItem>[];
    var addedBattle = false;
    for (final name in widget.groupNames) {
      if (name == 'switch_soul_config') {
        final model = controller.groupsData.value[name]!;
        final visible = <Widget>[const Divider()];
        for (var i = 0; i < model.members.length; i++) {
          final field = (model.members[i] as ArgumentModel).title;
          if (!{
            'enable_switch_$_soul',
            'enable_switch_${_soul}_by_name',
            '${_soul}_group_team',
            '${_soul}_group_team_name',
          }.contains(field)) {
            continue;
          }
          visible.add(
            ArgumentView(
              key: ValueKey('${widget.script}-$name-$field'),
              scriptName: widget.script,
              taskName: widget.task,
              getGroupName: model.getGroupName,
              index: i,
              setArgument:
                  widget.args.setArgumentOverride ?? controller.setArgument,
            ),
          );
        }
        sections.add(
          section(
            name,
            '切换御魂',
            visible,
            selection: _soul,
            onSelected: (value) => setState(() => _soul = value),
          ),
        );
      } else if (_activityBattles.keys.any(
        (key) => name == '${key}_battle_conf',
      )) {
        if (addedBattle) continue;
        addedBattle = true;
        final group = '${_battle}_battle_conf';
        sections.add(
          section(
            group,
            '战斗配置',
            children(group),
            selection: _battle,
            options: battleOptions,
            onSelected: (value) => setState(() => _battle = value),
          ),
        );
      } else {
        sections.add(section(name, name.tr, children(name)));
      }
    }
    return ExpansionTileGroup(spaceBetweenItem: 10, children: sections);
  }
}
