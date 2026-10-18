import { ImmersiveLight } from '../common/ImmersiveLight';
import { GameLifecycleBus } from '../common/GameLifecycleBus';

/** Own the native title slot so header materials apply to the real Navigation title bar. */
@ComponentV2
export struct PageDestination {
  @Param gameId: string = '';
  @Param onPageShown: () => void = () => {};
  @Builder emptyContent() {}
  @BuilderParam header: () => void = this.emptyContent;
  @BuilderParam content: () => void = this.emptyContent;

  build() {
    NavDestination() {
      this.content()
    }
    .title({ builder: () => { this.header(); }, height: $r('app.float.native_header_height') }, ImmersiveLight.titleBar())
    .hideBackButton(true)
    .onShown(() => {
      this.onPageShown();
      if (this.gameId.length > 0) { GameLifecycleBus.setPageVisible(this.gameId, true); }
    })
    .onHidden(() => {
      if (this.gameId.length > 0) { GameLifecycleBus.setPageVisible(this.gameId, false); }
    })
    .onBackPressed(() => {
      return this.gameId.length > 0 ? GameLifecycleBus.notifyBackRequested() : false;
    })
  }
}
