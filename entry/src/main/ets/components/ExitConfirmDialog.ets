/**
 * 退出对局确认弹窗 — 宇宙蓝 × 雪域灰
 *
 * 对局进行中点「返回」（或系统侧滑）时弹出：确认后退出（分数已由 ViewModel 结算保留），
 * 取消则回到对局。视觉沿用 GameResultDialog 的居中卡片语言。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';

@ComponentV2
export struct ExitConfirmDialog {
  @Param title: Resource | string = $r('app.string.exit_confirm_title');
  @Param description: Resource | string = $r('app.string.exit_confirm_desc');
  @Param confirmText: Resource | string = $r('app.string.exit_confirm_leave');
  @Param cancelText: Resource | string = $r('app.string.exit_confirm_stay');
  /** 确认退出：关闭弹窗并返回首页（分数由 ViewModel 的 dispose/onAppHidden 结算） */
  @Param onConfirm: () => void = () => {};
  /** 继续对局：仅关闭弹窗 */
  @Param onCancel: () => void = () => {};

  @Local actionTaken: boolean = false;
  private actionTimer: number = -1;

  aboutToDisappear(): void {
    if (this.actionTimer >= 0) { clearTimeout(this.actionTimer); this.actionTimer = -1; }
  }

  private choose(confirm: boolean): void {
    if (this.actionTaken) { return; }
    this.actionTaken = true;
    this.actionTimer = setTimeout(() => {
      this.actionTimer = -1;
      if (confirm) { this.onConfirm(); } else { this.onCancel(); }
    }, HarmonyMotion.value(this.getUIContext(), $r('app.float.motion_action_guard_duration'), 320));
  }

  build() {
    Column() {
      Column({ space: SpacingTokens.md }) {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(34)
            .fontWeight(FontWeight.Medium)
            .fontColor([SemanticColors.warning])
        }
        .width(64).height(64)
        .borderRadius(RadiusTokens.full)
        .backgroundColor(SemanticColors.surfaceHover)
        .justifyContent(FlexAlign.Center)

        Text(this.title)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeHeadline)
          .fontWeight(FontTokens.weightBold)
          .fontColor(SemanticColors.textPrimary)
          .width('100%').textAlign(TextAlign.Center)

        Text(this.description)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(SemanticColors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)

        Row({ space: SpacingTokens.base }) {
          Button() {
            Text(this.cancelText)
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody)
              .fontWeight(FontTokens.weightMedium)
              .fontColor(SemanticColors.textPrimary)
              .width('100%').textAlign(TextAlign.Center)
          }
          .type(ButtonType.Normal).layoutWeight(1)
          .constraintSize({ minHeight: $r('app.float.home_action_min_height') })
          .padding({ left: SpacingTokens.md, right: SpacingTokens.md, top: SpacingTokens.md, bottom: SpacingTokens.md })
          .backgroundColor(SemanticColors.surfaceHover)
          .borderRadius(RadiusTokens.md)
          .clickEffect(HarmonyMotion.press(this.getUIContext()))
          .enabled(!this.actionTaken)

          .onClick(() => { this.choose(false); })

          Button() {
            Text(this.confirmText)
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody)
              .fontWeight(FontTokens.weightSemibold)
              .fontColor(SemanticColors.textOnPrimary)
              .width('100%').textAlign(TextAlign.Center)
          }
          .type(ButtonType.Normal).layoutWeight(1)
          .constraintSize({ minHeight: $r('app.float.home_action_min_height') })
          .padding({ left: SpacingTokens.md, right: SpacingTokens.md, top: SpacingTokens.md, bottom: SpacingTokens.md })
          .backgroundColor(SemanticColors.primary)
          .borderRadius(RadiusTokens.md)
          .clickEffect(HarmonyMotion.press(this.getUIContext()))
          .enabled(!this.actionTaken)

          .onClick(() => { this.choose(true); })
        }
        .width('100%')
        .margin({ top: SpacingTokens.sm })
      }
      .width('86%')
      .constraintSize({ maxWidth: $r('app.float.motion_dialog_max_width') })
      .padding(SpacingTokens.xl)
      .borderRadius(RadiusTokens.xl)
      .backgroundColor($r('app.color.surface'))
      .shadow(ShadowTokens.float)
      .alignItems(HorizontalAlign.Center)
      .renderGroup(true)
      .scale({
        x: HarmonyMotion.closeScale(this.getUIContext(), this.actionTaken),
        y: HarmonyMotion.closeScale(this.getUIContext(), this.actionTaken)
      })
      .translate({ y: HarmonyMotion.closeOffset(this.getUIContext(), this.actionTaken) })
      .opacity(this.actionTaken ? 0 : 1)
      .animation(HarmonyMotion.exit(this.getUIContext()))
      .transition(HarmonyMotion.dialog(this.getUIContext()))
    }
    .width('100%').height('100%')
    .backgroundColor(SemanticColors.scrim)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .justifyContent(FlexAlign.Center)
    .opacity(this.actionTaken ? 0 : 1)
    .animation(HarmonyMotion.exit(this.getUIContext()))
    .transition(HarmonyMotion.scrim(this.getUIContext()))
    .onClick(() => {})
  }
}
