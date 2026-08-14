# Movie Detail Review Actions Design

## Goal

在影片详情“基本信息”操作区中，把“想看”和“看过”接入真实影评接口，并根据详情响应中的当前用户影评状态展示创建、更新或删除操作。

“存入清单”现有流程保持不变，新增按钮位于它的左侧。

## Scope

本次包含：

- 解析详情响应 `movie.review`。
- 创建或更新“想看”“看过”影评。
- 删除当前“想看”或“看过”影评。
- “看过”评分与评论表单。
- 扩展共享 `StarRating`，使其在可选模式下支持五颗星点击评分。
- 操作成功后的本地状态更新与详情数据校准。
- 服务、模型、共享组件和影片详情页面的回归测试。

本次不包含：

- 编辑一条已经标记为“看过”的评分或评论。
- 独立影评编辑页面。
- 半星评分、零分提交或 10 分制输入。
- 修改短评列表、点赞、举报或“存入清单”业务。
- 新增依赖、本地化或触觉反馈。

## Authoritative API Contract

接口契约以用户提供的 OpenAPI 附件为准。

### 创建或更新影评

```http
POST /api/v1/movies/{movie_id}/reviews
Content-Type: application/json
```

“想看”只发送必需状态：

```json
{
  "status": "want_watch"
}
```

“看过”发送用户实际填写的数据：

```json
{
  "score": 3,
  "content": "用户填写的评论内容",
  "status": "watched"
}
```

约束：

- `score` 是整数，范围为 1–5。
- `content` 必填，提交前去除首尾空白，去除后不得为空。
- `status` 只使用 `want_watch` 或 `watched`。
- 不为“想看”发送占位 `score` 或 `content`。
- POST 成功响应的 `data.review` 是操作后的当前用户影评。

### 删除影评

```http
DELETE /api/v1/movies/{movie_id}/reviews/{review_id}
```

`review_id` 必须来自当前详情的 `movie.review.id`，或最近一次 POST 成功返回的 `review.id`。删除响应不承担页面状态推导职责；DELETE 成功即表示当前用户影评已删除。

## Detail Model

`MovieDetail` 新增可空的当前用户影评字段，JSON 来源固定为 `movie.review`。复用现有 `Review` 模型，至少保留：

- `id`
- `status`
- `score`
- `content`

`normalizeMovieDetailJson` 对详情中的 `review` 执行以下处理：

- 缺失或 `null`：归一化为 `null`。
- 对象：复用 `normalizeReviewJson`，将数字或字符串 ID 统一为字符串。
- `status` 原样保留，页面只识别 `want_watch` 与 `watched`。

详情中的当前用户影评与“短评”Tab 加载的公开影评列表相互独立。

## Service Interface

`MovieDetailService` 增加两个职责明确的方法：

```dart
Future<Review> createOrUpdateReview({
  required String movieId,
  required String status,
  int? score,
  String? content,
});

Future<void> deleteReview({
  required String movieId,
  required String reviewId,
});
```

服务层负责：

- 使用 JSON `Map`，不使用 `FormData`。
- “想看”请求只发送 `status`。
- “看过”请求发送 `score`、去除首尾空白后的 `content` 和 `status`。
- 对“看过”的 1–5 分范围及非空评论进行防御性校验。
- 从已解包的 `data.review` 解析并返回 `Review`。
- 构造包含准确 `movie_id`、`review_id` 的 DELETE 路径。

页面不直接组装 URL 或请求 JSON。

## Action-State Matrix

操作区继续使用现有紧凑按钮样式和 `Wrap` 布局，顺序固定如下：

| 当前详情状态 | 按钮顺序 |
| --- | --- |
| `review == null` | `想看`、`看过`、`存入清单` |
| `review.status == want_watch` | `删除想看`、`看过`、`存入清单` |
| `review.status == watched` | `删除看过`、`存入清单` |

行为：

- 点击“想看”：直接 POST `status=want_watch`。
- 点击“删除想看”：DELETE 当前影评。
- 点击“看过”：打开“标记为看过”表单。
- 已想看时点击“看过”：表单提交后直接 POST `status=watched`，由服务端更新同一影片的当前用户影评，不先发送 DELETE。
- 点击“删除看过”：DELETE 当前影评。
- 已看过状态不显示“想看”或“看过”。
- 未识别的 `review.status` 按未标记状态展示创建入口，不改变或删除未知状态。

按钮使用稳定 Key，测试和无障碍工具可以区分想看、看过、删除和存入清单操作。

## Watched Form

点击“看过”后使用 `showModalBottomSheet` 打开可滚动、键盘安全的 Material 3 表单：

- 标题：`标记为看过`
- 评分标签：`评分`
- 评分控件：交互式 `StarRating`
- 评论输入框：`评论内容`
- 操作：`取消`、`提交`

表单初始状态：

- 未选择评分。
- 评论内容为空。
- “提交”不可用。

验证规则：

- 五颗星分别对应整数 1、2、3、4、5 分。
- 选择一颗星后可点击其他星修改评分。
- 评论去除首尾空白后必须非空。
- 评分和评论均有效时才允许提交。
- 提交期间禁用评分、输入和操作按钮，阻止重复请求。

