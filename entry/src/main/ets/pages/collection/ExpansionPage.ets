import { GameInfo, GameDifficulty } from '../../common/GameConstants';
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../../common/DesignTokens';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { DisplayFrameLoop } from '../../common/DisplayFrameLoop';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { GameSessionTransfer } from '../../common/GameSessionTransfer';
import { GameDataManager } from '../../model/GameData';
import { expansionRules } from '../../model/ExpansionCatalog';
import { ExpansionPiece, ExpansionPile, BLOCK_SHAPES } from '../../model/game/ExpansionState';
import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { GameHeader } from '../../components/GameHeader';
import { GameResultDialog } from '../../components/GameResultDialog';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { range } from '../../common/Range';
import { ExpansionExtras } from './ExpansionExtras';
import { ExpansionMatchingBoard } from './ExpansionMatchingBoard';
import { ExpansionSortingBoard } from './ExpansionSortingBoard';
import { MATCHING_IDS } from '../../model/game/ExpansionMatching';
import { SORTING_IDS } from '../../model/game/ExpansionSorting';
import { ACTION_IDS } from '../../model/game/ExpansionAction';
import { SPORTS_IDS } from '../../model/game/ExpansionSports';
import { ExpansionWorldBoard } from './ExpansionWorldBoard';
import { ExpansionCardBoard } from './ExpansionCardBoard';
import { CHESS_IDS } from '../../model/game/ExpansionChess';
import { POKER_IDS } from '../../model/game/ExpansionPoker';
import { CARD_IDS } from '../../model/game/ExpansionCards';
import { BRAIN_IDS } from '../../model/game/ExpansionBrain';
import { LIFE_IDS } from '../../model/game/ExpansionLife';
import { ExpansionBrainBoard } from './ExpansionBrainBoard';
import { ExpansionLifeBoard } from './ExpansionLifeBoard';
import { ExpansionArt } from '../../common/ExpansionArt';
import { GameArtTile } from '../../components/GameArtTile';
import { ExpansionFeedback } from '../../components/ExpansionFeedback';

@ComponentV2
export struct ExpansionPage {
  @Param gameId: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local vm: ExpansionViewModel = new ExpansionViewModel();
  @Local game: GameInfo | undefined = undefined;
  @Local arenaWidth: number = 320;

