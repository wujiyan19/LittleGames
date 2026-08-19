/**
 * 统一 GamePanel — 所有游戏页面的标准化外框
 * 背景使用品牌渐变资源，深浅色模式自动适配
 */
import { DarkColors, SpacingTokens, ShadowTokens } from '../common/DesignTokens';
import { router } from '@kit.ArkUI';

@ComponentV2
export struct GamePanel {
  @Param showHeader: boolean = true;
  @BuilderParam headerContent?: () => void;
  @BuilderParam bodyContent: () => void;
  @BuilderParam overlayContent?: () => void;

  build() {
    Stack() {
      // 品牌渐变背景
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            [DarkColors.gradientScreen[0], 0],
            [DarkColors.gradientScreen[1], 0.4],
            [DarkColors.gradientScreen[2], 1]
          ]
        })

      Column() {
        if (this.showHeader) {
          this.headerContent!()
        } else {
          // 默认头部：返回按钮（40×40 热区）
          Row() {
            Button() {
              SymbolGlyph($r('sys.symbol.arrow_left'))
                .fontSize(18)
                .fontColor([DarkColors.textPrimary])
            }
            .type(ButtonType.Circle)
            .width(40).height(40)
            .backgroundColor(DarkColors.surface)
            .shadow(ShadowTokens.button)
            .onClick(() => router.back())
            Blank()
          }
          .width('100%')
          .padding({
            left: SpacingTokens.base,
            right: SpacingTokens.base,
            top: SpacingTokens.sm,
            bottom: SpacingTokens.sm
          })
          .backgroundColor(DarkColors.surfaceTranslucent)
          .backdropBlur(20)
        }
        this.bodyContent()
      }
      .width('100%').height('100%')

      if (this.overlayContent) {
        Column() { this.overlayContent!() }
          .width('100%').height('100%')
          .backgroundColor(DarkColors.scrim)
          .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
  }
}
