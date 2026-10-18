import { hdsMaterial, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { SemanticColors } from './DesignTokens';

/** HarmonyOS 6.1 HDS materials. The system chooses the effect level for this device. */
export class ImmersiveLight {
  static titleBar(): NavigationTitleOptions {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return {
        paddingStart: LengthMetrics.vp(0), paddingEnd: LengthMetrics.vp(0),
        systemMaterial: new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.REGULAR })
      };
    }
    return {
      paddingStart: LengthMetrics.vp(0), paddingEnd: LengthMetrics.vp(0),
      backgroundColor: SemanticColors.surface
    };
  }

  static settingsSheet(onDisappear: () => void): SheetOptions {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return {
        height: SheetSize.LARGE, showClose: false, dragBar: false,
        systemMaterial: new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.THICK }),
        onDisappear: onDisappear
      };
    }
    return {
      height: SheetSize.LARGE, showClose: false, dragBar: false,
      backgroundColor: SemanticColors.bg, onDisappear: onDisappear
    };
  }

  static floatingTabs(): HdsTabsFloatingStyle {
    let materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.ADAPTIVE;
    try {
      const types: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
      if (types.includes(hdsMaterial.MaterialType.IMMERSIVE)) {
        materialType = hdsMaterial.MaterialType.IMMERSIVE;
      }
      hilog.info(0x0000, 'LittleGames', 'Floating tab material: %{public}d; supported: %{public}s',
        materialType, JSON.stringify(types));
    } catch (e) {
      hilog.warn(0x0000, 'LittleGames', 'Using adaptive system material');
    }
    return {
      barWidth: {
        smallWidth: $r('app.float.home_tab_width_small'),
        mediumWidth: $r('app.float.home_tab_width_medium'),
        largeWidth: $r('app.float.home_tab_width_large')
      },
      barSideMargin: $r('app.float.home_tab_side_margin'),
      barBottomMargin: $r('app.float.home_tab_bottom_margin'),
      systemMaterialEffect: {
        materialType: materialType,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      thermoCtrl: true
    };
  }
}