  aboutToAppear(): void {
    this.game = GameDataManager.getGameById(this.gameId);
    this.vm.init(this.gameId, new DisplayFrameLoop(this.getUIContext())); GameLifecycleBus.attach(this.vm);
    if (!GameSessionTransfer.restore(this.vm)) { this.vm.startGame(); }
  }
  aboutToDisappear(): void { GameLifecycleBus.detach(this.vm); this.vm.dispose(); }
  requestExit(): void { if (!this.vm.requestBack()) { this.pathStack.pop(); } }
  color(value: number): Resource {
    const palette: Resource[] = [$r('app.color.expansion_color_1'), $r('app.color.expansion_color_2'), $r('app.color.expansion_color_3'),
      $r('app.color.expansion_color_4'), $r('app.color.expansion_color_5'), $r('app.color.expansion_color_6')];
    return value <= 0 ? SemanticColors.surface : palette[(value - 1) % palette.length];
  }
  symbol(value: number): string { return value <= 0 ? '' : ['◆', '●', '★', '▲', '♥', '✿'][(value - 1) % 6]; }
  arrow(value: number): string { return ['↑', '→', '↓', '←'][value % 4]; }
  fruit(tier: number): string { return ['🍒', '🍓', '🍇', '🍊', '🍎', '🍐', '🍑', '🥭', '🍈', '🍉'][tier]; }
  pipe(mask: number): string { return ['', '╵', '╶', '└', '╷', '│', '┌', '├', '╴', '┘', '─', '┴', '┐', '┤', '┬', '┼'][mask]; }
  scenery(index: number, right: boolean): string {
    const v: number = this.vm.state.board[index];
    return ['🌲', '🌻', '🏠', '🍄', '🌳', '🦋'][(v - 1 + (right && this.vm.state.target.includes(index) ? 1 : 0)) % 6];
  }
  arenaRadius(p: ExpansionPiece): number { return p.kind === 8 ? 70 : p.kind === 10 ? 50 : p.r; }
  arenaText(p: ExpansionPiece): string {
    if (p.kind === 13) { return '🚪'; }
    if (p.kind === 14) { return '⚙'; }
    if (p.kind === 15) { return '👾'; }
    if (p.kind === 16) { return '⌒'; }
    if (p.kind === 17) { return '🏀'; }
    if (p.kind === 18) { return '♩'; }
    if (this.gameId === 'fruitmerge') { return this.fruit(p.color); }
    if (this.gameId === 'fisheat') { return '🐟'; }
    if (this.gameId === 'blackhole') { return p.kind === 8 ? '●' : this.symbol(p.color); }
    if (this.gameId === 'runner') { return p.kind === 6 ? '🏃' : p.color === 1 ? '●' : '▣'; }
    return this.symbol(p.color);
  }
  arenaScale(): number { return this.arenaWidth / 360; }
  measureArena(area: Area): void {
    const width: number = Number(area.width);
    if (Number.isFinite(width) && width > 0) { this.arenaWidth = width; }
  }
  resultTitle(): Resource {
    if ((CHESS_IDS.includes(this.gameId) && this.vm.state.data[8] === 1) || (this.gameId === 'mahjong' && this.vm.state.data[3] === 1)) { return $r('app.string.expansion_draw_game'); }
    if (this.gameId === 'tug') { return $r('app.string.expansion_player_wins', this.vm.state.cursor + 1); }
    if (this.gameId === 'dots') {
      const blue: number = this.vm.state.data.filter((v: number) => v === 1).length; const red: number = this.vm.state.data.filter((v: number) => v === 2).length;
      return blue === red ? $r('app.string.expansion_draw_game') : $r('app.string.expansion_player_wins', blue > red ? 1 : 2);
    }
    return this.vm.state.outcome === 1 ? $r('app.string.collection_win') : $r('app.string.collection_fail');
  }
  value(index: number): number {
    if (this.gameId === 'tilestack') { const top: number = this.vm.top(index); return top < 0 ? 0 : this.vm.state.board[top]; }
    return this.vm.state.board[index];
  }
  depth(index: number): number {
    const count: number = this.vm.state.cols * this.vm.state.rows; let result: number = 0;
    for (let layer: number = 0; layer < 3; layer++) { if (this.vm.state.board[layer * count + index] > 0) { result++; } } return result;
  }
  cellText(index: number): string {
    if (this.gameId === 'pipes') { return this.pipe(this.vm.state.board[index]); }
    if (this.gameId === 'sokoban') {
      if (index === this.vm.state.cursor) { return '🚶'; }
      if (this.vm.state.pieces.some((p: ExpansionPiece) => p.y * this.vm.state.cols + p.x === index)) { return '📦'; }
      return this.vm.state.board[index] === 1 ? '▣' : this.vm.state.board[index] === 2 ? '◎' : '';
    }
    const v: number = this.value(index); if (this.gameId === 'arrowclear') { return v === 0 ? '' : this.arrow(v - 1); }
    return this.gameId === 'blockfit' ? '' : this.symbol(v);
  }
  cellArt(index: number): Resource {
    if (this.gameId === 'pipes') { return ExpansionArt.pipe(this.vm.state.board[index]); }
    if (this.gameId === 'sokoban') {
      if (index === this.vm.state.cursor) { return $r('app.media.exp_robot'); }
      if (this.vm.state.pieces.some((p: ExpansionPiece) => p.y * this.vm.state.cols + p.x === index)) { return $r('app.media.exp_crate'); }
      return this.vm.state.board[index] === 1 ? $r('app.media.exp_wall') : this.vm.state.board[index] === 2 ? $r('app.media.exp_goal') : $r('app.media.exp_floor');
    }
    const value: number = this.value(index);
    if (value === 0) { return $r('app.media.exp_empty'); }
    if (this.gameId === 'arrowclear') { return ExpansionArt.arrow(value - 1); }
    return this.gameId === 'blockfit' ? ExpansionArt.block(value - 1) : ExpansionArt.tile(value - 1);
  }
  remaining(): number {
    if (this.gameId === 'solitaire') { return 52 - this.vm.state.piles.slice(9).reduce((total: number, pile: ExpansionPile) => total + pile.cards.length, 0); }
    if (this.gameId === 'sokoban') { return this.vm.state.pieces.filter((p: ExpansionPiece) => this.vm.state.board[p.y * this.vm.state.cols + p.x] !== 2).length; }
    if (this.gameId === 'pipes') { return this.vm.state.board.length - this.vm.state.tray.length; }
    return this.gameId === 'screwout' || this.gameId === 'parkingjam' || this.gameId === 'mahjongsolitaire' ? this.vm.state.pieces.filter((p: ExpansionPiece) => p.alive && p.kind !== 1).length :
      this.vm.state.board.filter((v: number) => v > 0).length;
  }

