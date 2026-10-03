import { SemanticColors, FontTokens, RadiusTokens } from '../common/DesignTokens';
import { resolveString } from '../common/I18nUtils';
import { Haptics } from '../common/Haptics';

/** Fixed-size native hit target with a textured piece and compositor-only feedback. */
@ComponentV2
export struct GameArtTile {
  @Param image: Resource = $r('app.media.exp_empty');
  @Param label: string = '';
  @Param description: Resource | string = '';
  @Param selected: boolean = false;
  @Param available: boolean = true;
  @Param onTap: () => void = (): void => {};
  @Param textColor: ResourceColor = SemanticColors.textPrimary;
  @Local pressed: boolean = false;

  build() {
    Button({ type: ButtonType.Normal }) {
      Stack() {
        Image(this.image).width('100%').height('100%').objectFit(ImageFit.Fill)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no');
        if (this.label.length > 0) {
          Text(this.label).fontSize(FontTokens.sizeBodyLarge).fontWeight(FontWeight.Medium)
            .fontColor(this.textColor).textAlign(TextAlign.Center).hitTestBehavior(HitTestMode.None);
        }
      }.width('100%').height('100%').renderGroup(true);
    }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
      .borderRadius(RadiusTokens.sm)
      .border({ width: this.selected ? 2 : 0, color: SemanticColors.primary })
      .scale({ x: this.pressed ? 0.92 : this.selected ? 1.04 : 1, y: this.pressed ? 0.92 : this.selected ? 1.04 : 1 })
      .animation({ duration: 160, curve: Curve.FastOutSlowIn })
      .enabled(this.available).accessibilityText(resolveString(this.description, this.getUIContext().getHostContext())).accessibilityGroup(true)
      .onClick(() => { Haptics.tap(); this.onTap(); })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) { this.pressed = true; }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressed = false; }
      });
  }
}
