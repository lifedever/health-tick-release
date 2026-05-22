# 国家节假日日历查看 — 技术说明

| 项目 | 说明 |
|------|------|
| 文档日期 | 2026-05-21 |
| 功能名称 | 国家节假日同步后日历查看 |
| 文档类型 | 技术设计（Tech） |
| 主要语言 | Swift 5.9+ / SwiftUI |

---

## 1. 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│  SettingsView (AppTab)                                       │
│  · Toggle holidaySyncEnabled                                 │
│  · syncNationalHolidays() → HolidayCalendarService             │
│  · showHolidayCalendar → .sheet(HolidayCalendarView)         │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌─────────────────────┐           ┌─────────────────────┐
│ HolidayCalendarService│           │ HolidayCalendarView │
│ · HTTP sync          │           │ · Month grid UI     │
│ · HolidaySyncResult  │           │ · Day detail        │
└──────────┬───────────┘           └──────────┬──────────┘
           │                                   │
           └──────────────┬────────────────────┘
                          ▼
                 ┌─────────────────┐
                 │ AppConfig        │
                 │ · holidayCalendar│
                 │ · holidayCalendarNames
                 │ · holidayDayKind │
                 │ · isWorkDay      │
                 └────────┬─────────┘
                          ▼
                 ┌─────────────────┐
                 │ Database (SQLite)│
                 │ config KV table  │
                 └─────────────────┘
```

日历视图**只读**，不修改配置；工作日逻辑仍由 `AppConfig.isWorkDay(at:)` 统一供计时器与休息时段使用。

---

## 2. 文件变更清单

| 文件 | 变更类型 | 职责 |
|------|----------|------|
| `Sources/HolidayCalendar.swift` | 修改 | API 同步、类型定义、工作日解析 |
| `Sources/HolidayCalendarView.swift` | 新增 | 月历 Sheet UI |
| `Sources/SettingsView.swift` | 修改 | 入口按钮、同步后打开 Sheet |
| `Sources/AppState.swift` | 修改 | `holidayCalendarNames` 配置字段 |
| `Sources/Database.swift` | 修改 | 持久化 `holiday_calendar_names` |
| `Sources/Strings.swift` | 修改 | 中英文文案 |

---

## 3. 外部 API

**提供方：** [timor.tech](https://timor.tech/) 节假日接口  

**请求：**

```
GET https://timor.tech/api/holiday/year/{year}
Timeout: 15s
```

**响应（节选）：**

```json
{
  "code": 0,
  "holiday": {
    "01-01": {
      "holiday": true,
      "name": "元旦",
      "date": "2025-01-01"
    },
    "01-26": {
      "holiday": false,
      "name": "春节前补班",
      "date": "2025-01-26"
    }
  }
}
```

**字段语义：**

| 字段 | 含义 |
|------|------|
| `holiday: true` | 放假 |
| `holiday: false` | 调休上班 |
| `name` | 可选，展示用 |
| `date` | `yyyy-MM-dd`，存储键 |

**同步策略：** `syncNationalHolidays()` 并行逻辑上顺序请求 `year` 与 `year+1`（以上海时区当前年为准），合并为单个 `HolidaySyncResult`。

---

## 4. 数据模型

### 4.1 `HolidaySyncResult`

```swift
struct HolidaySyncResult {
    var workDayOverrides: [String: Bool]  // date → isWorkDay
    var labels: [String: String]          // date → display name
}
```

**映射规则（写入时）：**

```swift
workDayOverrides[entry.date] = !entry.holiday
// holiday=true  → false（不计入工作日）
// holiday=false → true （调休上班）
```

### 4.2 `AppConfig` 持久化字段

| Key | 类型 | 说明 |
|-----|------|------|
| `holiday_sync_enabled` | `"0"` / `"1"` | 开关 |
| `holiday_calendar` | JSON `[String: Bool]` | 国务院表内日期覆盖 |
| `holiday_calendar_names` | JSON `[String: String]` | **本次新增**，日期名称 |
| `holiday_calendar_synced_at` | ISO8601 字符串 | 上次同步时间 |
| `work_days` | JSON `Set<Int>` | 默认工作日（Calendar weekday） |

旧版本无 `holiday_calendar_names` 时解码失败则保持默认空字典，兼容升级。

### 4.3 `HolidayDayKind`

```swift
enum HolidayDayKind {
    case rest          // 国务院：放假
    case makeupWork    // 国务院：调休上班
    case defaultWork   // 回退：用户在 workDays 中
    case defaultOff    // 回退：不在 workDays 中
}
```

解析入口：`AppConfig.holidayDayKind(at:)`  

```swift
if holidaySyncEnabled, let explicit = holidayCalendar[key] {
    return explicit ? .makeupWork : .rest
}
return workDays.contains(weekday) ? .defaultWork : .defaultOff
```

`isWorkDay(at:)` 实现为 `holidayDayKind(at:).countsAsWorkDay`，避免逻辑分叉。

---

## 5. UI 实现（`HolidayCalendarView`）

### 5.1 呈现方式

- `SettingsView.AppTab` 使用 `@State private var showHolidayCalendar`
- `.sheet(isPresented: $showHolidayCalendar) { HolidayCalendarView().environment(state) }`

### 5.2 月历网格算法

1. 取 `displayedYear` / `displayedMonth` 当月 1 日（`HolidayCalendarService.chinaCalendar`）；
2. 计算 leading blanks：`(weekday - firstWeekday + 7) % 7`，`firstWeekday = 1`（周日）；
3. 填充 `1...daysInMonth`，尾部补齐至 7 的倍数；
4. 每格调用 `config.holidayDayKind(at:)` 决定颜色与字重。

### 5.3 状态

| `@State` | 用途 |
|----------|------|
| `displayedYear` / `displayedMonth` | 当前浏览月份 |
| `selectedDate` | 详情面板，默认今天 |

### 5.4 命名注意

Swift Charts 等框架存在 `legend` 符号；月历图例视图命名为 `legendView`，避免与 Swift 解析冲突。

---

## 6. 同步流程（`AppTab.syncNationalHolidays`）

```
用户点击「立即同步」
    → isSyncingHolidays = true
    → Task { HolidayCalendarService.syncNationalHolidays() }
        ├─ 成功 → MainActor
        │     · holidayCalendar = result.workDayOverrides
        │     · holidayCalendarNames = result.labels
        │     · holidayCalendarSyncedAt = ISO8601 now
        │     · showHolidayCalendar = true
        └─ 失败 → holidaySyncError = localizedDescription
    → isSyncingHolidays = false
