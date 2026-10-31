part of args;

class ActivityGeneralSettings extends StatefulWidget {
  const ActivityGeneralSettings({
    super.key,
    required this.script,
    required this.task,
    required this.group,
    required this.onChanged,
  });
  final String script;
  final String task;
  final GroupsModel group;
  final SetArgumentCallback onChanged;

  @override
  State<ActivityGeneralSettings> createState() =>
      _ActivityGeneralSettingsState();
}

class _ActivityGeneralSettingsState extends State<ActivityGeneralSettings> {
  List<ArgumentModel> get members => widget.group.members.cast<ArgumentModel>();
  ArgumentModel? field(String name) =>
      members.firstWhereOrNull((m) => m.title == name);
  void save(String name, dynamic value) {
    final model = field(name);
    if (model == null) return;
    final controller = Get.find<ArgsController>();
    setState(() => model.value = value);
    if (controller.isDraftMode.value) {
      controller.stageArgumentChange(
        widget.group.groupName,
        name,
        value,
        model.type,
      );
    } else {
      widget.onChanged(
        widget.script,
        widget.task,
        widget.group.groupName,
        name,
        model.type,
        value,
      );
    }
  }

  Widget input(String name, {String? label}) {
    final index = members.indexWhere((m) => m.title == name);
    if (index < 0) return const SizedBox.shrink();
    return ArgumentView(
      key: ValueKey(name),
      index: index,
      scriptName: widget.script,
      taskName: widget.task,
      getGroupName: widget.group.getGroupName,
      setArgument: widget.onChanged,
      compact: true,
      label: label,
    );
  }

  Widget passInput(int index, String label) {
    final values = (field('pass_limit')?.value.toString() ?? '0').split(',');
    return Row(
      children: [
        Text('$label：'),
        const SizedBox(width: 6),
        Expanded(
          child: TextFormField(
            key: ValueKey('pass-$index-${widget.script}'),
            initialValue: index < values.length ? values[index] : '0',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: true,
              errorText: Get.find<ArgsController>().fieldError(
                widget.group.groupName,
                'pass_limit',
              ),
            ),
            onChanged: (value) {
              final next = (field('pass_limit')?.value.toString() ?? '0').split(
                ',',
              );
              while (next.length < 2) {
                next.add('0');
              }
              next[index] = value.isEmpty ? '0' : value;
              save('pass_limit', next.join(','));
            },
          ),
        ),
      ],
    );
  }

  Widget pair(Widget left, Widget right) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    ),
  );

  Widget mode(String title, Widget content) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Text(title),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: content),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const handled = {
      'task_sequence',
      'climb_task_sequence',
      'throw_limit',
      'ap_limit',
      'ap100_limit',
      'pass_limit',
      'boss_limit',
      'fakegod_limit',
    };
    final remaining = members.where((m) => !handled.contains(m.title)).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ActivitySequenceBoard(
            title: '任务启用项',
            options: const ['探索', '大富翁', '伪神', '爬塔', '首领boss'],
            value: ArgumentModel.normalizeMultiEnumValue(
              field('task_sequence')?.value,
            ),
            onChanged: (value) => save('task_sequence', value),
          ),
          const SizedBox(height: 16),
          if (field('climb_task_sequence') != null)
            ActivitySequenceBoard(
              title: '爬塔启用项',
              options: const ['体力', '简单', '困难', '百体'],
              value: ArgumentModel.normalizeMultiEnumValue(
                field('climb_task_sequence')?.value,
              ),
              onChanged: (value) => save('climb_task_sequence', value),
            ),
          const SizedBox(height: 16),
          mode('大富翁', input('throw_limit', label: '投掷次数')),
          mode(
            '爬塔',
            Column(
              children: [
                pair(
                  input('ap_limit', label: '体力'),
                  input('ap100_limit', label: '百体'),
                ),
                pair(passInput(0, '简单'), passInput(1, '困难')),
              ],
            ),
          ),
          mode('伪神', input('fakegod_limit', label: '行动次数')),
          mode('首领boss', input('boss_limit', label: '挑战次数')),
          const Divider(),
          for (var i = 0; i < remaining.length; i += 2)
            pair(
              input(remaining[i].title),
              i + 1 < remaining.length
                  ? input(remaining[i + 1].title)
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class ActivitySequenceBoard extends StatefulWidget {
  const ActivitySequenceBoard({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final List<String> options;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  @override
  State<ActivitySequenceBoard> createState() => _ActivitySequenceBoardState();
}

class _ActivitySequenceBoardState extends State<ActivitySequenceBoard> {
  final GlobalKey _listKey = GlobalKey();
  Offset? _dragPosition;
  List<String> get selected => widget.value;
  Widget tile(String name, {bool placeholder = false}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: placeholder
            ? colors.surfaceContainerHighest.withValues(alpha: .3)
            : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!placeholder)
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.drag_indicator, size: 16),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(name, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget draggable(
    String name, {
    required bool active,
  }) => LongPressDraggable<String>(
    key: ValueKey('${widget.title}-$name-$active'),
    data: name,
    feedback: DragCopyFeedback(label: name),
    childWhenDragging: Opacity(opacity: .25, child: tile(name)),
    onDragStarted: () => _dragPosition = null,
    onDragUpdate: (details) => _dragPosition = details.globalPosition,
    onDragEnd: (details) {
      if (!active || details.wasAccepted) return;
      final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      // The pointer, rather than the feedback's top left, defines a drop outside.
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      if (!bounds.contains(_dragPosition ?? details.offset)) {
        widget.onChanged(selected.where((item) => item != name).toList());
      }
    },
    child: tile(name),
  );

  Widget dropSlot(int index, Widget child) => DragTarget<String>(
    onWillAcceptWithDetails: (details) => widget.options.contains(details.data),
    onAcceptWithDetails: (details) {
      final next = [...selected];
      next.remove(details.data);
      final target = index.clamp(0, next.length);
      next.insert(target, details.data);
      widget.onChanged(next);
    },
    builder: (context, candidates, rejected) => Container(
      key: ValueKey(index < selected.length ? selected[index] : 'empty'),
      color: candidates.isEmpty
          ? Colors.transparent
          : Theme.of(context).colorScheme.primary.withValues(alpha: .12),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = selected;
    return SizedBox(
      height: 20 + widget.options.length * 38.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title),
                const SizedBox(height: 8),
                for (var row = 0; row < (widget.options.length + 1) ~/ 2; row++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        for (var col = 0; col < 2; col++) ...[
                          if (col > 0) const SizedBox(width: 6),
                          Expanded(
                            child: row * 2 + col >= widget.options.length
                                ? const SizedBox.shrink()
                                : enabled.contains(
                                    widget.options[row * 2 + col],
                                  )
                                ? tile(
                                    widget.options[row * 2 + col],
                                    placeholder: true,
                                  )
                                : draggable(
                                    widget.options[row * 2 + col],
                                    active: false,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              key: _listKey,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < enabled.length; i++)
                    dropSlot(
                      i,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: draggable(enabled[i], active: true),
                      ),
                    ),
                  Expanded(
                    child: dropSlot(enabled.length, const SizedBox.expand()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
