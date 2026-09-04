/**
 * 打地鼠 - HarmonyOS 设计风格
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { range } from '../../common/Range';

const HOLE_COUNT = 9;

@ComponentV2
export struct WhackMolePage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local holes: boolean[] = [false, false, false, false, false, false, false, false, false];
  @Local score: number = 0;
  @Local highScore: number = 0;
  @Local timeLeft: number = 30;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  /**
   * 对局状态。原先由 isPlaying + isPaused 两个布尔拼出，其中「已结束但仍处于暂停」
   * 是无意义的非法态。改为单一枚举后，非法态在类型层面就无法表达。
   */
  @Local status: GameStatus = GameStatus.PLAYING;
  private mtimer: number = -1;
  private ctimer: number = -1;
  /** 本次暂停是否由「切后台」自动触发——决定回到前台时是否需要自动恢复 */
  private autoPaused: boolean = false;
  private idx3: number[] = range(3);

  aboutToAppear(): void {
    this.highScore = GameDataManager.getGameById('whackmole')?.highScore ?? 0;
    this.startGame();
  }
  aboutToDisappear(): void { clearInterval(this.mtimer); clearInterval(this.ctimer); }

  /**
   * 切后台自动暂停。
   * 本局限时只有 30 秒，若不处理，倒计时会在后台一路归零直接结算。
   * 两个定时回调（倒计时 / 地鼠出现）都只放行 PLAYING 状态，置位即可。
   */
  onPageHide(): void {
    if (this.status === GameStatus.PLAYING) {
      this.autoPaused = true;
      this.status = GameStatus.PAUSED;
    }
  }

  onPageShow(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.status = GameStatus.PLAYING;
    }
  }

  startGame(): void {
    if (this.score > 0) { GameDataManager.updateHighScore('whackmole', this.score); }
    GameDataManager.incrementPlayCount('whackmole');
    this.score = 0;
    this.timeLeft = this.getGameTime();
    this.status = GameStatus.PLAYING;
    this.holes = [false, false, false, false, false, false, false, false, false];
    clearInterval(this.ctimer);
    this.ctimer = setInterval(() => {
      if (this.status === GameStatus.PLAYING) {
        this.timeLeft--;
        if (this.timeLeft <= 0) { this.gameOver(); }
      }
    }, 1000);
    this.spawnMole();
  }
  /** 手动暂停/恢复。只在「进行中 ⇄ 暂停」间切换，已结束的对局不会被误切换 */
  togglePause(): void {
    if (this.status === GameStatus.PLAYING) {
      this.status = GameStatus.PAUSED;
    } else if (this.status === GameStatus.PAUSED) {
      this.status = GameStatus.PLAYING;
    }
  }

  spawnMole(): void {
    clearInterval(this.mtimer);
    this.mtimer = setInterval(() => {
      if (this.status !== GameStatus.PLAYING) { return; }
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

  getTimeColor(): ResourceColor {
    if (this.timeLeft <= 5) { return SemanticColors.error; }
    return SemanticColors.success;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  whack(index: number): void {
    if (this.status !== GameStatus.PLAYING) { return; }
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
    this.status = GameStatus.OVER;
    clearInterval(this.ctimer);
    clearInterval(this.mtimer);
    if (this.score > this.highScore) { this.highScore = this.score; }
    GameDataManager.updateHighScore('whackmole', this.score);
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '打地鼠', // 得分/最高分已由下方大字指标卡展示，关闭标题栏的小字重复显示
          showScore: false,
          isPaused: this.status === GameStatus.PAUSED,
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => { this.togglePause(); },
          onRestart: () => { this.startGame(); } })

        Row() {
          Column() {
            Text('得分').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.score).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })

          Column() {
            Text('时间').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text(this.timeLeft + 's').fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
              .fontColor(this.getTimeColor())
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          ForEach(this.idx3, (row: number) => {
            Row() {
              ForEach(this.idx3, (col: number) => {
                this.MoleHole(row * 3 + col)
              }, (col: number) => col.toString())
            }
          }, (row: number) => row.toString())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '时间到！',
          detail: '得分 ' + this.score,
          detailColor: SemanticColors.accent,
          primaryText: '再来一局',
          onPrimary: () => { this.startGame(); },
          secondaryText: '返回',
          onSecondary: () => { this.pathStack.pop(); }
        })
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
          .backgroundColor(SemanticColors.surface)
          // 阴影恒为半透明黑：投影在深浅两种底色上都应压暗，不随主题反转
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.25)', offsetY: 4 })
          .margin({ bottom: 8 })
      }
    }
    .layoutWeight(1).aspectRatio(0.92)
    .justifyContent(FlexAlign.End)
    .onClick(() => this.whack(index))
  }
}
