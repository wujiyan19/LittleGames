import { GameDifficulty } from '../common/GameConstants';
import { GameLifecycleObserver } from '../common/GameLifecycleBus';
import { FrameLoop } from '../common/FrameLoop';
import { GameDataManager } from '../model/GameData';
import { ExpansionModel } from '../model/game/ExpansionModel';
import { ExpansionState } from '../model/game/ExpansionState';
import { CHESS_IDS } from '../model/game/ExpansionChess';

interface ExpansionSnapshot { version: number; state: ExpansionState; recorded: boolean; paused: boolean; }

@ObservedV2
export class ExpansionViewModel implements GameLifecycleObserver {
  @Trace state: ExpansionState = new ExpansionState();
  @Trace difficulty: GameDifficulty = GameDifficulty.NORMAL;
  @Trace paused: boolean = false;
  @Trace confirmExit: boolean = false;
  @Trace canUndo: boolean = false;
  @Trace dragging: boolean = false;
  @Trace legalTargets: number[] = [];
  @Trace feedbackSerial: number = 0;
  @Trace feedbackKind: number = 0;
  @Trace feedbackGain: number = 0;
  @Trace effectsEnabled: boolean = true;
  private model: ExpansionModel = new ExpansionModel();
  private frame: FrameLoop | null = null;
  private id: string = '';
  private recorded: boolean = false;
  private visible: boolean = true;
  private accumulator: number = 0;
  private renderElapsed: number = 0;
  private tone: (note: number) => void = (note: number): void => {};
  private toneStop: () => void = (): void => {};
  private toneSerial: number = 0;

  init(id: string, frame: FrameLoop | null = null): void {
    this.id = id; this.frame = frame; this.difficulty = GameDataManager.getInitialDifficulty(id);
  }
  setToneCallbacks(play: (note: number) => void, stop: () => void): void { this.tone = play; this.toneStop = stop; this.toneSerial = 0; }
  startGame(): void {
    this.stop(); this.paused = false; this.confirmExit = false; this.recorded = false; this.dragging = false;
    this.feedbackKind = 0; this.feedbackGain = 0; this.feedbackSerial++;
    const level: number = this.difficulty === GameDifficulty.EASY ? 0 : this.difficulty === GameDifficulty.HARD ? 2 : 1;
    this.effectsEnabled = this.visible;
    this.model.start(this.id, level); GameDataManager.incrementPlayCount(this.id); this.sync(false);
  }
  changeDifficulty(d: GameDifficulty): void {
    if (d === this.difficulty) { return; } this.difficulty = d;
    GameDataManager.rememberGameDifficulty(this.id, d); this.startGame();
  }
  private sync(feedback: boolean = true): void {
    const previous: ExpansionState = this.state;
    this.state = JSON.parse(JSON.stringify(this.model.state)) as ExpansionState; this.canUndo = this.model.canUndo();
    if (feedback && this.effectsEnabled && previous.id === this.state.id && previous.outcome === 0) {
      const gain: number = this.state.score - previous.score;
      const hurt: boolean = ['shooter', 'tanks', 'fortress', 'survival', 'roomdefense'].includes(this.id) &&
        previous.data.length > 0 && this.state.data.length > 0 && this.state.data[this.id === 'roomdefense' ? 1 : 0] < previous.data[this.id === 'roomdefense' ? 1 : 0];
      if (this.state.errors > previous.errors || hurt) { this.feedbackKind = 2; this.feedbackGain = 0; this.feedbackSerial++; }
      else if (gain > 0) { this.feedbackKind = 1; this.feedbackGain = gain; this.feedbackSerial++; }
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
  }
  tap(index: number): void {
    if (this.blocked()) { return; }
    if (this.state.id === 'melody' && this.state.phase === 0 && this.state.outcome === 0 && index >= 0 && index < 4) { this.tone(index); }
    this.model.tap(index); this.sync(); this.run();
  }
  activate(): void { if (this.blocked()) { return; } this.model.activate(); this.sync(); this.run(); }
  action(): void { if (this.blocked()) { return; } this.model.action(); this.sync(); }
  choose(index: number): void { if (this.blocked()) { return; } this.model.choose(index); this.sync(); }
  undo(): void { if (this.blocked()) { return; } this.model.undo(); this.feedbackKind = 0; this.feedbackGain = 0; this.feedbackSerial++; this.sync(false); }
  aim(x: number, y: number): void {
    if (this.blocked()) { return; } this.model.aim(x, y); this.sync(); this.run();
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
  private stop(): void { this.frame?.stop(); this.accumulator = 0; this.renderElapsed = 0; this.toneStop(); }
  togglePause(): void { this.paused = !this.paused; this.effectsEnabled = !this.blocked() && this.state.outcome === 0; this.setDragging(false); if (this.paused) { this.stop(); } else { this.run(); } }
  onAppHidden(): void { this.visible = false; this.effectsEnabled = false; this.setDragging(false); this.stop(); }
  onAppShown(): void { this.visible = true; this.effectsEnabled = !this.blocked() && this.state.outcome === 0; this.run(); }
  onBackRequested(): boolean { return this.requestBack(); }
  requestBack(): boolean {
    if (this.state.outcome !== 0 || !GameDataManager.getSetting('confirmExitEnabled', true)) { return false; }
    this.confirmExit = true; this.effectsEnabled = false; this.setDragging(false); this.stop(); return true;
  }
  dismissExitConfirm(): void { this.confirmExit = false; this.effectsEnabled = !this.blocked() && this.state.outcome === 0; this.run(); }
  dispose(): void { this.visible = false; this.effectsEnabled = false; this.stop(); this.setDragging(false); this.frame?.dispose(); }
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
      if (!expected.valid(snapshot.state)) { return false; }
      this.stop(); this.model.restore(snapshot.state); this.recorded = snapshot.recorded || snapshot.state.outcome !== 0;
      this.difficulty = snapshot.state.level === 0 ? GameDifficulty.EASY : snapshot.state.level === 2 ? GameDifficulty.HARD : GameDifficulty.NORMAL;
      this.paused = snapshot.paused || (this.model.realtime() && snapshot.state.phase !== 0);
      this.confirmExit = false; this.dragging = false; this.effectsEnabled = !this.blocked();
      this.feedbackKind = 0; this.feedbackGain = 0; this.feedbackSerial++; this.sync(false); return true;
    } catch (e) { return false; }
  }
}
