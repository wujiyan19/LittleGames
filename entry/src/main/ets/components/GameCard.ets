/**
 * 游戏卡片 — 精选页与分类页共用
 * 原先是 Index.ets 内的 @Builder，抽出后两个 Tab 各自持有，不再共享单文件
 */
import { SemanticColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens, GameBadgeColors } from '../common/DesignTokens';
import { GameInfo, GameCategory } from '../common/GameConstants';
import { resolveString } from '../common/I18nUtils';

const EMPTY_GAME: GameInfo = {
  id: '',
  name: '',
  category: GameCategory.PUZZLE,
  icon: '',
  description: '',
  highScore: 0,
  playCount: 0,
  scoreLabel: $r('app.string.score_label')
};

@ComponentV2
export struct GameCard {
  @Param game: GameInfo = EMPTY_GAME;
  /** 点击跳转，由父组件持有导航逻辑（各 Tab 不感知 NavPathStack）。命名为 onTap 以避开基类 onClick 属性 */
  @Param onTap: () => void = () => {};
  @Local isPressed: boolean = false;

  buildA11yText(): string {
    const context = this.getUIContext().getHostContext();
    const nameStr = resolveString(this.game.name, context);
    const descStr = resolveString(this.game.description, context);
    return nameStr + '，' + descStr;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.game.icon)
            .fontSize(28)
        }
        .width(52).height(52)
        .borderRadius(RadiusTokens.base)
        .linearGradient({
          angle: 135,
          colors: GameBadgeColors.getGradient(this.game.id)
        })
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 8, color: $r('app.color.button_shadow'), offsetX: 0, offsetY: 2 })

        if (this.game.playCount > 0) {
          Text('' + this.game.playCount)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeCaption)
            .fontWeight(FontTokens.weightBold)
            .fontColor(SemanticColors.textOnPrimary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(RadiusTokens.full)
            .backgroundColor(SemanticColors.primary)
            .margin({ left: -8, top: -4 })
        }
      }
      .alignItems(VerticalAlign.Top)

      Text(this.game.name)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.textPrimary)
        .margin({ top: SpacingTokens.sm })

      Text(this.game.description)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodySmall)
        .fontColor(SemanticColors.textTertiary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.xs })

      if (this.game.playCount > 0) {
        Row() {
          Text($r('app.string.card_played_count', this.game.playCount))
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeCaption)
            .fontColor(SemanticColors.textTertiary)
        }
        .margin({ top: SpacingTokens.xs })
      }
    }
    .width('100%')
    .padding(SpacingTokens.base)
    .borderRadius(RadiusTokens.xl)
    .backgroundColor(SemanticColors.surface)
    .shadow(ShadowTokens.card)
    .alignItems(HorizontalAlign.Start)
    .scale({ x: this.isPressed ? 0.95 : 1.0, y: this.isPressed ? 0.95 : 1.0 })
    .accessibilityGroup(true)
    .accessibilityText(this.buildA11yText())
    .onClick(() => { this.onTap(); })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.getUIContext().animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
          this.isPressed = true;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
          this.isPressed = false;
        });
      }
    })
  }
}
