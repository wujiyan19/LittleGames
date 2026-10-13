import { GameLifecycleBus } from './GameLifecycleBus';
import { GameSessionTransfer, ContinuationValidation } from './GameSessionTransfer';
import { GameRoutes } from '../router/GameRouteRegistry';
import { isGameAvailable } from './GameAvailability';

export interface ContinuationNavigationState {
  tab: number;
  paths: string[];
}

export interface AppContinuationState extends ContinuationNavigationState {
  version: number;
  gameId: string;
  gamePayload: string;
}

/** Explicit navigation and game restoration for both cold and already-running targets. */
export class AppContinuation {
  // Worst-case UTF-8 is three bytes per UTF-16 code unit. Leave room under Want's 100 KB limit.
  static readonly MAX_PAYLOAD_LENGTH: number = 20000;
  private static captureNavigation: (() => ContinuationNavigationState) | null = null;
  private static restoreNavigation: ((state: AppContinuationState) => void) | null = null;
  private static pending: AppContinuationState | null = null;
  private static stateHandler: (active: boolean) => void = () => {};
  private static failureHandler: (() => void) | null = null;
  private static pendingFailure: boolean = false;
  private static restoring: boolean = false;

  static setRestoring(restoring: boolean): void {
    AppContinuation.restoring = restoring;
    AppContinuation.stateHandler(!restoring && AppContinuation.captureNavigation !== null);
  }

  static setFailureHandler(handler: () => void): void {
    AppContinuation.failureHandler = handler;
    if (AppContinuation.pendingFailure) {
      AppContinuation.pendingFailure = false;
      handler();
    }
  }

  static reportFailure(): void {
    const handler: (() => void) | null = AppContinuation.failureHandler;
    if (handler !== null) { handler(); }
    else { AppContinuation.pendingFailure = true; }
  }

  static setStateHandler(handler: (active: boolean) => void): void {
    AppContinuation.stateHandler = handler;
    handler(!AppContinuation.restoring && AppContinuation.captureNavigation !== null);
  }

  static connect(capture: () => ContinuationNavigationState,
    restore: (state: AppContinuationState) => void): void {
    AppContinuation.captureNavigation = capture;
    AppContinuation.restoreNavigation = restore;
    const pending: AppContinuationState | null = AppContinuation.pending;
    AppContinuation.pending = null;
    if (pending !== null) { restore(pending); }
    AppContinuation.stateHandler(!AppContinuation.restoring);
  }

  static disconnect(): void {
    AppContinuation.captureNavigation = null;
    AppContinuation.restoreNavigation = null;
    AppContinuation.failureHandler = null;
    AppContinuation.pending = null;
    AppContinuation.pendingFailure = false;
    AppContinuation.restoring = false;
    GameSessionTransfer.setFailureHandler(() => {});
    GameSessionTransfer.setRestoredHandler(() => {});
    GameSessionTransfer.clear();
    AppContinuation.stateHandler(false);
  }

  static capture(): string {
    const capture: (() => ContinuationNavigationState) | null = AppContinuation.captureNavigation;
    if (capture === null || AppContinuation.restoring) { throw new Error('Application page is not ready'); }
    const navigation: ContinuationNavigationState = capture();
    const paths: string[] = navigation.paths;
    const gameIndex: number = paths.length > 0 && paths[0] === 'PlayHistoryPage' ? 1 : 0;
    const first: string = paths.length > gameIndex ? paths[gameIndex] : '';
    const gameId: string = GameRoutes.gameIdForRoute(first);
    const state: AppContinuationState = {
      version: 1,
      tab: navigation.tab,
      paths: paths,
      gameId: gameId,
      gamePayload: gameId.length > 0 ? GameLifecycleBus.exportSession(gameId) : ''
    };
    const payload: string = JSON.stringify(state);
    if (!AppContinuation.isValid(state) || payload.length > AppContinuation.MAX_PAYLOAD_LENGTH) {
      throw new Error('Unsupported continuation state');
    }
    return payload;
  }

  static receive(payload: string): boolean {
    try {
      if (payload.length > AppContinuation.MAX_PAYLOAD_LENGTH) { return false; }
      const state: AppContinuationState = JSON.parse(payload) as AppContinuationState;
      if (!AppContinuation.isValid(state)) { return false; }
      const restore: ((state: AppContinuationState) => void) | null = AppContinuation.restoreNavigation;
      if (restore === null) { AppContinuation.pending = state; }
      else { restore(state); }
      return true;
    } catch (e) {
      return false;
    }
  }

  static hasPending(): boolean {
    return AppContinuation.pending !== null;
  }

  private static isValid(state: AppContinuationState): boolean {
    if (state === null || state.version !== 1 || !ContinuationValidation.integer(state.tab, 0, 2) ||
        !Array.isArray(state.paths) || state.paths.length > 4 || typeof state.gameId !== 'string' ||
        typeof state.gamePayload !== 'string') { return false; }
    if (state.gameId.length > 0 && !isGameAvailable(state.gameId)) { return false; }
    for (let i = 0; i < state.paths.length; i++) {
      if (typeof state.paths[i] !== 'string' || !GameRoutes.isKnownRoute(state.paths[i]) ||
          (i > 0 && state.paths[i] === 'PlayHistoryPage')) { return false; }
    }
    const gameIndex: number = state.paths.length > 0 && state.paths[0] === 'PlayHistoryPage' ? 1 : 0;
    const pathCount: number = state.paths.length - gameIndex;
    const first: string = pathCount > 0 ? state.paths[gameIndex] : '';
    const gameId: string = GameRoutes.gameIdForRoute(first);
    if (gameId.length > 0) {
      if (pathCount > 3 || (pathCount >= 2 && state.paths[gameIndex + 1] !== 'SettingsPage')) { return false; }
      if (pathCount === 3 && state.paths[gameIndex + 2] !== 'AboutPage') { return false; }
    } else {
      if (pathCount > 2 || (pathCount === 2 &&
        (first !== 'SettingsPage' || state.paths[gameIndex + 1] !== 'AboutPage'))) { return false; }
    }
    return state.gameId === gameId && (gameId.length > 0 ? state.gamePayload.length > 0 : state.gamePayload === '');
  }
}
