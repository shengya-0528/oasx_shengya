import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
import 'package:oasx/modules/home/widgets/analysis_panel.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Hosts the desktop right sidebar for statistics and logs.
class WorkbenchSidebarPanel extends StatelessWidget {
  /// Creates the right workbench sidebar.
  const WorkbenchSidebarPanel({
    super.key,
    required this.controller,
    required this.scriptName,
    this.separateHeader = false,
  });

  /// Dashboard controller that owns sidebar tab state.
  final HomeDashboardController controller;

  /// Active script rendered by the sidebar.
  final String scriptName;
  final bool separateHeader;

  @override
  Widget build(BuildContext context) {
    if (separateHeader) {
      return Obx(() {
        final tabs = controller.workbenchSidebarTabsFor(
          HomeWorkbenchLayoutMode.threePane,
        );
        final currentTab = controller.displayedWorkbenchSidebarTabFor(
          HomeWorkbenchLayoutMode.threePane,
        );
        final header = Wrap(
          spacing: 6,
          runSpacing: 4,
          children: tabs
              .map(
                (tab) => ChoiceChip(
                  label: Text(_tabLabel(tab)),
                  showCheckmark: false,
                  selected: currentTab == tab,
                  onSelected: (_) =>
                      controller.setActiveWorkbenchSidebarTabValue(tab),
                ),
              )
              .toList(),
        );
        if (currentTab == HomeWorkbenchTab.logs && scriptName.isNotEmpty) {
          return LogCenterPanel(scriptName: scriptName, header: header);
        }
        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(alignment: Alignment.topLeft, child: header),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: currentTab == HomeWorkbenchTab.stats
                    ? const ScriptStatisticsPanel()
                    : ScriptAnalysisPanel(scriptName: scriptName),
              ),
            ),
          ],
        );
      });
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          final tabs = controller.workbenchSidebarTabsFor(
            HomeWorkbenchLayoutMode.threePane,
          );
          final currentTab = controller.displayedWorkbenchSidebarTabFor(
            HomeWorkbenchLayoutMode.threePane,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tabs
                    .map(
                      (tab) => ChoiceChip(
                        label: Text(_tabLabel(tab)),
                        showCheckmark: false,
                        selected: currentTab == tab,
                        onSelected: (_) =>
                            controller.setActiveWorkbenchSidebarTabValue(tab),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: switch (currentTab) {
                  HomeWorkbenchTab.stats => const ScriptStatisticsPanel(),
                  HomeWorkbenchTab.logs => LogCenterPanel(
                    scriptName: scriptName,
                  ),
                  HomeWorkbenchTab.analysis => ScriptAnalysisPanel(
                    scriptName: scriptName,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Resolves a localized label for one sidebar tab.
  String _tabLabel(HomeWorkbenchTab value) {
    return switch (value) {
      HomeWorkbenchTab.stats => I18n.homeStatsTab.tr,
      HomeWorkbenchTab.logs => I18n.log.tr,
      HomeWorkbenchTab.analysis => I18n.homeAnalysisTab.tr,
      _ => '',
    };
  }
}
