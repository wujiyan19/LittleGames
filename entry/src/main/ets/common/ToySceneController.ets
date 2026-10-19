import { Scene, Node, Camera, Color, Mat4x4, EnvironmentBackgroundType } from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Native handles live only in the view layer; no frame loop or persisted game state. */
@ObservedV2
export class ToySceneController {
  @Trace options: SceneOptions | undefined = undefined;
  @Trace failed: boolean = false;
  scene: Scene | null = null;
  private generation: number = 0;
  private camera: Camera | null = null;
  private world: Node | null = null;
  private fitX: number = 0;
  private fitY: number = 0;

  async load(uri: Resource, background: Color): Promise<boolean> {
    const generation: number = ++this.generation;
    this.failed = false;
    try {
      const scene: Scene = await Scene.load(uri);
      if (generation !== this.generation) { scene.destroy(); return false; }
      this.scene = scene;
      const camera: Node | null = this.node('ToyCamera');
      if (camera === null) { throw new Error('Toy camera missing'); }
      const view: Camera = camera as Camera;
      this.camera = view;
      this.world = this.node('world');
      view.enabled = true;
      view.msaa = true;
      view.postProcess = { bloom: { scaleFactor: 0 }, vignette: { intensity: 0 }, colorFringe: { intensity: 0 } };
      view.clearColor = background;
      scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
      this.options = { scene: scene, modelType: ModelType.TEXTURE };
      return true;
    } catch (e) {
      if (generation === this.generation) {
        this.scene?.destroy(); this.scene = null; this.camera = null; this.world = null;
        this.options = undefined; this.failed = true;
        hilog.error(0x0000, 'LittleGames', 'Toy scene failed to load: %{public}s', String(e));
      }
      return false;
    }
  }

  node(name: string): Node | null {
    const root: Node | null = this.scene?.root ?? null;
    return root === null ? null : this.find(root, name);
  }

  private find(root: Node, name: string): Node | null {
    if (root.name === name) { return root; }
    for (let i: number = 0; i < root.children.count(); i++) {
      const child: Node | null = root.children.get(i);
      if (child !== null) {
        const found: Node | null = this.find(child, name);
        if (found !== null) { return found; }
      }
    }
    return null;
  }

  draw(): void {
    if (this.camera !== null && this.world !== null) {
      // Use the native projection, including its glTF orthographic import convention.
      // The 360x460 authored coordinates must fill the same rectangle as native touch input.
      const projection: Mat4x4 = this.camera.getProjectionMatrix();
      if (projection.x.x !== 0 && projection.y.y !== 0) {
        const x: number = 1 / (180 * Math.abs(projection.x.x));
        const y: number = 1 / (230 * Math.abs(projection.y.y));
        if (x !== this.fitX || y !== this.fitY) {
          this.fitX = x; this.fitY = y;
          this.world.scale = { x: x, y: y, z: 1 };
        }
      }
    }
    this.scene?.renderFrame();
  }
  dispose(): void {
    this.generation++;
    this.options = undefined;
    this.camera = null; this.world = null;
    this.fitX = 0; this.fitY = 0;
    this.scene?.destroy(); this.scene = null;
  }
}
