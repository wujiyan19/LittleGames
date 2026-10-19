import { Context } from '@kit.AbilityKit';
import { resolveFormattedString } from './I18nUtils';

/** Legacy hours formatter stays available; UI uses adaptive duration below. */
export function playTimeHours(milliseconds: number): string {
  const value: number = Number.isFinite(milliseconds) ? Math.max(0, milliseconds) : 0;
  return (value / 3600000).toFixed(1);
}

export function formatPlayTime(milliseconds: number, context: Context | undefined): string {
  const value: number = Number.isFinite(milliseconds) ? Math.max(0, milliseconds) : 0;
  if (value === 0) { return resolveFormattedString($r('app.string.play_time_zero'), [], context); }
  if (value < 60000) { return resolveFormattedString($r('app.string.play_time_under_minute'), [], context); }
  if (value < 3600000) {
    return resolveFormattedString($r('app.string.play_time_minutes'), [Math.floor(value / 60000).toString()], context);
  }
  return resolveFormattedString($r('app.string.play_time_hours'), [playTimeHours(value)], context);
}
