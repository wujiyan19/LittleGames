import { Context } from '@kit.AbilityKit';
import { resolveFormattedString } from './I18nUtils';

/** 存储保留毫秒，展示统一为小时并保留一位小数。 */
export function playTimeHours(milliseconds: number): string {
  const value: number = Number.isFinite(milliseconds) ? Math.max(0, milliseconds) : 0;
  return (value / 3600000).toFixed(1);
}

export function formatPlayTime(milliseconds: number, context: Context | undefined): string {
  return resolveFormattedString($r('app.string.play_time_hours'), [playTimeHours(milliseconds)], context);
}
