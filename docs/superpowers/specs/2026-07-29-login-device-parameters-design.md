# 登录设备参数调整设计

## 背景

当前登录页已经使用 OpenAPI 要求的 `FormData` 提交请求，但设备 UUID
由时间戳拼接生成，设备名称、型号、系统版本及应用字段为旧的固定值。
本次调整要求登录请求与官方 Android 客户端 1.9.35 的参数生成逻辑一致。

## 范围

本次仅调整登录请求参数，不修改注册、启动或其他接口的参数。

具体目标：

- `username` 取登录输入框文本并执行 `trim()`。
- `password` 原样取登录输入框文本。
- 用户名和密码不做额外编码、哈希或加密。
- 从真实 Android 设备信息生成设备字段。
- 缓存并稳定复用设备 UUID。
- 使用指定的官方客户端应用字段。

## 依赖

新增两个直接依赖：

- `device_info_plus`：读取 `AndroidDeviceInfo`。
- `uuid`：生成 UUID v4 和 UUID v5。

## 架构

设备信息读取、UUID 生成和参数组装放在 `lib/core/` 下的独立服务中。
登录页只负责读取输入、调用服务并提交请求。

服务的外部依赖需要可替换，以便单元测试通过 fake 提供设备信息和 UUID，
不依赖真实 Android 平台通道。

## 数据流

登录操作按以下顺序执行：

1. 读取登录页的用户名并执行 `trim()`，密码保持原值。
2. 从 `SharedPreferences` 读取 `key_device_uuid`。
3. 若缓存值非空，直接使用该值。
4. 若缓存值为空或不存在，通过 `device_info_plus` 读取
   `AndroidDeviceInfo`。
5. 根据 `androidInfo.id` 生成 UUID：
   - 等于 `9774d56d682e549c` 时，使用 UUID v4。
   - 其他值使用 UUID v5：
     - namespace：`6ba7b812-9dad-11d1-80b4-00c04fd430c8`
     - name：`androidInfo.id`
6. 将新 UUID 写入 `key_device_uuid`。
7. 组装完整设备参数并以 `FormData` 提交登录请求。

即使 UUID 已经缓存，服务仍需读取 Android 设备信息，以生成设备名称、型号和
系统版本；只跳过 UUID 的重新生成。

## 登录请求字段

| 字段 | 来源或固定值 |
| --- | --- |
| `username` | 用户名输入框文本执行 `trim()` |
| `password` | 密码输入框原始文本 |
| `device_uuid` | 缓存值，或按上述规则生成并缓存 |
| `device_name` | `androidInfo.manufacturer` |
| `device_model` | `${androidInfo.model}/${androidInfo.board}` |
| `platform` | `android` |
| `system_version` | `androidInfo.version.release` |
| `app_channel` | `official` |
| `app_version` | `official` |
| `app_version_number` | `1.9.35` |

UUID v5 的命名空间严格采用需求给出的字符串。虽然该数值在标准 UUID
命名空间常量中通常对应 OID，本实现不按文字标签替换为其他值。

## 错误处理

- 设备信息读取、UUID 生成或缓存写入失败时，不发送缺少设备字段的登录请求。
- 异常交由登录页现有错误处理逻辑展示。
- 不引入静默回退的伪设备信息，避免发送不符合契约的数据。

## 测试策略

### 单元测试

覆盖设备参数服务的以下行为：

- 存在非空缓存 UUID 时稳定复用。
- 缓存为空或不存在时生成并持久化 UUID。
- Android ID 为 `9774d56d682e549c` 时使用 UUID v4。
- 正常 Android ID 使用指定 namespace 和 Android ID 生成 UUID v5。
- 正确映射 manufacturer、model/board 和 version.release。
- 正确输出四个固定应用字段。

### Widget 测试

更新登录页请求测试，验证：

- 请求仍为 `FormData`。
- 完整字段与官方客户端参数契约一致。
- 用户名前后空格被移除。
- 密码中的字符和前后空格保持原样。
- 页面通过可替换的设备参数服务测试，不调用真实平台通道。

## 非目标

- 不调整注册接口的设备参数。
- 不调整 startup 等其他接口的应用版本参数。
- 不改变登录成功后的认证存储和路由行为。
- 不改变登录页面视觉样式。