  build() {
    Stack() {
      Column() {
        GameHeader({ gameTitle: this.game?.name ?? '', showScore: true, scoreValue: this.vm.state.score,
          highScoreValue: this.game?.highScore ?? 0, showPause: this.vm.realtime(), isPaused: this.vm.paused,
          difficulty: this.vm.difficulty, onDifficultyChange: (d: GameDifficulty) => { this.vm.changeDifficulty(d); },
          onPauseToggle: () => { this.vm.togglePause(); }, onBack: () => { this.requestExit(); }, onRestart: () => { this.vm.startGame(); } })
        Scroll() {
          Column({ space: SpacingTokens.base }) {
            this.Status()
            if (BRAIN_IDS.includes(this.gameId)) { ExpansionBrainBoard({ gameId: this.gameId, vm: this.vm }) }
            if (LIFE_IDS.includes(this.gameId)) { ExpansionLifeBoard({ gameId: this.gameId, vm: this.vm }) }
            if (CHESS_IDS.includes(this.gameId) || POKER_IDS.includes(this.gameId) || CARD_IDS.includes(this.gameId)) { ExpansionCardBoard({ gameId: this.gameId, vm: this.vm }) }
            if (ACTION_IDS.includes(this.gameId) || SPORTS_IDS.includes(this.gameId)) { ExpansionWorldBoard({ gameId: this.gameId, vm: this.vm }) }
            if (MATCHING_IDS.includes(this.gameId)) { ExpansionMatchingBoard({ gameId: this.gameId, vm: this.vm }) }
            if (SORTING_IDS.includes(this.gameId)) { ExpansionSortingBoard({ gameId: this.gameId, vm: this.vm }) }
            if (['blockfit', 'tilestack', 'arrowclear', 'sokoban', 'pipes'].includes(this.gameId)) { this.GridBoard() }
            if (this.gameId === 'differences') { this.Differences() }
            if (this.gameId === 'blockfit') { this.BlockTray() }
            if (this.gameId === 'tilestack') { this.TileTray() }
            if (this.gameId === 'watersort') { this.Tubes() }
            if (this.gameId === 'parkingjam') { this.Parking() }
            if (this.gameId === 'screwout') { this.Screws() }
            if (this.vm.realtime() && this.gameId !== 'restaurant' && !ACTION_IDS.includes(this.gameId) && !SPORTS_IDS.includes(this.gameId) && !BRAIN_IDS.includes(this.gameId) && !LIFE_IDS.includes(this.gameId)) { this.Arena() }
            if (['roomdefense', 'basketball', 'rhythm', 'restaurant', 'runner'].includes(this.gameId) && this.vm.state.phase === 0) {
              Button($r('app.string.expansion_ready')).onClick(() => { this.vm.activate(); })
            }
            if (['solitaire', 'characters', 'restaurant', 'roomdefense', 'rhythm'].includes(this.gameId)) {
              ExpansionExtras({ gameId: this.gameId, vm: this.vm })
            }
            if (this.gameId === 'runner') {
              Row({ space: SpacingTokens.base }) {
                Button($r('app.string.expansion_left')).layoutWeight(1).height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(0); })
                Button($r('app.string.expansion_right')).layoutWeight(1).height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(1); })
              }.width('100%')
            }
            if (this.gameId === 'sokoban') {
              Row({ space: SpacingTokens.sm }) {
                ForEach(range(4), (d: number) => {
                  Button(this.arrow(d)).layoutWeight(1).height($r('app.float.expansion_control_height'))
                    .accessibilityText($r('app.string.expansion_move', this.arrow(d))).onClick(() => { this.vm.tap(d); })
                }, (d: number) => d.toString())
              }.width('100%')
            }
            if (!this.vm.realtime()) {
              Button($r('app.string.expansion_undo')).enabled(this.vm.canUndo).height($r('app.float.expansion_control_height'))
                .onClick(() => { this.vm.undo(); })
            }
            Column({ space: SpacingTokens.sm }) {
              Text($r('app.string.collection_rules')).fontWeight(FontWeight.Bold).fontColor(SemanticColors.textPrimary)
              Text(expansionRules(this.gameId)).fontSize(FontTokens.sizeBody).lineHeight($r('app.float.collection_rule_line')).fontColor(SemanticColors.textSecondary)
            }.alignItems(HorizontalAlign.Start).width('100%').padding(SpacingTokens.base)
              .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          }.width('100%').constraintSize({ maxWidth: $r('app.float.expansion_board_max') })
            .padding({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: SpacingTokens.xl })
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off).enableScrollInteraction(!this.vm.dragging)
      }.width('100%').height('100%').padding({ bottom: SafeAreaInsets.bottom })
      Column() {
        ExpansionFeedback({ vm: this.vm })
      }.width('100%').height('100%').padding({ top: $r('app.float.art_feedback_top') }).hitTestBehavior(HitTestMode.None)
      if (this.vm.paused) {
        Column({ space: SpacingTokens.base }) {
          Text($r('app.string.expansion_paused')).fontSize(FontTokens.sizeTitle).fontColor(SemanticColors.textPrimary)
          Button($r('app.string.expansion_resume')).onClick(() => { this.vm.togglePause(); })
        }.padding(SpacingTokens.xl).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.xl)
      }
      if (this.vm.state.outcome !== 0) {
        GameResultDialog({ title: this.resultTitle(),
          detail: $r('app.string.collection_score_result', this.vm.state.score), showDetail: true,
          primaryText: $r('app.string.result_play_again'), onPrimary: () => { this.vm.startGame(); },
          showSecondary: true, secondaryText: $r('app.string.exit_confirm_leave'), onSecondary: () => { this.pathStack.pop(); }, cardStyle: true, celebrate: this.vm.state.outcome === 1 })
      }
      if (this.vm.confirmExit) {
        ExitConfirmDialog({ onConfirm: () => { this.vm.dismissExitConfirm(); this.pathStack.pop(); }, onCancel: () => { this.vm.dismissExitConfirm(); } })
      }
    }.width('100%').height('100%').backgroundColor(SemanticColors.bg)
  }
  @Builder
  Status() {
    Column({ space: SpacingTokens.sm }) {
      if (BRAIN_IDS.includes(this.gameId) || LIFE_IDS.includes(this.gameId)) {
        Text($r('app.string.expansion_progress', this.gameId === 'picturepuzzle' ? this.vm.state.board.filter((v: number, i: number) => v === i).length : ['hiddenobjects', 'onestroke'].includes(this.gameId) ? this.vm.state.tray.length : LIFE_IDS.includes(this.gameId) || this.gameId === 'beatjump' ? this.vm.state.cursor : this.vm.state.moves, this.vm.state.goal)).fontColor(SemanticColors.textPrimary)
        if (['hiddenobjects', 'idiom', 'melody', 'fishing'].includes(this.gameId)) { Text($r('app.string.expansion_errors', this.vm.state.errors)).fontColor(SemanticColors.warning) }
        if (this.gameId === 'linerescue') { Text($r('app.string.expansion_time', Math.max(0, Math.ceil(this.vm.state.goal - this.vm.state.time)))).fontColor(SemanticColors.textSecondary) }
      } else if (CHESS_IDS.includes(this.gameId) || POKER_IDS.includes(this.gameId) || CARD_IDS.includes(this.gameId)) {
        Text($r('app.string.expansion_moves', this.vm.state.moves)).fontColor(SemanticColors.textSecondary)
      } else if (ACTION_IDS.includes(this.gameId) || SPORTS_IDS.includes(this.gameId)) {
        if (['shooter', 'tanks', 'fortress', 'survival'].includes(this.gameId)) {
          Text($r('app.string.expansion_health', this.vm.state.data[0])).fontColor(SemanticColors.textPrimary)
          Text($r('app.string.expansion_progress', this.vm.state.moves, this.vm.state.goal)).fontColor(SemanticColors.textSecondary)
          if (this.gameId === 'fortress') { Text($r('app.string.expansion_fortress_coins', this.vm.state.data[1])).fontColor(SemanticColors.textSecondary) }
        }
        if (this.gameId === 'penalty') { Text($r('app.string.expansion_penalty_score', this.vm.state.data[0], this.vm.state.data[1])).fontColor(SemanticColors.textPrimary) }
        if (['pingpong', 'airhockey'].includes(this.gameId)) { Text($r('app.string.expansion_match_score', this.vm.state.data[0], this.vm.state.data[1])).fontColor(SemanticColors.textPrimary) }
        if (['fruitslice', 'flappy', 'bowling', 'billiards'].includes(this.gameId)) { Text($r('app.string.expansion_progress', this.gameId === 'fruitslice' ? this.vm.state.moves : this.vm.state.cursor, this.vm.state.goal)).fontColor(SemanticColors.textPrimary) }
        if (['platformer', 'grapple', 'hillclimb'].includes(this.gameId)) { Text($r('app.string.expansion_progress', Math.floor(this.vm.state.pieces[0].x), this.vm.state.goal)).fontColor(SemanticColors.textPrimary) }
        if (this.gameId === 'drift') { Text($r('app.string.expansion_time', Math.max(0, Math.ceil(this.vm.state.goal - this.vm.state.time)))).fontColor(SemanticColors.textPrimary) }
        if (this.gameId === 'golf') { Text($r('app.string.expansion_strokes', this.vm.state.moves, this.vm.state.goal)).fontColor(SemanticColors.textPrimary) }
        if (['fruitslice', 'billiards'].includes(this.gameId)) { Text($r('app.string.expansion_errors', this.vm.state.errors)).fontColor(SemanticColors.warning) }
      } else if (this.gameId === 'blockfit' || this.gameId === 'runner') {
        Text($r('app.string.expansion_target', this.vm.state.goal)).fontColor(SemanticColors.textPrimary)
        if (this.gameId === 'blockfit') { Text($r('app.string.expansion_controls_hint')).fontColor(SemanticColors.textSecondary) }
      } else if (this.gameId === 'untangle') {
        Text($r('app.string.expansion_crossings', this.vm.state.data[0])).fontColor(SemanticColors.textPrimary)
      } else if (['buscolor', 'yarn', 'sand'].includes(this.gameId)) {
        Text($r('app.string.expansion_progress', this.vm.state.cursor, this.vm.state.goal)).fontColor(SemanticColors.textPrimary)
      } else if (['blackhole', 'fisheat', 'differences', 'characters', 'rhythm', 'restaurant', 'roomdefense', 'basketball'].includes(this.gameId)) {
        Text($r('app.string.expansion_progress', this.gameId === 'basketball' ? this.vm.state.data[0] : this.gameId === 'differences' ? this.vm.state.tray.length : this.vm.state.moves, this.vm.state.goal)).fontColor(SemanticColors.textPrimary)
        if (this.gameId === 'blackhole') {
          Text($r('app.string.expansion_time', Math.max(0, Math.ceil(120 - 20 * this.vm.state.level - this.vm.state.time)))).fontColor(SemanticColors.textSecondary)
        }
      } else if (this.gameId === 'bubbleshooter') {
        Row({ space: SpacingTokens.md }) {
          Text($r('app.string.expansion_shots', Math.max(0, this.vm.state.goal - this.vm.state.moves))).fontColor(SemanticColors.textPrimary)
          Image(ExpansionArt.bubble(this.vm.state.next - 1)).width(38).height(38).objectFit(ImageFit.Contain)
            .accessibilityText($r('app.string.expansion_next_ball'))
        }
      } else if (this.gameId === 'fruitmerge') {
        Row({ space: SpacingTokens.sm }) {
          Text($r('app.string.expansion_drop', this.vm.state.next + 1)).fontColor(SemanticColors.textPrimary)
          Image(ExpansionArt.fruit(this.vm.state.next)).width(38).height(38).objectFit(ImageFit.Contain)
        }
      } else {
        Text($r('app.string.expansion_remaining', this.remaining(), this.vm.state.moves)).fontColor(SemanticColors.textPrimary)
      }
      if (['arrowclear', 'differences', 'characters'].includes(this.gameId)) { Text($r('app.string.expansion_errors', this.vm.state.errors)).fontColor(SemanticColors.warning) }
      if (this.gameId === 'screwout' && this.vm.state.tray.length === 3) {
        Text($r('app.string.expansion_full')).fontColor(SemanticColors.warning)
      }
    }
  }
  @Builder
  GridBoard() {
    Column({ space: SpacingTokens.xs }) {
      ForEach(range(this.vm.state.rows), (row: number) => {
        Row({ space: SpacingTokens.xs }) {
          ForEach(range(this.vm.state.cols), (col: number) => {
            Column() {
              Stack({ alignContent: Alignment.BottomEnd }) {
                GameArtTile({ image: this.cellArt(row * this.vm.state.cols + col),
                  description: $r('app.string.expansion_cell', row + 1, col + 1, this.cellText(row * this.vm.state.cols + col)),
                  selected: this.gameId === 'pipes' && this.vm.state.tray.includes(row * this.vm.state.cols + col),
                  onTap: () => { if (this.gameId !== 'sokoban') { this.vm.tap(row * this.vm.state.cols + col); } } })
                if (this.gameId === 'tilestack' && this.depth(row * this.vm.state.cols + col) > 0) {
                  Text(this.depth(row * this.vm.state.cols + col).toString()).fontSize(FontTokens.sizeCaption)
                    .fontColor(SemanticColors.textPrimary).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.xs).padding(2)
                }
                if (this.gameId === 'pipes' && (row * this.vm.state.cols + col === 0 || row * this.vm.state.cols + col === this.vm.state.cursor)) {
                  Text('●').fontSize(FontTokens.sizeCaption).fontColor(row * this.vm.state.cols + col === 0 ? SemanticColors.primary : SemanticColors.success).padding(2)
                }
              }.width('100%').height('100%')
            }.layoutWeight(1).height('100%').padding(0).borderRadius(RadiusTokens.sm)
              .backgroundColor(this.gameId === 'pipes' ? (this.vm.state.tray.includes(row * this.vm.state.cols + col) ? SemanticColors.primaryLight : SemanticColors.surface) :
                ['arrowclear', 'sokoban'].includes(this.gameId) ? SemanticColors.surface : this.color(this.value(row * this.vm.state.cols + col)))
              .opacity(['arrowclear', 'tilestack'].includes(this.gameId) && this.value(row * this.vm.state.cols + col) === 0 ? 0.25 : 1)
              .accessibilityText($r('app.string.expansion_cell', row + 1, col + 1, this.cellText(row * this.vm.state.cols + col)))
          }, (col: number) => col.toString())
        }.width('100%').layoutWeight(1)
      }, (row: number) => this.vm.state.cols + ':' + row)
    }.width('100%').aspectRatio(this.vm.state.cols / this.vm.state.rows).padding(SpacingTokens.sm)
      .backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
  @Builder
  Differences() {
    Row({ space: SpacingTokens.sm }) { this.Scene(false); this.Scene(true) }.width('100%')
  }
  @Builder
  Scene(right: boolean) {
    Column({ space: SpacingTokens.xs }) {
      Text(right ? $r('app.string.expansion_changed') : $r('app.string.expansion_reference')).fontColor(SemanticColors.textSecondary).fontSize(FontTokens.sizeCaption)
      Column({ space: SpacingTokens.xs }) {
        ForEach(range(5), (row: number) => {
          Row({ space: 2 }) {
            ForEach(range(5), (col: number) => {
              Column() {
                GameArtTile({ image: ExpansionArt.object((this.vm.state.board[row * 5 + col] - 1 + (right && this.vm.state.target.includes(row * 5 + col) ? 1 : 0)) % 6),
                  description: $r('app.string.expansion_cell', row + 1, col + 1, this.scenery(row * 5 + col, right)),
                  selected: right && this.vm.state.tray.includes(row * 5 + col), onTap: () => { if (right) { this.vm.tap(row * 5 + col); } } })
              }.layoutWeight(1).height('100%')
            }, (col: number) => col.toString())
          }.layoutWeight(1).width('100%')
        }, (row: number) => row.toString())
      }.width('100%').aspectRatio(1).padding(SpacingTokens.xs).backgroundColor(SemanticColors.boardBg).borderRadius(RadiusTokens.sm)
    }.layoutWeight(1)
  }
  @Builder
  BlockTray() {
    Row({ space: SpacingTokens.sm }) {
      ForEach(this.vm.state.tray, (shape: number, slot: number) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: SpacingTokens.xs }) {
            Text($r('app.string.expansion_piece', slot + 1)).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textSecondary)
            Column({ space: 2 }) {
              ForEach(range(3), (row: number) => {
                Row({ space: 2 }) {
                  ForEach(range(3), (col: number) => {
                    Image(ExpansionArt.block(slot)).width(16).height(16).objectFit(ImageFit.Fill)
                      .opacity(shape >= 0 && col < BLOCK_SHAPES[shape].cols && row < BLOCK_SHAPES[shape].rows && BLOCK_SHAPES[shape].cells.includes(row * BLOCK_SHAPES[shape].cols + col) ? 1 : 0)
                  }, (col: number) => col.toString())
                }
              }, (row: number) => row.toString())
            }
          }.padding(SpacingTokens.sm)
        }.layoutWeight(1).padding(0).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm)
          .border({ width: this.vm.state.selected === slot ? 2 : 0, color: SemanticColors.primary })
          .enabled(shape >= 0).onClick(() => { this.vm.choose(slot); })
      }, (shape: number, slot: number) => slot.toString())
    }.width('100%')
  }
  @Builder
  TileTray() {
    Column({ space: SpacingTokens.sm }) {
      Text($r('app.string.expansion_tray', this.vm.state.tray.length)).fontColor(SemanticColors.textPrimary)
      Row({ space: SpacingTokens.xs }) {
        ForEach(range(7), (index: number) => {
          Image(this.vm.state.tray[index] === undefined ? $r('app.media.exp_empty') : ExpansionArt.tile(this.vm.state.tray[index] - 1))
            .layoutWeight(1).height(42).objectFit(ImageFit.Contain).accessibilityText(this.symbol(this.vm.state.tray[index] ?? 0))
        }, (index: number) => index.toString())
      }.width('100%')
    }
  }
  @Builder
  Tubes() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(range(this.vm.state.cols), (tube: number) => {
        Button({ type: ButtonType.Normal }) {
          Stack() {
            Column({ space: 0 }) {
              ForEach([3, 2, 1, 0], (layer: number) => {
                Image(ExpansionArt.water(this.vm.state.board[tube * 4 + layer] - 1))
                  .objectFit(ImageFit.Fill).width('100%').layoutWeight(1).opacity(this.vm.state.board[tube * 4 + layer] > 0 ? 1 : 0)
              }, (layer: number) => layer.toString())
            }.width('52%').height('78%').translate({ y: 8 }).borderRadius(RadiusTokens.base).clip(true)
            Image($r('app.media.exp_tube')).width('100%').height('100%').objectFit(ImageFit.Fill).hitTestBehavior(HitTestMode.None)
          }.width('100%').height('100%').renderGroup(true)
        }.width('20%').height($r('app.float.expansion_tube_height')).margin(SpacingTokens.xs).padding(0)
          .backgroundColor(Color.Transparent).borderRadius(RadiusTokens.base)
          .border({ width: this.vm.state.selected === tube ? 3 : 1, color: this.vm.state.selected === tube ? SemanticColors.primary : SemanticColors.border })
          .accessibilityText($r('app.string.expansion_tube', tube + 1, this.vm.state.board.slice(tube * 4, tube * 4 + 4).join(', ')))
          .onClick(() => { this.vm.tap(tube); })
      }, (tube: number) => tube.toString())
    }.width('100%')
  }
  @Builder
  Parking() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.vm.state.pieces, (p: ExpansionPiece) => {
        Column() {
          GameArtTile({ image: ExpansionArt.car(p.id % 6), label: this.arrow(p.color), textColor: SemanticColors.textOnPrimary,
            description: $r('app.string.expansion_car', p.id + 1, this.arrow(p.color)), available: p.alive, onTap: () => { this.vm.tap(p.id); } })
        }
          .width(p.w * this.arenaWidth / this.vm.state.cols - 4).height(p.h * this.arenaWidth / this.vm.state.rows - 4)
          .translate({ x: p.x * this.arenaWidth / this.vm.state.cols + 2, y: p.y * this.arenaWidth / this.vm.state.rows + 2 })
          .backgroundColor(this.color(p.id % 6 + 1)).borderRadius(RadiusTokens.sm).opacity(p.alive ? 1 : 0).enabled(p.alive)
      }, (p: ExpansionPiece) => p.id.toString())
    }.width('100%').aspectRatio(1).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      .onAreaChange((previous: Area, current: Area) => { this.measureArena(current); })
  }
  @Builder
  Screws() {
    Column({ space: SpacingTokens.sm }) {
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(3), (slot: number) => {
          Text(this.vm.state.tray[slot] === undefined ? '○' : '⊕').fontSize(FontTokens.sizeTitle).fontColor(SemanticColors.textSecondary)
        }, (slot: number) => slot.toString())
      }
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.vm.state.pieces, (p: ExpansionPiece) => {
          if (p.kind === 0) {
            Image($r('app.media.exp_plate')).objectFit(ImageFit.Fill)
              .width(p.w * this.arenaScale()).height(p.h * this.arenaScale()).backgroundColor(this.color(p.color)).borderRadius(RadiusTokens.sm)
              .translate({ x: p.x * this.arenaScale(), y: p.y * this.arenaScale() }).opacity(p.alive ? 0.9 : 0).hitTestBehavior(HitTestMode.None)
          } else {
            Column() {
              GameArtTile({ image: $r('app.media.exp_screw'), available: p.alive,
                description: $r('app.string.expansion_screw', p.owner + 1), onTap: () => { this.vm.tap(p.id); } })
            }.width(36 * this.arenaScale()).height(36 * this.arenaScale())
              .translate({ x: (p.x - 18) * this.arenaScale(), y: (p.y - 18) * this.arenaScale() }).opacity(p.alive ? 1 : 0).enabled(p.alive)
          }
        }, (p: ExpansionPiece) => p.id.toString())
      }.width('100%').aspectRatio(360 / 460).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base).clip(true)
        .onAreaChange((previous: Area, current: Area) => { this.measureArena(current); })
    }.width('100%')
  }
  @Builder
  Arena() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.gameId === 'runner' || this.gameId === 'rhythm') {
        Row() {
          ForEach(range(this.gameId === 'runner' ? 3 : 4), (lane: number) => {
            Text('').layoutWeight(1).height('100%').border({ width: { right: 1 }, color: SemanticColors.border })
          }, (lane: number) => lane.toString())
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        Text('').width('100%').height(1).backgroundColor(SemanticColors.primary).translate({ y: 400 * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
      }
      if (this.gameId === 'bubbleshooter') {
        ForEach(range(120), (index: number) => {
          Image(ExpansionArt.bubble(this.vm.state.board[index] - 1)).width(38 * this.arenaScale()).height(38 * this.arenaScale()).objectFit(ImageFit.Contain)
            .translate({ x: (this.vm.bubbleX(index) - 19) * this.arenaScale(), y: (this.vm.bubbleY(index) - 19) * this.arenaScale() })
            .opacity(this.vm.state.board[index] > 0 ? 1 : 0).hitTestBehavior(HitTestMode.None)
        }, (index: number) => index.toString())
        Text('↑').width(40 * this.arenaScale()).height(40 * this.arenaScale()).textAlign(TextAlign.Center).fontSize(FontTokens.sizeTitle)
          .fontColor(SemanticColors.primary).translate({ x: 160 * this.arenaScale(), y: 415 * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
      } else if (this.gameId === 'fruitmerge') {
        Text($r('app.string.expansion_warning')).width('100%').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.warning)
          .border({ width: { bottom: 1 }, color: SemanticColors.warning }).translate({ y: 50 * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
      }
      ForEach(this.vm.state.pieces, (p: ExpansionPiece) => {
        Image(ExpansionArt.piece(this.gameId, p)).objectFit(ImageFit.Contain)
          .width(this.arenaRadius(p) * 2 * this.arenaScale()).height(this.arenaRadius(p) * 2 * this.arenaScale())
          .scale({ x: (this.gameId === 'fisheat' && p.vx < 0 ? -1 : 1) * p.r / this.arenaRadius(p), y: p.r / this.arenaRadius(p) })
          .translate({ x: (p.x - this.arenaRadius(p)) * this.arenaScale(), y: (p.y - this.arenaRadius(p)) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
      }, (p: ExpansionPiece) => p.id.toString())
    }.width('100%').aspectRatio(360 / 460).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base).clip(true)
      .onAreaChange((previous: Area, current: Area) => { this.measureArena(current); })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down && ['blackhole', 'fisheat'].includes(this.gameId)) { this.vm.setDragging(true); }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.setDragging(false); }
        if ((event.type === TouchType.Down || (event.type === TouchType.Move && ['blackhole', 'fisheat'].includes(this.gameId))) && event.touches.length > 0 && this.arenaScale() > 0) {
          this.vm.aim(event.touches[0].x / this.arenaScale(), event.touches[0].y / this.arenaScale());
        }
      })
  }
}
