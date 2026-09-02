/**
 * 统一方向控制面板 — 宇宙蓝 × 雪域灰
 * 方向键使用系统 Symbol 图标，按键高度 ≥ 48vp（热区 ≥ 40vp）
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct ControlPad {
  @Param buttonSize: number = 56;
  @Param showCenter: boolean = false;
  @Param centerLabel: string = '';
  @Param onUp: () => void = () => {};
  @Param onDown: () => void = () => {};
  @Param onLeft: () => void = () => {};
  @Param onRight: () => void = () => {};
  @Param onCenter: () => void = () => {};
  @BuilderParam actionButtons?: () => void;

  getCenterOpacity(): number {
    if (this.showCenter) { return 1; }
    return 0.3;
  }

  build() {
    Column({ space: SpacingTokens.sm }) {
      if (this.actionButtons) {
        this.actionButtons!()
        Blank().height(4)
      }
      // 上
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_up'))
          .fontSize(18)
          .fontColor([SemanticColors.textPrimary])
      }
      .width(this.buttonSize).height(48)
      .backgroundColor(SemanticColors.surface)
      .borderRadius(RadiusTokens.base)
      .shadow(ShadowTokens.button)
      .onClick(() => { this.onUp(); })

      // 左 / 中 / 右
      Row({ space: SpacingTokens.md }) {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(18)
            .fontColor([SemanticColors.textPrimary])
        }
        .width(this.buttonSize).height(48)
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.base)
        .shadow(ShadowTokens.button)
        .onClick(() => { this.onLeft(); })

        Button() {
          if (this.centerLabel.length > 0) {
            Text(this.centerLabel)
              .fontFamily(FontTokens.family)
              .fontSize(14)
              .fontWeight(FontTokens.weightMedium)
              .fontColor(SemanticColors.textPrimary)
          } else {
            Circle({ width: 10, height: 10 }).fill(SemanticColors.textPrimary)
          }
        }
        .width(this.buttonSize).height(48)
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.base)
        .opacity(this.getCenterOpacity())
        .shadow(ShadowTokens.button)
        .onClick(() => { this.onCenter(); })

        Button() {
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(18)
            .fontColor([SemanticColors.textPrimary])
        }
        .width(this.buttonSize).height(48)
        .backgroundColor(SemanticColors.surface)
        .borderRadius(RadiusTokens.base)
        .shadow(ShadowTokens.button)
        .onClick(() => { this.onRight(); })
      }

      // 下
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_down'))
          .fontSize(18)
          .fontColor([SemanticColors.textPrimary])
      }
      .width(this.buttonSize).height(48)
      .backgroundColor(SemanticColors.surface)
      .borderRadius(RadiusTokens.base)
      .shadow(ShadowTokens.button)
      .onClick(() => { this.onDown(); })
    }
  }
}
