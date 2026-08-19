/**
 * 记忆翻牌 - HarmonyOS 设计风格
 */
import { router, display } from '@kit.ArkUI';
import { DarkColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty } from '../../common/GameConstants';

interface CardInfo { id: number; emoji: string; flipped: boolean; matched: boolean; }

const ALL_EMOJIS: string[] = ['🎮','🎯','🎲','🎸','🎨','🚀','🌈','⭐','🍎','🌺','🐶','🐱'];

@Entry
@ComponentV2
struct MemoryCardPage {
  @Local cards: CardInfo[] = [];
  @Local flippedIdxs: number[] = [];
  @Local matchedCount: number = 0;
  @Local attempts: number = 0;
  @Local bestScore: number = 999;
  @Local isWin: boolean = false;
  @Local cardW: number = 78;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local rowIdx: number[] = [0, 1, 2, 3];
  private locked: boolean = false;
  private idx4: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    this.initCardSize();
    this.startGame();
  }

  initCardSize(): void {
    const d = display.getDefaultDisplaySync();
    const wVp = px2vp(d.width);
    this.cardW = Math.max(56, Math.floor((Math.min(wVp, 520) - 48) / 4));
    if (this.getRowCount() >= 6) { this.cardW = Math.floor(this.cardW * 0.8); }
  }

  getPairCount(): number {
    if (this.difficulty === GameDifficulty.EASY) { return 6; }
    if (this.difficulty === GameDifficulty.HARD) { return 12; }
    return 8;
  }

  getRowCount(): number {
    return Math.floor(this.getPairCount() / 2);
  }

  changeDifficulty(d: GameDifficulty): void {
    if (this.difficulty === d) { return; }
    this.difficulty = d;
    this.initCardSize();
    this.startGame();
  }

  startGame(): void {
    let emojiPool: string[] = [];
    for (let i = 0; i < ALL_EMOJIS.length; i++) { emojiPool.push(ALL_EMOJIS[i]); }
    // shuffle
    for (let i = emojiPool.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = emojiPool[i]; emojiPool[i] = emojiPool[j]; emojiPool[j] = tmp;
    }
    const selected = emojiPool.slice(0, this.getPairCount());
    const cs: CardInfo[] = [];
    for (let i = 0; i < selected.length; i++) {
      cs.push({ id: i * 2, emoji: selected[i], flipped: false, matched: false });
      cs.push({ id: i * 2 + 1, emoji: selected[i], flipped: false, matched: false });
    }
    // shuffle cards
    for (let i = cs.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = cs[i]; cs[i] = cs[j]; cs[j] = tmp;
    }
    this.cards = cs;
    this.rowIdx = [];
    for (let i = 0; i < this.getRowCount(); i++) { this.rowIdx.push(i); }
    this.flippedIdxs = [];
    this.matchedCount = 0;
    this.attempts = 0;
    this.isWin = false;
    this.locked = false;
  }

  flipCard(idx: number): void {
    if (this.locked || this.isWin) { return; }
    if (this.flippedIdxs.length >= 2) { return; }
    if (this.cards[idx].matched) { return; }
    let alreadyFlipped = false;
    for (let i = 0; i < this.flippedIdxs.length; i++) {
      if (this.flippedIdxs[i] === idx) { alreadyFlipped = true; break; }
    }
    if (alreadyFlipped) { return; }
    this.cards[idx].flipped = true;
    let newFlipped: number[] = [];
    for (let i = 0; i < this.flippedIdxs.length; i++) { newFlipped.push(this.flippedIdxs[i]); }
    newFlipped.push(idx);
    this.flippedIdxs = newFlipped;
    if (this.flippedIdxs.length === 2) {
      this.attempts++;
      this.locked = true;
      const a = this.flippedIdxs[0];
      const b = this.flippedIdxs[1];
      if (this.cards[a].emoji === this.cards[b].emoji) {
        setTimeout(() => {
          this.cards[a].matched = true;
          this.cards[b].matched = true;
          this.flippedIdxs = [];
          this.matchedCount++;
          this.locked = false;
          if (this.matchedCount === this.getPairCount()) {
            this.isWin = true;
            if (this.attempts < this.bestScore) { this.bestScore = this.attempts; }
          }
        }, 500);
      } else {
        setTimeout(() => {
          this.cards[a].flipped = false;
          this.cards[b].flipped = false;
          this.flippedIdxs = [];
          this.locked = false;
        }, 800);
      }
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[DarkColors.gradientScreen[0], 0], [DarkColors.gradientScreen[1], 0.5], [DarkColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '记忆翻牌',
          showScore: false,
          subtitle: '已配对 ' + this.matchedCount + ' / ' + this.getPairCount(),
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { router.back(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); }
        })

        Row() {
          Column() {
            Text('尝试').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text('' + this.attempts).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(DarkColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })
          Column() {
            Text('最佳').fontSize(FontTokens.sizeCaption).fontColor(DarkColors.textTertiary)
            Text(this.bestScore === 999 ? '--' : '' + this.bestScore).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(DarkColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(DarkColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          ForEach(this.rowIdx, (r: number) => {
            Row() {
              ForEach(this.idx4, (c: number) => {
                Column() {
                  if (this.cards[r * 4 + c].flipped || this.cards[r * 4 + c].matched) {
                    Text(this.cards[r * 4 + c].emoji).fontSize(Math.max(24, this.cardW * 0.45))
                  } else {
                    SymbolGlyph($r('sys.symbol.star'))
                      .fontSize(Math.max(16, this.cardW * 0.3))
                      .fontColor([DarkColors.textTertiary])
                  }
                }.width(this.cardW).height(this.cardW * 1.15).margin(3)
                .backgroundColor(this.cards[r * 4 + c].matched ? DarkColors.success :
                  this.cards[r * 4 + c].flipped ? DarkColors.accent : DarkColors.surface)
                .borderRadius(RadiusTokens.base)
                .shadow(ShadowTokens.button)
                .opacity(this.cards[r * 4 + c].matched ? 0.72 : 1)
                .onClick(() => this.flipCard(r * 4 + c))
              })
            }
          })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%')

      if (this.isWin) {
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

          Text('全部找到!')
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold)
            .fontColor(DarkColors.textPrimary).margin({ top: SpacingTokens.md, bottom: SpacingTokens.xs })
          Text('尝试: ' + this.attempts + '  ·  最佳: ' + this.bestScore)
            .fontFamily(FontTokens.family)
            .fontSize(FontTokens.sizeSubtitle).fontColor(DarkColors.warning)
            .margin({ bottom: SpacingTokens.base })
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
        }.width('86%').padding(SpacingTokens.lg)
        .borderRadius(RadiusTokens.xl)
        .backgroundColor(DarkColors.surfaceTranslucent)
        .backdropBlur(24)
        .shadow(ShadowTokens.float)
      }
    }.width('100%').height('100%')
  }
}
