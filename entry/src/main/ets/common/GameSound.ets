export enum GameSoundEvent { ACTION, REWARD, ERROR, WIN, LOSE, DRAW }

/** Observable preference and event boundary; native playback belongs to GameSoundPlayer. */
@ObservedV2
export class GameSound {
  static readonly MIN_VOLUME: number = 0;
  static readonly MAX_VOLUME: number = 100;
  static readonly DEFAULT_VOLUME: number = 100;
  static readonly VOLUME_STEP: number = 1;
  @Trace enabled: boolean = true;
  @Trace volume: number = GameSound.DEFAULT_VOLUME;
  private gameId: string = '';
  private visible: boolean = true;
  private playback: (gameId: string, event: GameSoundEvent) => void =
    (gameId: string, event: GameSoundEvent): void => {};
  private prepare: (gameId: string) => void = (gameId: string): void => {};
  private halt: () => void = (): void => {};
  private volumeChanged: () => void = (): void => {};

  connect(play: (gameId: string, event: GameSoundEvent) => void,
    prepare: (gameId: string) => void, stop: () => void,
    volumeChanged: () => void = (): void => {}): void {
    this.playback = play; this.prepare = prepare; this.halt = stop;
    this.volumeChanged = volumeChanged;
    if (this.gameId.length > 0) { this.prepare(this.gameId); }
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (!enabled) { this.stop(); }
  }

  static normalizeVolume(volume: number): number {
    if (!Number.isFinite(volume)) { return GameSound.DEFAULT_VOLUME; }
    return Math.round(Math.max(GameSound.MIN_VOLUME, Math.min(GameSound.MAX_VOLUME, volume)));
  }

  setVolume(volume: number): void {
    if (!Number.isFinite(volume)) { return; }
    const next: number = GameSound.normalizeVolume(volume);
    if (next === this.volume) { return; }
    this.volume = next;
    if (next === GameSound.MIN_VOLUME) { this.stop(); }
    else { this.volumeChanged(); }
  }

  selectGame(gameId: string): void {
    this.stop(); this.gameId = gameId;
    this.prepare(gameId);
  }

  setVisible(visible: boolean): void {
    this.visible = visible;
    if (!visible) { this.stop(); }
  }

  canPlay(gameId: string): boolean {
    return this.enabled && this.volume > GameSound.MIN_VOLUME && this.visible && this.gameId === gameId && gameId.length > 0;
  }

  play(gameId: string, event: GameSoundEvent = GameSoundEvent.ACTION): void {
    if (this.canPlay(gameId)) { this.playback(gameId, event); }
  }

  stop(gameId: string = this.gameId): void { if (gameId === this.gameId) { this.halt(); } }

  disconnect(): void {
    this.stop(); this.gameId = '';
    this.playback = (gameId: string, event: GameSoundEvent): void => {};
    this.prepare = (gameId: string): void => {};
    this.halt = (): void => {};
    this.volumeChanged = (): void => {};
  }
}

export const gameSound: GameSound = new GameSound();
