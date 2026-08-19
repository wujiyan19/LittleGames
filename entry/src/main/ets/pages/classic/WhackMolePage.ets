/**
 * 打地鼠 - HarmonyOS 设计风格
 */
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';

const HOLE_COUNT = 9;

@Entry
@ComponentV2
struct WhackMolePage {
  @Local holes: boolean[] = [false, false, false, false, false, false, false, false, false];
  @Local score: number = 0;
  @Local highScore: number = 0;
  @Local timeLeft: number = 30;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local isPlaying: boolean = true;
  @Local isPaused: boolean = false;
  private mtimer: number = -1;
  private ctimer: number = -1;
  private idx3: number[] = [0, 1, 2];

  aboutToAppear(): void { this.startGame(); }
  aboutToDisappear(): void { clearInterval(this.mtimer); clearInterval(this.ctimer); }

  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore('whackmole', this.score); }
    GameDataManager.incrementPlayCount('whackmole');
    this.score = 0;
    this.timeLeft = this.getGameTime();
    this.isPlaying = true;
    this.isPaused = false;
    this.holes = [false, false, false, false, false, false, false, false, false];
    clearInterval(this.ctimer);
    this.ctimer = setInterval(() => {
      if (!this.isPaused && this.isPlaying) {
        this.timeLeft--;
        if (this.timeLeft <= 0) { this.gameOver(); }
      }
    }, 1000);
    this.spawnMole();
  }

  spawnMole(): void {
    clearInterval(this.mtimer);
    this.mtimer = setInterval(() => {
      if (this.isPaused || !this.isPlaying) { return; }
      let nh = [false, false, false, false, false, false, false, false, false];
      let count = Math.random() < 0.3 ? 2 : 1;
      let placed = 0;
      while (placed < count) {
        let idx = Math.floor(Math.random() * HOLE_COUNT);
        if (!nh[idx]) { nh[idx] = true; placed++; }
      }
      this.holes = nh;
    }, this.getSpawnInterval());
  }

  getGameTime(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 40; }
    if (this.difficulty === GameDifficulty.HARD) { return 20; }
    return 30;
  }

  getSpawnInterval(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 1000; }
    if (this.difficulty === GameDifficulty.HARD) { return 600; }
    return 800;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  whack(index: number): void {
    if (!this.isPlaying || this.isPaused) { return; }
    if (this.holes[index]) {
      this.score += 10;
      let nh = this.holes.slice();
      nh[index] = false;
      this.holes = nh;
    } else {
      this.score = Math.max(0, this.score - 5);
    }
  }

  gameOver(): void {
    this.isPlaying = false;
    clearInterval(this.ctimer);
    clearInterval(this.mtimer);
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore('whackmole', this.score);
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '打地鼠', scoreValue: this.score, highScoreValue: this.highScore,
          isPaused: this.isPaused,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => { this.isPaused = !this.isPaused; },
          onRestart: () => { this.startGame(); } })

        Row() {
          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text('' + this.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(DarkColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('时间').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text(this.timeLeft + 's').fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
              .fontColor(this.timeLeft <= 5 ? DarkColors.error : DarkColors.success)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          ForEach(this.idx3, (row: number) => {
            Row() {
              ForEach(this.idx3, (col: number) => {
                this.MoleHole(row * 3 + col)
              })
            }
          })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%')

      if (!this.isPlaying) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([DarkColors.warning])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text('时间到！')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('得分 ' + this.score)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.accent)
            .margin({ bottom: SpacingTokens.lg })
          Row({ space: SpacingTokens.base }) {
            Button() {
              Row({ space: SpacingTokens.xs }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(16).fontColor([DarkColors.textOnPrimary])
                Text('再来一局')
                  .fontFamily(FontTokens.family)
                  .fontSize(FontTokens.sizeBody).fontColor(DarkColors.textOnPrimary)
              }
            }
            .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
            .backgroundColor(DarkColors.primary).borderRadius(RadiusTokens.full)
            .shadow(ShadowTokens.button)
            .onClick(() => this.startGame())
            Button('返回')
              .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
              .fontFamily(FontTokens.family)
              .fontColor(DarkColors.textPrimary).backgroundColor(DarkColors.surface)
              .borderRadius(RadiusTokens.full).shadow(ShadowTokens.button)
              .onClick(() => this.getUIContext().getRouter().back())
          }
        }.width('100%').height('100%').backgroundColor(DarkColors.scrim)
        .backdropBlur(20).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }

  @Builder
  MoleHole(index: number) {
    Column() {
      if (this.holes[index]) {
        Text('🐹')
          .fontSize(44)
          .translate({ y: -8 })
      } else {
        Column() {}
          .width('72%').aspectRatio(1.4)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.surface)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.25)', offsetY: 4 })
          .margin({ bottom: 8 })
      }
    }
    .layoutWeight(1).aspectRatio(0.92)
    .justifyContent(FlexAlign.End)
    .onClick(() => this.whack(index))
  }
}
