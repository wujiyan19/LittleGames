/**
 * HarmonyOS 原生设计令牌。
 * 页面颜色优先采用系统资源；游戏棋盘色保留应用资源并提供深色版本。
 * ArkTS 严格模式
 */

/**
 * 品牌语义别名，统一指向系统强调色。
 */
export class BrandColors {
  static cosmicBlue: Resource = $r('sys.color.ohos_id_color_emphasize');
  static cosmicBlueBright: Resource = $r('sys.color.ohos_id_color_emphasize');
  static cosmicBlueDeep: Resource = $r('sys.color.ohos_id_color_emphasize');
  static auroraPurple: Resource = $r('sys.color.ohos_id_color_emphasize');
  static auroraPurpleBright: Resource = $r('sys.color.ohos_id_color_emphasize');
  static deepSpace: Resource = $r('sys.color.ohos_id_color_sub_background');
  static deepSpaceSurface: Resource = $r('sys.color.ohos_id_color_component_normal');
  static snowfieldBg: Resource = $r('sys.color.ohos_id_color_sub_background');
  static snowfieldSurface: Resource = $r('sys.color.ohos_id_color_component_normal');
  static snowfieldInk: Resource = $r('sys.color.ohos_id_color_text_primary');
}

/**
 * 语义色令牌。component_normal 在本地模拟器的深浅模式中均提供可读的卡片层级。
 */
export class SemanticColors {
  static bg: Resource = $r('sys.color.ohos_id_color_sub_background');
  static bgElevated: Resource = $r('sys.color.ohos_id_color_component_normal');
  static surface: Resource = $r('sys.color.ohos_id_color_component_normal');
  static surfaceHover: Resource = $r('sys.color.ohos_id_color_component_normal');
  static surfaceTranslucent: Resource = $r('sys.color.ohos_id_color_bottom_tab_sub_bg_blur');
  static scrim: Resource = $r('app.color.scrim');
  static primary: Resource = $r('sys.color.ohos_id_color_emphasize');
  static primaryHover: Resource = $r('sys.color.ohos_id_color_emphasize');
  static primaryActive: Resource = $r('sys.color.ohos_id_color_emphasize');
  static primaryLight: Resource = $r('sys.color.ohos_id_color_component_activated');
  static accent: Resource = $r('sys.color.ohos_id_color_emphasize');
  static accentLight: Resource = $r('sys.color.ohos_id_color_component_activated');
  static success: Resource = $r('app.color.success');
  static warning: Resource = $r('app.color.warning');
  static error: Resource = $r('app.color.error');
  static textPrimary: Resource = $r('sys.color.ohos_id_color_text_primary');
  static textSecondary: Resource = $r('sys.color.ohos_id_color_text_secondary');
  static textTertiary: Resource = $r('sys.color.ohos_id_color_text_tertiary');
  static textDisabled: Resource = $r('sys.color.ohos_id_color_text_tertiary');
  static textOnPrimary: Resource = $r('sys.color.ohos_id_color_text_primary_contrary');
  static divider: Resource = $r('sys.color.ohos_id_color_component_normal');
  static border: Resource = $r('app.color.border');
  static borderStrong: Resource = $r('app.color.border_strong');
  static gradientScreen: Resource[] = [
    $r('sys.color.ohos_id_color_sub_background'),
    $r('sys.color.ohos_id_color_sub_background'),
    $r('sys.color.ohos_id_color_sub_background')
  ];
  static gradientHero: Resource[] = [
    $r('sys.color.ohos_id_color_emphasize'),
    $r('sys.color.ohos_id_color_emphasize'),
    $r('sys.color.ohos_id_color_emphasize')
  ];
  static gradientBrand: Resource[] = [
    $r('sys.color.ohos_id_color_emphasize'),
    $r('sys.color.ohos_id_color_emphasize')
  ];
  /** 游戏棋盘/格子系统色 */
  static cellHidden: Resource = $r('app.color.cell_hidden');
  static cellRevealed: Resource = $r('app.color.cell_revealed');
  static boardBg: Resource = $r('app.color.board_bg');
  static boardBorder: Resource = $r('app.color.board_border');
}

/**
 * 间距令牌
 */
export class SpacingTokens {
  static xs = 4;
  static sm = 8;
  static md = 12;
  static base = 16;
  static lg = 20;
  static xl = 24;
  static xxl = 32;
  static xxxl = 48;
  static pageHorizontal = 16;
  static pageTop = 12;
  static pageBottom = 24;
}

/**
 * 圆角令牌
 */
export class RadiusTokens {
  static xs = 4;
  static sm = 8;
  static md = 8;
  static base = 16;
  static lg = 16;
  static xl = 24;
  static xxl = 32;
  static full = 9999;
}

/**
 * 字体令牌 —— 统一使用 HarmonyOS Sans 系统字体
 */
export class FontTokens {
  /** 系统字体：HarmonyOS Sans，跨设备渲染效果最佳 */
  static family = 'HarmonyOS Sans';
  static sizeCaption = 12;
  static sizeBodySmall = 12;
  static sizeBody = 14;
  static sizeBodyLarge = 16;
  static sizeSubtitle = 16;
  static sizeTitle = 24;
  static sizeHeadline = 24;
  static sizeDisplay = 30;
  static sizeMega = 48;

  static weightRegular = 400;
  static weightMedium = 500;
  static weightSemibold = 600;
  static weightBold = 700;
}

/**
 * 阴影令牌：只为浮层保留轻投影。
 */
export class ShadowTokens {
  static card: ShadowOptions = { radius: 0, color: $r('app.color.card_shadow'), offsetX: 0, offsetY: 0 };
  static button: ShadowOptions = { radius: 0, color: $r('app.color.button_shadow'), offsetX: 0, offsetY: 0 };
  static float: ShadowOptions = { radius: 8, color: $r('app.color.float_shadow'), offsetX: 0, offsetY: 2 };
}
/**
 * 游戏徽章统一使用系统强调色。
 */
export class GameBadgeColors {
  static getGradient(gameId: string): [Resource, number][] {
    return [[SemanticColors.primary, 0], [SemanticColors.primary, 1]];
  }
}
