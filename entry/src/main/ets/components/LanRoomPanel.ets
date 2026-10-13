import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';
import { LanGameSession } from '../common/LanGameSession';

/** Shared room controls for the seven two-player games. */
@ComponentV2
export struct LanRoomPanel {
  @Param session: LanGameSession = new LanGameSession();
  @Local input: string = '';
  @Local expanded: boolean = false;

  private errorText(): Resource {
    switch (this.session.error) {
      case 'invalid_address': return $r('app.string.lan_error_invalid_address');
      case 'mismatch': return $r('app.string.lan_error_mismatch');
      case 'protocol': return $r('app.string.lan_error_protocol');
      case 'background': return $r('app.string.lan_error_background');
      case 'no_address': return $r('app.string.lan_error_no_address');
      case 'busy': return $r('app.string.lan_error_busy');
      case 'network': return $r('app.string.lan_error_network');
      default: return $r('app.string.lan_disconnected_hint');
    }
  }

  @Builder
  Action(label: Resource, action: () => void, primary: boolean = false) {
    Button(label)
      .type(ButtonType.Normal).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
      .fontWeight(FontTokens.weightMedium)
      .fontColor(primary ? SemanticColors.textOnPrimary : SemanticColors.primary)
      .backgroundColor(primary ? SemanticColors.primary : SemanticColors.bg)
      .borderRadius(RadiusTokens.sm).constraintSize({ minHeight: $r('app.float.collection_control_height') })
      .padding({ left: SpacingTokens.md, right: SpacingTokens.md })
      .clickEffect(HarmonyMotion.press(this.getUIContext())).onClick(action)
  }

  @Builder
  ConnectionControls() {
    Text($r('app.string.lan_description')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
      .fontColor(SemanticColors.textSecondary).width('100%')
    Row() {
      this.Action($r('app.string.lan_host'), () => { this.session.host(); }, true)
    }.width('100%').justifyContent(FlexAlign.Start)
    Text($r('app.string.lan_address_label')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
      .fontColor(SemanticColors.textSecondary).width('100%')
    Row({ space: SpacingTokens.sm }) {
      TextInput({ text: this.input, placeholder: $r('app.string.lan_address_placeholder') })
        .layoutWeight(1).height($r('app.float.collection_control_height'))
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textPrimary)
        .placeholderColor(SemanticColors.textTertiary).placeholderFont({ size: FontTokens.sizeBody })
        .backgroundColor(SemanticColors.bg).borderRadius(RadiusTokens.sm).caretColor(SemanticColors.primary)
        .accessibilityText($r('app.string.lan_address_label'))
        .onChange((value: string) => { this.input = value; })
      this.Action($r('app.string.lan_join'), () => { this.session.join(this.input); }, true)
    }.width('100%')
  }

  @Builder
  RoomStatus() {
    if (this.session.status === 'hosting') {
      Text($r('app.string.lan_hosting')).fontColor(SemanticColors.textPrimary)
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontWeight(FontTokens.weightMedium)
      Text($r('app.string.lan_hosting_hint')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
        .fontColor(SemanticColors.textSecondary)
      if (this.session.address.length > 0) {
        Text(this.session.address).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodyLarge)
          .fontWeight(FontTokens.weightSemibold).fontColor(SemanticColors.primary).width('100%')
      }
    } else if (this.session.status === 'connecting') {
      Text($r('app.string.lan_connecting')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
        .fontColor(SemanticColors.textSecondary)
    } else if (this.session.status === 'connected') {
      Text($r('app.string.lan_connected_player', this.session.localPlayer))
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.primary)
      if (this.session.wantsRestart) {
        Text($r('app.string.lan_restart_waiting')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
          .fontColor(SemanticColors.textSecondary)
      } else if (this.session.peerWantsRestart) {
        Text($r('app.string.lan_restart_requested')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
          .fontColor(SemanticColors.textSecondary)
        this.Action($r('app.string.lan_restart_accept'), () => { this.session.requestRestart(); }, true)
      } else if (this.session.pending) {
        Text($r('app.string.lan_pending')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
          .fontColor(SemanticColors.textSecondary)
      } else {
        Text($r('app.string.lan_connected_hint')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
          .fontColor(SemanticColors.textSecondary)
      }
    } else {
      Text(this.session.status === 'disconnected' ? $r('app.string.lan_disconnected') : $r('app.string.lan_error'))
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontWeight(FontTokens.weightMedium)
        .fontColor(SemanticColors.textPrimary)
      Text(this.errorText()).fontFamily(FontTokens.family).fontSize(FontTokens.sizeCaption)
        .fontColor(SemanticColors.textSecondary).width('100%')
      this.ConnectionControls()
    }
  }

  build() {
    Column({ space: SpacingTokens.sm }) {
      if (this.session.status === 'local' && !this.expanded) {
        Row() {
          this.Action($r('app.string.lan_title'), () => { this.expanded = true; })
        }.width('100%').justifyContent(FlexAlign.Center)
      } else {
        Row({ space: SpacingTokens.sm }) {
          Text($r('app.string.lan_title')).fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody)
            .fontWeight(FontTokens.weightSemibold).fontColor(SemanticColors.textPrimary).layoutWeight(1)
          if (this.session.status === 'local') {
            this.Action($r('app.string.lan_collapse'), () => { this.expanded = false; })
          } else {
            this.Action(this.session.status === 'connected' ? $r('app.string.lan_leave') :
              (this.session.status === 'hosting' || this.session.status === 'connecting' ?
                $r('app.string.lan_cancel') : $r('app.string.lan_back_local')),
              () => { this.session.leave(); this.expanded = false; })
          }
        }.width('100%')
        if (this.session.status === 'local') {
          this.ConnectionControls()
        } else {
          this.RoomStatus()
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding(SpacingTokens.md).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.base)
      .id('lan-room-panel')
  }
}
