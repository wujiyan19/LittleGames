/**
 * 设计令牌系统 —— 「宇宙蓝 × 雪域灰」
 * 品牌基调：宇宙蓝（深邃星空蓝 + 极光紫）与 雪域灰（清冷浅灰）。
 * 所有语义色通过 resources 定义（base=亮色 / dark=深色），
 * 组件统一引用 $r('app.color.*')，随系统深浅色模式自动适配。
 * ArkTS 严格模式
 */

/**
 * 品牌色常量（深浅色模式共用，用于品牌渐变 / 强调装饰）
 */
export class BrandColors {
  /** 宇宙蓝主色 */
  static cosmicBlue = '#2D6CE8';
  /** 宇宙蓝（亮） */
  static cosmicBlueBright = '#5C9AFF';
  /** 宇宙蓝（深） */
  static cosmicBlueDeep = '#1B4DB8';
  /** 极光紫 */
  static auroraPurple = '#7A5AF8';
  /** 极光紫（亮） */
  static auroraPurpleBright = '#9A83FF';
  /** 宇宙深空 */
  static deepSpace = '#0B1135';
  /** 宇宙深空面板 */
  static deepSpaceSurface = '#182257';
  /** 雪域灰背景 */
  static snowfieldBg = '#F4F6FB';
  /** 雪域灰面板 */
  static snowfieldSurface = '#FFFFFF';
  /** 雪域墨色 */
  static snowfieldInk = '#12203A';
}

/**
 * 亮色语义令牌 —— 引用资源，随主题自动适配
 */
export class LightColors {
  static bg: Resource = $r('app.color.bg');
  static bgElevated: Resource = $r('app.color.bg_elevated');
  static surface: Resource = $r('app.color.surface');
  static surfaceHover: Resource = $r('app.color.surface_hover');
  static surfaceTranslucent: Resource = $r('app.color.surface_translucent');
  static scrim: Resource = $r('app.color.scrim');
  static primary: Resource = $r('app.color.primary');
  static primaryHover: Resource = $r('app.color.primary_hover');
  static primaryActive: Resource = $r('app.color.primary_active');
  static primaryLight: Resource = $r('app.color.primary_light');
  static accent: Resource = $r('app.color.accent');
  static accentLight: Resource = $r('app.color.accent_light');
  static success: Resource = $r('app.color.success');
  static warning: Resource = $r('app.color.warning');
  static error: Resource = $r('app.color.error');
  static textPrimary: Resource = $r('app.color.text_primary');
  static textSecondary: Resource = $r('app.color.text_secondary');
  static textTertiary: Resource = $r('app.color.text_tertiary');
  static textDisabled: Resource = $r('app.color.text_disabled');
  static textOnPrimary: Resource = $r('app.color.text_on_primary');
  static divider: Resource = $r('app.color.divider');
  static border: Resource = $r('app.color.border');
  static borderStrong: Resource = $r('app.color.border_strong');
  static gradientScreen: Resource[] = [
    $r('app.color.gradient_screen_start'),
    $r('app.color.gradient_screen_mid'),
    $r('app.color.gradient_screen_end')
  ];
  static gradientHero: Resource[] = [
    $r('app.color.gradient_hero_start'),
    $r('app.color.gradient_hero_mid'),
    $r('app.color.gradient_hero_end')
  ];
  static gradientBrand: Resource[] = [
    $r('app.color.gradient_brand_start'),
    $r('app.color.gradient_brand_end')
  ];
  /** 游戏棋盘/格子系统色 */
  static cellHidden: Resource = $r('app.color.cell_hidden');
  static cellRevealed: Resource = $r('app.color.cell_revealed');
  static boardBg: Resource = $r('app.color.board_bg');
  static boardBorder: Resource = $r('app.color.board_border');
}

/**
 * 深色语义令牌 —— 与亮色令牌引用同一组语义资源，由系统自动选择深浅值
 */
export class DarkColors {
  static bg: Resource = $r('app.color.bg');
  static bgElevated: Resource = $r('app.color.bg_elevated');
  static surface: Resource = $r('app.color.surface');
  static surfaceHover: Resource = $r('app.color.surface_hover');
  static surfaceTranslucent: Resource = $r('app.color.surface_translucent');
  static scrim: Resource = $r('app.color.scrim');
  static primary: Resource = $r('app.color.primary');
  static primaryHover: Resource = $r('app.color.primary_hover');
  static primaryActive: Resource = $r('app.color.primary_active');
  static primaryLight: Resource = $r('app.color.primary_light');
  static accent: Resource = $r('app.color.accent');
  static accentLight: Resource = $r('app.color.accent_light');
  static success: Resource = $r('app.color.success');
  static warning: Resource = $r('app.color.warning');
  static error: Resource = $r('app.color.error');
  static textPrimary: Resource = $r('app.color.text_primary');
  static textSecondary: Resource = $r('app.color.text_secondary');
  static textTertiary: Resource = $r('app.color.text_tertiary');
  static textDisabled: Resource = $r('app.color.text_disabled');
  static textOnPrimary: Resource = $r('app.color.text_on_primary');
  static divider: Resource = $r('app.color.divider');
  static border: Resource = $r('app.color.border');
  static borderStrong: Resource = $r('app.color.border_strong');
  static gradientScreen: Resource[] = [
    $r('app.color.gradient_screen_start'),
    $r('app.color.gradient_screen_mid'),
    $r('app.color.gradient_screen_end')
  ];
  static gradientHero: Resource[] = [
    $r('app.color.gradient_hero_start'),
    $r('app.color.gradient_hero_mid'),
    $r('app.color.gradient_hero_end')
  ];
  static gradientBrand: Resource[] = [
    $r('app.color.gradient_brand_start'),
    $r('app.color.gradient_brand_end')
  ];
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
  static xs = 2;
  static sm = 4;
  static md = 8;
  static base = 12;
  static lg = 16;
  static xl = 20;
  static xxl = 28;
  static full = 9999;
}

/**
 * 字体令牌 —— 统一使用 HarmonyOS Sans 系统字体
 */
export class FontTokens {
  /** 系统字体：HarmonyOS Sans，跨设备渲染效果最佳 */
  static family = 'HarmonyOS Sans';
  static sizeCaption = 10;
  static sizeBodySmall = 12;
  static sizeBody = 14;
  static sizeBodyLarge = 16;
  static sizeSubtitle = 18;
  static sizeTitle = 20;
  static sizeHeadline = 24;
  static sizeDisplay = 32;
  static sizeMega = 48;

  static weightRegular = 400;
  static weightMedium = 500;
  static weightSemibold = 600;
  static weightBold = 700;
}

/**
 * 阴影令牌 —— 轻拟物质感（轻投影，避免过度设计）
 */
export class ShadowTokens {
  /** 卡片阴影 */
  static card: ShadowOptions = { radius: 16, color: $r('app.color.card_shadow'), offsetX: 0, offsetY: 4 };
  /** 按钮阴影 */
  static button: ShadowOptions = { radius: 12, color: $r('app.color.button_shadow'), offsetX: 0, offsetY: 3 };
  /** 悬浮/弹层阴影 */
  static float: ShadowOptions = { radius: 24, color: $r('app.color.button_shadow'), offsetX: 0, offsetY: 8 };
}
