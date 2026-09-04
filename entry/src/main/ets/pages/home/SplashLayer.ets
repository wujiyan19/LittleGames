/**
 * 启动闪屏层 — 覆盖在首页上的品牌展示层
 *
 * 原先是 Index.ets 内的 @Builder（动画状态与 UI 混在一起），抽出后：
 * 动画状态自持、播放完成通过 onFinish 通知父组件隐藏自己。
 *
 * 注意：这里的深空渐变、光晕与白色文字均为**品牌固定配色**（deepSpace 系），
 * 不随系统深浅色模式变化——闪屏是品牌展示页，两套主题下都应呈现同一张「宇宙蓝星空」。
 * 因此本文件内的 #16205F / #2A2B7E / rgba(...) / #FFFFFF 是刻意为之，请勿替换为语义色。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens, BrandColors } from '../../common/DesignTokens';

@ComponentV2
export struct SplashLayer {
  /** 播放完成（含所有定格动画）后回调，父组件用它隐藏本层 */
  @Param onFinish: () => void = () => {};
  @Local iconAnimOpacity: number = 0;
  @Local iconAnimScale: number = 0.6;
  @Local iconAnimTranslateY: number = 20;
  @Local titleAnimOpacity: number = 0;
  @Local subtitleAnimOpacity: number = 0;

  aboutToAppear(): void {
    this.startSplash();
  }

  startSplash(): void {
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
          this.onFinish();
        }, 800);
      }, 300);
    }, 600);
  }

  build() {
    Stack() {
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

      Circle({ width: 260, height: 260 })
        .fill('rgba(93, 134, 255, 0.25)')
        .blur(60)
        .position({ x: -80, y: -40 })
      Circle({ width: 220, height: 220 })
        .fill('rgba(122, 90, 248, 0.22)')
        .blur(60)
        .position({ x: '72%', y: '68%' })

      Column() {
        Column() {
          SymbolGlyph($r('sys.symbol.gamecontroller'))
            .fontSize(72)
            .fontWeight(FontWeight.Medium)
            .fontColor([BrandColors.cosmicBlueBright, BrandColors.auroraPurpleBright])
        }
        .width(152).height(152)
        // 图标居中：alignItems 默认已是 Center，但 justifyContent 默认是 Start，
        // 漏写就会让图标贴在圆圈顶部（原实现即缺此项）
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
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
