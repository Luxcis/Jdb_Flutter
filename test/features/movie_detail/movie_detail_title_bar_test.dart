import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_detail_title_bar.dart';

const _longTitle = 'SSIS-123 这是一个需要多行展示才能完整显示的影片标题，用于验证展开态不会把标题截断为单行';
const _titleTextKey = Key('movie-detail-title-text');
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

Text _titleText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(_titleTextKey));
}

ScrollableState _scrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable).first);
}

void main() {
  testWidgets('页面处于顶部时以多行展示完整标题', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());

    expect(find.byKey(_titleBarKey), findsOneWidget);
    expect(_titleText(tester).maxLines, greaterThan(1));
    expect(_titleText(tester).overflow, TextOverflow.ellipsis);
    // 多行文字高度明显超过单行高度。
    expect(tester.getSize(find.byKey(_titleTextKey)).height, greaterThan(40));
    expect(_titleBarHeight(tester), greaterThan(kToolbarHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('向下滚动后标题收拢为单行并随滚动连续收缩', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());
    final expandedHeight = _titleBarHeight(tester);

    final position = _scrollable(tester).position;
    position.jumpTo(1);
    await tester.pump();

    expect(_titleText(tester).maxLines, 1);
    expect(_titleText(tester).overflow, TextOverflow.ellipsis);
    final partialHeight = _titleBarHeight(tester);
    expect(partialHeight, lessThan(expandedHeight));
    expect(partialHeight, greaterThan(kToolbarHeight));

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
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
    expect(_titleText(tester).maxLines, 1);

    position.jumpTo(0);
    await tester.pump();
    expect(_titleText(tester).maxLines, greaterThan(1));
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
    expect(_titleText(tester).maxLines, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('空标题退化为单行标题栏且不抛异常', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness(title: ''));

    expect(_titleBarHeight(tester), closeTo(kToolbarHeight, 0.01));
    expect(_titleText(tester).maxLines, 1);
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

    expect(_titleText(tester).maxLines, greaterThan(1));
    expect(tester.getSize(find.byKey(_titleTextKey)).height, greaterThan(50));
    expect(tester.takeException(), isNull);

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(_titleText(tester).maxLines, 1);
    // 收起态单行标题不被垂直压缩截断：文本高度保持 2x 行高，标题栏也能容纳。
    final collapsedTextHeight = tester
        .getSize(find.byKey(_titleTextKey))
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
    expect(_titleText(tester).maxLines, 1);

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('打开详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
