/**
 * 猜数字 - HarmonyOS 设计风格
 */
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';

interface RecordItem { guess: string; a: number; b: number; seq: number; }

@Entry
@ComponentV2
struct GuessNumberPage {
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
    if (a === this.getSecretLength()) { this.isWin = true; this.isPlaying = false; }
    if (this.tries >= this.getMaxTries()) { this.isPlaying = false; }
    this.input = '';
  }

  getResultColor(a: number): ResourceColor {
    if (a === this.getSecretLength()) { return DarkColors.success; }
    return DarkColors.warning;
  }

  getInputColor(): ResourceColor {
    if (this.input.length === this.getSecretLength()) { return DarkColors.success; }
    return DarkColors.textPrimary;
  }

  getKeyFontSize(key: string): number {
    if (key === '确定') { return FontTokens.sizeBody; }
    return 24;
  }

  getKeyFontColor(key: string): ResourceColor {
    if (key === '确定') {
      if (this.input.length === this.getSecretLength()) { return DarkColors.textOnPrimary; }
      return DarkColors.textTertiary;
    }
    return DarkColors.textPrimary;
  }

  getKeyBgColor(key: string): ResourceColor {
    if (key === '确定') {
      if (this.input.length === this.getSecretLength()) { return DarkColors.primary; }
      return DarkColors.surfaceHover;
    }
    if (key === '⌫') { return DarkColors.error; }
    return DarkColors.surface;
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
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({ gameTitle: '猜数字', scoreValue: this.tries, highScoreValue: this.getMaxTries(),
          subtitle: '尝试 ' + this.tries + ' / ' + this.getMaxTries(),
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.getUIContext().getRouter().back(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); } })

        Column() {
          Text('猜一个由' + this.getSecretLength() + '个不重复数字组成的密码')
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(DarkColors.textTertiary).margin({ top: SpacingTokens.sm })
          Text('输入' + this.getSecretLength() + '位数字后提交')
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(DarkColors.textTertiary)
          Text('已尝试: ' + this.tries + '/' + this.getMaxTries())
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
            .fontColor(DarkColors.warning).margin({ top: SpacingTokens.xs })
        }.alignItems(HorizontalAlign.Center).margin({ bottom: SpacingTokens.md })

        Column() {
          Row({ space: SpacingTokens.xs }) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(12).fontColor([DarkColors.accent])
            Text('猜测记录')
              .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
              .fontColor(DarkColors.textTertiary).margin({ bottom: 0 })
          }.width('100%').margin({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: 4 })

          List() {
            ForEach(this.records.slice(0, 6), (rec: RecordItem, index: number) => {
              ListItem() {
                Row() {
                  Text('#' + (this.records.length - index))
                    .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
                    .fontColor(DarkColors.textTertiary).width(28)
                  Text(rec.guess).fontWeight(FontWeight.Bold)
                    .fontColor(DarkColors.textPrimary).margin({ left: SpacingTokens.sm }).fontSize(FontTokens.sizeSubtitle)
                  Text(rec.a + 'A' + rec.b + 'B').fontWeight(FontWeight.Bold)
                    .fontColor(this.getResultColor(rec.a))
                    .margin({ left: SpacingTokens.md }).fontSize(FontTokens.sizeBodyLarge)
                  Blank()
                }.width('100%').padding({ left: SpacingTokens.sm, right: SpacingTokens.sm })
              }.height(40)
            }, (rec: RecordItem) => rec.seq.toString())
          }.height(Math.min(this.records.length * 40, 240))
          .backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
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
      }.width('100%').height('100%')

      if (this.isWin) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([DarkColors.success])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text('恭喜猜中!')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('密码: ' + this.secret + '  ·  ' + this.tries + ' 次')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.warning)
            .margin({ bottom: SpacingTokens.base })
          this.RestartButton()
        }.width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor(DarkColors.surfaceTranslucent)
        .backdropBlur(24)
        .shadow(ShadowTokens.float)
      } else if (!this.isPlaying) {
        Column() {
          Column() {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor([DarkColors.error])
          }
          .width(72).height(72)
          .borderRadius(RadiusTokens.full)
          .backgroundColor(DarkColors.primaryLight)
          .justifyContent(FlexAlign.Center)

          Text(this.getMaxTries() + '次用完了')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('密码: ' + this.secret)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.error)
            .margin({ bottom: SpacingTokens.base })
          this.RestartButton()
        }.width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor(DarkColors.surfaceTranslucent)
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
              .fontSize(20).fontColor([DarkColors.textOnPrimary])
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
  }
}
