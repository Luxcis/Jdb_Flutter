// 核心工具：GitHub 代理前缀拼接与规范化。
// 独立于 feature 层放置，使 core 层的 SettingsProvider 也能复用，
// 从而在数据边界统一实现「非空代理一定以 / 结尾」的约定。
//
// 使用约定：代理为空串（''）表示「不使用代理」；非空即完整代理前缀
// （以 / 结尾，如 https://hub.luxcis.top/）。buildGitHubUrl 始终可按
// proxy + fullUrl 直接拼接，无需对内置/自定义代理分叉。

/// 代理前缀非空时拼接到完整 URL 前，否则原样返回。
String buildGitHubUrl(String proxy, String fullUrl) =>
    proxy.isEmpty ? fullUrl : '$proxy$fullUrl';

/// 规范化代理前缀：空串保留；非空且不以 / 结尾时自动补齐 /。
String normalizeGithubProxy(String proxy) =>
    proxy.isEmpty || proxy.endsWith('/') ? proxy : '$proxy/';
