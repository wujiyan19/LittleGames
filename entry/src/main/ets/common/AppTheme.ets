import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** UIAbility.setColorMode 从 API 18 起支持，须在页面加载完成后调用。 */
export class AppTheme {
  static apply(context: common.UIAbilityContext, mode: string): boolean {
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (mode === 'light') { colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT; }
    if (mode === 'dark') { colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK; }
    try {
      context.setColorMode(colorMode);
      return true;
    } catch (e) {
      hilog.error(0x0000, 'LittleGames', 'Failed to apply theme mode');
      return false;
    }
  }
}
