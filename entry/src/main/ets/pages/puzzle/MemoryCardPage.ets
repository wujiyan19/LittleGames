/**
 * 记忆翻牌 - HarmonyOS 设计风格
 */
import { SemanticColors, RadiusTokens, FontTokens, ShadowTokens, SpacingTokens } from '../../common/DesignTokens';
import { GameHeader } from '../../components/GameHeader';
import { GameDifficulty, GameStatus } from '../../common/GameConstants';
import { GameDataManager } from '../../model/GameData';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ScreenUtils } from '../../common/ScreenUtils';
import { range } from '../../common/Range';

interface CardInfo { id: number; emoji: string; flipped: boolean; matched: boolean; }

const ALL_EMOJIS: string[] = ['🎮','🎯','🎲','🎸','🎨','🚀','🌈','⭐','🍎','🌺','🐶','🐱'];
// 棋盘列数固定为 4；行数随难度变化（见 getRowCount）
const COLS = 4;

@ComponentV2
export struct MemoryCardPage {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local safeBottom: number = SafeAreaInsets.bottom;
  @Local cards: CardInfo[] = [];
  @Local flippedIdxs: number[] = [];
  @Local matchedCount: number = 0;
  @Local attempts: number = 0;
  @Local bestScore: number = 999;
    /** 对局状态。本游戏无暂停玩法，只有 进行中 ⇄ 已结束 两态 */
@Local status: GameStatus = GameStatus.PLAYING;
  @Local cardW: number = 78;
  @Local difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Local rowIdx: number[] = range(4);
  private locked: boolean = false;
  private flipTimer: number = -1;
  private colIdx: number[] = range(COLS);

  aboutToAppear(): void {
    const hs = GameDataManager.getGameById('memorycard')?.highScore ?? 0;
    this.bestScore = hs > 0 ? Math.max(1, 1000 - hs) : 999;
    this.initCardSize();
    this.startGame();
  }
  aboutToDisappear(): void { clearTimeout(this.flipTimer); }

  initCardSize(): void {
    this.cardW = ScreenUtils.calcCell(COLS, 520, 48, 56);
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
    GameDataManager.incrementPlayCount('memorycard');
    clearTimeout(this.flipTimer);
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
    this.rowIdx = range(this.getRowCount());
    this.flippedIdxs = [];
    this.matchedCount = 0;
    this.attempts = 0;
    this.status = GameStatus.PLAYING;
    this.locked = false;
  }

  // copy-on-write 更新卡牌状态：cards 是 @Local，直接改 cards[i].flipped 这种
  // 「数组内对象的字段赋值」观测不到，必须整体替换数组才会触发重渲染
  cloneCards(): CardInfo[] {
    const next: CardInfo[] = [];
    for (let i = 0; i < this.cards.length; i++) {
      const cur = this.cards[i];
      next[i] = { id: cur.id, emoji: cur.emoji, flipped: cur.flipped, matched: cur.matched };
    }
    return next;
  }

  setCardFlipped(idx: number, flipped: boolean): void {
    const next = this.cloneCards();
    next[idx].flipped = flipped;
    this.cards = next;
  }

  setPairFlipped(a: number, b: number, flipped: boolean): void {
    const next = this.cloneCards();
    next[a].flipped = flipped;
    next[b].flipped = flipped;
    this.cards = next;
  }

  setPairMatched(a: number, b: number): void {
    const next = this.cloneCards();
    next[a].matched = true;
    next[b].matched = true;
    this.cards = next;
  }

