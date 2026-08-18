# ReviewTile 交互优化与评论点赞设计

日期：2026-08-18
状态：已批准（用户逐节确认）

## 1. 背景与目标

`ReviewTile`（lib/core/widgets/review_tile.dart）当前整卡包在 `InkWell` 中，点击任意位置都会跳转影片详情。本次优化：

1. **点击区域收敛**：仅点击影片信息区（封面 + 标题 + 番号区域）跳转影片详情。
2. **正文展开交互**：点击评论正文自动展开/收起长评论（保留原「展开/收起」按钮作为辅助入口）。
3. **评论点赞**：实现 `POST /api/v1/movies/{movie_id}/reviews/{review_id}/like` 点赞功能。

组件在两处复用：热门评论列表（reviews_screen）与影片详情短评列表（movie_detail_screen）。

## 2. 需求决策（已确认）

| 决策点 | 结论 |
|--------|------|
| 点赞语义 | **仅点赞（幂等）**：点击只做点赞，不提供取消；已点赞（`liked=true`）的评论不再响应点赞点击 |
| 未登录处理 | 点击点赞时若未登录，SnackBar 提示「请先登录」+「去登录」Action，不发起请求 |
| 已点赞状态来源 | 服务端 `liked` 字段（接口文档评论实体含 `liked: boolean`） |
| 正文展开交互 | 点击正文展开/收起 + 保留右下角「展开/收起」按钮 |
| 点击跳转区域 | **仅影片信息区**（封面+标题+番号）可跳转；作者行、正文、点赞行均不跳转 |
| 实现方案 | **方案 A**：ReviewTile 自带点赞逻辑 + core 层 `ReviewApi.likeReview` 方法 |

## 3. 接口定义

### 3.1 点赞端点

```
POST /api/v1/movies/{movie_id}/reviews/{review_id}/like
```

- 路径参数：`movie_id`（影片 ID）、`review_id`（评论 ID）
- 认证：BearerAuth + jdsignature（jdsignature 由现有 `SignatureInterceptor` 自动附加）
- 响应：BaseEntity（`success: 1` 成功；失败走现有 `ResponseInterceptor` 统一错误处理，鉴权类错误自动登出）

### 3.2 端点常量

`lib/core/network/endpoints.dart` 新增：

```dart
// ── 评论点赞 ──
static const String reviewLike =
    '/api/v1/movies/{movie_id}/reviews/{review_id}/like';
```

> 注：`/api/v1/reviews/hotly` POST 也是「热门评论点赞」，但路径参数不明确；热门列表评论均携带 movie，统一使用带 movie_id 的端点。

### 3.3 点赞 API 封装（core 层）

> **架构约束**：`ReviewTile` 位于 `lib/core/widgets/`，而 RULES.md 规定「core 不依赖具体 feature」，
> 因此点赞调用不能放在 `ReviewsService`（features 层）。在 `lib/core/network/` 新建 `ReviewApi` 封装。

`lib/core/network/review_api.dart` 新建：

```dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';

/// 评论相关 API 封装（core 层，供通用组件复用）。
class ReviewApi {
  ReviewApi(this._api);

  final ApiClient _api;

  /// 为指定评论点赞（幂等）。
  Future<void> likeReview({
    required String movieId,
    required String reviewId,
  }) async {
    await _api.post(
      Endpoints.reviewLike
          .replaceAll('{movie_id}', movieId)
          .replaceAll('{review_id}', reviewId),
    );
  }
}
```

> `ReviewsService` 与 `MovieDetailService` 均不新增点赞方法，避免重复封装。

## 4. 数据模型

### 4.1 Review 增加 liked 字段

`lib/core/models/review.dart`：

- 新增 `final bool liked;`，构造参数 `this.liked = false`
- 重新运行 build_runner 生成 `review.g.dart`（`json['liked'] as bool? ?? false`）

### 4.2 归一化

`lib/core/network/api_data.dart` 的 `normalizeReviewJson` 新增：

```dart
'liked': apiBool(json['liked'], false),
```

兼容 `liked` 缺失、布尔、字符串（`'1'`/`'true'`）、数字（`1`/`0`）等形态。

## 5. ReviewTile 组件改造

### 5.1 状态化

`ReviewTile` 由 `StatelessWidget` 改为 `StatefulWidget`，本地状态：

- `_liked`：初始值 `widget.review.liked`
- `_likedCount`：初始值 `widget.review.likedCount`
- `_liking`：点赞请求进行中（防重复点击）

`didUpdateWidget` 中同步外部 review 变化（如详情页刷新后传入新 review 对象时，重置为服务端最新状态）。

### 5.2 点击区域划分

```
┌──────────────────────────────┐
│ [封面][标题/番号]  ← InkWell  │ ← 仅此区域点击跳影片详情
│ 作者 看过N部   ★★★★☆         │ ← 不跳转
│ 评论正文（超5行可点）         │ ← 点击正文展开/收起
│ 👍 123              日期     │ ← 点赞行：点击点赞/引导登录
└──────────────────────────────┘
```

