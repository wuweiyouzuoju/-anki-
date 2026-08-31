# 输入框焦点主题与按钮按压态回归修复设计

## 目标

保留输入答案框最终有效的焦点主题修复，同时消除该修复扩散到全应用后造成的设置页帮助按钮灰闪和学习页六个操作按钮整组蓝闪。最终行为以 2.0.1 的按钮交互为基线：只有实际按下的按钮产生反馈，设置分组展开时新出现的帮助按钮不闪背景。

## 已确认的因果链

2.0.1 与当前版本的学习页六按钮代码，在去掉后来无效的 `stateEffect(false)` 后逐字符一致。因此六按钮源码本身不是版本差异。

输入答案框先后叠加了三类处理：

1. 外层 `Column` 的左右内边距、底部避让和 `surface_card` 背景解决输入框宽度、手势导航条遮挡及页面主题色横带。
2. `stateStyles` 与 `focusBox` 约束输入框自身的边框、背景及外部焦点框。
3. 最后在 `EntryAbility.onCreate()` 调用 `ThemeControl.setDefaultTheme()`，将五个焦点 token 设为透明。这一步最终覆盖了系统主题绘制层，但作用域是整个 Ability，所有 ArkUI 内置组件都会受到影响。

全局主题覆盖是 2.0.1 与当前版本之间唯一同时改变设置页 `Button` 和学习页 `Button` 默认交互主题的新增代码。设置页的条件节点在整组 `animateTo` 中创建、学习页六按钮由一个页面级状态共同刷新，又分别放大了焦点主题切换的瞬时效果。此前新增 `stateEffect(false)` 只关闭原生按压切换，不控制焦点主题或显式动画，因而无效。

## 设计

### 输入答案框

- 删除 `EntryAbility` 中 Ability 级 `ThemeControl.setDefaultTheme()` 及对应导入。
- 在学习页只用 `WithTheme` 包裹输入答案 `TextInput`，局部覆写与最终有效补丁相同的五个焦点 token：`compBackgroundFocus`、`compFocusedPrimary`、`compFocusedSecondary`、`compFocusedTertiary`、`interactiveFocus`。
- 保留外层 `Column`、左右内边距、float 模式底部避让、`surface_card` 背景、`stateStyles`、`focusBox`、Enter 提交和输入内容更新。各层职责不同，不删除已解决的布局和输入行为。
- 局部主题中只改焦点 token，不改 `interactivePressed`、`interactiveHover`、品牌色或其他系统 token。

### 设置分组

- 保留统一 `设置分组卡片` 外壳、标题、帮助按钮、色板、方框、圆角和旋转三角。
- 标题行点击直接调用展开回调，不再用 `animateTo` 包住整个状态更新。
- 三角自身继续使用 150ms EaseOut `.animation()`，因此只有角度变化参与动画；帮助按钮和内容节点直接创建或移除，不进入整组隐式动画。
- 帮助按钮继续使用透明背景和现有点击行为。删除为错误假设增加的 `stateEffect(false)`；其视觉不再依赖全局主题补丁。

### 学习操作按钮

- 新增专用于学习答案条的局部状态组件，每个实例持有自己的 `@State` 按下布尔值。
- 埋藏、暂停、Again、Hard、Good、Easy 六个按钮分别使用一个实例；按下只更新该实例，松开或取消只恢复该实例。
- 保持现有文案、字号、文字色、背景色、边框、圆角、高度、行权重、80ms EaseOut 反馈和业务回调不变。Good 的按下边框仍使用动作主色。
- 删除页面级 `按下评分`、辅助伪 rating tag 及六处共享状态判断。评分值、埋藏/暂停模式、点击调用和 Anki 调度链路不变。
- 组件内显式关闭原生 `stateEffect`，使自定义局部状态成为唯一按压背景来源；这里的关闭是防止单个按钮出现双重反馈，不再被误写成整组闪烁的根因。

## 测试设计

先修改契约测试并确认红灯，再修改生产代码：

1. 入口能力不得调用 `ThemeControl.setDefaultTheme`。
2. 输入答案框必须位于局部 `WithTheme` 内，且五个焦点 token 完整、无 `interactivePressed` 覆写；既有布局、`stateStyles` 和 `focusBox` 仍存在。
3. 设置分组的展开回调不得位于 `animateTo` 中；箭头必须保留局部 150ms 动画。
4. 学习页不得保留页面级 `按下评分`；六个业务按钮必须使用独立状态组件，组件必须在 Down/Up/Cancel 间维护本地状态。
5. 完整运行 `npm test` 和 `npm run build:app`。

自动契约测试只证明作用域和状态所有权，不宣称能证明瞬时视觉。动态验收必须捕获连续帧：逐个按六个学习按钮时其余按钮不变；展开调度器、学习布局等分组时帮助按钮无灰色背景帧；输入答案框聚焦后仍无原主题色块。无法连接实体设备时必须明确记录为待真机验证，不能用静态截图替代。

## 范围边界

- 不修改 Anki Rust、protobuf、NAPI、数据库、调度算法或卡片队列。
- 不修改 Agent 制卡/改卡的模型、工具、草稿和写入边界。
- 不改变输入答案题的字段识别、逐字符比对、Enter 翻面或卡片渲染。
- 不回退统一设置分组组件，只收窄其动画作用域。