  flipCard(idx: number): void {
    if (this.locked || this.status === GameStatus.OVER) { return; }
    if (this.flippedIdxs.length >= 2) { return; }
    if (this.cards[idx].matched) { return; }
    let alreadyFlipped = false;
    for (let i = 0; i < this.flippedIdxs.length; i++) {
      if (this.flippedIdxs[i] === idx) { alreadyFlipped = true; break; }
    }
    if (alreadyFlipped) { return; }
    this.setCardFlipped(idx, true);
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
        this.flipTimer = setTimeout(() => {
          this.setPairMatched(a, b);
          this.flippedIdxs = [];
          this.matchedCount++;
          this.locked = false;
          if (this.matchedCount === this.getPairCount()) {
            this.status = GameStatus.OVER;
            if (this.attempts < this.bestScore) { this.bestScore = this.attempts; }
            GameDataManager.updateHighScore('memorycard', Math.max(1, 1000 - this.attempts));
          }
        }, 500);
      } else {
        this.flipTimer = setTimeout(() => {
          this.setPairFlipped(a, b, false);
          this.flippedIdxs = [];
          this.locked = false;
        }, 800);
      }
    }
  }

  getCardBg(idx: number): ResourceColor {
    const card = this.cards[idx];
    if (card.matched) { return SemanticColors.success; }
    if (card.flipped) { return SemanticColors.accent; }
    return SemanticColors.surface;
  }

  getCardOpacity(idx: number): number {
    if (this.cards[idx].matched) { return 0.72; }
    return 1;
  }

  getBestText(): string {
    if (this.bestScore === 999) { return '--'; }
    return '' + this.bestScore;
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[SemanticColors.gradientScreen[0], 0], [SemanticColors.gradientScreen[1], 0.5], [SemanticColors.gradientScreen[2], 1]] })

      Column() {
        GameHeader({
          gameTitle: '记忆翻牌',
          showScore: false,
          subtitle: '已配对 ' + this.matchedCount + ' / ' + this.getPairCount(),
          difficulty: this.difficulty,
          onDifficultyChange: (d: GameDifficulty) => { this.changeDifficulty(d); },
          onBack: () => { this.pathStack.pop(); },
          onPauseToggle: () => {},
          onRestart: () => { this.startGame(); }
        })

        Row() {
          Column() {
            Text('尝试').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text('' + this.attempts).fontSize(FontTokens.sizeHeadline).fontWeight(FontTokens.weightBold).fontColor(SemanticColors.accent)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 16 })
          Column() {
            Text('最佳').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textTertiary)
            Text(this.getBestText()).fontSize(FontTokens.sizeHeadline)
              .fontWeight(FontTokens.weightBold).fontColor(SemanticColors.textPrimary)
          }.layoutWeight(1).padding(8).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          .alignItems(HorizontalAlign.Center).margin({ left: 8, right: 16 })
        }.margin({ top: 12, bottom: 12 })

        Column() {
          ForEach(this.rowIdx, (r: number) => {
            Row() {
              ForEach(this.colIdx, (c: number) => {
                Column() {
                  if (this.cards[r * COLS + c].flipped || this.cards[r * COLS + c].matched) {
                    Text(this.cards[r * COLS + c].emoji).fontSize(Math.max(24, this.cardW * 0.45))
                  } else {
                    SymbolGlyph($r('sys.symbol.star'))
                      .fontSize(Math.max(16, this.cardW * 0.3))
                      .fontColor([SemanticColors.textTertiary])
                  }
                }.width(this.cardW).height(this.cardW * 1.15).margin(3)
                .backgroundColor(this.getCardBg(r * COLS + c))
                .borderRadius(RadiusTokens.base)
                .shadow(ShadowTokens.button)
                .opacity(this.getCardOpacity(r * COLS + c))
                .onClick(() => this.flipCard(r * COLS + c))
              }, (c: number) => c.toString())
            }
          }, (r: number) => r.toString())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }.width('100%').height('100%').padding({ bottom: this.safeBottom })

      if (this.status === GameStatus.OVER) {
        GameResultDialog({
          symbol: $r('sys.symbol.star_fill'),
          symbolColor: SemanticColors.warning,
          title: '全部找到!',
          detail: '尝试: ' + this.attempts + '  ·  最佳: ' + this.bestScore,
          detailColor: SemanticColors.warning,
          primaryText: '再来一局',
          onPrimary: () => { this.startGame(); },
          cardStyle: true
        })
      }
    }.width('100%').height('100%')
  }
}
