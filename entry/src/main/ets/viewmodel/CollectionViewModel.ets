import { GameDifficulty } from '../common/GameConstants';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { ContinuationValidation as V } from '../common/GameSessionTransfer';
import { GameDataManager } from '../model/GameData';
import { CollectionModel, CollectionState, COLLECTION_IDS } from '../model/game/CollectionModel';

interface CollectionSnapshot {
  version: number;
  state: CollectionState;
  recorded: boolean;
}

@ObservedV2
export class CollectionViewModel implements GameLifecycleObserver {
  @Trace state: CollectionState = new CollectionState();
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Trace confirmExit: boolean = false;
  @Trace checked: boolean = false;
  @Trace feedback: string = '';
  @Trace lastCorrect: boolean = false;
  private model: CollectionModel = new CollectionModel();
  private timer: number = -1;
  private recorded: boolean = false;
  private id: string = '';

  init(id: string): void { this.id = id; this.difficulty = GameDataManager.getInitialDifficulty(id); }
  startGame(): void {
    this.dispose(); this.confirmExit = false; this.checked = false; this.recorded = false; this.feedback = '';
    const level: number = this.difficulty === GameDifficulty.EASY ? 0 : this.difficulty === GameDifficulty.HARD ? 2 : 1;
    this.model.start(this.id, level); GameDataManager.incrementPlayCount(this.id); this.sync();
  }
  changeDifficulty(d: GameDifficulty): void {
    if (d === this.difficulty) { return; }
    this.difficulty = d; GameDataManager.rememberGameDifficulty(this.id, d); this.startGame();
  }
  private sync(): void {
    // Replace the snapshot so ArkUI observes mutations of arrays and scalar model fields.
    this.state = JSON.parse(JSON.stringify(this.model.state)) as CollectionState;
    if (this.state.outcome !== 0 && !this.recorded) {
      this.recorded = true; this.dispose();
      const game = GameDataManager.getGameById(this.id);
      const score: number = this.model.isDuel() ? (game?.highScore ?? 0) + 1 : this.state.score;
      GameDataManager.updateHighScore(this.id, score);
    }
  }
  tap(index: number): void {
    if (this.confirmExit) { return; }
    this.model.tap(index); this.checked = false; this.sync();
    if (this.id === 'reaction' && this.state.phase === 1 && this.state.outcome === 0 && this.timer < 0) {
      this.timer = setTimeout(() => {
        this.timer = -1; this.model.tick(Date.now()); this.sync();
      }, Math.max(1, this.state.signalAt - Date.now()));
    }
  }
  choose(index: number): void {
    if (this.confirmExit) { return; }
    const answer: number = this.state.answer; const round: number = this.state.round;
    const value: number = this.state.choices[index];
    this.model.choose(index);
    if (this.model.isQuiz() && this.model.state.round > round) {
      this.lastCorrect = value === answer;
      this.feedback = this.id === 'compare' ? (answer === -1 ? '＜' : answer === 0 ? '＝' : '＞') : answer.toString();
    }
    this.sync();
  }
  action(): void { this.model.action(); this.checked = this.state.id === 'nonogram'; this.sync(); }
  move(direction: number): void { this.tap(this.model.neighbor(this.state.cursor, direction)); }
  isDuel(): boolean { return this.model.isDuel(); }
  isQuiz(): boolean { return this.model.isQuiz(); }
  legal(index: number): boolean { return this.id === 'reversi' && this.model.flips(index, this.state.player).length > 0; }
  clues(column: boolean): string {
    const lines: string[] = [];
    for (let i = 0; i < this.state.cols; i++) { lines.push((i + 1) + ': ' + this.model.clue(this.state.target, i, column)); }
    return lines.join('  /  ');
  }
  tower(post: number): string {
    const discs: string[] = [];
    for (let i = 0; i < this.state.board.length; i++) { if (this.state.board[i] === post) { discs.push('━'.repeat(i + 1) + ' ' + (i + 1)); } }
    return discs.join('\n');
  }
  onAppHidden(): void {
    this.dispose();
    if (this.id === 'reaction' && this.state.outcome === 0) { this.model.state.phase = 0; this.model.state.signalAt = 0; this.sync(); }
  }
  onAppShown(): void {}
  onBackRequested(): boolean { return this.requestBack(); }
  requestBack(): boolean {
    if (this.state.outcome !== 0 || !GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    this.onAppHidden(); this.confirmExit = true; return true;
  }
  dismissExitConfirm(): void { this.confirmExit = false; }
  dispose(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  continuationGameId(): string { return this.id; }
  exportContinuation(): string {
    const snapshot: CollectionSnapshot = { version: 1, state: this.state, recorded: this.recorded };
    return JSON.stringify(snapshot);
  }
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 16384) { return false; }
      const snapshot: CollectionSnapshot = JSON.parse(payload) as CollectionSnapshot;
      if (snapshot === null || snapshot.version !== 1 || typeof snapshot.recorded !== 'boolean') { return false; }
      const s: CollectionState = snapshot.state;
      if (s === null || s.id !== this.id || !COLLECTION_IDS.includes(s.id) || !V.integer(s.level, 0, 2) ||
        !V.integer(s.cols, 1, 11) || !V.integer(s.selected, -1, 120) || !V.integer(s.player, 1, 2) ||
        !V.integer(s.moves, 0, 1000000) || !V.integer(s.round, 0, 10) || !V.integer(s.score, 0, 100000) ||
        !V.integer(s.answer, -1000, 1000000) || !V.integer(s.cursor, 0, 121) || !V.integer(s.phase, 0, 2) ||
        !V.integer(s.outcome, 0, 3) || typeof s.prompt !== 'string' || s.prompt.length > 200 ||
        !Number.isFinite(s.signalAt) || s.signalAt < 0 ||
        !Array.isArray(s.board) || s.board.length > 121 || !V.numbers(s.board, s.board.length, -1, 1000) ||
        !Array.isArray(s.target) || s.target.length > 36 || !V.numbers(s.target, s.target.length, 0, 1000) ||
        !Array.isArray(s.choices) || s.choices.length > 6 || !V.numbers(s.choices, s.choices.length, -1000, 1000)) { return false; }
      const expected: CollectionModel = new CollectionModel(); expected.start(this.id, s.level);
      if (s.cols !== expected.state.cols || s.board.length !== expected.state.board.length ||
          s.target.length !== expected.state.target.length || s.choices.length !== expected.state.choices.length) { return false; }
      if (['nim', 'hanoi', 'flood', 'compare'].includes(s.id) &&
          s.choices.some((value: number, index: number) => value !== expected.state.choices[index])) { return false; }
      if (s.id === 'hanoi' && !V.numbers(s.board, s.board.length, 0, 2)) { return false; }
      if (s.id === 'hanoi' && !V.integer(s.selected, -1, 2)) { return false; }
      if (s.id === 'peg') {
        if (s.selected >= s.board.length || (s.selected >= 0 && s.board[s.selected] !== 1)) { return false; }
        for (let i = 0; i < s.board.length; i++) {
          const valid: boolean = Math.floor(i / 5) === 2 || i % 5 === 2;
          if (valid ? !V.integer(s.board[i], 0, 1) : s.board[i] !== -1) { return false; }
        }
      }
      if (s.id === 'maze' && (!V.numbers(s.board, s.board.length, 0, 1) || s.cursor >= s.board.length ||
          s.answer !== s.board.length - s.cols - 2 || s.board[s.cursor] !== 0 || s.board[s.answer] !== 0)) { return false; }
      if (['lights', 'nonogram'].includes(s.id) && !V.numbers(s.board, s.board.length, 0, 1)) { return false; }
      if (s.id === 'nonogram' && !V.numbers(s.target, s.target.length, 0, 1)) { return false; }
      if (s.id === 'flood' && (!V.numbers(s.board, s.board.length, 0, 3) || !V.integer(s.answer, 1, s.board.length + 4))) { return false; }
      if (s.id === 'memorysequence' && (!V.numbers(s.target, s.target.length, 1, 9) || s.cursor > s.target.length)) { return false; }
      if (s.id === 'memorysequence' && s.board.some((value: number, index: number) => value !== index + 1)) { return false; }
      if (s.id === 'schulte' && (new Set<number>(s.board).size !== s.board.length ||
          !V.numbers(s.board, s.board.length, 1, s.board.length) || !V.integer(s.answer, 1, s.board.length + 1))) { return false; }
      if (expected.isDuel() && s.id !== 'nim' && !V.numbers(s.board, s.board.length, 0, 2)) { return false; }
      if (s.id === 'nim' && !V.numbers(s.board, 1, 0, 12 + s.level * 5)) { return false; }
      if (expected.isQuiz() && (!s.choices.includes(s.answer) || new Set<number>(s.choices).size !== s.choices.length)) { return false; }
      if (s.id === 'missing' && (new Set<number>(s.target).size !== s.target.length ||
          !s.target.includes(s.answer) || s.board.includes(s.answer) || new Set<number>(s.board).size !== s.board.length ||
          s.board.some((value: number) => !s.target.includes(value)) || s.choices.some((value: number) => !s.target.includes(value)))) { return false; }
      this.dispose(); this.model.state = s;
      this.difficulty = s.level === 0 ? GameDifficulty.EASY : s.level === 2 ? GameDifficulty.HARD : GameDifficulty.NORMAL;
      // A restored result must not award its score a second time.
      this.recorded = snapshot.recorded || s.outcome !== 0;
      if (s.id === 'reaction' && s.outcome === 0) { s.phase = 0; s.signalAt = 0; }
      this.confirmExit = false; this.checked = false; this.feedback = ''; this.sync(); return true;
    } catch (e) { return false; }
  }
}
