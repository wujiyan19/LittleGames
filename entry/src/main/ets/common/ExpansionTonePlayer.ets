import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { resourceManager } from '@kit.LocalizationKit';

export class ExpansionTonePlayer {
  onReady: (ready: boolean) => void = (ready: boolean): void => {};
  private pool: media.SoundPool | null = null;
  private sounds: number[] = [];
  private loaded: number[] = [];
  private streams: number[] = [];
  private disposed: boolean = false;
  private generation: number = 0;
  async init(manager: resourceManager.ResourceManager): Promise<void> {
    try {
      const info: audio.AudioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_GAME, rendererFlags: 0 };
      const pool: media.SoundPool = await media.createSoundPool(4, info);
      if (this.disposed) { await pool.release(); return; } this.pool = pool;
      pool.on('loadComplete', (sound: number): void => { this.loaded.push(sound); this.ready(); });
      for (let i: number = 0; i < 4; i++) {
        const path: string = 'expansion_tone_' + i + '.wav'; const raw: resourceManager.RawFileDescriptor = await manager.getRawFd(path);
        try { if (!this.disposed) { this.sounds.push(await pool.load(raw.fd, raw.offset, raw.length)); } } finally { await manager.closeRawFd(path); }
        if (this.disposed) { return; } this.ready();
      }
    } catch (e) { if (!this.disposed) { this.onReady(false); } }
  }
  private ready(): void { if (!this.disposed && this.sounds.length === 4 && this.sounds.every((id: number) => this.loaded.includes(id))) { this.onReady(true); } }
  async play(note: number): Promise<void> {
    if (this.disposed || !this.pool || note < 0 || note >= this.sounds.length || !this.loaded.includes(this.sounds[note])) { return; }
    const pool: media.SoundPool = this.pool; const generation: number = this.generation;
    try {
      const stream: number = await pool.play(this.sounds[note]);
      if (this.disposed || generation !== this.generation) { try { await pool.stop(stream); } catch (e) {} return; }
      this.streams.push(stream); if (this.streams.length > 8) { this.streams.shift(); }
    } catch (e) {}
  }
  async stop(): Promise<void> {
    this.generation++;
    const pool: media.SoundPool | null = this.pool; const streams: number[] = this.streams; this.streams = []; if (!pool) { return; }
    for (let i: number = 0; i < streams.length; i++) { try { await pool.stop(streams[i]); } catch (e) {} }
  }
  async dispose(): Promise<void> {
    this.generation++;
    this.disposed = true; this.onReady = (ready: boolean): void => {}; const pool: media.SoundPool | null = this.pool; this.pool = null; this.streams = [];
    if (pool) { try { await pool.release(); } catch (e) {} }
  }
}
