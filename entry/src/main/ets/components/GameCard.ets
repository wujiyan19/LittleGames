/**
 * 游戏卡片 — 精选页与分类页共用
 * 原先是 Index.ets 内的 @Builder，抽出后两个 Tab 各自持有，不再共享单文件
 */
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../common/DesignTokens';
import { GameInfo, GameCategory } from '../common/GameConstants';
import { resolveString } from '../common/I18nUtils';
import { HarmonyMotion } from '../common/HarmonyMotion';
import { playTimeHours } from '../common/PlayTime';

const EMPTY_GAME: GameInfo = {
  id: '',
  name: '',
  category: GameCategory.PUZZLE,
  icon: '',
  description: '',
  highScore: 0,
  playTimeMs: 0,
  scoreLabel: $r('app.string.score_label')
};

@ComponentV2
export struct GameCard {
  @Param game: GameInfo = EMPTY_GAME;
  /** 点击跳转，由父组件持有导航逻辑（各 Tab 不感知 NavPathStack）。命名为 onTap 以避开基类 onClick 属性 */
  @Param onTap: () => void = () => {};

  buildA11yText(): string {
    const context = this.getUIContext().getHostContext();
    const nameStr = resolveString(this.game.name, context);
    const descStr = resolveString(this.game.description, context);
    return nameStr + '，' + descStr;
  }

  build() {
    Column() {
      Column() {
        Image(this.game.icon)
          .width(42).height(42)
          .objectFit(ImageFit.Contain)
      }
      .width(52).height(52)
      .borderRadius(RadiusTokens.base)
      .backgroundColor(SemanticColors.gameIconBackground)
      .justifyContent(FlexAlign.Center)

      Text(this.game.name)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBodyLarge)
        .fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.textPrimary)
        .width('100%')
        .minLines(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.sm })

      // 按行数预留空间，短简介和未游玩卡片也保持相同尺寸，并随系统字号缩放。
      Text(this.game.description)
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textSecondary)
        .width('100%')
        .minLines(2)
        .align(Alignment.TopStart)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.xs })

      Text($r('app.string.card_played_time', playTimeHours(this.game.playTimeMs)))
        .fontFamily(FontTokens.family)
        .fontSize(FontTokens.sizeCaption)
        .fontColor(SemanticColors.textTertiary)
        .width('100%')
        .minLines(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SpacingTokens.xs })
        .visibility(this.game.playTimeMs > 0 ? Visibility.Visible : Visibility.Hidden)
    }
    .width('100%')
    .padding(SpacingTokens.base)
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(SemanticColors.surface)

    .alignItems(HorizontalAlign.Start)
    .renderGroup(true)
    .clickEffect(HarmonyMotion.press(this.getUIContext(), true))
    .accessibilityGroup(true)
    .accessibilityText(this.buildA11yText())
    .onClick(() => { this.onTap(); })
  }
}
