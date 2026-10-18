import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { SemanticColors } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';

@ComponentV2
export struct HeaderIconButton {
  @Param symbol: Resource = $r('sys.symbol.arrow_left');
  @Param label: Resource = $r('app.string.a11y_header_back');
  @Param controlId: string = '';
  @Param onPress: () => void = () => {};

  @Builder
  Icon() {
    SymbolGlyph(this.symbol).fontSize($r('app.float.home_header_action_icon_size'))
      .fontColor([SemanticColors.textPrimary])
  }

  @Styles
  headerAppearance() {
    .width($r('app.float.home_action_min_height')).height($r('app.float.home_action_min_height'))
    .backgroundColor(SemanticColors.surface)
    .clickEffect(HarmonyMotion.press(this.getUIContext()))
    .accessibilityText(this.label).id(this.controlId)
    .onClick(() => { this.onPress(); })
  }

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Button() { this.Icon() }.type(ButtonType.Circle).headerAppearance()
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN, interactive: true
        }))
    } else {
      Button() { this.Icon() }.type(ButtonType.Circle).headerAppearance()
    }
  }
}
