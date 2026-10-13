export enum GameSoundEvent { ACTION, REWARD, ERROR, WIN, LOSE, DRAW }

/** Observable preference and event boundary; native playback belongs to GameSoundPlayer. */
@ObservedV2
export class GameSound {
  @Trace enabled: boolean = true;
  private gameId: string = '';
  private visible: boolean = true;
  private playback: (gameId: string, event: GameSoundEvent) => void =
    (gameId: string, event: GameSoundEvent): void => {};
  private prepare: (gameId: string) => void = (gameId: string): void => {};
  private halt: () => void = (): void => {};

  connect(play: (gameId: string, event: GameSoundEvent) => void,
    prepare: (gameId: string) => void, stop: () => void): void {
    this.playback = play; this.prepare = prepare; this.halt = stop;
    if (this.gameId.length > 0) { this.prepare(this.gameId); }
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (!enabled) { this.stop(); }
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
    return this.enabled && this.visible && this.gameId === gameId && gameId.length > 0;
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
  }
}

export const gameSound: GameSound = new GameSound();
