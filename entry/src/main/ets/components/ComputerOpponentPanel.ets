import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../common/DesignTokens';
import { GameDifficulty, getDifficultyLabel } from '../common/GameConstants';

@ComponentV2
export struct ComputerOpponentPanel {
  @Param gameId: string = '';
  @Param thinking: boolean = false;
  @Param player: number = 2;
  @Param reaction: boolean = false;
  @Param difficulty: GameDifficulty = GameDifficulty.NORMAL;

  description(): Resource {
    if (this.gameId === 'doudizhu') { return $r('app.string.computer_doudizhu'); }
    if (this.gameId === 'guandan') { return $r('app.string.computer_guandan'); }
    if (this.gameId === 'mahjong') { return $r('app.string.computer_mahjong'); }
    if (this.gameId === 'xiangqi') { return $r('app.string.computer_xiangqi'); }
    if (this.gameId === 'chess') { return $r('app.string.computer_chess'); }
    return $r('app.string.computer_ludo');
  }

  build() {
    Column({ space: SpacingTokens.sm }) {
      Row({ space: SpacingTokens.sm }) {
        Text($r('app.string.computer_mode')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
          .fontWeight(FontTokens.weightSemibold).fontColor(SemanticColors.textPrimary).layoutWeight(1)
        Text(getDifficultyLabel(this.difficulty)).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
          .fontColor(SemanticColors.textSecondary)
      }.width('100%')
      Text(this.description()).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
        .fontColor(SemanticColors.textSecondary)
      Text(this.thinking ? $r('app.string.computer_thinking', this.player) :
        this.reaction ? $r('app.string.computer_mahjong_reaction') : $r('app.string.computer_your_turn'))
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.primary).id('computer-turn-status')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(SpacingTokens.md)
      .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base).id('computer-opponent-panel')
  }
}