POST 成功后关闭表单；非认证错误时保留表单内容并显示失败提示，允许用户重试。认证错误继续交给现有全局认证处理。

## Interactive StarRating

共享 `StarRating` 增加可选交互能力，不创建第二套星级组件。

建议接口：

```dart
StarRating({
  required double score,
  String semanticLabel = '评分',
  double size = 18,
  ValueChanged<int>? onChanged,
  bool enabled = true,
})
```

只读模式：

- `onChanged == null`。
- 保持现有 5 星渲染、半星显示、10 分制自动折算、颜色、尺寸和整体语义。
- 现有影片卡片、详情评分和短评调用方无需修改。

交互模式：

- `onChanged != null`。
- `enabled` 只控制交互是否可用；它不改变只读/交互模式，也不改变当前选中显示。
- 表单只传入 0–5 的直接星数；0 表示尚未评分，不能提交。
- 第 N 颗星触发 `onChanged(N)`，N 的范围固定为 1–5。
- 选中值之前的星为实心，其余为空心；交互评分不产生半星。
- 每颗星都是独立可点击语义按钮，标签分别为 `1分` 至 `5分`。
- 点击区域满足移动端可操作性，不依赖覆盖在整行上的坐标计算。
- 表单提交期间传入 `enabled=false`，保留交互式五星外观并阻止评分变化。

## Page State and Data Flow

页面增加独立于公开短评列表的当前用户影评状态：

- 首次详情成功后，以 `detail.review` 初始化。
- 影评操作共享一个进行中标记；进行中时禁用所有想看、看过和删除按钮。
- “存入清单”保持独立，不复用影评操作锁。

创建或更新成功：

1. 使用 POST 响应的 `review` 立即更新按钮状态。
2. 关闭“看过”表单。
3. 重新调用详情接口，只更新影片详情与当前用户影评。
4. 使用服务端详情校准想看数、看过数和最终影评状态。

删除成功：

1. 立即把当前用户影评设为 `null`。
2. 重新调用详情接口校准人数和最终状态。

详情校准失败不回滚已经成功的影评操作；按钮保留由成功响应或成功 DELETE 得出的状态，并提示人数或详情刷新失败。只有 POST 或 DELETE 本身失败时才保持原状态。

## Error Handling

- `JWTVerificationError`、`NonExistentUser` 和 HTTP 401：沿用 `ResponseInterceptor` 与全局登录跳转，不重复显示普通失败提示。
- POST/DELETE 非认证失败：不改变操作前状态，显示 `操作失败，请重试`。
- POST 成功但详情校准失败：保留新的影评状态，显示 `状态已更新，详情刷新失败`。
- DELETE 成功但详情校准失败：保留未标记状态，显示同一刷新提示。
- 表单校验错误在本地阻止请求，不发送无效 JSON。
- 页面销毁后不更新状态或显示提示。

## Testing

### StarRating Widget Tests

- 现有只读 5 星、半星和 10 分制折算行为不变。
- 交互模式固定渲染五颗星。
- 点击第 1–5 颗星分别回调整数 1–5。
- 选择值改变后实心星数量正确。
- 每颗星具有独立评分语义。
- `onChanged` 存在但 `enabled=false` 时不触发回调，且保持当前选中显示。

### Model and Normalization Tests

- 详情 `review` 缺失与 `null` 均解析为 `null`。
- 数字 `review.id` 转为字符串。
- `status`、`score`、`content` 正确保留。
- 当前用户影评不影响公开短评列表解析。

### Service Tests

- “想看”POST 路径正确，JSON 只有 `status=want_watch`。
- “看过”POST 精确发送整数 `score`、裁剪后的 `content`、`status=watched`。
- 1、5 分可提交；0、6 分及空白评论在发出请求前被拒绝。
- POST 成功响应正确解析 `data.review`。
- DELETE 路径包含准确 movie ID 和 review ID。

### Movie Detail Widget Tests

- 三种详情状态分别显示状态矩阵规定的按钮和顺序。
- 所有新增按钮位于“存入清单”左侧。
- “看过”打开表单，初始不能提交。
- `StarRating` 五颗星映射 1–5，评论必填。
- 有效表单提交精确 JSON，成功后显示“删除看过”并关闭表单。
- 已想看提交“看过”不先发送 DELETE。
- 删除想看和删除看过使用详情中的 review ID。
- 请求期间重复点击不产生第二个请求。
- POST/DELETE 失败保持原按钮状态。
- 认证错误沿用现有全局处理。
- 成功操作后的详情校准更新人数；校准失败不回滚按钮状态。
- “存入清单”现有测试继续通过。

## Acceptance Criteria

- 影片详情操作区根据 `movie.review` 正确展示想看、看过或删除状态。
- “想看”发送只含状态的 JSON。
- “看过”必须通过五颗交互星选择 1–5 分，并填写非空评论。
- “看过”发送精确的 `score`、`content`、`status=watched` JSON。
- 删除操作使用当前影评 ID。
- 已看过状态只显示“删除看过”和“存入清单”。
- 现有 `StarRating` 只读消费者、短评列表和存入清单流程无回归。
- 不新增依赖，不推送远端，不触发版本发布。
