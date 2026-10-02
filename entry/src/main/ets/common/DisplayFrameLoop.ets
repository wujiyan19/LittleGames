import { displaySync } from '@kit.ArkGraphics2D';
import { UIContext } from '@kit.ArkUI';
import { FrameLoop } from './FrameLoop';

/** API 11+ 帧源。限制到 60fps，静止时停止，避免高刷设备无谓运行 120fps。 */
export class DisplayFrameLoop implements FrameLoop {
  private context: UIContext;
  private sync: displaySync.DisplaySync | null = null;
  private running: boolean = false;
  private lastTimestamp: number = 0;
  private onFrame: (deltaMs: number) => void = () => {};
  private handleFrame = (info: displaySync.IntervalInfo): void => {
    if (!this.running) { return; }
    // 官方 IntervalInfo 的时间戳单位为纳秒，使用单调帧时间，避免墙钟调整。
    const timestamp: number = info.timestamp / 1000000;
    const delta: number = this.lastTimestamp === 0 ? 0 : Math.max(0, timestamp - this.lastTimestamp);
    this.lastTimestamp = timestamp;
    this.onFrame(delta);
  };

  constructor(context: UIContext) {
    this.context = context;
  }

  start(onFrame: (deltaMs: number) => void): void {
    this.onFrame = onFrame;
    if (this.running) { return; }
    this.context.runScopedTask(() => {
      if (this.sync === null) {
        this.sync = displaySync.create();
        this.sync.setExpectedFrameRateRange({ min: 30, max: 60, expected: 60 });
        this.sync.on('frame', this.handleFrame);
      }
      this.lastTimestamp = 0;
      this.running = true;
      this.sync.start();
    });
  }

  stop(): void {
    this.running = false;
    this.lastTimestamp = 0;
    this.sync?.stop();
  }

  dispose(): void {
    this.stop();
    this.sync?.off('frame', this.handleFrame);
    this.sync = null;
    this.onFrame = () => {};
  }
}
