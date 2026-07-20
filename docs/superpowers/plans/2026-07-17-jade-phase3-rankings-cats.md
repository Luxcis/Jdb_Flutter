# Jade Phase 3 — 排行榜 + 类别 Plan

> Executing with parallel subagents on `feature/phase3-rankings-cats`.

**Goal:** 实现 spec §8 排行榜（6 Tab）和 §9 类别（5 Tab），复用 MovieGridView/MovieListTile/FilterDrawer/SortSegmented/SortSelect/PaginationController。

**Architecture:** `lib/features/rankings/` 和 `lib/features/categories/`，各含 services/provider/screens/widgets。

## Global Constraints
- 中文硬编码，无本地化，Material 3，复用已有共享组件
- Git 代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890`
- 提交仅含任务文件，不 push
