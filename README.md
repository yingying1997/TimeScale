# 时光刻度

时光刻度是一款面向 HarmonyOS 的重要日子、倒计时与纪念日管理应用。应用支持公历/农历日期记录、重复事件、系统日历提醒、桌面服务卡片和统计分析，适合用于生日、纪念日、考试、旅行、项目节点等时间节点的长期管理。

## 项目概览

| 项目 | 内容 |
| --- | --- |
| 应用名称 | 时光刻度 |
| Bundle Name | `com.ying.timescale` |
| 当前版本 | `1.0.0` |
| Version Code | `1000000` |
| 开发者 | Ying Studio |
| 运行平台 | HarmonyOS |
| 支持设备 | Phone、Tablet |
| API 类型 | Stage 模型 |
| Target SDK | `6.0.2(22)` |
| Compatible SDK | `6.0.2(22)` |
| 开发语言 | ArkTS |

## 功能特性

- 事件管理：支持创建、编辑、删除重要日期事件，并记录标题、备注、主题色。
- 倒计时展示：自动识别今天、未来、已过期事件，展示距离目标日期的天数。
- 公历/农历：支持公历日期和农历日期，适配生日、传统节日、纪念日等场景。
- 重复规则：支持单次、每月、每年重复，并自动计算下一次发生日期。
- 事件提醒：支持当天提醒和提前一天提醒，并同步写入系统日历。
- 列表交互：支持关键词搜索、侧滑删除、长按拖拽排序。
- 数据统计：统计事件总数、近 7 天/30 天、本月提醒、未来一年趋势、重复类型和日期类型分布。
- 桌面卡片：提供 HarmonyOS 服务卡片，快速查看最近的重要日子。
- 本地存储：使用 HarmonyOS RDB 保存事件和提醒实例数据。
- 备份扩展：已接入 HarmonyOS Backup Extension Ability 入口。

## 技术栈

- ArkTS
- ArkUI
- HarmonyOS Stage Model
- RDB 本地数据库
- CalendarKit 系统日历能力
- Form Extension Ability 服务卡片
- Backup Extension Ability 备份扩展
- Hvigor 构建体系
- Hypium 单元测试

## 项目亮点

- 分层清晰：页面层、服务层、仓储层、数据模型和工具类职责分离，便于维护和测试。
- 日期规则完整：封装公历/农历事件的发生日期计算，覆盖每月重复、每年重复、闰月和 2 月 29 日等边界。
- 提醒降级处理：对日历权限拒绝、提醒时间已过、系统日历写入失败等场景进行提示和状态处理。
- 卡片联动刷新：事件保存、删除和排序后刷新服务卡片，保证桌面卡片与应用内数据一致。
- 统计可视化：使用 Canvas 绘制重复类型分布和未来一年趋势，提升数据可读性。
- 测试覆盖核心规则：单元测试覆盖列表逻辑、提醒发生日期、提醒排程等核心业务。

## 目录结构

```text
.
+-- AppScope/                         # 应用级配置、图标和基础资源
+-- entry/                            # 主业务模块
|   +-- src/main/ets/
|   |   +-- database/                 # RDB 数据库管理
|   |   +-- entryability/             # 主 Ability
|   |   +-- entrybackupability/       # 备份扩展 Ability
|   |   +-- entryformability/         # 服务卡片 Ability
|   |   +-- helpers/                  # 页面映射与展示辅助逻辑
|   |   +-- model/                    # 数据模型
|   |   +-- pages/                    # 页面：列表、表单、统计
|   |   +-- repository/               # 数据仓储
|   |   +-- services/                 # 提醒、统计、卡片、日期计算等业务服务
|   |   +-- store/                    # 页面数据状态封装
|   |   +-- theme/                    # 主题与视觉常量
|   |   +-- utils/                    # 通用工具
|   |   +-- widget/                   # 桌面服务卡片页面
|   +-- src/test/                     # 本地单元测试
+-- hvigor/                           # Hvigor 构建配置
+-- build-profile.json5               # 工程构建配置
+-- oh-package.json5                  # 工程依赖配置
+-- README.md
```

## 关键实现

- 数据库：`RdbManager` 创建 `events` 与 `reminder_instances` 两张表，并通过迁移语句兼容后续字段扩展。
- 数据仓储：`EventRepository` 和 `ReminderInstanceRepository` 负责事件与提醒实例的持久化读写。
- 日期计算：`EventOccurrenceService` 和 `LunarDateService` 负责公历/农历事件下一次发生日期计算。
- 提醒同步：`ReminderService` 通过 CalendarKit 创建系统日历提醒，`ReminderOccurrenceGenerator` 为重复事件生成未来提醒实例。
- 服务卡片：`EntryFormAbility`、`CardManager`、`CardRefreshService` 和 `CardDataBuilder` 负责卡片数据生成与刷新。
- 统计分析：`StatisticsService` 统一生成统计页所需的摘要、趋势、分布和洞察文案。

## 权限说明

应用会申请以下权限：

| 权限 | 用途 |
| --- | --- |
| `ohos.permission.READ_CALENDAR` | 读取系统日历，用于创建或维护提醒事件 |
| `ohos.permission.WRITE_CALENDAR` | 写入系统日历，用于同步重要日子的提醒 |

权限仅用于将用户主动设置的提醒写入系统日历。若用户拒绝日历权限，事件本身仍可保存，但系统日历提醒无法创建。

## 数据与隐私

- 事件数据保存在设备本地 RDB 数据库 `event.db` 中。
- 当前项目未接入云端同步、账号系统或第三方统计 SDK。
- 日历提醒会写入本地系统日历账号 `TimeScale`。
- 删除事件时会同步尝试清理对应的系统日历提醒。

## 环境要求

- DevEco Studio 已安装并配置 HarmonyOS SDK。
- 已安装项目匹配的 SDK：`6.0.2(22)`。
- 已完成 `ohpm install` 依赖安装，或在 DevEco Studio 中完成同步。

## 安装依赖

```bash
ohpm install
```

如果使用 DevEco Studio，可以直接打开项目并等待依赖同步完成。

## 本地运行

1. 使用 DevEco Studio 打开项目根目录。
2. 选择 `entry` 模块和目标设备。
3. 连接真机或启动模拟器。
4. 点击 Run 运行调试版本。

## 测试

```bash
hvigor test -p product=default -p buildMode=debug
```

## 构建

调试构建：

```bash
hvigor assembleHap -p product=default -p buildMode=debug
```

发布构建：

```bash
hvigor assembleHap -p product=default -p buildMode=release
```

## 版权

Copyright (c) 2026 Ying Studio. All rights reserved.

本项目未使用 MIT、Apache-2.0 等开源许可证。未经授权，不得复制、修改、分发或用于商业用途。
