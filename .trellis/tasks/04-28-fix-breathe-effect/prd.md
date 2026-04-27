# fix: 账号检测中呼吸效果增强

## Goal

增强 AccountCard 状态点的呼吸动画，使账号列表刷新时用户能清晰感知哪些账号正在检测中。

## What I already know

- `_StatusDot` (account_card.dart L177-262) 使用 `AnimationController(duration: 1200ms, repeat(reverse: true))`
- 当前动画参数: scale 0.85↔1.15 (幅度 0.30), opacity 0.5↔1.0 (幅度 0.5)
- 点大小仅 10px，配合微弱幅度难以察觉
- `boxShadow` blurRadius=8, spreadRadius=0, alpha=0.4

## Fix Strategy

增强以下参数：
- scale: 0.70 ↔ 1.40 (幅度从 0.30 提升到 0.70)
- opacity: 0.25 ↔ 1.0 (幅度从 0.5 提升到 0.75)
- boxShadow: spreadRadius 随 scale 同步脉动，blurRadius 增大
- duration: 保持 1200ms 或微调至 1000ms

## Acceptance Criteria

- [ ] 检测中的状态点有明显的呼吸脉动效果
- [ ] 非检测状态不受影响

## Files

- `lib/features/accounts/presentation/widgets/account_card.dart` — _StatusDot widget
