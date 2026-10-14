import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { resourceManager } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameSound, GameSoundEvent, gameSound } from './GameSound';

/** Loads only the active game's two sounds plus shared result/error cues. */
export class GameSoundPlayer {
  private manager: resourceManager.ResourceManager | null = null;
  private pool: media.SoundPool | null = null;
  private gameId: string = '';
  private sounds: number[] = [];
  private loaded: Set<number> = new Set<number>();
  private streams: Set<number> = new Set<number>();
  private generation: number = 0;
  private playbackGeneration: number = 0;
  private lastPlayedAt: number = -1;
  private preparing: Promise<void> = Promise.resolve();
  private volumeDirty: boolean = false;
  private updatingVolume: boolean = false;

  init(manager: resourceManager.ResourceManager): void {
    this.manager = manager;
    gameSound.connect((id: string, event: GameSoundEvent): void => { this.play(id, event); },
      (id: string): void => { this.prepare(id); }, (): void => { this.stop(); },
      (): void => { this.updateVolume(); });
  }

  private prepare(gameId: string): void {
    const generation: number = ++this.generation;
    this.stop();
    // Serialize loads so rapid navigation never opens the same raw FD twice.
    this.preparing = this.preparing.then(() => { return this.loadGame(gameId, generation); });
  }

  private async loadGame(gameId: string, generation: number): Promise<void> {
    if (generation !== this.generation) { return; }
    const previous: media.SoundPool | null = this.pool;
    this.pool = null; this.gameId = gameId; this.sounds = [];
    this.loaded = new Set<number>(); this.streams = new Set<number>();
    if (previous) { await this.release(previous); }
    const manager: resourceManager.ResourceManager | null = this.manager;
    if (!manager || gameId.length === 0 || generation !== this.generation) { return; }
    try {
      const info: audio.AudioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_GAME, rendererFlags: 0 };
      const pool: media.SoundPool = await media.createSoundPool(4, info);
      if (generation !== this.generation) { await this.release(pool); return; }
      this.pool = pool;
      pool.on('loadComplete', (soundId: number): void => {
        if (generation === this.generation) { this.loaded.add(soundId); }
      });
      pool.on('playFinishedWithStreamId', (streamId: number): void => {
        if (generation === this.generation) { this.streams.delete(streamId); }
      });
      pool.on('error', (error: BusinessError): void => {
        hilog.warn(0x0000, 'GameSound', 'SoundPool error: %{public}d', error.code);
      });
      const paths: string[] = ['sounds/' + gameId + '_action.wav', 'sounds/' + gameId + '_reward.wav',
        'sounds/common_error.wav', 'sounds/common_win.wav', 'sounds/common_lose.wav', 'sounds/common_draw.wav'];
      for (let i: number = 0; i < paths.length; i++) {
        if (generation !== this.generation) { return; }
        const raw: resourceManager.RawFileDescriptor = await manager.getRawFd(paths[i]);
        try {
          if (generation !== this.generation) { return; }
          const soundId: number = await pool.load(raw.fd, raw.offset, raw.length);
          if (generation !== this.generation) { return; }
          this.sounds.push(soundId);
        } finally { await manager.closeRawFd(paths[i]); }
      }
    } catch (e) {
      if (generation === this.generation) {
        hilog.warn(0x0000, 'GameSound', 'Sound resource preparation failed for %{public}s', gameId);
        const failed: media.SoundPool | null = this.pool; this.pool = null;
        if (failed) { await this.release(failed); }
      }
    }
  }

  private async play(gameId: string, event: GameSoundEvent): Promise<void> {
    const pool: media.SoundPool | null = this.pool;
    const soundId: number | undefined = this.sounds[event];
    if (!pool || this.gameId !== gameId || !gameSound.canPlay(gameId) ||
      soundId === undefined || !this.loaded.has(soundId)) { return; }
    const now: number = Date.now();
    // Bound rapid gestures and physics hits; results always take precedence.
    if (event < GameSoundEvent.WIN && this.lastPlayedAt >= 0 && now - this.lastPlayedAt < 60) { return; }
    if (event >= GameSoundEvent.WIN) { this.stop(); }
    this.lastPlayedAt = now;
    const generation: number = this.generation;
    const playbackGeneration: number = this.playbackGeneration;
    const volume: number = gameSound.volume;
    const gain: number = 0.65 * volume / GameSound.MAX_VOLUME;
    const options: media.PlayParameters = { loop: 0, leftVolume: gain, rightVolume: gain,
      priority: event >= GameSoundEvent.WIN ? 2 : 1 };
    try {
      const stream: number = await pool.play(soundId, options);
      if (generation !== this.generation || playbackGeneration !== this.playbackGeneration || !gameSound.canPlay(gameId)) {
        try { await pool.stop(stream); } catch (e) {}
        return;
      }
      this.streams.add(stream);
      if (volume !== gameSound.volume) { this.updateVolume(); }
    } catch (e) {
      hilog.warn(0x0000, 'GameSound', 'Sound playback failed for %{public}s', gameId);
    }
  }

  private async updateVolume(): Promise<void> {
    this.volumeDirty = true;
    if (this.updatingVolume) { return; }
    this.updatingVolume = true;
    try {
      while (this.volumeDirty) {
        this.volumeDirty = false;
        const pool: media.SoundPool | null = this.pool;
        if (!pool) { continue; }
        const gain: number = 0.65 * gameSound.volume / GameSound.MAX_VOLUME;
        const streams: number[] = Array.from(this.streams);
        for (let i: number = 0; i < streams.length; i++) {
          try { await pool.setVolume(streams[i], gain, gain); } catch (e) {}
        }
      }
    } finally { this.updatingVolume = false; }
  }

  async stop(): Promise<void> {
    this.playbackGeneration++; this.lastPlayedAt = -1;
    const pool: media.SoundPool | null = this.pool;
    const streams: number[] = Array.from(this.streams); this.streams.clear();
    if (!pool) { return; }
    for (let i: number = 0; i < streams.length; i++) {
      try { await pool.stop(streams[i]); } catch (e) {}
    }
  }

  private async release(pool: media.SoundPool): Promise<void> {
    try { await pool.release(); } catch (e) {}
  }

  async dispose(): Promise<void> {
    gameSound.disconnect(); this.generation++;
    const pool: media.SoundPool | null = this.pool;
    this.pool = null; this.manager = null; this.sounds = []; this.loaded.clear(); this.streams.clear();
    if (pool) { await this.release(pool); }
  }
}
