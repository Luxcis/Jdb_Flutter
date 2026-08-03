import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/widgets/search_movie_filter_bar.dart';

void main() {
  testWidgets('窄屏大字体下显示三行紧凑筛选项且默认值正确', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: SearchMovieFilterBar(
              value: SearchMovieFilter(),
              onChanged: _ignoreFilterChange,
            ),
          ),
        ),
      ),
    );

    expect(find.text('类型'), findsOneWidget);
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('排序'), findsOneWidget);
    for (final label in [
      '有码',
      '无码',
      '欧美',
      'FC2',
      '动漫',
      '可播放',
      '含磁链',
      '字幕',
      '单体',
      '相关度',
      '发布时间',
      '更新时间',
      '评分',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    final selected = chips
        .where((chip) => chip.selected)
        .map((chip) => (chip.label as Text).data);
    expect(selected, ['全部', '全部', '相关度']);
    expect(
      chips.every((chip) => chip.visualDensity == VisualDensity.compact),
      isTrue,
    );
    expect(chips.every((chip) => chip.showCheckmark == false), isTrue);

    final horizontalScrollViews = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((view) => view.scrollDirection == Axis.horizontal);
    expect(horizontalScrollViews, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击当前选项时不重复通知筛选变化', (tester) async {
    final changes = <SearchMovieFilter>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchMovieFilterBar(
            value: const SearchMovieFilter(),
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('相关度'));
    await tester.pump();

    expect(changes, isEmpty);
  });
}

void _ignoreFilterChange(SearchMovieFilter _) {}
