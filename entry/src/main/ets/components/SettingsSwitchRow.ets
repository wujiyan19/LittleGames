import { SemanticColors, FontTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct SettingsSwitchRow {
  @Param title: Resource = $r('app.string.settings_title');
  @Param detail: Resource | string = '';
  @Param isOn: boolean = false;
  @Param onToggle: (value: boolean) => void = () => {};

  build() {
    Row({ space: SpacingTokens.md }) {
      Column({ space: SpacingTokens.xs }) {
        Text(this.title).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
          .fontWeight(FontTokens.weightMedium).fontColor(SemanticColors.textPrimary)
        Text(this.detail).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall)
          .fontColor(SemanticColors.textTertiary)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(SemanticColors.primary)
        .accessibilityText(this.title)
        .onChange((value: boolean) => { this.onToggle(value); })
    }.width('100%').padding(SpacingTokens.base)
  }
}
