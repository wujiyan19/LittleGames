import { GameDifficulty } from '../common/GameConstants';
import { GameLifecycleBus, GameLifecycleObserver } from '../common/GameLifecycleBus';
import { FrameLoop } from '../common/FrameLoop';
import { GameDataManager } from '../model/GameData';
import { ExpansionModel } from '../model/game/ExpansionModel';
import { ExpansionPiece, ExpansionState } from '../model/game/ExpansionState';
import { CHESS_IDS } from '../model/game/ExpansionChess';
import { ExpansionRenderPiece } from './ExpansionRenderPiece';
import { COMPUTER_GAME_IDS, COMPUTER_TURN_DELAY_MS } from '../common/ComputerOpponent';
import { GameSoundEvent, gameSound } from '../common/GameSound';

interface ExpansionSnapshot { version: number; state: ExpansionState; recorded: boolean; paused: boolean; }

@ObservedV2
export class ExpansionViewModel implements GameLifecycleObserver {
  @Trace state: ExpansionState = new ExpansionState();
  @Trace worldPieces: ExpansionRenderPiece[] = [];
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Trace paused: boolean = false;
  @Trace confirmExit: boolean = false;
  @Trace isFinished: boolean = false;
  @Trace canUndo: boolean = false;
  @Trace dragging: boolean = false;
  @Trace legalTargets: number[] = [];
  @Trace feedbackSerial: number = 0;
  @Trace feedbackKind: number = 0;
  @Trace feedbackGain: number = 0;
  @Trace effectsEnabled: boolean = true;
  @Trace computerThinking: boolean = false;
  @Trace computerPlayer: number = 1;
  private model: ExpansionModel = new ExpansionModel();
  private frame: FrameLoop | null = null;
  private id: string = '';
  private initialProgress: string = '';
  private recorded: boolean = false;
  private visible: boolean = true;
  private accumulator: number = 0;
  private renderElapsed: number = 0;
  private tone: (note: number) => void = (note: number): void => {};
  private toneStop: () => void = (): void => {};
  private toneSerial: number = 0;
  private computerTimer: number = -1;
  private computerGeneration: number = 0;

