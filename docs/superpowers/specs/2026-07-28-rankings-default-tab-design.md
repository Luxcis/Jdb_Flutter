# 排行榜默认 Tab 改为"有码"

## 需求

排行榜页面进入时默认选中"有码"tab（索引 2），替代当前的 Top250（索引 0）。

## 范围

- 所有入口（底部导航、无参路由跳转）默认显示"有码"
- `/rankings?tab=hot` → "看热播"的逻辑保持不变

## 改动清单

### 1. rankings_screen.dart — 构造函数默认值

**文件**：`lib/features/rankings/screens/rankings_screen.dart`  
**位置**：第 17 行

```dart
// 修改前
const RankingsPage({super.key, this.initialTabIndex = 0})

// 修改后
const RankingsPage({super.key, this.initialTabIndex = 2})
```

### 2. app_router.dart — 路由 fallback 值

**文件**：`lib/core/router/app_router.dart`  
**位置**：第 90 行

```dart
// 修改前
initialTabIndex: state.uri.queryParameters['tab'] == 'hot' ? 1 : 0,

// 修改后
initialTabIndex: state.uri.queryParameters['tab'] == 'hot' ? 1 : 2,
```

### 3. 测试更新

**文件**：`test/features/rankings/rankings_screen_test.dart`

检查并更新所有断言默认 `initialTabIndex = 0` 的测试用例，将期望值改为 `2`。

## 行为变化对照

| 入口方式                | 修改前        | 修改后     |
|---------------------|------------|---------|
| 底部导航点击排行            | Top250 (0) | 有码 (2)  |
| 无参数路由 `/rankings`   | Top250 (0) | 有码 (2)  |
| `/rankings?tab=hot` | 看热播 (1)    | 看热播 (1) |

## 约束

- tabs 数组 `['Top250', '看热播', '有码', '无码', '欧美', 'FC2']` 不做调整
- 不影响各 tab 内部的功能逻辑
