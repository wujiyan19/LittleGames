import { curves, UIContext } from '@kit.ArkUI';

/**
 * HarmonyOS 动效：原生按压反馈、可接续的弹簧运动、独立的透明度转场。
 * 只动画化 scale / translate / opacity，不对棋盘或列表布局做插值。
 * springMotion 的时长由物理参数决定，不能用 duration 限制它。
 */
export class HarmonyMotion {
  static value(context: UIContext, resource: Resource, fallback: number): number {
    const host = context.getHostContext();
    if (host) {
      try {
        return host.resourceManager.getNumber(resource.id);
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  /** 系统处理按下、释放和手势取消；卡片的形变比按钮更轻。 */
  static press(context: UIContext, card: boolean = false): ClickEffect {
    return {
      level: ClickEffectLevel.LIGHT,
      scale: card ? HarmonyMotion.value(context, $r('app.float.motion_card_press_scale'), 0.98) :
        HarmonyMotion.value(context, $r('app.float.motion_button_press_scale'), 0.96)
    };
  }

  static selection(context: UIContext): AnimateParam {
    return {
      curve: curves.springMotion(
        HarmonyMotion.value(context, $r('app.float.motion_selection_response'), 0.28),
        HarmonyMotion.value(context, $r('app.float.motion_spring_damping'), 0.88))
    };
  }

  static tabScale(context: UIContext, selected: boolean): number {
    return selected ? 1 : HarmonyMotion.value(context, $r('app.float.motion_tab_rest_scale'), 0.92);
  }

  static tabOffset(context: UIContext, selected: boolean): number {
    return selected ? HarmonyMotion.value(context, $r('app.float.motion_tab_lift'), -1.5) : 0;
  }

  static scrim(context: UIContext): TransitionEffect {
    return TransitionEffect.opacity(0).animation({
      duration: HarmonyMotion.value(context, $r('app.float.motion_scrim_duration'), 180),
      curve: Curve.EaseOut
    });
  }

  static exit(context: UIContext): AnimateParam {
    return {
      duration: HarmonyMotion.value(context, $r('app.float.motion_exit_duration'), 140), curve: Curve.EaseIn
    };
  }

  static closeScale(context: UIContext, closing: boolean): number {
    return closing ? HarmonyMotion.value(context, $r('app.float.motion_dialog_end_scale'), 0.98) : 1;
  }

  static closeOffset(context: UIContext, closing: boolean): number {
    return closing ? HarmonyMotion.value(context, $r('app.float.motion_dialog_exit_offset'), 8) : 0;
  }

  /** 浮层进入有重量感，退出更快；遮罩与卡片使用不同节奏。 */
  static dialog(context: UIContext): TransitionEffect {
    const startScale: number = HarmonyMotion.value(context, $r('app.float.motion_dialog_start_scale'), 0.94);
    const endScale: number = HarmonyMotion.value(context, $r('app.float.motion_dialog_end_scale'), 0.98);
    const appear: TransitionEffect = TransitionEffect.opacity(0).animation({
      duration: HarmonyMotion.value(context, $r('app.float.motion_scrim_duration'), 180), curve: Curve.EaseOut
    }).combine(TransitionEffect.scale({ x: startScale, y: startScale })
      .combine(TransitionEffect.translate({
        y: HarmonyMotion.value(context, $r('app.float.motion_dialog_enter_offset'), 16)
      })).animation({
        curve: curves.springMotion(
          HarmonyMotion.value(context, $r('app.float.motion_dialog_response'), 0.38),
          HarmonyMotion.value(context, $r('app.float.motion_spring_damping'), 0.88))
      }));
    const disappear: TransitionEffect = TransitionEffect.opacity(0)
      .combine(TransitionEffect.scale({ x: endScale, y: endScale }))
      .combine(TransitionEffect.translate({
        y: HarmonyMotion.value(context, $r('app.float.motion_dialog_exit_offset'), 8)
      })).animation({
        duration: HarmonyMotion.value(context, $r('app.float.motion_exit_duration'), 140), curve: Curve.EaseIn
      });
    return TransitionEffect.asymmetric(appear, disappear);
  }

  static content(context: UIContext): TransitionEffect {
    return TransitionEffect.opacity(0)
      .combine(TransitionEffect.translate({
        y: HarmonyMotion.value(context, $r('app.float.motion_content_offset'), 8)
      })).animation({
        duration: HarmonyMotion.value(context, $r('app.float.motion_content_duration'), 180), curve: Curve.EaseOut
      });
  }
}
