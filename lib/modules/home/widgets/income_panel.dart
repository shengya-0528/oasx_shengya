import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/income_controller.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';
import 'package:oasx/modules/home/widgets/income_formatters.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kIncomePanelPadding = 12.0;
const _kIncomeSectionSpacing = 12.0;
const _kIncomeCardHeight = 64.0;
const _kIncomeCardMaxWidth = 260.0;
const _kIncomeCardGap = 8.0;
const _kIncomeIconSize = 30.0;
const _kIncomeDropdownBorderRadius = 10.0;
const _kIncomeDropdownHorizontalPadding = 10.0;
const _kIncomeDateMenuMaxVisibleItems = 6;

/// Main income (资产) tab content for the active script.
///
/// One card per resource shows the amount read from the last snapshot of the
/// selected day plus its change against the chosen baseline (1 / 3 / 7 days
/// before), so a long-running script can be watched without opening the game UI.
class ScriptIncomePanel extends StatelessWidget {
  /// Creates the income panel.
  const ScriptIncomePanel({super.key});

  /// Income controller resolved from the home binding.
  HomeIncomeController get controller => Get.find<HomeIncomeController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final day = controller.income.value;
      final availableDates =
          controller.availableDateKeys.toList(growable: false);
      if (day == null) {
        return _IncomePlaceholder(
          label: _placeholderLabel(),
          message: _placeholderMessage(),
          loading: _placeholderIsLoading(),
        );
      }
      final items = _orderedItems(day);
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          _kIncomePanelPadding,
          _kIncomeSectionSpacing,
          _kIncomePanelPadding,
          _kIncomeSectionSpacing,
        ),
        children: [
          _IncomeHeader(
            day: day,
            availableDates: availableDates,
            selectedDateKey: controller.selectedDateKey.value,
            onSelected: controller.selectDate,
            onRefresh: controller.isLoading
                ? null
                : () => unawaited(controller.reload()),
            compareDays: controller.compareDays.value,
            onCompare: controller.selectCompareDays,
          ),
          const SizedBox(height: _kIncomeSectionSpacing),
          if (items.isEmpty)
            _IncomeEmptyCard(message: I18n.incomeEmpty.tr)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _kIncomeCardMaxWidth,
                    mainAxisExtent: _kIncomeCardHeight,
                    crossAxisSpacing: _kIncomeCardGap,
                    mainAxisSpacing: _kIncomeCardGap,
                  ),
              itemCount: items.length,
              itemBuilder: (context, index) => _IncomeCard(item: items[index]),
            ),
        ],
      );
    });
  }

  /// Returns the placeholder title for the current controller state.
  String _placeholderLabel() {
    if (controller.datesLoading.value || controller.incomeLoading.value) {
      return I18n.incomeLoading.tr;
    }
    if (controller.lastErrorMessage.value.isNotEmpty) {
      return I18n.error.tr;
    }
    return I18n.incomeTab.tr;
  }

  /// Returns the placeholder hint for the current controller state.
  String _placeholderMessage() {
    final error = controller.lastErrorMessage.value;
    if (error.isNotEmpty) {
      return error;
    }
    if (controller.datesLoading.value || controller.incomeLoading.value) {
      return '';
    }
    return I18n.incomeEmpty.tr;
  }

  /// Returns whether the placeholder should show a loading indicator.
  bool _placeholderIsLoading() {
    return controller.datesLoading.value || controller.incomeLoading.value;
  }

  /// Orders the day rows by the backend field order, keeping unknown rows last.
  List<ScriptIncomeItem> _orderedItems(ScriptIncomeDay day) {
    final remaining = <String, ScriptIncomeItem>{
      for (final item in day.items) item.name: item,
    };
    final ordered = <ScriptIncomeItem>[];
    for (final field in incomeItemFields) {
      final item = remaining.remove(field);
      if (item != null) {
        ordered.add(item);
      }
    }
    ordered.addAll(remaining.values);
    return ordered;
  }
}

