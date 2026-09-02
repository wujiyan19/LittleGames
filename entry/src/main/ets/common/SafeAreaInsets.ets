/**
 * 安全区避让高度（单位 vp）
 *
 * 背景：应用未开启全屏（EntryAbility 未调 setWindowLayoutFullScreen），
 * 系统已为三键导航栏预留布局空间；但手势导航下导航栏高度为 0，
 * 手势条是「悬浮」在应用内容之上的，底部控件会被遮挡。
 *
 * 因此取 AvoidAreaType.TYPE_NAVIGATION_INDICATOR：
 * - 手势导航 → 手势条高度（约 8~10vp），需额外避让
 * - 三键导航 → 0，与系统避让不重复计算
 *
 * 由 EntryAbility.onWindowStageCreate 初始化，并监听 avoidAreaChange 实时更新。
 * 单位为 vp —— getWindowAvoidArea 返回的是 px，必须换算后使用。
 */
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class SafeAreaInsets {
  /** 底部需要额外避让的高度（vp） */
  static bottom: number = 0;

  /**
   * px → vp 换算系数。获取失败时退化为 1（即不换算，按原值处理）。
   */
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
   * 从窗口读取底部手势条避让高度并更新（单位转换为 vp）
   */
  static updateFromWindow(win: window.Window): void {
    try {
      const area: window.AvoidArea =
        win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      SafeAreaInsets.bottom = area.bottomRect.height / SafeAreaInsets.density();
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'getWindowAvoidArea failed, bottom=0');
      SafeAreaInsets.bottom = 0;
    }
  }
}
