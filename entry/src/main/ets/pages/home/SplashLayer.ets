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
  /** 收起闪屏的定时器句柄，组件销毁时清理，避免回调落在已卸载的层上 */
  private finishTimer: number = -1;

  aboutToAppear(): void {
    this.startSplash();
  }
  aboutToDisappear(): void {
    if (this.finishTimer !== -1) {
      clearTimeout(this.finishTimer);
      this.finishTimer = -1;
    }
  }

  /**
   * 品牌动效编排：图标 → 标题 → 副标题依次淡入，约 1s 后通知父组件收起。
   * 原实现为三层嵌套 setTimeout，总时长 600+600+300+800 ≈ 2.3s，且纯干等；
   * 改为多个 animateTo + delay 并行编排，总时长压到 ~1s，可读性也更好。
   */
  startSplash(): void {
    // 图标：淡入 + 放大上移
    this.getUIContext().animateTo({
      duration: 420,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.iconAnimOpacity = 1;
      this.iconAnimScale = 1;
      this.iconAnimTranslateY = 0;
    });
    // 标题：延后淡入
    this.getUIContext().animateTo({
      duration: 300,
      delay: 220,
      curve: Curve.EaseOut
    }, () => {
      this.titleAnimOpacity = 1;
    });
    // 副标题：再延后淡入
    this.getUIContext().animateTo({
      duration: 260,
      delay: 400,
      curve: Curve.EaseOut
    }, () => {
      this.subtitleAnimOpacity = 1;
    });
    // 总体约 1s 后收起（覆盖最后一段副标题淡入）
    this.finishTimer = setTimeout(() => {
      this.finishTimer = -1;
      this.onFinish();
    }, 1000);
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
