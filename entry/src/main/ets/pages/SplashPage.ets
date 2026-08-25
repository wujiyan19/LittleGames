/**
 * 闪屏页 — 宇宙蓝 × 雪域灰
 */
import { BrandColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';

@Entry
@ComponentV2
struct SplashPage {
  @Local iconAnimOpacity: number = 0;
  @Local iconAnimScale: number = 0.6;
  @Local iconAnimTranslateY: number = 20;
  @Local titleAnimOpacity: number = 0;
  @Local subtitleAnimOpacity: number = 0;

  aboutToAppear(): void {
    this.startAnimation();
  }

  startAnimation(): void {
    this.getUIContext().animateTo({
      duration: 600,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.iconAnimOpacity = 1;
      this.iconAnimScale = 1;
      this.iconAnimTranslateY = 0;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 400,
        curve: Curve.EaseOut
      }, () => {
        this.titleAnimOpacity = 1;
      });
      setTimeout(() => {
        this.getUIContext().animateTo({
          duration: 300,
          curve: Curve.EaseOut
        }, () => {
          this.subtitleAnimOpacity = 1;
        });
        setTimeout(() => {
          this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
        }, 800);
      }, 300);
    }, 600);
  }

  build() {
    Stack() {
      // 品牌渐变背景
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 160,
          colors: [
            [BrandColors.deepSpace, 0],
            ['#16205F', 0.5],
            ['#2A2B7E', 1]
          ]
        })

      // 装饰光斑（轻拟物质感）
      Circle({ width: 260, height: 260 })
        .fill('rgba(93, 134, 255, 0.25)')
        .blur(60)
        .position({ x: -80, y: -40 })
      Circle({ width: 220, height: 220 })
        .fill('rgba(122, 90, 248, 0.22)')
        .blur(60)
        .position({ x: '72%', y: '68%' })

      Column() {
        // 品牌图标徽章
        Column() {
          SymbolGlyph($r('sys.symbol.gamecontroller'))
            .fontSize(72)
            .fontWeight(FontWeight.Medium)
            .fontColor([BrandColors.cosmicBlueBright, BrandColors.auroraPurpleBright])
        }
        .width(152).height(152)
        .borderRadius(RadiusTokens.full)
        .backgroundColor('rgba(255, 255, 255, 0.10)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.22)', radius: RadiusTokens.full })
        .backdropBlur(20)
        .shadow(ShadowTokens.float)
        .opacity(this.iconAnimOpacity)
        .scale({ x: this.iconAnimScale, y: this.iconAnimScale })
        .translate({ y: this.iconAnimTranslateY })

        Text('小游戏合集')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeDisplay)
          .fontWeight(FontTokens.weightBold)
          .fontColor('#FFFFFF')
          .opacity(this.titleAnimOpacity)
          .margin({ top: 28 })

        Text('宇宙蓝 × 雪域灰 · 轻拟物设计')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody)
          .fontColor('rgba(255, 255, 255, 0.72)')
          .opacity(this.subtitleAnimOpacity)
          .margin({ top: SpacingTokens.sm })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%').height('100%')
  }
}
