/** 可注入的帧源；模型测试可手动推进，不依赖窗口或真实计时器。 */
export interface FrameLoop {
  start(onFrame: (deltaMs: number) => void): void;
  stop(): void;
  dispose(): void;
}
