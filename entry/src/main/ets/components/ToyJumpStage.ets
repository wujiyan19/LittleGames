import { Node, Camera } from '@kit.ArkGraphics3D';
import { resourceManager } from '@kit.LocalizationKit';
import { ToySceneController } from '../common/ToySceneController';
import { JumpJumpViewModel, PlatformData } from '../viewmodel/JumpJumpViewModel';
import { SemanticColors, FontTokens } from '../common/DesignTokens';
import { GameDataManager } from '../model/GameData';

/** Orthographic fixed camera. Screen x and the existing landing interval stay identical. */
@ComponentV2
export struct ToyJumpStage {
  @Param vm: JumpJumpViewModel = new JumpJumpViewModel();
  @Param widthVp: number = 360;
  @Param heightVp: number = 460;
  @Param groundY: number = 160;
  @Param onReady: (ready: boolean) => void = (ready: boolean): void => {};
  @Local renderer: ToySceneController = new ToySceneController();
  private platforms: Node[] = [];
  private player: Node | null = null;
  private shadowNode: Node | null = null;
  private camera: Camera | null = null;

  @Monitor('vm.playerX', 'vm.playerJumpX', 'vm.playerJumpY', 'vm.playerDropY',
    'vm.playerScaleX', 'vm.playerScaleY', 'vm.platformRevision', 'vm.currentIndex',
    'widthVp', 'heightVp', 'groundY')
  update(): void { this.sync(); }

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void {
    this.onReady(false);
    this.platforms = []; this.player = null; this.shadowNode = null; this.camera = null;
    this.renderer.dispose();
  }

  private async load(): Promise<void> {
    const theme: string = GameDataManager.getThemeMode();
    const dark: boolean = theme === 'dark' || (theme === 'system' &&
      this.getUIContext().getHostContext()?.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK);
    const ready: boolean = await this.renderer.load(dark ? $rawfile('toy/jump_dark.glb') : $rawfile('toy/jump.glb'),
      dark ? { r: 0.014, g: 0.030, b: 0.045, a: 1 } : { r: 0.96, g: 0.94, b: 0.88, a: 1 });
    if (!ready) { return; }
    this.player = this.renderer.node('player'); this.shadowNode = this.renderer.node('shadow');
    this.camera = this.renderer.node('ToyCamera') as Camera;
    for (let i: number = 0; i < 14; i++) {
      const platform: Node | null = this.renderer.node('platform' + i);
      if (platform !== null) { this.platforms.push(platform); }
    }
    this.sync();
    this.onReady(true);
  }

  private sync(): void {
    if (this.camera === null || this.widthVp <= 0 || this.heightVp <= 0) { return; }
    // The authored camera spans 360x460; each axis maps to the measured stage separately.
    const scale: number = 360 / this.widthVp;
    this.camera.position = { x: 0, y: 0, z: 1000 };
    let visible: number = 0;
    for (let i: number = 0; i < this.vm.platforms.length; i++) {
      const p: PlatformData = this.vm.platforms[i];
      if (p.centerX + p.width / 2 < -20 || p.centerX - p.width / 2 > this.widthVp + 20) { continue; }
      if (visible >= this.platforms.length) { break; }
      const node: Node = this.platforms[visible++];
      node.visible = true;
      node.position = { x: p.centerX * scale - 180, y: 230 - this.groundY * 460 / this.heightVp, z: 0 };
      node.scale = { x: p.width * scale / 100, y: 460 / this.heightVp, z: 1 };
    }
    for (let i: number = visible; i < this.platforms.length; i++) { this.platforms[i].visible = false; }
    const x: number = (this.vm.playerX + this.vm.playerJumpX) * scale - 180;
    const y: number = 230 - (this.groundY + this.vm.playerJumpY + this.vm.playerDropY) * 460 / this.heightVp;
    if (this.player !== null) {
      this.player.position = { x: x, y: y + 8 * 460 / this.heightVp, z: 36 };
      this.player.scale = { x: scale * this.vm.playerScaleX, y: 460 / this.heightVp * this.vm.playerScaleY, z: 1 };
    }
    if (this.shadowNode !== null) {
      const shrink: number = Math.max(0.4, 1 + this.vm.playerJumpY / 160);
      this.shadowNode.position = { x: x, y: 230 - this.groundY * 460 / this.heightVp - 2, z: 30 };
      this.shadowNode.scale = { x: scale * shrink, y: 460 / this.heightVp, z: 1 };
      this.shadowNode.visible = this.vm.playerDropY === 0;
    }
    this.renderer.draw();
  }

  build() {
    Stack() {
      if (this.renderer.options !== undefined) {
        Component3D(this.renderer.options).width('100%').height('100%')
          .renderWidth('80%').renderHeight('80%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
          .onAppear(() => { this.sync(); })
      } else if (this.renderer.failed) {
        Button($r('app.string.toy_scene_retry')).onClick(() => { this.load(); })
      } else {
        Text($r('app.string.toy_scene_loading')).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textSecondary)
      }
    }.width('100%').height('100%').id('toy-jump-scene')
  }
}
