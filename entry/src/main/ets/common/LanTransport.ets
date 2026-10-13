import { connection, socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { LAN_MAX_FRAME_BYTES, LanFrameBuffer } from './LanFraming';
import { LanProtocol } from './LanProtocol';

export interface LanTransportObserver {
  onConnected(): void;
  onMessage(message: string): void;
  onDisconnected(): void;
  onError(code: string): void;
}

export interface LanConnection {
  setObserver(observer: LanTransportObserver): void;
  startHost(): Promise<string>;
  join(address: string): Promise<void>;
  send(message: string): void;
  close(): void;
}

/** One room has one host and one guest. Native objects exist only while a room is open. */
export class LanTransport implements LanConnection {
  static readonly PORT: number = 41237;
  private static readonly CONNECT_TIMEOUT_MS: number = 8000;
  private static readonly MAX_PENDING_BYTES: number = 1048576;
  private observer: LanTransportObserver | undefined = undefined;
  private server: socket.TCPSocketServer | undefined = undefined;
  private client: socket.TCPSocket | undefined = undefined;
  // Retain the accepted connection for its entire lifetime, including asynchronous sends.
  private peer: socket.TCPSocketConnection | undefined = undefined;
  private frames: LanFrameBuffer = new LanFrameBuffer();
  private decoder: util.TextDecoder | undefined = undefined;
  private encoder: util.TextEncoder | undefined = undefined;
  private connected: boolean = false;
  private generation: number = 0;
  private timer: number = -1;
  private cancelConnect: (() => void) | undefined = undefined;
  private queue: ArrayBuffer[] = [];
  private pendingBytes: number = 0;
  private sending: boolean = false;
  private closing: Promise<void> = Promise.resolve();

  setObserver(observer: LanTransportObserver): void {
    this.observer = observer;
  }

  async startHost(): Promise<string> {
    this.close();
    const token: number = this.generation;
    await this.closing;
    this.checkCurrent(token);
    let stage: string = 'network';
    try {
      const address: string = await this.localAddress();
      this.checkCurrent(token);
      if (address.length === 0) { stage = 'no_address'; throw new Error('No local IPv4 address'); }
      stage = 'listen';
      const server: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
      this.server = server;
      server.on('connect', (peer: socket.TCPSocketConnection): void => {
        if (token !== this.generation || this.peer !== undefined) {
          this.releasePeer(peer);
          return;
        }
        this.peer = peer;
        peer.on('message', (info: socket.SocketMessageInfo): void => { this.receive(info.message, token); });
        peer.on('close', (): void => { this.disconnected(token); });
        peer.on('error', (error: BusinessError): void => { this.fail(this.errorCode(error, 'connection'), token); });
        this.connected = true;
        this.observer?.onConnected();
      });
      server.on('error', (error: BusinessError): void => { this.fail(this.errorCode(error, 'listen'), token); });
      const endpoint: socket.NetAddress = { address: address, family: 1, port: LanTransport.PORT };
      await server.listen(endpoint);
      this.checkCurrent(token);
      return address;
    } catch (error) {
      if (token === this.generation) { this.fail(this.errorCode(error as BusinessError, stage), token); }
      throw error as Error;
    }
  }

  async join(address: string): Promise<void> {
    this.close();
    const token: number = this.generation;
    const target: string = address.trim();
    if (!LanProtocol.address(target)) {
      this.fail('address', token);
      throw new Error('Invalid local IPv4 address');
    }
    await this.closing;
    this.checkCurrent(token);
    try {
      const client: socket.TCPSocket = socket.constructTCPSocketInstance();
      this.client = client;
      client.on('message', (info: socket.SocketMessageInfo): void => { this.receive(info.message, token); });
      client.on('close', (): void => { this.disconnected(token); });
      client.on('error', (error: BusinessError): void => { this.fail(this.errorCode(error, 'connect'), token); });
      const local: socket.NetAddress = { address: '0.0.0.0', family: 1, port: 0 };
      await client.bind(local);
      this.checkCurrent(token);
      await new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
        this.cancelConnect = (): void => { reject(new Error('Connection cancelled')); };
        this.timer = setTimeout((): void => {
          reject(new Error('Connection timeout'));
          this.fail('timeout', token);
        }, LanTransport.CONNECT_TIMEOUT_MS);
        const endpoint: socket.NetAddress = { address: target, family: 1, port: LanTransport.PORT };
        const options: socket.TCPConnectOptions = { address: endpoint, timeout: LanTransport.CONNECT_TIMEOUT_MS };
        client.connect(options).then((): void => {
          if (token !== this.generation) { reject(new Error('Connection cancelled')); return; }
          this.clearConnectTimer();
          this.cancelConnect = undefined;
          this.connected = true;
          this.observer?.onConnected();
          resolve();
        }).catch((error: BusinessError): void => {
          reject(new Error('Connection failed'));
          this.fail(this.errorCode(error, 'connect'), token);
        });
      });
      this.checkCurrent(token);
    } catch (error) {
      if (token === this.generation) { this.fail(this.errorCode(error as BusinessError, 'connect'), token); }
      throw error as Error;
    }
  }

  send(message: string): void {
    if (!this.connected) { return; }
    const token: number = this.generation;
    try {
      if (message.length === 0 || message.length > LAN_MAX_FRAME_BYTES ||
        message.indexOf('\n') >= 0 || message.indexOf('\r') >= 0) {
        this.fail('frame', token);
        return;
      }
      if (this.encoder === undefined) { this.encoder = new util.TextEncoder(); }
      const bytes: Uint8Array = this.encoder.encodeInto(message);
      if (bytes.length > LAN_MAX_FRAME_BYTES) { this.fail('frame', token); return; }
      if (this.pendingBytes + bytes.length + 1 > LanTransport.MAX_PENDING_BYTES) {
        this.fail('send', token);
        return;
      }
      const framed: Uint8Array = new Uint8Array(bytes.length + 1);
      framed.set(bytes);
      framed[bytes.length] = 10;
      this.queue.push(framed.buffer as ArrayBuffer);
      this.pendingBytes += framed.length;
      if (!this.sending) { this.flush(token); }
    } catch (error) {
      this.fail(this.errorCode(error as BusinessError, 'send'), token);
    }
  }

  close(): void {
    this.generation++;
    this.clearConnectTimer();
    const cancel: (() => void) | undefined = this.cancelConnect;
    this.cancelConnect = undefined;
    cancel?.();
    this.connected = false;
    this.frames.clear();
    this.queue = [];
    this.pendingBytes = 0;
    this.sending = false;
    const server: socket.TCPSocketServer | undefined = this.server;
    const client: socket.TCPSocket | undefined = this.client;
    const peer: socket.TCPSocketConnection | undefined = this.peer;
    this.server = undefined;
    this.client = undefined;
    this.peer = undefined;
    const previous: Promise<void> = this.closing;
    this.closing = this.releaseHandles(previous, server, client, peer);
  }

  private async localAddress(): Promise<string> {
    const networks: connection.NetHandle[] = await connection.getAllNets();
    for (let i: number = 0; i < networks.length; i++) {
      const capabilities: connection.NetCapabilities = await connection.getNetCapabilities(networks[i]);
      if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) < 0 &&
        capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_ETHERNET) < 0) { continue; }
      const properties: connection.ConnectionProperties = await connection.getConnectionProperties(networks[i]);
      for (let j: number = 0; j < properties.linkAddresses.length; j++) {
        const address: string = properties.linkAddresses[j].address.address;
        if (LanProtocol.address(address)) { return address; }
      }
    }
    return '';
  }

  private receive(data: ArrayBuffer, token: number): void {
    if (token !== this.generation) { return; }
    try {
      const frames: Uint8Array[] = this.frames.push(data);
      if (this.decoder === undefined) { this.decoder = util.TextDecoder.create('utf-8', { fatal: true }); }
      for (let i: number = 0; i < frames.length; i++) {
        if (token !== this.generation) { return; }
        this.observer?.onMessage(this.decoder.decodeToString(frames[i]));
      }
    } catch (error) {
      this.fail('frame', token);
    }
  }

  private async flush(token: number): Promise<void> {
    this.sending = true;
    try {
      while (token === this.generation && this.connected && this.queue.length > 0) {
        const data: ArrayBuffer = this.queue[0];
        const options: socket.TCPSendOptions = { data: data };
        if (this.peer !== undefined) { await this.peer.send(options); }
        else if (this.client !== undefined) { await this.client.send(options); }
        else { break; }
        if (token !== this.generation) { return; }
        this.queue.shift();
        this.pendingBytes -= data.byteLength;
      }
    } catch (error) {
      this.fail(this.errorCode(error as BusinessError, 'send'), token);
    } finally {
      if (token === this.generation) { this.sending = false; }
    }
  }

  private disconnected(token: number): void {
    if (token !== this.generation) { return; }
    this.close();
    this.observer?.onDisconnected();
  }

  private fail(code: string, token: number): void {
    if (token !== this.generation) { return; }
    this.close();
    this.observer?.onError(code);
  }

  private errorCode(error: BusinessError, fallback: string): string {
    return error.code === 201 ? 'permission' : fallback;
  }

  private checkCurrent(token: number): void {
    if (token !== this.generation) { throw new Error('LAN operation cancelled'); }
  }

  private clearConnectTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private async releasePeer(peer: socket.TCPSocketConnection): Promise<void> {
    try { peer.off('message'); peer.off('close'); peer.off('error'); } catch (error) {}
    try { await peer.close(); } catch (error) {}
  }

  private async releaseHandles(previous: Promise<void>, server: socket.TCPSocketServer | undefined,
    client: socket.TCPSocket | undefined, peer: socket.TCPSocketConnection | undefined): Promise<void> {
    // Detach immediately so an intentional close cannot report a stale disconnection.
    if (server !== undefined) {
      try { server.off('connect'); server.off('error'); } catch (error) {}
    }
    if (client !== undefined) {
      try { client.off('message'); client.off('close'); client.off('error'); } catch (error) {}
    }
    if (peer !== undefined) { await this.releasePeer(peer); }
    if (client !== undefined) { try { await client.close(); } catch (error) {} }
    if (server !== undefined) { try { await server.close(); } catch (error) {} }
    await previous;
  }
}
