import { Node } from '@kit.ArkGraphics3D';
import { resourceManager } from '@kit.LocalizationKit';
import { ToySceneController } from '../common/ToySceneController';
import { ExpansionViewModel } from '../viewmodel/ExpansionViewModel';
import { ExpansionPiece } from '../model/game/ExpansionState';
import { SemanticColors, FontTokens } from '../common/DesignTokens';
import { GameDataManager } from '../model/GameData';

/** Exact 360x460 orthographic board; existing touch coordinates and physics are reused. */
@ComponentV2
export struct ToyRollingStage {
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local renderer: ToySceneController = new ToySceneController();
  @Local widthVp: number = 320;
  private ball: Node | null = null;
  private goal: Node | null = null;
  private walls: Node[] = [];
  private holes: Node[] = [];
  private previousX: number = 40;
  private previousY: number = 410;
  private angleX: number = 0;
  private angleY: number = 0;

  @Monitor('vm.state')
  update(): void { this.sync(); }
  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void {
    this.ball = null; this.goal = null; this.walls = []; this.holes = [];
    this.renderer.dispose();
  }

  private async load(): Promise<void> {
    const theme: string = GameDataManager.getThemeMode();
    const dark: boolean = theme === 'dark' || (theme === 'system' &&
      this.getUIContext().getHostContext()?.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK);
    const ready: boolean = await this.renderer.load(dark ? $rawfile('toy/rolling_dark.glb') : $rawfile('toy/rolling.glb'),
      dark ? { r: 0.014, g: 0.030, b: 0.045, a: 1 } : { r: 0.96, g: 0.94, b: 0.88, a: 1 });
    if (!ready) { return; }
    this.ball = this.renderer.node('ball'); this.goal = this.renderer.node('goal');
    for (let i: number = 0; i < 3; i++) {
      const wall: Node | null = this.renderer.node('wall' + i);
      const hole: Node | null = this.renderer.node('hole' + i);
      if (wall !== null) { this.walls.push(wall); }
      if (hole !== null) { this.holes.push(hole); }
    }
    this.sync();
  }

  private sync(): void {
    if (this.ball === null) { return; }
    let wall: number = 0; let hole: number = 0;
    for (let i: number = 0; i < this.vm.state.pieces.length; i++) {
      const p: ExpansionPiece = this.vm.state.pieces[i];
      if (p.kind === 32) {
        if (this.vm.state.phase === 0) { this.angleX = 0; this.angleY = 0; }
        else { this.angleX += (p.y - this.previousY) / 15; this.angleY += (p.x - this.previousX) / 15; }
        this.previousX = p.x; this.previousY = p.y;
        this.ball.position = { x: p.x - 180, y: 230 - p.y, z: 15 };
        // Rotate the sphere around its centre, including its cream stripe.
        this.ball.rotation = { x: Math.sin(this.angleX / 2) * Math.cos(this.angleY / 2),
          y: Math.cos(this.angleX / 2) * Math.sin(this.angleY / 2),
          z: Math.sin(this.angleX / 2) * Math.sin(this.angleY / 2),
          w: Math.cos(this.angleX / 2) * Math.cos(this.angleY / 2) };
      } else if (p.kind === 27 && this.goal !== null) {
        this.goal.position = { x: p.x - 180, y: 230 - p.y, z: 0 };
      } else if (p.kind === 26 && wall < this.walls.length) {
        this.walls[wall++].position = { x: p.x - 180, y: 230 - p.y - p.h / 2, z: 0 };
      } else if (p.kind === 31 && hole < this.holes.length) {
        const node: Node = this.holes[hole++]; node.visible = true;
        node.position = { x: p.x - 180, y: 230 - p.y, z: 0 };
      }
    }
    for (let i: number = hole; i < this.holes.length; i++) { this.holes[i].visible = false; }
    this.renderer.draw();
  }

  private touch(event: TouchEvent): void {
    if (this.renderer.options === undefined) { return; }
    if (event.type === TouchType.Down) { this.vm.setDragging(true); }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.setDragging(false); }
    if ((event.type === TouchType.Down || event.type === TouchType.Move) && event.touches.length > 0) {
      const scale: number = this.widthVp / 360;
      this.vm.aim(event.touches[0].x / scale, event.touches[0].y / scale);
    }
  }

  build() {
    Stack() {
      if (this.renderer.options !== undefined) {
        Component3D(this.renderer.options).width('100%').height('100%')
          .renderWidth('80%').renderHeight('80%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
          .onAppear(() => { this.sync(); })
        // A native input plane keeps coordinates local to this board, independent of the 3D surface.
        Column().width('100%').height('100%').backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.Block)
          .onTouch((event: TouchEvent) => { this.touch(event); })
      } else if (this.renderer.failed) {
        Button($r('app.string.toy_scene_retry')).onClick(() => { this.load(); })
      } else {
        Text($r('app.string.toy_scene_loading')).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textSecondary)
      }
    }.width('100%').aspectRatio(360 / 460).borderRadius($r('app.float.toy_board_radius')).clip(true)
      .id('toy-rolling-scene').accessibilityText($r('app.string.toy_rolling_board'))
      .onAreaChange((oldArea: Area, area: Area) => { this.widthVp = Number(area.width); })
  }
}
