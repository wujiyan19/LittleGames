import { bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class AppInfo {
  /** 读取当前安装包，发版时无需维护第二份版本号；查询自身无需额外权限。 */
  static version(): string {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.versionName + ' (' + info.versionCode.toString() + ')';
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'Failed to read application version');
      return '';
    }
  }
}