```

`AppState` 监听 `holidayCalendar` / `holidayCalendarNames` 变化时会触发 `checkQuietHours()`（与 `workDays` 变更相同路径）。

---

## 7. 时区与日期键

统一使用：

```swift
static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!
```

`AppConfig.dateKey(for:)` 格式：`yyyy-MM-dd`，Gregorian + 上海时区。

月历 `Calendar` 实例：`HolidayCalendarService.chinaCalendar`（`firstWeekday = 1`，locale 随 `L.isZhAccess`）。

---

## 8. 本地化

新增 `L.*` 键（见 `Strings.swift`）：

- `holidayViewCalendar`, `holidayCalendarTitle`, `holidayCalendarEmpty`
- `holidayKindRest`, `holidayKindMakeup`, `holidayKindDefaultWork`, `holidayKindDefaultOff`
- `holidayCountsAsWork`, `holidayCountsAsOff`
- `holidayInOfficialSchedule`, `holidayByWeekday`
- `holidayMonthTitle(year:month:)`

`HolidayDayKind.label` / 错误类型 `HolidayCalendarError` 均走 `L` 结构。

---

## 9. 测试建议

| 类别 | 建议 |
|------|------|
| 单元 | `holidayDayKind`：表内放假/调休、表外工作日/休息日组合 |
| 单元 | `dateKey` 跨时区边界（23:00 UTC 等） |
| 集成 | Mock URLSession 返回 timor JSON，验证 `HolidaySyncResult` 解析 |
| UI | 同步成功后 Sheet 弹出；空数据空状态 |
| 回归 | `isWorkDay` 与变更前行为一致（尤其调休上班日） |

现有 `Tests/test_update_checker.swift` 未覆盖本功能；可按上表补充。

---

## 10. 已知限制与后续扩展

| 限制 | 说明 |
|------|------|
| 数据源单一 | 仅 timor.tech；API 不可用则无法同步 |
| 名称缺失 | 旧同步记录无 `holiday_calendar_names`，需重新同步 |
| 无离线编辑 | 用户不能手动修正错误安排 |
| Sheet 尺寸固定 | 420pt 宽，未适配超大屏 |

**可选后续：**

- 启动时若开启同步且数据过期（如跨年）自动后台刷新；
- 在月历格子上直接显示节假日简称；
- 将日历提取为可复用组件供统计页引用。

---

## 11. 构建与验证

```bash
cd health-tick-release
swift build
./build.sh   # 安装 HealthTick Dev 到 ~/Applications
```

手动验证路径：**设置 → 应用 → 同步国家节假日 → 立即同步 → 检查日历 Sheet**。

---

## 12. 相关文档

- 产品规格见 [2026-05-21-holiday-calendar-spec.md](./2026-05-21-holiday-calendar-spec.md)
