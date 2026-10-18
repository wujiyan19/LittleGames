import { Want } from '@kit.AbilityKit';
import { GameRoutes } from '../router/GameRouteRegistry';

/** The launch request survives cold startup and is also observed by the already-open home page. */
@ObservedV2
export class WidgetLaunch {
  @Trace revision: number = 0;
  private pendingGameId: string = '';
  private resumeGameId: string = '';

  receive(want: Want): void {
    const gameId: Object | undefined = want.parameters?.widgetGameId;
    if (typeof gameId !== 'string' || GameRoutes.routeName(gameId).length === 0) { return; }
    this.pendingGameId = gameId;
    this.resumeGameId = want.parameters?.widgetResume === 'true' ? gameId : '';
    this.revision++;
  }

  takeGameId(): string {
    const gameId: string = this.pendingGameId;
    this.pendingGameId = '';
    return gameId;
  }

  takeResume(gameId: string): boolean {
    if (this.resumeGameId !== gameId) { return false; }
    this.resumeGameId = '';
    return true;
  }
}

export const widgetLaunch: WidgetLaunch = new WidgetLaunch();
