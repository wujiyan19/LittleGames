import { GameInfo, GameDifficulty } from '../../common/GameConstants';
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../../common/DesignTokens';
import { SafeAreaInsets } from '../../common/SafeAreaInsets';
import { GameLifecycleBus } from '../../common/GameLifecycleBus';
import { GameSessionTransfer } from '../../common/GameSessionTransfer';
import { GameDataManager } from '../../model/GameData';
import { collectionRules } from '../../model/CollectionCatalog';
import { CollectionViewModel } from '../../viewmodel/CollectionViewModel';
import { GameHeader } from '../../components/GameHeader';
import { ExitConfirmDialog } from '../../components/ExitConfirmDialog';
import { GameResultDialog } from '../../components/GameResultDialog';
import { CollectionArt } from '../../common/CollectionArt';

@ComponentV2
export struct CollectionPage {
  @Param gameId: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local vm: CollectionViewModel = new CollectionViewModel();
  @Local game: GameInfo | undefined = undefined;
  private artLabels: string[] = [];

  aboutToAppear(): void {
    this.game = GameDataManager.getGameById(this.gameId); this.vm.init(this.gameId);
    const labels: Resource[] = [$r('app.string.collection_empty'), $r('app.string.collection_art_robot'),
      $r('app.string.collection_art_exit'), $r('app.string.collection_art_wall'), $r('app.string.collection_art_path'),
      $r('app.string.collection_art_player'), $r('app.string.collection_art_on'), $r('app.string.collection_art_off'),
      $r('app.string.collection_art_filled'), $r('app.string.collection_art_peg'), $r('app.string.collection_art_legal')];
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.artLabels = labels.map((label: Resource) => {
        try { return context.resourceManager.getStringSync(label.id); } catch (e) { return ''; }
      });
    }
    GameLifecycleBus.attach(this.vm);
    if (!GameSessionTransfer.restore(this.vm)) { this.vm.startGame(); }
  }
  aboutToDisappear(): void { GameLifecycleBus.detach(this.vm); this.vm.dispose(); }
  requestExit(): void { if (!this.vm.requestBack()) { this.pathStack.pop(); } }
  rows(): number[] {
    return new Array<number>(Math.ceil(this.vm.state.board.length / this.vm.state.cols)).fill(0).map((v: number, i: number) => i);
  }
  columns(): number[] { return new Array<number>(this.vm.state.cols).fill(0).map((v: number, i: number) => i); }
  showBoard(): boolean {
    return !this.vm.isQuiz() && !['hanoi', 'nim', 'reaction'].includes(this.gameId);
  }
  cellText(index: number): string {
    const value: number = this.vm.state.board[index];
    if (this.gameId === 'schulte' || this.gameId === 'memorysequence') { return value.toString(); }
    if (this.gameId === 'flood') { return (value + 1).toString(); }
    return this.vm.legal(index) ? '·' : '';
  }
  cellDescription(index: number): string {
    const value: number = this.vm.state.board[index];
    let label: number = 0;
    if (this.gameId === 'maze') {
      label = index === this.vm.state.cursor ? 1 : index === this.vm.state.answer ? 2 : value === 1 ? 3 : 4;
    } else if (this.vm.isDuel() && value > 0) {
      return (this.artLabels[5] ?? '').replace('%d', value.toString());
    } else if (this.gameId === 'lights') {
      label = value === 1 ? 6 : 7;
    } else if (this.gameId === 'nonogram') {
      label = value === 1 ? 8 : 0;
    } else if (this.gameId === 'peg' && value === 1) {
      label = 9;
    } else if (this.vm.legal(index)) { label = 10;
    } else if (this.cellText(index).length > 0) { return this.cellText(index); }
    return this.artLabels[label] ?? '';
  }
  indices(count: number): number[] {
    return new Array<number>(count).fill(0).map((v: number, i: number) => i);
  }
  discs(post: number): number[] {
    const result: number[] = [];
    for (let i = 0; i < this.vm.state.board.length; i++) {
      if (this.vm.state.board[i] === post) { result.push(i); }
    }
    return result;
  }
  memoryCards(): number[] {
    if (this.gameId === 'memorysequence' && this.vm.state.phase !== 0) {
      return new Array<number>(this.vm.state.target.length).fill(0);
    }
    return this.vm.state.phase === 0 ? this.vm.state.target : this.vm.state.board;
  }
  choiceText(index: number): string {
    const value: number = this.vm.state.choices[index];
    if (this.gameId === 'compare') { return value === -1 ? '＜' : value === 0 ? '＝' : '＞'; }
    return (this.gameId === 'flood' ? value + 1 : value).toString();
  }
  reactionText(): Resource {
    if (this.vm.state.phase === 0) { return $r('app.string.collection_reaction_start'); }
    return this.vm.state.phase === 1 ? $r('app.string.collection_reaction_wait') : $r('app.string.collection_reaction_go');
  }
  resultTitle(): Resource {
    if (this.vm.isDuel()) {
      return this.vm.state.outcome === 3 ? $r('app.string.collection_draw') : $r('app.string.collection_player_win', this.vm.state.outcome);
    }
    return this.vm.state.outcome === 1 ? $r('app.string.collection_win') : $r('app.string.collection_fail');
  }
  resultDetail(): Resource {
    if (this.gameId === 'reaction' && this.vm.state.outcome === 1) { return $r('app.string.collection_reaction_result', this.vm.state.answer); }
    if (this.vm.isDuel()) { return $r('app.string.collection_steps', this.vm.state.moves); }
    return $r('app.string.collection_score_result', this.vm.state.score);
  }

  build() {
    Stack() {
      Column() {
        GameHeader({ gameTitle: this.game?.name ?? '', showScore: false, showPause: false,
          showDifficulty: !['tictactoe', 'gomoku', 'reversi', 'fourline', 'reaction'].includes(this.gameId),
          difficulty: this.vm.difficulty, onDifficultyChange: (d: GameDifficulty) => { this.vm.changeDifficulty(d); },
          onBack: () => { this.requestExit(); }, onRestart: () => { this.vm.startGame(); } })
        Scroll() {
          Column({ space: SpacingTokens.base }) {
            this.StatusLine()
            if (this.vm.isQuiz() && this.vm.feedback.length > 0) {
              Text(this.vm.lastCorrect ? $r('app.string.collection_correct', this.vm.feedback) : $r('app.string.collection_wrong', this.vm.feedback))
                .fontSize(FontTokens.sizeBodySmall).fontColor(this.vm.lastCorrect ? SemanticColors.success : SemanticColors.warning)
            }
            if (this.gameId === 'nonogram') {
              Column({ space: SpacingTokens.sm }) {
                Text($r('app.string.collection_columns')).fontWeight(FontWeight.Bold).fontColor(SemanticColors.textPrimary)
                Text(this.vm.clues(true)).fontColor(SemanticColors.textPrimary)
                Text($r('app.string.collection_rows')).fontWeight(FontWeight.Bold).fontColor(SemanticColors.textPrimary)
                Text(this.vm.clues(false)).fontColor(SemanticColors.textPrimary)
              }.width('100%')
            }
            if (this.gameId === 'memorysequence' || this.gameId === 'missing') { this.MemoryCards() }
            if (this.vm.isQuiz() && this.gameId !== 'missing') { this.Question() }
            if (this.showBoard()) { this.Board() }
            if (this.gameId === 'nim') { this.Stones() }
            if (this.gameId === 'hanoi') { this.Towers() }
            if (this.gameId === 'reaction') {
              Button({ type: ButtonType.Normal }) {
                Column({ space: SpacingTokens.sm }) {
                  Image(CollectionArt.signal(this.vm.state.phase)).width($r('app.float.collection_art_beacon')).aspectRatio(1)
                  Text(this.reactionText()).fontSize(FontTokens.sizeSubtitle).fontWeight(FontWeight.Bold).fontColor(SemanticColors.textPrimary)
                }.padding(SpacingTokens.base)
              }
                .width('100%').height($r('app.float.collection_signal_height'))
                .borderRadius(RadiusTokens.xl).backgroundColor(SemanticColors.surface)
                .accessibilityText(this.reactionText())
                .onClick(() => { this.vm.tap(0); })
            }
            if (this.gameId === 'maze') {
              Row({ space: SpacingTokens.sm }) {
                ForEach(['↑', '→', '↓', '←'], (label: string, direction: number) => {
                  Button(label).layoutWeight(1).height($r('app.float.collection_control_height'))
                    .onClick(() => { this.vm.move(direction); })
                })
              }.width('100%')
            }
            if (this.vm.state.choices.length > 0 && this.gameId !== 'hanoi' && !(this.gameId === 'missing' && this.vm.state.phase === 0)) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                ForEach(this.vm.state.choices, (value: number, index: number) => {
                  Button({ type: ButtonType.Normal }) {
                    Stack() {
                      Image(this.gameId === 'flood' ? CollectionArt.flood(value) : $r('app.media.col_ceramic_cell'))
                        .width('100%').height('100%').objectFit(ImageFit.Fill)
                      Text(this.choiceText(index)).fontSize(FontTokens.sizeSubtitle).fontWeight(FontWeight.Bold)
                        .fontColor(this.gameId === 'flood' ? $r('app.color.collection_ink') : $r('app.color.collection_art_ink'))
                    }.width('100%').height('100%')
                  }
                    .width('44%').height($r('app.float.collection_control_height')).margin(SpacingTokens.xs)
                    .padding(0).borderRadius(RadiusTokens.sm).backgroundColor(Color.Transparent)
                    .accessibilityText(this.choiceText(index)).onClick(() => { this.vm.choose(index); })
                }, (value: number, index: number) => this.vm.state.round + ':' + index + ':' + value)
              }.width('100%')
            }
            if ((this.gameId === 'memorysequence' || this.gameId === 'missing') && this.vm.state.phase === 0) {
              Button($r('app.string.collection_ready')).onClick(() => { this.vm.action(); })
            }
            if (this.gameId === 'nonogram') {
              Button($r('app.string.collection_check')).onClick(() => { this.vm.action(); })
              if (this.vm.checked && this.vm.state.outcome === 0) {
                Text($r('app.string.collection_check_again')).fontColor(SemanticColors.warning)
              }
            }
            Column({ space: SpacingTokens.sm }) {
              Text($r('app.string.collection_rules')).fontWeight(FontWeight.Bold).fontColor(SemanticColors.textPrimary)
              Text(collectionRules(this.gameId)).fontSize(FontTokens.sizeBody).lineHeight($r('app.float.collection_rule_line')).fontColor(SemanticColors.textSecondary)
            }.alignItems(HorizontalAlign.Start).width('100%').padding(SpacingTokens.base)
              .backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
          }.width('100%').constraintSize({ maxWidth: $r('app.float.collection_board_max') })
            .padding({ left: SpacingTokens.base, right: SpacingTokens.base, bottom: SpacingTokens.xl })
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }.width('100%').height('100%').padding({ bottom: SafeAreaInsets.bottom })
      if (this.vm.state.outcome !== 0) {
        GameResultDialog({ title: this.resultTitle(), detail: this.resultDetail(), showDetail: true,
          primaryText: $r('app.string.result_play_again'), onPrimary: () => { this.vm.startGame(); },
          showSecondary: true, secondaryText: $r('app.string.exit_confirm_leave'), onSecondary: () => { this.pathStack.pop(); }, cardStyle: true })
      }
      if (this.vm.confirmExit) {
        ExitConfirmDialog({ onConfirm: () => { this.vm.dismissExitConfirm(); this.pathStack.pop(); },
          onCancel: () => { this.vm.dismissExitConfirm(); } })
      }
    }.width('100%').height('100%').backgroundColor(SemanticColors.bg)
  }
  @Builder
  StatusLine() {
    Column({ space: SpacingTokens.sm }) {
      if (this.vm.isDuel()) {
        Row({ space: SpacingTokens.sm }) {
          Image(CollectionArt.piece(this.gameId, this.vm.state.player)).width($r('app.float.collection_art_turn')).aspectRatio(1)
          Text($r('app.string.collection_turn', this.vm.state.player)).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeBodyLarge)
        }
      }
      else if (this.vm.isQuiz()) { Text($r('app.string.collection_round', Math.min(10, this.vm.state.round + 1), this.vm.state.score)).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeBodyLarge) }
      else if (this.gameId === 'flood') { Text($r('app.string.collection_limit', this.vm.state.moves, this.vm.state.answer)).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeBodyLarge) }
      else if (this.gameId === 'schulte') { Text($r('app.string.collection_target', this.vm.state.answer)).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeBodyLarge) }
      else if (this.gameId === 'memorysequence') { Text($r('app.string.collection_progress', this.vm.state.cursor, this.vm.state.target.length)).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeBodyLarge) }
      else if (this.gameId !== 'reaction') { Text($r('app.string.collection_steps', this.vm.state.moves)).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeBodyLarge) }
      if (this.gameId === 'nim') { Text($r('app.string.collection_stones', this.vm.state.board[0])).fontColor(SemanticColors.textPrimary).fontSize(FontTokens.sizeTitle) }
    }
  }
  @Builder
  Board() {
    Stack() {
      Image(CollectionArt.board(this.gameId)).width('100%').height('100%').objectFit(ImageFit.Fill)
      Column({ space: this.gameId === 'gomoku' || this.gameId === 'maze' ? 0 : SpacingTokens.xs }) {
        ForEach(this.rows(), (row: number) => {
          Row({ space: this.gameId === 'gomoku' || this.gameId === 'maze' ? 0 : SpacingTokens.xs }) {
            ForEach(this.columns(), (col: number) => {
              Button({ type: ButtonType.Normal }) { this.Cell(row * this.vm.state.cols + col) }
                .layoutWeight(1).height('100%').padding(0).borderRadius(RadiusTokens.xs)
                .backgroundColor(Color.Transparent)
                .border({ width: this.vm.state.selected === row * this.vm.state.cols + col ? 2 : 0, color: SemanticColors.primary })
                .opacity(this.gameId === 'peg' && this.vm.state.board[row * this.vm.state.cols + col] === -1 ? 0 : 1)
                .enabled(!(this.gameId === 'memorysequence' && this.vm.state.phase === 0) &&
                  !(this.gameId === 'peg' && this.vm.state.board[row * this.vm.state.cols + col] === -1))
                .accessibilityText($r('app.string.collection_cell', row + 1, col + 1, this.cellDescription(row * this.vm.state.cols + col)))
                .onClick(() => { this.vm.tap(row * this.vm.state.cols + col); })
            }, (col: number) => this.vm.state.cols.toString() + ':' + col.toString())
          }.width('100%').layoutWeight(1)
        }, (row: number) => this.vm.state.cols.toString() + ':' + row.toString())
      }.width('100%').height('100%').padding(SpacingTokens.md)
    }.width('100%').aspectRatio(this.vm.state.cols / Math.max(1, this.rows().length))
  }
  @Builder
  Cell(index: number) {
    Stack() {
      Image(CollectionArt.cell(this.gameId, this.vm.state.board[index])).width('100%').height('100%').objectFit(ImageFit.Fill)
      if (this.vm.isDuel() && this.vm.state.board[index] > 0) {
        Image(CollectionArt.piece(this.gameId, this.vm.state.board[index])).width('94%').height('94%').objectFit(ImageFit.Contain)
      } else if (this.gameId === 'peg' && this.vm.state.board[index] === 1) {
        Image($r('app.media.col_peg')).width('94%').height('94%').objectFit(ImageFit.Contain)
      } else if (this.gameId === 'maze' && index === this.vm.state.cursor) {
        Image($r('app.media.col_robot')).width('100%').height('100%').objectFit(ImageFit.Contain)
      } else if (this.gameId === 'maze' && index === this.vm.state.answer) {
        Image($r('app.media.col_portal')).width('100%').height('100%').objectFit(ImageFit.Contain)
      }
      if (this.cellText(index).length > 0) {
        Text(this.cellText(index)).fontSize(this.vm.state.cols >= 7 ? FontTokens.sizeBody : FontTokens.sizeSubtitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.gameId === 'flood' ? $r('app.color.collection_ink') :
            this.gameId === 'reversi' ? Color.White : $r('app.color.collection_art_ink'))
      }
    }.width('100%').height('100%')
  }
  @Builder
  Question() {
    Stack() {
      Image(CollectionArt.question(this.gameId)).width('100%').height('100%').objectFit(ImageFit.Fill)
      Column({ space: SpacingTokens.sm }) {
        Image(this.game?.icon).width($r('app.float.collection_art_question_icon')).aspectRatio(1)
        Text(this.vm.state.prompt).fontSize(FontTokens.sizeTitle).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.collection_art_ink')).textAlign(TextAlign.Center).width('100%')
      }.padding(SpacingTokens.xl).width('100%')
    }.width('100%').height($r('app.float.collection_art_question_height'))
  }
  @Builder
  MemoryCards() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(this.memoryCards(), (value: number, index: number) => {
        Stack() {
          Image(this.gameId === 'memorysequence' && this.vm.state.phase !== 0 ?
            $r('app.media.col_card_back') : $r('app.media.col_card_front')).width('100%').height('100%').objectFit(ImageFit.Fill)
          if (!(this.gameId === 'memorysequence' && this.vm.state.phase !== 0)) {
            Text(value.toString()).fontSize(FontTokens.sizeSubtitle).fontWeight(FontWeight.Bold).fontColor($r('app.color.collection_art_ink'))
          }
        }.width($r('app.float.collection_art_card_width')).height($r('app.float.collection_art_card_height'))
          .margin(SpacingTokens.xs)
          .accessibilityText(this.gameId === 'memorysequence' && this.vm.state.phase !== 0 ?
            $r('app.string.collection_art_hidden') : $r('app.string.collection_art_card', value))
      }, (value: number, index: number) => index.toString() + ':' + value.toString())
    }.width('100%').padding(SpacingTokens.sm).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
  }
  @Builder
  Stones() {
    Stack() {
      Image($r('app.media.col_table_tray')).width('100%').height('100%').objectFit(ImageFit.Fill)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignContent: FlexAlign.Center }) {
        ForEach(this.indices(this.vm.state.board[0]), (index: number) => {
          Image($r('app.media.col_stone')).width('14%').height($r('app.float.collection_art_stone')).objectFit(ImageFit.Contain)
        }, (index: number) => index.toString())
      }.width('100%').height('100%').padding(SpacingTokens.base)
    }.width('100%').height($r('app.float.collection_art_tray_height'))
      .accessibilityText($r('app.string.collection_stones', this.vm.state.board[0]))
  }
  @Builder
  Towers() {
    Row({ space: SpacingTokens.sm }) {
      ForEach([0, 1, 2], (post: number) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: SpacingTokens.sm }) {
            Text($r('app.string.collection_post', post + 1)).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textPrimary)
            Stack({ alignContent: Alignment.Bottom }) {
              Image($r('app.media.col_hanoi_post')).width('100%').height('100%').objectFit(ImageFit.Fill)
              Column() {
                ForEach(this.discs(post), (disc: number) => {
                  Stack() {
                    Image(CollectionArt.disc(disc)).width('100%').height('100%').objectFit(ImageFit.Fill)
                    Text((disc + 1).toString()).fontSize(FontTokens.sizeBodySmall).fontWeight(FontWeight.Bold).fontColor($r('app.color.collection_ink'))
                  }.width((44 + disc * 13) + '%').height($r('app.float.collection_art_disc_height'))
                }, (disc: number) => disc.toString())
              }.width('100%').padding({ bottom: SpacingTokens.xl })
            }.width('100%').layoutWeight(1)
          }.width('100%').height('100%').padding(SpacingTokens.xs)
        }.layoutWeight(1).height($r('app.float.collection_art_tower_height')).padding(SpacingTokens.xs)
          .backgroundColor(this.vm.state.selected === post ? SemanticColors.primaryLight : SemanticColors.surface)
          .borderRadius(RadiusTokens.base)
          .border({ width: this.vm.state.selected === post ? 2 : 0, color: SemanticColors.primary })
          .accessibilityText($r('app.string.collection_art_tower', post + 1, this.discs(post).map((disc: number) => disc + 1).join(', ')))
          .onClick(() => { this.vm.choose(post); })
      })
    }.width('100%')
  }
}
