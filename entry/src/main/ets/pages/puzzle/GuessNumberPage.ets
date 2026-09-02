/**
 * 猜数字 - HarmonyOS 设计风格
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';

interface RecordItem { guess: string; a: number; b: number; seq: number; }

@ComponentV2
export struct GuessNumberPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local secret: string = '';
  @Local input: string = '';
  @Local records: RecordItem[] = [];
  @Local isWin: boolean = false;
  @Local isPlaying: boolean = true;
  @Local tries: number = 0;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  private recordSeq: number = 0;

  aboutToAppear(): void { this.startGame(); }

  startGame(): void {
    GameDataManager.incrementPlayCount('guessnumber');
    const digits: number[] = [0,1,2,3,4,5,6,7,8,9];
    let s = '';
    for (let i = 0; i < this.getSecretLength(); i++) {
      const idx = Math.floor(Math.random() * digits.length);
      s += '' + digits.splice(idx, 1)[0];
    }
    this.secret = s;
    this.input = '';
    this.records = [];
    this.isWin = false;
    this.isPlaying = true;
    this.tries = 0;
  }

  getSecretLength(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 3; }
    if (this.difficulty === GameDifficulty.HARD) { return 5; }
    return 4;
  }

  getMaxTries(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 8; }
    if (this.difficulty === GameDifficulty.HARD) { return 12; }
    return 10;
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.startGame();
  }

  pushDigit(d: string): void {
    if (!this.isPlaying || this.isWin || this.input.length >= this.getSecretLength()) { return; }
    if (this.input.indexOf(d) >= 0) { return; }
    this.input += d;
  }
  deleteDigit(): void {
    if (!this.isPlaying) { return; }
    this.input = this.input.substring(0, this.input.length - 1);
  }
  submit(): void {
    if (!this.isPlaying || this.input.length !== this.getSecretLength() || this.isWin) { return; }
    this.tries++;
    let a = 0;
    let b = 0;
    for (let i = 0; i < this.getSecretLength(); i++) {
      if (this.input[i] === this.secret[i]) { a++; }
      else if (this.secret.indexOf(this.input[i]) >= 0) { b++; }
    }
    this.recordSeq++;
    const rec: RecordItem = { guess: this.input, a: a, b: b, seq: this.recordSeq };
    const newRecs: RecordItem[] = [rec];
    for (let i = 0; i < this.records.length; i++) { newRecs.push(this.records[i]); }
    this.records = newRecs;
    if (a === this.getSecretLength()) {
      this.isWin = true;
      this.isPlaying = false;
      GameDataManager.updateHighScore('guessnumber', this.getScore());
    }
    if (this.tries >= this.getMaxTries()) { this.isPlaying = false; }
    this.input = '';
  }

  /**
   * 本局得分：难度越高基数越高，尝试次数越多扣分越多。
   * 与扫雷（用时）、华容道（步数）保持同一口径——「越优越高分」，
   * 因此三者都标注为换算分（见 GameInfo.scoreLabel）。
   */
  getScore(): number {
    let bonus = 0;
    if (this.difficulty === GameDifficulty.NORMAL) { bonus = 200; }
    if (this.difficulty === GameDifficulty.HARD) { bonus = 400; }
    return Math.max(1, 1000 + bonus - this.tries * 30);
  }

  getResultColor(a: number): ResourceColor {
    if (a === this.getSecretLength()) { return SemanticColors.success; }
    return SemanticColors.warning;
  }

  getInputColor(): ResourceColor {
    if (this.input.length === this.getSecretLength()) { return SemanticColors.success; }
    return SemanticColors.textPrimary;
  }

  getKeyFontSize(key: string): number {
    if (key === '确定') { return FontTokens.sizeBody; }
    return 24;
  }

  getKeyFontColor(key: string): ResourceColor {
    if (key === '确定') {
      if (this.input.length === this.getSecretLength()) { return SemanticColors.textOnPrimary; }
      return SemanticColors.textTertiary;
    }
    return SemanticColors.textPrimary;
  }

  getKeyBgColor(key: string): ResourceColor {
    if (key === '确定') {
      if (this.input.length === this.getSecretLength()) { return SemanticColors.primary; }
      return SemanticColors.surfaceHover;
    }
    if (key === '⌫') { return SemanticColors.error; }
    return SemanticColors.surface;
  }

  getKeyShadow(key: string): ShadowOptions | undefined {
    if (key === '确定' && this.input.length === this.getSecretLength()) {
      return ShadowTokens.button;
    }
    return undefined;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '猜数字', scoreValue: this.tries, highScoreValue: this.getMaxTries(),
          subtitle: '尝试 ' + this.tries + ' / ' + this.getMaxTries(),
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); } })

        Column() {
          Text('猜一个由' + this.getSecretLength() + '个不重复数字组成的密码')
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary).margin({ top: SpacingTokens.sm })
          Text('输入' + this.getSecretLength() + '位数字后提交')
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.textTertiary)
          Text('已尝试: ' + this.tries + '/' + this.getMaxTries())
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(SemanticColors.warning).margin({ top: SpacingTokens.xs })
        }.alignItems(HorizontalAlign.Center).margin({ bottom: SpacingTokens.md })

        Column() {
          Row({ space: SpacingTokens.xs }) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(12).fontColor([SemanticColors.accent])
            Text('猜测记录')
              .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
              .fontColor(SemanticColors.textTertiary).margin({ bottom: 0 })
          }.width('100%').margin({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: 4 })

          List() {
            ForEach(this.records.slice(0, 6), (rec: RecordItem, index: number) => {
              ListItem() {
                Row() {
                  Text('#' + (this.records.length - index))
                    .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
                    .fontColor(SemanticColors.textTertiary).width(28)
                  Text(rec.guess).fontWeight(FontWeight.Bold)
                    .fontColor(SemanticColors.textPrimary).margin({ left: SpacingTokens.sm }).fontSize(FontTokens.sizeSubtitle)
                  Text(rec.a + 'A' + rec.b + 'B').fontWeight(FontWeight.Bold)
                    .fontColor(this.getResultColor(rec.a))
                    .margin({ left: SpacingTokens.md }).fontSize(FontTokens.sizeBodyLarge)
                  Blank()
                }.width('100%').padding({ left: SpacingTokens.sm, right: SpacingTokens.sm })
              }.height(40)
            }, (rec: RecordItem) => rec.seq.toString())
          }.height(Math.min(this.records.length * 40, 240))
          .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .margin({ left: SpacingTokens.base, right: SpacingTokens.base })
        }.layoutWeight(1)

        Column() {
          Text(this.input + '_'.repeat(this.getSecretLength() - this.input.length))
            .fontFamily(FontTokens.family)
            .fontSize(32).fontWeight(FontWeight.Bold)
            .fontColor(this.getInputColor())
            .margin({ bottom: SpacingTokens.base })

          this.KeyRow(['1', '2', '3'])
          this.KeyRow(['4', '5', '6'])
          this.KeyRow(['7', '8', '9'])
          this.KeyRow(['⌫', '0', '确定'])
        }.padding({ bottom: SpacingTokens.lg })
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.isWin) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([SemanticColors.success])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(SemanticColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text('恭喜猜中!')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(SemanticColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('密码: ' + this.secret + '  ·  ' + this.tries + ' 次')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(SemanticColors.warning)
            .margin({ bottom: SpacingTokens.base })
          this.RestartButton()
        }.width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor(SemanticColors.surfaceTranslucent)
        .backdropBlur(24)
        .shadow(ShadowTokens.float)
      } else if (!this.isPlaying) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([SemanticColors.error])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(SemanticColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text(this.getMaxTries() + '次用完了')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(SemanticColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('密码: ' + this.secret)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(SemanticColors.error)
            .margin({ bottom: SpacingTokens.base })
          this.RestartButton()
        }.width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor(SemanticColors.surfaceTranslucent)
        .backdropBlur(24)
        .shadow(ShadowTokens.float)
      }
    }.width('100%').height('100%')
  }

  @Builder
  KeyRow(keys: string[]) {
    Row({ space: SpacingTokens.sm }) {
      ForEach(keys, (key: string) => {
        Button() {
          if (key === '⌫') {
            SymbolGlyph($r('sys.symbol.delete_left'))
              .fontSize(20).fontColor([SemanticColors.textOnPrimary])
          } else {
            Text(key)
              .fontFamily(FontTokens.family)
              .fontSize(this.getKeyFontSize(key))
              .fontColor(this.getKeyFontColor(key))
          }
        }
        .layoutWeight(1).height(52)
        .backgroundColor(this.getKeyBgColor(key))
        .borderRadius(RadiusTokens.base)
        .shadow(this.getKeyShadow(key))
        .onClick(() => {
          if (key === '⌫') { this.deleteDigit(); }
          else if (key === '确定') { this.submit(); }
          else { this.pushDigit(key); }
        })
      }, (key: string) => key)
    }
    .width('100%')
    .margin({ bottom: SpacingTokens.sm })
  }

  @Builder
  RestartButton() {
    Button() {
      Row({ space: SpacingTokens.xs }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(16).fontColor([SemanticColors.textOnPrimary])
        Text('再来一局')
          .fontFamily(FontTokens.family)
          .fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textOnPrimary)
      }
    }
    .height(44).padding({ left: SpacingTokens.lg, right: SpacingTokens.lg })
    .backgroundColor(SemanticColors.primary).borderRadius(RadiusTokens.full)
    .shadow(ShadowTokens.button)
    .onClick(() => this.startGame())
  }
}