/// Header with the day selector, the first-read time and the refresh button.
class _IncomeHeader extends StatelessWidget {
  const _IncomeHeader({
    required this.day,
    required this.availableDates,
    required this.selectedDateKey,
    required this.onSelected,
    required this.onRefresh,
    required this.compareDays,
    required this.onCompare,
  });

  final ScriptIncomeDay day;
  final List<String> availableDates;
  final String selectedDateKey;
  final ValueChanged<String> onSelected;
  final VoidCallback? onRefresh;
  final int compareDays;
  final ValueChanged<int> onCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseline = day.baselineDate.trim().isEmpty
        ? '--'
        : formatIncomeDayLabel(day.baselineDate);
    return Container(
      padding: const EdgeInsets.only(bottom: _kIncomeSectionSpacing),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(
        children: [
          _IncomeDateDropdown(
            dates: availableDates,
            selectedDateKey: selectedDateKey,
            onSelected: onSelected,
          ),
          const SizedBox(width: 8),
          _IncomeCompareDropdown(
            options: HomeIncomeController.compareDayOptions,
            selectedDays: compareDays,
            onSelected: onCompare,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${I18n.incomeBaseline.tr} $baseline',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: I18n.incomeRefresh.tr,
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Day selector rendered as a compact dropdown.
class _IncomeDateDropdown extends StatelessWidget {
  const _IncomeDateDropdown({
    required this.dates,
    required this.selectedDateKey,
    required this.onSelected,
  });

  final List<String> dates;
  final String selectedDateKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = selectedDateKey.isEmpty
        ? '--'
        : formatIncomeDayLabel(selectedDateKey);
    return PopupMenuButton<String>(
      enabled: dates.isNotEmpty,
      tooltip: '',
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 120),
      itemBuilder: (context) => [
        for (final date in dates.take(_kIncomeDateMenuMaxVisibleItems))
          PopupMenuItem<String>(
            value: date,
            child: Text(formatIncomeDayLabel(date)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kIncomeDropdownHorizontalPadding,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(_kIncomeDropdownBorderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compare-baseline selector rendered as a compact dropdown.
class _IncomeCompareDropdown extends StatelessWidget {
  const _IncomeCompareDropdown({
    required this.options,
    required this.selectedDays,
    required this.onSelected,
  });

  final List<int> options;
  final int selectedDays;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${I18n.incomeCompare.tr} ${formatIncomeCompareDays(selectedDays)}';
    return PopupMenuButton<int>(
      tooltip: '',
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 120),
      itemBuilder: (context) => [
        for (final days in options)
          PopupMenuItem<int>(
            value: days,
            child: Text(formatIncomeCompareDays(days)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kIncomeDropdownHorizontalPadding,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(_kIncomeDropdownBorderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 14,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

/// One resource card: icon, localized label, amount and delta.
class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.item});

  final ScriptIncomeItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconPath = incomeItemIcon(item.name);
    final delta = formatIncomeDelta(item.delta);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kIncomeIconSize,
            height: _kIncomeIconSize,
            child: iconPath == null
                ? Icon(
                    Icons.savings_outlined,
                    size: 22,
                    color: theme.textTheme.bodySmall?.color,
                  )
                : Image.asset(iconPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incomeItemLabel(item.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.75,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatIncomeQuantity(item.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(width: 6),
            Text(
              delta.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: delta.unchanged
                    ? theme.textTheme.bodySmall?.color
                    : (delta.increase
                          ? const Color(0xFF2E7D32)
                          : theme.colorScheme.error),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card shown when the selected day has no readable row.
class _IncomeEmptyCard extends StatelessWidget {
  const _IncomeEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

/// Centered placeholder for the loading, empty and error states.
class _IncomePlaceholder extends StatelessWidget {
  const _IncomePlaceholder({
    required this.label,
    required this.message,
    this.loading = false,
  });

  final String label;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_kIncomePanelPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Icon(
                Icons.inventory_2_outlined,
                size: 28,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(height: 10),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