- **影片信息区** `_MovieHeader` 外包 `InkWell`：`onTap: () => context.push('/movie/${movie.id}')`
- **正文区** `_ExpandableReviewContent`：整块 `GestureDetector` 点击切换 `_expanded`；保留右下角「展开/收起」TextButton（与正文点击行为一致）
- **点赞行**：`InkWell` 包裹点赞图标 + 数字，点击不跳转

卡片本身不再有整体 InkWell，点击区域互不干扰。

### 5.3 点赞交互逻辑

> **关键约束（用户确认）**：点赞逻辑在组件内部实现，但登录态**只在点击点赞时**通过 `context.read<AuthProvider>()` 读取（不依赖 Provider 包裹也能 build），避免破坏现有无 Provider 包裹的屏幕测试。`AuthProvider` 缺失时按未登录处理（提示登录）。

点击点赞行：

1. **读取登录态**：`context.read<AuthProvider>()`（无 Provider 时捕获 `ProviderNotFoundException` 视为未登录）→ 未登录 → SnackBar「请先登录」+ Action「去登录」→ `context.push('/login')`，不发请求
2. 已登录：
   - `_liked == true` → 不响应（幂等，已点赞）
   - `_liking == true` → 忽略（防连点）
   - 否则：`setState(_liking = true)` → `ReviewApi(ApiClient.instance).likeReview(movieId: review.movie!.id, reviewId: review.id)`
     - 成功 → `_liked = true`、`_likedCount + 1`
     - 失败 → SnackBar「点赞失败，请重试」，不改本地状态
     - `finally` 复位 `_liking = false`

### 5.4 依赖与边界

- 登录态：**点击时** `context.read<AuthProvider>()`，缺失视为未登录（Provider 已在 main.dart 装配，仅测试场景可能缺失）
- 网络：`ApiClient.instanceOrNull` 构造 `ReviewApi`（core 层，供组件复用）
- 边界：`review.movie == null` 时点赞行仍渲染，点击提示「无法点赞」（防御性处理，如影片详情页评论 fixture 无 movie 的场景）

### 5.5 无障碍

- 点赞行 `Semantics(button: true, ...)`：未点赞 label「点赞，当前 N 人已赞」；已点赞「已点赞」
- 展开/收起沿用现有 TextButton 语义

## 6. 测试计划

### 6.1 单元测试

| 文件 | 用例 |
|------|------|
| `test/core/models/review_model_test.dart` | ① `liked: true` 解析 ② `liked` 缺失默认 false ③ `liked: "1"` 归一化 true |
| `test/core/network/review_api_test.dart` | ① likeReview 发送 POST 到正确路径 ② 路径替换正确 |

### 6.2 组件测试（`test/core/widgets/review_tile_test.dart`）

| 用例 | 断言 |
|------|------|
| 点击影片信息区跳转详情 | 点击封面/标题区域 → `/movie/m1` |
| 点击正文展开/收起 | 长评论点正文展开，再点收起 |
| 短评论点击正文无效果 | 短评论无展开按钮 |
| 未登录点击点赞 | SnackBar「请先登录」+「去登录」Action，无点赞请求 |
| 无 Provider 包裹点击点赞 | 按未登录处理：SnackBar「请先登录」，不抛 ProviderNotFoundException |
| 已登录点赞成功 | 图标变实心、数字 +1、`liked` 更新 |
| 已登录但已点赞 | 点击无效果，不重复发请求 |
| 点赞失败 | SnackBar「点赞失败，请重试」，数字不变 |
| 点赞中防连点 | 请求未返回时再点不触发第二次请求 |

> 组件测试需要：`ChangeNotifierProvider` 注入 `AuthProvider` + `FakeAdapter` 注入 `ApiClient.forTest`；「无 Provider」用例用裸 `MaterialApp` 渲染验证降级路径。

### 6.3 验证命令

```bash
flutter analyze
flutter test
```

## 7. 涉及文件清单

| 文件 | 变更 |
|------|------|
| `lib/core/models/review.dart` | +`liked` 字段 |
| `lib/core/models/review.g.dart` | build_runner 重新生成 |
| `lib/core/network/api_data.dart` | `normalizeReviewJson` +`liked` |
| `lib/core/network/endpoints.dart` | +`reviewLike` 常量 |
| `lib/core/network/review_api.dart` | 新建：`ReviewApi.likeReview()` |
| `lib/core/widgets/review_tile.dart` | 状态化、点击区域划分、点赞逻辑 |
| `test/core/models/review_model_test.dart` | +liked 解析用例 |
| `test/core/network/review_api_test.dart` | 新建：likeReview 用例 |
| `test/core/widgets/review_tile_test.dart` | 改造 + 新增用例 |

## 8. 不做的事（YAGNI）

- 不实现取消点赞（接口无对应端点，需求确认仅点赞）
- 不引入本地持久化点赞记忆（已点赞状态以服务端 `liked` 为准）
- 不引入 Controller/Provider 统一管理点赞状态（方案 A 决策）
- 不实现热门评论点赞的 `/api/v1/reviews/hotly` POST 变体
