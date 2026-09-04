/**
 * 屏幕 / 窗口尺寸工具
 *
 * 由来：原先 8 个游戏页各自写了一遍「取屏幕宽 → px 转 vp → 算格子边长」，
 * 只有几个魔数不同（见报告 P1-4）。更关键的是它们都用
 * display.getDefaultDisplaySync().width —— 那是**整个屏幕**的物理宽度，
 * 不是页面可用宽度，在分屏、自由窗口、折叠屏展开态下算出的格子会偏大、棋盘溢出。
 *
 * 改为以**窗口宽度**为准（getWindowProperties().windowRect.width，单位 px），
 * 由 EntryAbility 初始化并监听 windowSizeChange 保持最新。
 *
 * 注意：ArkTS 静态方法内不能用 this，一律用类名访问（ScreenUtils.xxx）。
 */
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class ScreenUtils {
  /** 最近一次取到的窗口宽度（px）；0 表示尚未初始化 */
  private static widthPx: number = 0;

  /** px → vp 换算系数。获取失败时退化为 1（即不换算） */
  private static density(): number {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      if (d.densityPixels > 0) {
        return d.densityPixels;
      }
      return 1;
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'getDefaultDisplaySync failed, fallback density=1');
      return 1;
    }
  }

  /**
   * 从窗口读取当前宽度。由 EntryAbility 调用，并在 windowSizeChange 时重复调用。
   * windowRect 的单位是 px，此处只做存储，取值时再换算。
   */
  static updateFromWindow(win: window.Window): void {
    try {
      ScreenUtils.widthPx = win.getWindowProperties().windowRect.width;
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'getWindowProperties failed, window width unknown');
      ScreenUtils.widthPx = 0;
    }
  }

  /**
   * 当前窗口可用宽度（vp）。
   * 未初始化（例如 EntryAbility 尚未回调）时回退到屏幕宽度，保持旧行为不劣化。
   */
  static windowWidthVp(): number {
    const density: number = ScreenUtils.density();
    if (density <= 0) {
      return 0;
    }
    if (ScreenUtils.widthPx > 0) {
      return ScreenUtils.widthPx / density;
    }
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      return d.width / density;
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'getDefaultDisplaySync failed, window width unknown');
      return 0;
    }
  }

  /**
   * 计算棋盘格子边长（vp）
   *
   * @param count   一行（或一列）的格子数
   * @param maxWidth 棋盘允许占用的最大宽度（vp），窄屏按窗口算、宽屏按此值封顶
   * @param padding 需要扣除的内边距与格子间距总和（vp）
   * @param minSize 格子最小边长（vp），防止极窄窗口下算成 0 或负数
   */
  static calcCell(count: number, maxWidth: number, padding: number, minSize: number): number {
    const widthVp: number = ScreenUtils.windowWidthVp();
    if (widthVp <= 0 || count <= 0) {
      return minSize;
    }
    return Math.max(minSize, Math.floor((Math.min(widthVp, maxWidth) - padding) / count));
  }
}
