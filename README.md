# Happy Tree Friends

适用于《魔兽世界》正式服 12.1 的轻量实用功能合集插件。当前版本为 `0.4.0`，包含：

- 自动修理（可选个人金币，或公会银行优先）
- 自动售卖可出售的灰色物品
- 友方仅姓名模式：保留友方玩家姓名并隐藏血条等姓名板信息
- 可锁定、可拖动并带高对比描边的透明角色属性悬浮层
- 每项属性独立显示/隐藏、文字颜色和全局字号设置
- 精致的左右布局管理页与可选调试模式
- 根据客户端语言自动切换简体中文或英文

## 安装

将整个 `HappyTreeFriends` 文件夹复制到正式服客户端的插件目录：

```text
World of Warcraft/_retail_/Interface/AddOns/HappyTreeFriends/
```

目录内应直接包含 `HappyTreeFriends.toc`、`Core.lua` 等文件，不能多嵌套一层同名目录。登录角色选择界面后，在“插件”中确认 `Happy Tree Friends` 已启用。

## 使用

- `/htf`：打开设置
- `/htf stats`：直接打开属性悬浮层设置页
- `/htf merchant`：直接打开商人功能页
- `/htf nameplates`：直接打开友方姓名设置页
- `/htf debug`：快速开关调试模式
- `/htf dump`：打开调试页并生成可复制的诊断报告
- `/htf clearlog`：清空持久化调试日志
- `/htf help`：显示命令帮助

插件设置页采用左侧分类、右侧功能内容的布局；为保护金币、物品与现有界面习惯，首次安装时自动修理、自动售卖灰色物品、公会维修和友方仅姓名模式默认关闭，属性悬浮层默认开启并锁定，调试模式默认关闭。启用相应开关后立即生效。

## 语言

- `zhCN` 客户端使用简体中文。
- `enUS` 客户端使用英文。
- 其他尚未提供单独翻译的客户端语言默认回退到英文。

### 属性悬浮层

1. 输入 `/htf stats` 打开“角色属性”。
2. 关闭“锁定属性悬浮层”，游戏画面会出现带边框的拖动区域。
3. 用鼠标左键拖到合适位置，再重新锁定。锁定后背景和边框完全透明，也不会拦截鼠标。
4. 在同一页面逐项选择显示/隐藏，点击每行右侧色块调整文字颜色，并用 `−` / `+` 修改全局字号。

位置、锁定状态、字号、每项可见性与颜色均保存在 `HappyTreeFriendsDB` 中，`/reload` 和重新登录后仍会保留。

### 友方仅姓名模式

“友方仅姓名模式”开启时会先保存以下当前设置，再应用仅姓名显示：

- `UnitNameFriendlyPlayerName`：开启友方玩家姓名。
- `nameplateShowFriendlyPlayers`：开启友方玩家姓名板。
- `nameplateShowOnlyNameForFriendlyPlayerUnits`：使用暴雪自带的友方玩家仅姓名样式，隐藏血条、施法条、光环和其他姓名板信息。

关闭该功能后会精确恢复开启前保存的值；如果某项暂时无法恢复，快照不会被清除，插件会在角色再次进入世界时重试。功能开启期间如果相关 CVar 被游戏设置或其他插件修改，Happy Tree Friends 会合并一次重新应用。若客户端没有第三项原生仅姓名 CVar，则回退为开启友方姓名并关闭友方姓名板。

### 公会银行维修

“优先使用公会银行维修”只有在“自动修理”同时开启时生效：

- 关闭：始终调用个人金币修理。
- 开启且角色有公会维修权限：先使用当前可用的公会维修额度，额度不足时由个人金币补足。
- 没有权限、没有额度或额度不可安全读取：回退到纯个人金币修理。
- 公会额度与个人金币合计不足：跳过修理，不主动产生部分扣款。

## 12.1 / 12.0+ API 兼容策略

