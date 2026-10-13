import { LAN_GAME_IDS, LanGameAdapter, LanPacket, LanProtocol } from './LanProtocol';
import { LanConnection, LanTransport, LanTransportObserver } from './LanTransport';

export { LAN_GAME_IDS, LanGameAdapter } from './LanProtocol';

/** Two devices, one authoritative model. A failed connection stays frozen until explicitly left. */
@ObservedV2
export class LanGameSession implements LanTransportObserver {
  @Trace status: string = 'local';
  @Trace address: string = '';
  @Trace error: string = '';
  @Trace localPlayer: number = 0;
  @Trace revision: number = 0;
  @Trace wantsRestart: boolean = false;
  @Trace peerWantsRestart: boolean = false;
  @Trace pending: boolean = false;
  private adapter: LanGameAdapter | null;
  private transport: LanConnection;
  private active: boolean = false;
  private round: number = 0;
  private sentSequence: number = 0;
  private receivedSequence: number = 0;
  private generation: number = 0;
  private heartbeat: number = -1;
  private handshake: number = -1;
  private delayedClose: number = -1;
  private missedHeartbeats: number = 0;

  constructor(adapter: LanGameAdapter | null = null, transport: LanConnection | null = null) {
    this.adapter = adapter;
    this.transport = transport === null ? new LanTransport() : transport;
    this.transport.setObserver(this);
  }

  isOnline(): boolean { return this.status !== 'local'; }

  private begin(player: number): number {
    this.cleanup(); this.generation++;
    this.active = true; this.localPlayer = player; this.error = '';
    this.revision = 0; this.round = 0; this.sentSequence = 0; this.receivedSequence = 0;
    this.pending = false; this.wantsRestart = false; this.peerWantsRestart = false;
    return this.generation;
  }

  async host(): Promise<void> {
    if (this.status === 'connected' || this.status === 'hosting' || this.status === 'connecting') { return; }
    const generation: number = this.begin(1); this.status = 'hosting'; this.address = '';
    if (this.adapter === null || !LAN_GAME_IDS.includes(this.adapter.gameId())) { this.fail('protocol'); return; }
    try {
      const address: string = await this.transport.startHost();
      if (!this.active || generation !== this.generation) { return; }
      this.address = address;
      if (address.length === 0) { this.fail('no_address'); }
    } catch (e) { if (this.active && generation === this.generation) { this.fail('network'); } }
  }

  async join(address: string): Promise<void> {
    if (this.status === 'connected' || this.status === 'hosting' || this.status === 'connecting') { return; }
    const generation: number = this.begin(2); this.status = 'connecting'; this.address = address.trim();
    if (this.adapter === null || !LAN_GAME_IDS.includes(this.adapter.gameId())) { this.fail('protocol'); return; }
    if (!LanProtocol.address(this.address)) { this.fail('invalid_address'); return; }
    try { await this.transport.join(this.address); }
    catch (e) { if (this.active && generation === this.generation) { this.fail('network'); } }
  }

  onConnected(): void {
    if (!this.active) { return; }
    this.handshake = setTimeout(() => { this.handshake = -1; this.fail('network'); }, 10000);
    if (this.localPlayer === 2) { this.send(this.packet('hello')); }
  }

  onMessage(message: string): void {
    if (!this.active || this.adapter === null) { return; }
    const packet: LanPacket | null = LanProtocol.decode(message);
    if (packet === null) { this.reject('protocol'); return; }
    this.missedHeartbeats = 0;
    if (packet.type === 'error') { this.fail(packet.payload === 'mismatch' ? 'mismatch' : 'protocol'); return; }
    if (packet.game !== this.adapter.gameId()) { this.reject('mismatch'); return; }
    if (this.localPlayer === 1 && this.status === 'hosting' && packet.type === 'hello') {
      this.adapter.restart(); this.round = 1; this.revision = 0;
      this.status = 'connected'; this.startHeartbeat(); this.sendState('welcome'); return;
    }
    if (this.localPlayer === 2 && this.status === 'connecting' && packet.type === 'welcome') {
      if (packet.round !== 1 || packet.revision !== 0 || !this.adapter.restore(packet.payload)) { this.reject('protocol'); return; }
      this.round = packet.round; this.revision = packet.revision;
      this.status = 'connected'; this.startHeartbeat(); return;
    }
    if (this.status !== 'connected') { this.reject('protocol'); return; }
    if (packet.type === 'ping') { return; }
    if (this.localPlayer === 1 && packet.type === 'input') { this.receiveInput(packet); return; }
    if (this.localPlayer === 2 && packet.type === 'state') { this.receiveState(packet); return; }
    if (this.localPlayer === 1 && packet.type === 'restart' && packet.round === this.round) {
      this.peerWantsRestart = true; this.restartIfReady(); return;
    }
    if (this.localPlayer === 2 && packet.type === 'ready' && packet.round === this.round) {
      this.wantsRestart = this.wantsRestart || packet.guestReady; this.peerWantsRestart = packet.hostReady; return;
    }
    // Delayed intents from a previous round never affect the next game.
    if (packet.round < this.round) { return; }
    this.reject('protocol');
  }

  private receiveInput(packet: LanPacket): void {
    if (packet.sequence <= this.receivedSequence) { this.sendState(); return; }
    if (packet.sequence !== this.receivedSequence + 1) { this.reject('protocol'); return; }
    this.receivedSequence = packet.sequence;
    if (packet.round < this.round) { this.sendState(); return; }
    if (packet.round > this.round) { this.reject('protocol'); return; }
    // Tug is simultaneous: a newer host tap must not discard a guest tap already in flight.
    if (this.adapter !== null && (packet.revision === this.revision || this.adapter.gameId() === 'tug') &&
      this.allowed(packet.action, packet.index, 2) && this.adapter.apply(packet.action, packet.index, 2)) { this.revision++; }
    this.sendState();
  }

