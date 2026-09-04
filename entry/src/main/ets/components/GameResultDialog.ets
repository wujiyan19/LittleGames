/**
 * 统一结算弹窗 — 宇宙蓝 × 雪域灰
 *
 * 原先 10 个游戏页各自内联了一段结构完全相同的结算 UI（图标圆底 + 标题 +
 * 副标题 + 主/次按钮 + 遮罩三件套），重复约 120 行 ×10 处。本组件收敛掉这部分，
 * 差异全部通过参数表达。
 *
 * 两种形态：
 * - 全屏遮罩（cardStyle = false）：整屏 scrim + 背景模糊，内容居中。
 *   用于「游戏已结束、棋盘无需再看」的场景（贪吃蛇 / 2048 / 方块 / 打地鼠 / 扫雷）。
 * - 居中卡片（cardStyle = true）：86% 宽圆角卡片，棋盘边缘仍可见。
 *   用于「想让用户回看最终盘面」的场景（记忆翻牌 / 猜数字 / 拼图 / 华容道）。
 *
 * 次按钮（secondaryText）留空即不渲染——数独、华容道等页面只保留一个主操作。
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct GameResultDialog {
  /** 顶部圆形图标（系统 symbol 资源） */
  @Param symbol: Resource = $r('sys.symbol.star_fill');
  /** 图标前景色：成功用 success，失败用 error，普通结算用 warning */
  @Param symbolColor: ResourceColor = SemanticColors.warning;
  /** 主标题 */
  @Param title: string = '';
  /** 副标题（成绩详情），留空则不渲染 */
  @Param detail: string = '';
  /** 副标题颜色：成绩类用 accent，提示类用 warning */
  @Param detailColor: ResourceColor = SemanticColors.accent;
  /** 主按钮文案 */
  @Param primaryText: string = '再来一局';
  @Param onPrimary: () => void = () => {};
  /** 次按钮文案，留空则不渲染 */
  @Param secondaryText: string = '';
  @Param onSecondary: () => void = () => {};
  /** true = 居中卡片式；false = 全屏遮罩式 */
  @Param cardStyle: boolean = false;

  build() {
    if (this.cardStyle) {
      Column() { this.DialogContent() }
        .width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor(SemanticColors.surfaceTranslucent)
        .backdropBlur(24)
        .shadow(ShadowTokens.float)
    } else {
      Column() { this.DialogContent() }
        .width('100%').height('100%')
        .backgroundColor(SemanticColors.scrim)
        .backdropBlur(20)
        .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  DialogContent() {
    Column() {
      Column() {
        SymbolGlyph(this.symbol)
          .fontSize(40)
          .fontWeight(FontWeight.Medium)
          .fontColor([this.symbolColor])
      }
      .width(72).height(72)
      .borderRadius(RadiusTokens.full)
      .backgroundColor(SemanticColors.primaryLight)
      .justifyContent(FlexAlign.Center)

      Text(this.title)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
        .fontColor(SemanticColors.textPrimary)
        .margin({
          top: SpacingTokens.md,
          bottom: this.detail.length > 0 ? SpacingTokens.xs : SpacingTokens.base
        })

      if (this.detail.length > 0) {
        Text(this.detail)
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeSubtitle).fontColor(this.detailColor)
          .margin({ bottom: this.cardStyle ? SpacingTokens.base : SpacingTokens.lg })
      }

      Row({ space: SpacingTokens.base }) {
        Button() {
          Row({ space: SpacingTokens.xs }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(16).fontColor([SemanticColors.textOnPrimary])
            Text(this.primaryText)
              .fontFamily(FontTokens.family)
              .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textOnPrimary)
          }
        }
        .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
        .backgroundColor(SemanticColors.primary).borderRadius(RadiusTokens.full)
        .shadow(ShadowTokens.button)
        .onClick(() => this.onPrimary())

        if (this.secondaryText.length > 0) {
          Button(this.secondaryText)
            .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
            .fontFamily(FontTokens.family)
            .fontColor(SemanticColors.textPrimary).backgroundColor(SemanticColors.surface)
            .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button)
            .onClick(() => this.onSecondary())
        }
      }
    }
  }
}