  init(id: string, frame: FrameLoop | null = null): void {
    this.id = id; this.frame = frame; this.difficulty = GameDataManager.getInitialDifficulty(id);
    this.model.deferComputerTurns = true;
  }
  setToneCallbacks(play: (note: number) => void, stop: () => void): void { this.tone = play; this.toneStop = stop; this.toneSerial = 0; }
  startGame(): void {
    gameSound.stop(this.id);
    this.stop(); this.paused = false; this.confirmExit = false; this.recorded = false; this.dragging = false;
    this.feedbackKind = 0; this.feedbackGain = 0; this.feedbackSerial++;
    const level: number = this.difficulty === GameDifficulty.EASY ? 0 : this.difficulty === GameDifficulty.HARD ? 2 : 1;
    this.effectsEnabled = this.visible && !this.confirmExit;
    this.model.start(this.id, level); GameDataManager.recordGamePlayed(this.id); this.sync(false);
    this.initialProgress = JSON.stringify(this.state);
  }
  changeDifficulty(d: GameDifficulty): void {
    if (d === this.difficulty) { return; } this.difficulty = d;
    GameDataManager.rememberGameDifficulty(this.id, d); this.startGame();
  }
  private sync(feedback: boolean = true, interaction: boolean = false): void {
    const previous: ExpansionState = this.state;
    this.state = JSON.parse(JSON.stringify(this.model.state)) as ExpansionState; this.canUndo = this.model.canUndo();
    this.syncWorldPieces();
    this.isFinished = this.state.outcome !== 0;
    if (feedback && this.effectsEnabled && previous.id === this.state.id && previous.outcome === 0) {
      const gain: number = this.state.score - previous.score;
      const hurt: boolean = ['shooter', 'tanks', 'fortress', 'survival', 'roomdefense'].includes(this.id) &&
        previous.data.length > 0 && this.state.data.length > 0 && this.state.data[this.id === 'roomdefense' ? 1 : 0] < previous.data[this.id === 'roomdefense' ? 1 : 0];
      if (this.state.errors > previous.errors || hurt) { this.feedbackKind = 2; this.feedbackGain = 0; this.feedbackSerial++; }
      else if (gain > 0) { this.feedbackKind = 1; this.feedbackGain = gain; this.feedbackSerial++; }
      if (this.state.outcome !== 0) {
        const draw: boolean = this.id === 'chess' && this.state.data[8] === 1 || this.id === 'mahjong' && this.state.data[3] === 1;
        gameSound.play(this.id, draw ? GameSoundEvent.DRAW : this.state.outcome === 1 ? GameSoundEvent.WIN : GameSoundEvent.LOSE);
      } else if (this.state.errors > previous.errors || hurt) { gameSound.play(this.id, GameSoundEvent.ERROR); }
      else if (gain > 0) { gameSound.play(this.id, GameSoundEvent.REWARD); }
      else if (interaction && this.id !== 'melody' && (this.state.moves !== previous.moves || this.state.selected !== previous.selected ||
        this.state.phase !== previous.phase || this.state.cursor !== previous.cursor || this.state.serial !== previous.serial ||
        this.state.next !== previous.next || this.state.pieces.length !== previous.pieces.length || this.state.tray.join(',') !== previous.tray.join(','))) {
        gameSound.play(this.id);
      }
    }
    if (this.state.id === 'melody' && this.state.data[1] !== this.toneSerial) {
      this.toneSerial = this.state.data[1]; if (!this.blocked() && this.state.phase === 1 && this.state.selected >= 0) { this.tone(this.state.selected); }
    }
    this.legalTargets = [];
    if (CHESS_IDS.includes(this.state.id) && this.state.selected >= 0) {
      for (let to: number = 0; to < this.state.board.length; to++) { if (this.model.chess.legal(this.model.state, this.state.selected, to)) { this.legalTargets.push(to); } }
    }
    if (this.state.outcome !== 0 && !this.recorded) {
      this.recorded = true; this.stop(); GameDataManager.updateHighScore(this.id, this.state.score);
    }
    if (this.state.outcome !== 0) { this.effectsEnabled = false; }
    this.refreshComputerTurn();
  }
  private syncWorldPieces(): void {
    // ForEach keeps children for the same ID. Update the observed wrapper so their
    // images and transforms read the new snapshot without rebuilding every frame.
    const existing: Map<number, ExpansionRenderPiece> = new Map<number, ExpansionRenderPiece>();
    this.worldPieces.forEach((rendered: ExpansionRenderPiece) => { existing.set(rendered.id, rendered); });
    const next: ExpansionRenderPiece[] = [];
    this.state.pieces.forEach((piece: ExpansionPiece) => {
      if (!piece.alive) { return; }
      const rendered: ExpansionRenderPiece | undefined = existing.get(piece.id);
      if (rendered) { rendered.piece = piece; next.push(rendered); }
      else { next.push(new ExpansionRenderPiece(piece)); }
    });
    this.worldPieces = next;
  }
  tap(index: number): void {
    if (this.computerThinking || this.blocked()) { return; }
    if (this.state.id === 'melody' && this.state.phase === 0 && this.state.outcome === 0 && index >= 0 && index < 4) { this.tone(index); }
    this.model.tap(index); this.sync(true, true); this.run();
  }
  activate(): void { if (this.blocked()) { return; } this.model.activate(); this.sync(true, true); this.run(); }
  action(): void { if (this.blocked()) { return; } this.model.action(); this.sync(true, true); }
  choose(index: number): void { if (this.computerThinking || this.blocked()) { return; } this.model.choose(index); this.sync(true, true); }
  undo(): void { if (this.blocked()) { return; } this.cancelComputerTurn(); this.model.undo(); this.feedbackKind = 0; this.feedbackGain = 0; this.feedbackSerial++; this.sync(false); }
  aim(x: number, y: number): void {
    if (this.blocked()) { return; } this.model.aim(x, y); this.sync(true, true); this.run();
  }
  private blocked(): boolean { return this.paused || this.confirmExit || !this.visible; }
  setDragging(active: boolean): void {
    this.dragging = active && !this.blocked();
    if (!active && this.state.id === 'untangle') { this.model.releaseNode(); this.sync(); }
    if (!active && ['platformer', 'fruitslice', 'hillclimb', 'fishing'].includes(this.state.id)) { this.model.releaseControls(); this.sync(); }
  }
  terrain(x: number): number { return this.model.sports.terrain(x); }
  mahjongCan(command: number): boolean { return this.model.cards.mahjongCan(this.state, command); }
  tileFree(id: number): boolean { return this.model.matching.tileFree(this.state, id); }
  crossingEdges(): number[] { return this.model.sorting.crossingEdges(this.state); }
  realtime(): boolean { return this.model.realtime(); }
  top(index: number): number { return this.model.puzzle.top(this.state, index); }
  bubbleX(index: number): number { return this.model.physics.bubbleX(index); }
  bubbleY(index: number): number { return this.model.physics.bubbleY(index); }
  private run(): void {
    if (!this.frame || this.blocked() || this.state.outcome !== 0 || this.model.state.phase === 0) { return; }
    this.frame.start((deltaMs: number) => { this.advance(deltaMs); });
  }
  advance(deltaMs: number): void {
    if (this.blocked() || this.state.outcome !== 0 || !Number.isFinite(deltaMs) || deltaMs < 0) { return; }
    this.accumulator += Math.min(100, deltaMs); this.renderElapsed += deltaMs;
    while (this.accumulator >= 8 && this.model.state.outcome === 0) { this.model.step(0.008); this.accumulator -= 8; }
    if (this.renderElapsed >= 32 || this.model.state.outcome !== 0 || this.model.state.phase === 0) { this.renderElapsed = 0; this.sync(); }
    if (this.model.state.phase === 0 || this.model.state.outcome !== 0) { this.stop(); }
  }
  private stop(): void { this.cancelComputerTurn(); this.frame?.stop(); this.accumulator = 0; this.renderElapsed = 0; this.toneStop(); }
  togglePause(): void {
    gameSound.stop(this.id); this.paused = !this.paused; this.effectsEnabled = !this.blocked() && this.state.outcome === 0; this.setDragging(false); if (this.paused) { this.stop(); } else { this.run(); this.refreshComputerTurn(); } }
  onAppHidden(): void {
    gameSound.stop(this.id);
    this.visible = false; this.effectsEnabled = false; this.setDragging(false); this.stop();
  }
  onAppShown(): void { this.visible = true; this.effectsEnabled = !this.blocked() && this.state.outcome === 0; this.run(); this.refreshComputerTurn(); }
  onBackRequested(): boolean { return this.requestBack(); }
  requestBack(): boolean {
    if (this.state.outcome !== 0 || !GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    gameSound.stop(this.id); this.confirmExit = true; this.effectsEnabled = false; this.setDragging(false); this.stop(); return true;
  }
  dismissExitConfirm(): void { this.confirmExit = false; this.effectsEnabled = !this.blocked() && this.state.outcome === 0; this.run(); this.refreshComputerTurn(); }
  dispose(): void { this.visible = false; this.effectsEnabled = false; this.stop(); this.setDragging(false); this.frame?.dispose(); }
  isPlayTimeActive(): boolean {
    return this.state.id.length > 0 && this.state.outcome === 0 && !this.paused && !this.confirmExit;
  }

  hasProgress(): boolean { return this.state.outcome === 0 && JSON.stringify(this.state) !== this.initialProgress; }

  hasComputerOpponent(): boolean { return COMPUTER_GAME_IDS.includes(this.id); }
  private cancelComputerTurn(): void {
    this.computerGeneration++;
    if (this.computerTimer >= 0) { clearTimeout(this.computerTimer); this.computerTimer = -1; }
  }
  private refreshComputerTurn(): void {
    this.computerThinking = this.model.needsComputerTurn();
    this.computerPlayer = this.model.computerPlayer();
    if (!this.computerThinking) { this.cancelComputerTurn(); return; }
    if (this.computerTimer >= 0 || this.blocked() || !GameLifecycleBus.isAppForeground()) { return; }
    const generation: number = this.computerGeneration;
    this.computerTimer = setTimeout(() => {
      if (generation !== this.computerGeneration) { return; }
      this.computerTimer = -1;
      if (this.blocked() || !GameLifecycleBus.isAppForeground() || !this.model.needsComputerTurn()) { return; }
      this.model.computerTurn(); this.sync(true, true);
    }, COMPUTER_TURN_DELAY_MS);
  }

  continuationGameId(): string { return this.id; }
  exportContinuation(): string {
    // Use the live model, including the physics steps since the last rendered frame.
    const snapshot: ExpansionSnapshot = { version: 1, state: this.model.state, recorded: this.recorded, paused: this.paused };
    return JSON.stringify(snapshot);
  }
  importContinuation(payload: string): boolean {
    try {
      if (payload.length > 65536) { return false; }
      const snapshot: ExpansionSnapshot = JSON.parse(payload) as ExpansionSnapshot;
      if (snapshot === null || snapshot.version !== 1 || typeof snapshot.recorded !== 'boolean' || typeof snapshot.paused !== 'boolean') { return false; }
      const expected: ExpansionModel = new ExpansionModel(); expected.start(this.id, 1);
      if (snapshot.state === null || snapshot.state.id !== this.id || !expected.valid(snapshot.state)) { return false; }
      this.stop(); this.model.restore(snapshot.state); this.recorded = snapshot.recorded || snapshot.state.outcome !== 0;
      this.difficulty = snapshot.state.level === 0 ? GameDifficulty.EASY : snapshot.state.level === 2 ? GameDifficulty.HARD : GameDifficulty.NORMAL;
      this.paused = snapshot.paused || (this.model.realtime() && snapshot.state.phase !== 0);
      this.confirmExit = false; this.dragging = false; this.effectsEnabled = !this.blocked();
      this.feedbackKind = 0; this.feedbackGain = 0; this.feedbackSerial++; this.sync(false); return true;
    } catch (e) { return false; }
  }
}
