import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/profile/screens/profile_recent_viewed_page.dart';
import 'package:jade/features/profile/services/recent_viewed_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecentViewedSource implements RecentViewedDataSource {
  _FakeRecentViewedSource({this.multiplePages = false});

  final bool multiplePages;
  int pageRequests = 0;
  int clearCalls = 0;
  bool cleared = false;

  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async {
    pageRequests++;
    if (cleared) {
      return PagedResult(
        items: const [],
        currentPage: page,
        totalPages: page,
        total: 0,
      );
    }
    final itemCount = multiplePages && page == 1 ? 48 : 1;
    return PagedResult(
      items: [
        for (var index = 0; index < itemCount; index++)
          MovieSummary(
            id: 'm$page-$index',
            number: 'N-$page-$index',
            title: '影片 $page-$index',
            coverUrl: '',
          ),
      ],
      currentPage: page,
      totalPages: multiplePages ? 2 : 1,
      total: multiplePages ? 49 : 1,
    );
  }

  @override
  Future<void> clearRecentViewed() async {
    clearCalls++;
    cleared = true;
  }
}

Future<_FakeRecentViewedSource> _pumpPage(
  WidgetTester tester, {
  bool multiplePages = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  await auth.login(token: 'token', user: {'id': 1, 'username': 'tester'});
  final source = _FakeRecentViewedSource(multiplePages: multiplePages);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: ProfileRecentViewedPage(dataSource: source),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return source;
}

void main() {
  testWidgets('加载后显示标题删除按钮与三列 MovieCard 宫格', (tester) async {
    final source = await _pumpPage(tester);

    expect(find.text('近期浏览'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
    expect(find.byType(MovieCard), findsOneWidget);
    expect(source.pageRequests, 1);
  });

  testWidgets('点删除后取消不调用清空接口', (tester) async {
    final source = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('清空近期浏览？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.clearCalls, 0);
    expect(find.text('近期浏览'), findsOneWidget);
  });

  testWidgets('点删除确认后调用清空接口并刷新为空态', (tester) async {
    final source = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(source.clearCalls, 1);
    // 刷新后空态 + SnackBar
    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.text('已清空近期浏览'), findsOneWidget);
  });
}