  private receiveState(packet: LanPacket): void {
    if (packet.round < this.round || (packet.round === this.round && packet.revision < this.revision)) { return; }
    if (packet.round > this.round + 1 || packet.sequence > this.sentSequence ||
      (packet.round > this.round && (!this.wantsRestart || !this.peerWantsRestart)) ||
      this.adapter === null || !this.adapter.restore(packet.payload)) { this.reject('protocol'); return; }
    if (packet.round > this.round) { this.wantsRestart = false; this.peerWantsRestart = false; }
    this.round = packet.round; this.revision = packet.revision;
    this.pending = packet.sequence < this.sentSequence;
  }

  private allowed(kind: string, index: number, player: number): boolean {
    if (this.adapter === null || this.adapter.isFinished() || !LanProtocol.integer(index) || index > 1000) { return false; }
    const game: string = this.adapter.gameId();
    if (game === 'tug') { return kind === 'tap' && index === player - 1; }
    if (this.adapter.currentPlayer() !== player) { return false; }
    return game === 'nim' ? kind === 'choose' : kind === 'tap';
  }

  submit(kind: string, index: number): void {
    if (!this.active || this.status !== 'connected' || this.adapter === null || !this.allowed(kind, index, this.localPlayer)) { return; }
    if (this.localPlayer === 1) {
      if (this.adapter.apply(kind, index, 1)) { this.revision++; this.sendState(); }
    } else {
      if (this.pending && this.adapter.gameId() !== 'tug') { return; }
      const packet: LanPacket = this.packet('input'); packet.action = kind; packet.index = index;
      this.sentSequence++; packet.sequence = this.sentSequence; this.pending = true; this.send(packet);
    }
  }

  requestRestart(): void {
    if (!this.active || this.status !== 'connected' || this.wantsRestart) { return; }
    this.wantsRestart = true;
    if (this.localPlayer === 1) { this.restartIfReady(); }
    else { this.send(this.packet('restart')); }
  }

  private restartIfReady(): void {
    // Tell the guest both consent flags before the snapshot for the new round.
    const ready: LanPacket = this.packet('ready');
    ready.hostReady = this.wantsRestart; ready.guestReady = this.peerWantsRestart; this.send(ready);
    if (!this.wantsRestart || !this.peerWantsRestart || this.adapter === null) { return; }
    this.adapter.restart(); this.round++; this.revision = 0;
    this.wantsRestart = false; this.peerWantsRestart = false;
    this.sendState();
  }

  private packet(type: string): LanPacket {
    const packet: LanPacket = new LanPacket();
    packet.game = this.adapter === null ? '' : this.adapter.gameId(); packet.type = type;
    packet.round = this.round; packet.revision = this.revision; packet.sequence = this.receivedSequence;
    return packet;
  }

  private sendState(type: string = 'state'): void {
    if (this.adapter === null) { return; }
    const packet: LanPacket = this.packet(type); packet.payload = this.adapter.snapshot(); this.send(packet);
  }

  private send(packet: LanPacket): void { this.transport.send(JSON.stringify(packet)); }

  private startHeartbeat(): void {
    if (this.handshake >= 0) { clearTimeout(this.handshake); this.handshake = -1; }
    this.missedHeartbeats = 0;
    this.heartbeat = setInterval(() => {
      this.missedHeartbeats++;
      if (this.missedHeartbeats >= 6) { this.fail('network', 'disconnected'); return; }
      this.send(this.packet('ping'));
    }, 2000);
  }

  onDisconnected(): void { if (this.active) { this.fail('network', 'disconnected'); } }
  onError(code: string): void {
    if (this.active) { this.fail(code === 'address' ? 'invalid_address' : code === 'no_address' ? 'no_address' : 'network'); }
  }

  private reject(code: string): void {
    this.sendError(code); this.active = false; this.status = 'error'; this.error = code; this.pending = false;
    this.stopTimers();
    // Give the queued rejection a chance to reach the peer before closing TCP.
    this.delayedClose = setTimeout(() => { this.delayedClose = -1; this.transport.close(); }, 100);
  }

  private sendError(code: string): void { const packet: LanPacket = this.packet('error'); packet.payload = code; this.send(packet); }
  private fail(code: string, status: string = 'error'): void {
    this.cleanup(); this.status = status; this.error = code; this.pending = false;
  }
  private stopTimers(): void {
    if (this.heartbeat >= 0) { clearInterval(this.heartbeat); this.heartbeat = -1; }
    if (this.handshake >= 0) { clearTimeout(this.handshake); this.handshake = -1; }
    if (this.delayedClose >= 0) { clearTimeout(this.delayedClose); this.delayedClose = -1; }
  }
  private cleanup(): void { this.active = false; this.stopTimers(); this.transport.close(); }
  suspend(): void { if (this.isOnline() && this.active) { this.fail('background', 'disconnected'); } }
  close(): void {
    this.cleanup(); this.generation++; this.pending = false;
    if (['connected', 'connecting', 'hosting'].includes(this.status)) { this.status = 'disconnected'; }
  }
  leave(): void {
    this.close(); this.status = 'local'; this.localPlayer = 0; this.error = ''; this.pending = false;
    this.wantsRestart = false; this.peerWantsRestart = false;
    if (this.adapter !== null) { this.adapter.restart(); }
  }
}
