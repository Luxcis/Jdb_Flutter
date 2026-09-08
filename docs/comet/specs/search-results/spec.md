# 搜索结果页（search-results）完整目标规格

## 概述

搜索结果页有两个入口形态：

1. 关键词搜索结果页 `/search/results?q=<关键词>`（`SearchResultsPage`），由搜索首页 `/search` 发起；
2. 磁链搜索结果页 `/search/magnet/results?q=<关键词>&from_recent=<bool>`（`MagnetSearchResultsPage`），由磁链搜索首页 `/search/magnet` 发起。

两页共享同一页面标识规则：页面键由完整 URI（含 query 参数）决定。关键词变化即产生新页面；相同 URI 的结果页保持既有页面状态。

## 页面标识与重建

两个结果页的导航机制不同，但都遵循"新关键词得到全新结果页"：

- 关键词搜索结果页（`/search/results`）：页内重新搜索使用 `context.replace`。路由层页面键保持不变，页面 widget 键由完整 URI（含 query 参数）决定：URI 变化时页面子树整体重建（所有 Tab 的列表状态、分页游标、筛选与滚动位置重置，各数据源以新参数重新发起请求）；提交完全相同的关键词时 URI 不变，页面状态保留、不重新请求。
- 磁链搜索结果页（`/search/magnet/results`）：页内重新搜索使用 `context.pushReplacement`，每次提交（含相同关键词）都会以新页面键整体重建页面并按新参数重新加载；页面 widget 键同样由完整 URI 决定，作为一致性与回归防护。
- 从结果页 push 进入其他页面（如影片详情）再返回时，结果页仍在返回栈中，页面状态保留，不因页面键规则被重建。

## 关键词搜索结果页行为

- 页面结构：AppBar 中为关键词输入框（`TextInputAction.search`，`onSubmitted` 触发搜索），body 为 7 个可滚动 Tab：影片、演员、系列、片商、导演、清单、番号。
- 初始进入：以 URL 中的 `q`（已 trim）作为关键词，各 Tab 独立分页加载。
- 在结果页修改关键词并提交：
  - 关键词 trim 后为空：不导航、不保存历史、不重新搜索，停留在当前结果页；
  - 关键词有效：保存搜索历史，以 replace 语义跳转到 `/search/results?q=<新关键词>`（返回栈深度不变，系统返回回到搜索首页）；页面按页面标识规则重建，各 Tab 以新关键词重新加载，AppBar 搜索框文本为新关键词。
- 空关键词重定向：路由 `q` 缺失或 trim 后为空时重定向回 `/search`。

## 磁链搜索结果页行为

- 页面结构：AppBar 中为磁链关键词输入框（`TextInputAction.search`，`onSubmitted` 触发搜索），body 为排序分段控件 + 磁链分页列表。
- 初始进入：以 URL 中的 `q` 作为关键词、`from_recent` 作为来源标记加载数据。
- 在结果页修改关键词并提交：
  - 关键词 trim 后为空：不导航、不重新搜索；
  - 关键词有效：保存磁链搜索历史，以 `pushReplacement` 语义跳转到 `/search/magnet/results?q=<新关键词>&from_recent=false`（返回栈深度不变，系统返回回到磁链搜索首页）；页面按页面标识规则重建，以新关键词重新加载，AppBar 搜索框文本为新关键词；提交与当前相同的关键词同样重建并重新请求。
- 排序切换：原地切换并重新加载当前关键词的数据（不导航）。
- 空关键词重定向：路由 `q` 缺失或 trim 后为空时重定向回 `/search/magnet`。

## 不变量

- 搜索历史保存逻辑、保存时机（提交成功跳转前）不变。
- 分页控制器与跨页去重（`SearchPageSession`）行为不变。
- 结果页内重新搜索不新增返回栈深度。
- 不引入输入过程实时搜索。
