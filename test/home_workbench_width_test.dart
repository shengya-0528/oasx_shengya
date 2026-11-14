import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';

void main() {
  test('pane minimum widths allow narrower resizing', () {
    expect(kHomeWorkbenchMinCollectionWidth, 140);
    expect(kHomeWorkbenchMinDetailsWidth, 260);
    expect(kHomeWorkbenchBalancedMinCollectionWidth, 200);

    // The overview pane keeps a usable width once dragged to its limit.
    final narrow = resolveHomeWorkbenchLayout(
      maxWidth: 1700,
      collectionWidth: 200,
      splitRatio: 0.5,
    );
    expect(narrow.mode, HomeWorkbenchLayoutMode.threePane);
    expect(narrow.collectionWidth, 200);
  });

  test('task pane can be dragged down to its new minimum', () {
    const collection = 200.0;
    const details = 260.0;
    const log = 400.0;
    const maxWidth = collection +
        kHomeWorkbenchDividerWidth +
        details +
        kHomeWorkbenchDividerWidth +
        log;
    final resizableWidth = maxWidth -
        collection -
        kHomeWorkbenchDividerWidth -
        kHomeWorkbenchDividerWidth;
    final layout = resolveHomeWorkbenchLayout(
      maxWidth: maxWidth,
      collectionWidth: collection,
      splitRatio: details / resizableWidth,
    );
    expect(layout.mode, HomeWorkbenchLayoutMode.threePane);
    expect(layout.detailsWidth, closeTo(details, 0.5));
  });
}
