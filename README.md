# Happy Tree Friends

适用于《魔兽世界》正式服 12.1 的轻量实用功能合集插件。当前版本为 `0.1.1`，MVP 包含：

- 自动修理（只用个人金币）
- 自动售卖可出售的灰色物品
- 角色主要属性、副属性与三级属性展示
- 精致的左右布局管理页与可选调试模式

## 安装

将整个 `HappyTreeFriends` 文件夹复制到正式服客户端的插件目录：

```text
World of Warcraft/_retail_/Interface/AddOns/HappyTreeFriends/
```

目录内应直接包含 `HappyTreeFriends.toc`、`Core.lua` 等文件，不能多嵌套一层同名目录。登录角色选择界面后，在“插件”中确认 `Happy Tree Friends` 已启用。

## 使用

- `/htf`：打开设置
- `/htf stats`：直接打开角色属性页
- `/htf merchant`：直接打开商人功能页
- `/htf debug`：快速开关调试模式
- `/htf dump`：打开调试页并生成可复制的诊断报告
- `/htf clearlog`：清空持久化调试日志
- `/htf help`：显示命令帮助

插件设置页采用左侧分类、右侧功能内容的布局；为保护金币与物品，首次安装时自动修理和自动售卖灰色物品默认关闭，角色属性页默认开启，调试模式默认关闭。启用相应开关后立即生效。

## 12.1 / 12.0+ API 兼容策略

- TOC 使用 `## Interface: 120100`，目标为 Retail 12.1.0。
- 自动售卖使用当前客户端的 `C_MerchantFrame.GetNumJunkItems()` 与 `C_MerchantFrame.SellAllJunkItems()`，不依赖旧式背包遍历或已弃用容器 API。
- 自动修理沿用暴雪 12.1 商人界面仍在使用的 `CanMerchantRepair()`、`GetRepairAllCost()`、`RepairAllItems()`；只在 `MERCHANT_SHOW` 后一次执行。
- 属性读取逐项通过 `issecretvalue()` 防护。12.0 引入的受限/Secret Value 不会被格式化、比较或拼接；战斗中会延迟到脱战后刷新，受限字段显示为“受限”。
- 暴击显示沿用暴雪角色面板口径：在法术、远程与近战暴击中选择当前面板使用的数值；角色名与职业等条件 Secret Value 也会安全降级。

## 性能

没有 `OnUpdate` 循环、没有常驻背包扫描，也不监听战斗日志。商人功能只在打开商人窗口时执行一次；属性页仅在设置窗口中的属性页实际可见时，因装备/属性变化或脱战合并刷新一次。

## 调试与验证

开启“调试模式”后，插件会在聊天框输出带 `[HTF Debug]` 前缀的运行记录，并在 SavedVariables 中持久化最近 80 条；这些日志会跨 `/reload` 与重新登录保留。调试页默认展示最近 11 条，文本框可直接选择和复制。

输入 `/htf dump` 会生成包含插件版本、WoW build、Interface 版本、开关状态、商人流程状态和持久化日志的诊断报告，并自动全选文本。在 macOS 上按 `Command+C`，Windows 上按 `Ctrl+C` 即可复制。报告不会包含账号名、角色名或服务器名。

如果 WoW 安装在另一台机器上，推荐按以下方式远程验收：

1. 安装插件并输入 `/console scriptErrors 1`。
2. 输入 `/htf debug` 开启调试，复现问题。
3. 输入 `/htf dump`，复制完整报告并连同 Lua 报错堆栈发回。
4. 如需从文件取日志，正常退出游戏或执行 `/reload` 后，在该机器的 `WTF/Account/<账号目录>/SavedVariables/HappyTreeFriends.lua` 中查找 `debugLog`。

建议的游戏内验收顺序：

1. 登录后输入 `/htf`，确认设置页四个左侧分类能切换。
2. 勾选调试模式，前往可修理商人；确认自动修理只在装备有损耗且金币充足时发生。
3. 放入一个有售价的灰色物品后再次打开商人；确认它被自动出售。
4. 打开“角色属性”，装备/卸下一件装备验证数值刷新；在战斗中确认页面提示会在脱战后刷新而不是报 Lua 错。

不安装 WoW 客户端也可以运行仓库内的无客户端回归测试（首次执行会由 npm 临时下载 Fengari）：

```bash
npx --yes --package=fengari-node-cli fengari tests/headless.lua
```

该测试覆盖默认设置、Secret Value 安全降级、暴击口径、隐藏页面不刷新、商人操作与战斗后重试、持久化日志及诊断报告。它用于提前发现 Lua 逻辑回归，最终仍应以上述游戏内验收为准。

## 参考的当前客户端 API

- [Blizzard 12.1 MerchantFrame source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua)
- [Blizzard 12.1 Container API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
- [Blizzard 12.1 Player API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)
- [Blizzard 12.1 PaperDoll source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua)
- [Blizzard 12.1 Settings source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua)
- [Blizzard 12.1 ScrollFrame templates](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.xml)
