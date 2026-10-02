/** Explicit, versioned game snapshots. No timers, UI objects or native handles cross devices. */
export interface GameSessionParticipant {
  continuationGameId(): string;
  exportContinuation(): string;
  importContinuation(payload: string): boolean;
}

export class GameSessionTransfer {
  private static gameId: string = '';
  private static payload: string = '';
  private static onFailure: () => void = () => {};
  private static onRestored: () => void = () => {};

  static prepare(gameId: string, payload: string): void {
    GameSessionTransfer.gameId = gameId;
    GameSessionTransfer.payload = payload;
  }

  static setFailureHandler(handler: () => void): void {
    GameSessionTransfer.onFailure = handler;
  }

  static setRestoredHandler(handler: () => void): void {
    GameSessionTransfer.onRestored = handler;
  }

  static restore(participant: GameSessionParticipant): boolean {
    if (GameSessionTransfer.gameId !== participant.continuationGameId()) { return false; }
    const payload: string = GameSessionTransfer.payload;
    GameSessionTransfer.clear();
    const restored: boolean = participant.importContinuation(payload);
    if (!restored) { GameSessionTransfer.onFailure(); }
    else { GameSessionTransfer.onRestored(); }
    return restored;
  }

  static clear(): void {
    GameSessionTransfer.gameId = '';
    GameSessionTransfer.payload = '';
  }
}

export class ContinuationValidation {
  static integer(value: number, min: number = 0, max: number = 2147483647): boolean {
    return typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max;
  }

  static finite(value: number): boolean {
    return typeof value === 'number' && Number.isFinite(value) && Math.abs(value) < 10000000;
  }

  static numbers(values: number[], length: number, min: number, max: number): boolean {
    if (!Array.isArray(values) || values.length !== length) { return false; }
    for (let i = 0; i < values.length; i++) {
      if (!ContinuationValidation.integer(values[i], min, max)) { return false; }
    }
    return true;
  }

  static booleans(values: boolean[], length: number): boolean {
    if (!Array.isArray(values) || values.length !== length) { return false; }
    for (let i = 0; i < values.length; i++) {
      if (typeof values[i] !== 'boolean') { return false; }
    }
    return true;
  }

  static matrix(values: number[][], rows: number, cols: number, min: number, max: number): boolean {
    if (!Array.isArray(values) || values.length !== rows) { return false; }
    for (let i = 0; i < rows; i++) {
      if (!ContinuationValidation.numbers(values[i], cols, min, max)) { return false; }
    }
    return true;
  }

  static boolMatrix(values: boolean[][], rows: number, cols: number): boolean {
    if (!Array.isArray(values) || values.length !== rows) { return false; }
    for (let i = 0; i < rows; i++) {
      if (!ContinuationValidation.booleans(values[i], cols)) { return false; }
    }
    return true;
  }
}
