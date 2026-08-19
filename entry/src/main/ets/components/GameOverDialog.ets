/**
 * 统一游戏结束弹窗 — 宇宙蓝 × 雪域灰
 * 轻拟物磨砂质感 + 系统 Symbol 图标
 */
import { DarkColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';

@CustomDialog
export struct GameOverDialog {
  controller: CustomDialogController;
  score: number = 0;
  highScore: number = 0;
  isNewRecord: boolean = false;
  title: string = '游戏结束';
  subtitle: string = '';
  onRestart?: () => void;

  build() {
    Column() {
      // 图标徽章
      Column() {
        SymbolGlyph(this.isNewRecord ? $r('sys.symbol.star_fill') : $r('sys.symbol.gamecontroller'))
          .fontSize(44)
          .fontColor([this.isNewRecord ? DarkColors.warning : DarkColors.primary])
      }
      .width(84).height(84)
      .borderRadius(RadiusTokens.full)
      .backgroundColor(this.isNewRecord ? DarkColors.primaryLight : DarkColors.surfaceHover)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 28 })

      Text(this.title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeHeadline)
        .fontWeight(FontTokens.weightBold)
        .fontColor(DarkColors.textPrimary)
        .margin({ top: SpacingTokens.base })

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor(DarkColors.textSecondary)
          .margin({ top: SpacingTokens.xs })
      }

      // 得分卡片
      Column() {
        Text('最终得分')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeCaption)
          .fontColor(DarkColors.textTertiary)
          .margin({ bottom: SpacingTokens.xs })
        Text(this.score.toString())
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeMega)
          .fontWeight(FontTokens.weightBold)
          .fontColor(this.isNewRecord ? DarkColors.warning : DarkColors.primary)
      }
      .width('90%')
      .padding({ top: SpacingTokens.base, bottom: SpacingTokens.base })
      .backgroundColor(DarkColors.surface)
      .borderRadius(RadiusTokens.base)
      .margin({ top: SpacingTokens.lg })

      if (this.isNewRecord) {
        Row({ space: SpacingTokens.xs }) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(14)
            .fontColor([DarkColors.warning])
          Text('打破个人纪录！')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeBodySmall)
            .fontColor(DarkColors.warning)
            .fontWeight(FontTokens.weightMedium)
        }
        .margin({ top: SpacingTokens.sm })
      }

      // 操作区
      Row({ space: SpacingTokens.base }) {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(16)
            .fontColor([DarkColors.textOnPrimary])
        }
        .width(48).height(48)
        .borderRadius(RadiusTokens.full)
        .backgroundColor(DarkColors.primary)
        .shadow(ShadowTokens.button)
        .onClick(() => {
          this.onRestart?.();
          this.controller.close();
        })
      }
      .margin({ top: SpacingTokens.xl, bottom: SpacingTokens.xxl })
    }
    .width('85%')
    .borderRadius(RadiusTokens.xl)
    .padding({ left: SpacingTokens.base, right: SpacingTokens.base })
    .backgroundColor(DarkColors.surfaceTranslucent)
    .backdropBlur(30)
    .shadow(ShadowTokens.float)
    .border({ width: 1, color: DarkColors.border, radius: RadiusTokens.xl })
  }
}