- TOC 使用 `## Interface: 120100`，目标为 Retail 12.1.0。
- 自动售卖使用当前客户端的 `C_MerchantFrame.GetNumJunkItems()` 与 `C_MerchantFrame.SellAllJunkItems()`，不依赖旧式背包遍历或已弃用容器 API。
- 自动修理沿用暴雪 12.1 商人界面的 `CanMerchantRepair()`、`GetRepairAllCost()` 与 `RepairAllItems()`；个人修理调用 `RepairAllItems()`，公会优先调用 `RepairAllItems(true)`，并在调用前安全检查权限、维修额度与所需个人补款。
- 友方仅姓名模式使用当前客户端的 `C_CVar.GetCVar()` / `C_CVar.SetCVar()`，并由暴雪 `nameplateShowOnlyNameForFriendlyPlayerUnits` 控制友方玩家姓名板的仅姓名布局。
- 属性读取逐项通过 `issecretvalue()` 防护。12.0 引入的受限/Secret Value 不会被格式化、比较或拼接；战斗中会延迟到脱战后刷新，受限字段显示为“受限”。
- 暴击显示沿用暴雪角色面板口径：在法术、远程与近战暴击中选择当前面板使用的数值。
- 颜色选择器使用 12.1 的 `ColorPickerFrame:SetupColorPickerAndShow(info)` 回调模式，不依赖旧版全局回调字段。

## 性能

没有 `OnUpdate` 循环、没有常驻背包扫描，也不监听战斗日志。商人功能只在打开商人窗口时执行一次；属性悬浮层只在启用时因进入世界、装备/专精/属性变化或脱战合并刷新一次；友方仅姓名模式只响应所管理的 CVar 变化，并合并到下一帧校正。被隐藏的属性不会调用对应读取 API。

## 调试与验证

开启“调试模式”后，插件会在聊天框输出带 `[HTF Debug]` 前缀的运行记录，并在 SavedVariables 中持久化最近 80 条；这些日志会跨 `/reload` 与重新登录保留。调试页默认展示最近 11 条，文本框可直接选择和复制。

输入 `/htf dump` 会生成包含插件版本、WoW build、Interface 版本、开关状态、商人流程状态和持久化日志的诊断报告，并自动全选文本。在 macOS 上按 `Command+C`，Windows 上按 `Ctrl+C` 即可复制。报告不会包含账号名、角色名或服务器名。

如果 WoW 安装在另一台机器上，推荐按以下方式远程验收：

1. 安装插件并输入 `/console scriptErrors 1`。
2. 输入 `/htf debug` 开启调试，复现问题。
3. 输入 `/htf dump`，复制完整报告并连同 Lua 报错堆栈发回。
4. 如需从文件取日志，正常退出游戏或执行 `/reload` 后，在该机器的 `WTF/Account/<账号目录>/SavedVariables/HappyTreeFriends.lua` 中查找 `debugLog`。

建议的游戏内验收顺序：

1. 登录后输入 `/htf`，确认设置页五个左侧分类能切换。
2. 在暴雪选项中设置一组可辨认的友方姓名/姓名板状态；开启“友方仅姓名模式”，确认只显示友方玩家姓名，再关闭并确认原状态完整恢复。
3. 解锁属性悬浮层并拖动，重新锁定后确认背景透明、鼠标可正常点击其下方界面；再测试逐项隐藏、字号和颜色。
4. 勾选调试模式，前往可修理商人；分别验证纯个人修理，以及有权限角色的公会银行优先修理。
5. 放入一个有售价的灰色物品后再次打开商人；确认它被自动出售。
6. 装备/卸下一件装备验证悬浮层数值刷新；在战斗中确认保留旧值并提示脱战后刷新，而不是报 Lua 错。

不安装 WoW 客户端也可以运行仓库内的无客户端回归测试（首次执行会由 npm 临时下载 Fengari）：

```bash
npx --yes --package=fengari-node-cli fengari tests/headless.lua
```

该测试覆盖默认设置、友方姓名 CVar 快照/应用/精确恢复/失败重试及旧客户端回退、HUD 透明/锁定/拖动与位置持久化、逐项可见性、字体和颜色、Secret Value 安全降级、暴击口径、公会/个人维修分支、商人操作与战斗后重试、持久化日志及诊断报告。它用于提前发现 Lua 逻辑回归，最终仍应以上述游戏内验收为准。

## 参考的当前客户端 API

- [Blizzard 12.1 MerchantFrame source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua)
- [Blizzard 12.1 MerchantFrame XML（个人/公会维修按钮）](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml)
- [Blizzard 12.1 Container API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
- [Blizzard 12.1 Player API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)
- [Blizzard 12.1 PaperDoll source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua)
- [Blizzard 12.1 Settings source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua)
- [Blizzard 12.1 Nameplate settings definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua)
- [Blizzard 12.1 NamePlate unit frame source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua)
- [Blizzard 12.1 ColorPickerFrame source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua)
- [Blizzard 12.1 ScrollFrame templates](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.xml)
