import { GameInfo, GameCategory, GAME_CATEGORIES } from '../common/GameConstants';
import { SeededRandom } from '../model/game/RandomSource';
import { GameDataManager } from '../model/GameData';
import { DAILY_INSPIRATIONS } from '../model/DailyInspirationCatalog';

const STATE_KEY: string = 'dailyFeaturedBatch';
const RECOMMENDATION_COUNT: number = 6;

class DailyGameGroup {
  games: GameInfo[] = [];
  cursor: number = 0;
}

/** Local calendar-day content and repeatable recommendations, independent of UI and routing. */
@ObservedV2
export class DailyFeaturedViewModel {
  @Trace inspiration: Resource = $r('app.string.home_banner_subtitle');
  @Trace recommendations: GameInfo[] = [];
  private day: number = -1;
  private batch: number = 0;
  private catalogKey: string = '';
  private ordered: GameInfo[] = [];

  update(catalog: GameInfo[], date: Date = new Date()): void {
    if (!Number.isFinite(date.getTime())) { return; }
    const day: number = Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86400000);
    const index: number = ((day % DAILY_INSPIRATIONS.length) + DAILY_INSPIRATIONS.length) % DAILY_INSPIRATIONS.length;
    this.inspiration = DAILY_INSPIRATIONS[index];
    const orderedCatalog: GameInfo[] = catalog.slice().sort((left: GameInfo, right: GameInfo): number =>
      left.id < right.id ? -1 : left.id === right.id ? 0 : 1);
    const key: string = orderedCatalog.map((game: GameInfo): string => game.id).join(',');
    const stored: string[] = GameDataManager.getTextSetting(STATE_KEY, '').split(':');
    let batch: number = 0;
    if (stored.length === 2 && stored[0] === day.toString()) {
      const value: number = Number(stored[1]);
      if (Number.isInteger(value) && value >= 0 && value <= 1000000) { batch = value; }
    }
    if (day !== this.day || key !== this.catalogKey) {
      this.ordered = this.order(orderedCatalog, day);
      this.catalogKey = key;
    }
    this.day = day;
    this.batch = batch;
    this.select();
  }

  refresh(catalog: GameInfo[], date: Date = new Date()): void {
    this.update(catalog, date);
    if (this.ordered.length === 0 || !Number.isFinite(date.getTime())) { return; }
    this.batch = this.batch >= 1000000 ? 0 : this.batch + 1;
    GameDataManager.setTextSetting(STATE_KEY, this.day.toString() + ':' + this.batch.toString());
    this.select();
  }

  private order(catalog: GameInfo[], day: number): GameInfo[] {
    const random: SeededRandom = new SeededRandom(Math.abs(day) + 1);
    const groups: DailyGameGroup[] = [];
    GAME_CATEGORIES.forEach((category: GameCategory): void => {
      const group: DailyGameGroup = new DailyGameGroup();
      group.games = catalog.filter((game: GameInfo): boolean => game.category === category);
      for (let i: number = group.games.length - 1; i > 0; i--) {
        const at: number = Math.floor(random.next() * (i + 1));
        const previous: GameInfo = group.games[i];
        group.games[i] = group.games[at];
        group.games[at] = previous;
      }
      if (group.games.length > 0) { groups.push(group); }
    });
    const result: GameInfo[] = [];
    while (result.length < catalog.length && groups.length > 0) {
      const previousLength: number = result.length;
      groups.forEach((group: DailyGameGroup): void => {
        if (group.cursor < group.games.length) { result.push(group.games[group.cursor++]); }
      });
      if (previousLength === result.length) { break; }
    }
    return result;
  }

  private select(): void {
    const result: GameInfo[] = [];
    const count: number = Math.min(RECOMMENDATION_COUNT, this.ordered.length);
    for (let i: number = 0; i < count; i++) {
      result.push(this.ordered[(this.batch * RECOMMENDATION_COUNT + i) % this.ordered.length]);
    }
    this.recommendations = result;
  }
}
