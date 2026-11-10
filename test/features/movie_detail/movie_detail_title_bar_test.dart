import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_detail_title_bar.dart';

const _longTitle = 'SSIS-123 这是一个需要多行展示才能完整显示的影片标题，用于验证展开态不会把标题截断为单行';
const _titleTextKey = Key('movie-detail-title-text');
const _collapsedTitleTextKey = Key('movie-detail-title-text-collapsed');
const _expandedOpacityKey = Key('movie-detail-title-expanded-opacity');
const _collapsedOpacityKey = Key('movie-detail-title-collapsed-opacity');
const _titleBarKey = Key('movie-detail-title-bar');

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildHarness({String title = _longTitle}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          MovieDetailTitleBar(title: title),
          const SliverToBoxAdapter(child: SizedBox(height: 2000)),
        ],
      ),
    ),
  );
}

double _titleBarHeight(WidgetTester tester) {
  return tester.getSize(find.byType(AppBar)).height;
}

Text _expandedTitle(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(_titleTextKey));
}

Text _collapsedTitle(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(_collapsedTitleTextKey));
}

double _expandedOpacity(WidgetTester tester) {
  return tester.widget<Opacity>(find.byKey(_expandedOpacityKey)).opacity;
}

double _collapsedOpacity(WidgetTester tester) {
  return tester.widget<Opacity>(find.byKey(_collapsedOpacityKey)).opacity;
}

ScrollableState _scrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable).first);
}

void main() {
  testWidgets('页面处于顶部时以多行展示完整标题', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());

    expect(find.byKey(_titleBarKey), findsOneWidget);
    expect(find.byKey(_collapsedTitleTextKey), findsNothing);
    expect(_expandedTitle(tester).maxLines, greaterThan(1));
    expect(_expandedTitle(tester).overflow, TextOverflow.ellipsis);
    // 多行文字高度明显超过单行高度。
    expect(tester.getSize(find.byKey(_titleTextKey)).height, greaterThan(40));
    expect(_titleBarHeight(tester), greaterThan(kToolbarHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('向下滚动时标题随滚动距离收缩并做淡入淡出', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());
    final expandedHeight = _titleBarHeight(tester);
    final collapseRange = expandedHeight - kToolbarHeight;

    final position = _scrollable(tester).position;
    // 折叠过程中：两层标题同时存在且透明度介于 0 与 1 之间，高度随滚动收缩。
    position.jumpTo(collapseRange * 0.4);
    await tester.pump();
    expect(find.byKey(_titleTextKey), findsOneWidget);
    expect(find.byKey(_collapsedTitleTextKey), findsOneWidget);
    expect(_expandedOpacity(tester), inExclusiveRange(0.0, 1.0));
    expect(_collapsedOpacity(tester), inExclusiveRange(0.0, 1.0));
    final partialHeight = _titleBarHeight(tester);
    expect(partialHeight, lessThan(expandedHeight));
    expect(partialHeight, greaterThan(kToolbarHeight));

    // 完全收起后只剩单行省略标题，高度固定为 toolbar 高度。
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(_titleTextKey), findsNothing);
    expect(_collapsedTitle(tester).maxLines, 1);
    expect(_collapsedTitle(tester).overflow, TextOverflow.ellipsis);
    expect(_collapsedOpacity(tester), 1);
    expect(_titleBarHeight(tester), closeTo(kToolbarHeight, 0.01));
    expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动回到页面顶部后恢复多行完整标题', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());
    final expandedHeight = _titleBarHeight(tester);

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(_collapsedTitle(tester).maxLines, 1);

    position.jumpTo(0);
    await tester.pump();
    expect(find.byKey(_collapsedTitleTextKey), findsNothing);
    expect(_expandedTitle(tester).maxLines, greaterThan(1));
    expect(_titleBarHeight(tester), closeTo(expandedHeight, 0.01));
  });

  testWidgets('极端超长标题按屏幕可用高度上限截断', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      _buildHarness(title: 'SSIS-123 ${'这是一段很长的标题文案' * 40}'),
    );

    final height = _titleBarHeight(tester);
    expect(height, lessThanOrEqualTo(844 * 0.4 + 0.5));
    expect(height, greaterThanOrEqualTo(kToolbarHeight));
    expect(_expandedTitle(tester).maxLines, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('空标题退化为单行标题栏且不抛异常', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness(title: ''));

    expect(_titleBarHeight(tester), closeTo(kToolbarHeight, 0.01));
    expect(_expandedTitle(tester).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字号下展开与收起均不溢出', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                const MovieDetailTitleBar(title: _longTitle),
                const SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(_expandedTitle(tester).maxLines, greaterThan(1));
    expect(tester.getSize(find.byKey(_titleTextKey)).height, greaterThan(50));
    expect(tester.takeException(), isNull);

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(_collapsedTitle(tester).maxLines, 1);
    // 收起态单行标题不被垂直压缩截断：文本高度保持 2x 行高，标题栏也能容纳。
    final collapsedTextHeight = tester
        .getSize(find.byKey(_collapsedTitleTextKey))
        .height;
    expect(collapsedTextHeight, greaterThan(50));
    expect(
      _titleBarHeight(tester),
      greaterThanOrEqualTo(collapsedTextHeight + 21),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('收起态下返回按钮可点击返回上一页', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: CustomScrollView(
                        slivers: [
                          const MovieDetailTitleBar(title: _longTitle),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 2000),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(_collapsedTitle(tester).maxLines, 1);

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('打开详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
