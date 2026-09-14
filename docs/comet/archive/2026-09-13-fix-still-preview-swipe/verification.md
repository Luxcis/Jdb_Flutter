---
generated_from_state_version: 10
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 2
- 完成时间: 2026-09-13T07:21:10.872Z
- 摘要: 只读 Verifier 验收 A1-A9 全部通过。修复机制级证据充分（长列表滚回第一帧恢复记忆比例、同 URL 重挂载宽度一致、原有占位/clamp/点击/语义回归保留），Runtime 正式检查 flutter test 全量与 flutter analyze 均通过。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 剧照图片都已加载并展示后，将长剧照列表向左滑动远离起点，再向右滑动可正常回滑，不出现闪回（跳回列表开头）或滚动被抵消。 | 根因（重挂载 16:9→真实比例二次宽度变化引发滚动修正）已消除：MovieStillThumbnail 新增模块级 URL→clamp 后比例记忆，initState 同步恢复第一帧比例。长列表测试『解码后滚出可见区域再滚回，第一帧恢复记忆比例』验证滚回不触发解码回调、宽度不再二次变化。 |
| A2 | passed | brief.md | A2: 缩略图滚出可见区域后再滚回，立即以与之前加载完成时相同的宽高比显示，不再经历「16:9 占位 → 实际比例」的二次宽度变化。 | test『长列表：解码后滚出可见区域再滚回，第一帧恢复记忆比例』：item-2 解码为 1.5 后 jumpTo(maxScroll) 使 State 销毁（findsNothing），jumpTo(0) 重建后比例立即≈1.5，未经历 16:9 占位。 |
| A3 | passed | brief.md | A3: 保留原有行为：加载前 16:9 占位、加载完成后按实际宽高比完整显示、竖图/超宽图 clamp [1.0, 21/9]、点击与语义不变。 | diff 仅新增记忆缓存与 initState 恢复，占位 16/9、clamp、InkWell/CachedImage 结构未改；既有『加载完成前按 16:9 占位』『竖图钳制 1.0』『超宽图钳制 21/9』『点击触发 onTap』全部通过。 |
| A4 | passed | brief.md | A4: 同一 URL 的宽高比记忆在整段会话内有效，同一张剧照在两次滚回时宽度一致。 | test『长列表：同一 URL 重挂载后宽度与首次展示一致』：销毁整树重建后 rememberedStillThumbnailAspect≈1.5 且 tester.getSize 与首次展示一致；记忆为进程级、会话内有效。 |
| A5 | passed | specs/movie-detail-stills/spec.md | 长剧照列表向左滑动后可正常向右回滑 Given 剧照列表有多张图片且均已加载展示 When 将列表向左滑动远离起点，再向右滑动返回 Then 回滑全程平稳无跳变，不闪回列表开头，滚动不被抵消 | Spec 场景回滑：重挂载第一帧即用记忆比例，列表项宽度无二次变化，滚动修正源消除；60 项 ListView 上 maxScroll 跳回验证稳定。 |
| A6 | passed | specs/movie-detail-stills/spec.md | 滑出可见区域再滚回无二次宽度变化 Given 某缩略图已按图片实际宽高比显示后被滑出可见区域 When 该缩略图重新滚入可见区域 Then 其第一帧即以滑出前相同的宽高比构建，不再出现 16:9 占位到实际比例的二次变化 | 滚回 pump 一帧未触发 onImageSize 即达记忆比例 1.5，证明第一帧构建无二次宽度变化。 |
| A7 | passed | specs/movie-detail-stills/spec.md | 同一 URL 宽度跨挂载一致 Given 同一张剧照（同一 URL）在会话内多次因滚动被销毁重建 When 观察每次重建后的缩略图宽度 Then 全部一致，与该 URL 解码出的实际宽高比记忆值相同 | 同 A4：重建后记忆值≈1.5、宽度与 firstSize 相等；缓存键为缩略图传入 URL。 |
| A8 | passed | specs/movie-detail-stills/spec.md | 自适应显示行为保持不变 Given 剧照图片尚未加载或刚加载完成 When 查看对应缩略图 Then 未加载时为 16:9 占位；加载完成后按实际宽高比完整显示，竖图/超宽图 clamp 在 [1.0, 21/9] | 对照 detail-still-autoscale 归档规格：clampStillThumbnailAspect、常量与 AspectRatio+CachedImage 结构逐行未变；未解码仍 16:9 占位、解码按真实比例完整显示。 |
| A9 | passed | specs/movie-detail-stills/spec.md | 点击与语义保持不变 Given 缩略图已按宽高比记忆机制显示 When 点击任一剧照缩略图或使用无障碍服务聚焦 Then 打开大图查看器并定位对应图片；语义标签与 Key 与修改前一致 | InkWell(onTap) 与 CachedImage 结构未变，点击测试通过；Semantics 与 Key 位于未改动的 MovieScreenshotSection。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter test 全量 | test | . | passed | 0 | 26973 ms |
| flutter analyze | analyze | . | passed | 0 | 2775 ms |

## 阻塞项

_无。_

## 风险与跳过的工作

- 宽高比记忆为进程级 Map、无淘汰策略；每条仅一个 double，量级有限，如未来成为口碑问题再加淘汰。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 2 | pass | — | 只读 Verifier 验收 A1-A9 全部通过。修复机制级证据充分（长列表滚回第一帧恢复记忆比例、同 URL 重挂载宽度一致、原有占位/clamp/点击/语义回归保留），Runtime 正式检查 flutter test 全量与 flutter analyze 均通过。 | 2026-09-13T07:21:10.872Z |



## 结论

只读 Verifier 验收 A1-A9 全部通过。修复机制级证据充分（长列表滚回第一帧恢复记忆比例、同 URL 重挂载宽度一致、原有占位/clamp/点击/语义回归保留），Runtime 正式检查 flutter test 全量与 flutter analyze 均通过。
