/** The same version is required on both devices. Only the host sends game snapshots. */
export const LAN_GAME_IDS: string[] = ['tictactoe', 'gomoku', 'reversi', 'fourline', 'nim', 'dots', 'tug'];

export interface LanGameAdapter {
  gameId(): string;
  currentPlayer(): number;
  isFinished(): boolean;
  snapshot(): string;
  restore(payload: string): boolean;
  restart(): void;
  apply(kind: string, index: number, player: number): boolean;
}

export class LanPacket {
  version: number = 1;
  game: string = '';
  type: string = '';
  round: number = 0;
  revision: number = 0;
  sequence: number = 0;
  action: string = '';
  index: number = 0;
  payload: string = '';
  hostReady: boolean = false;
  guestReady: boolean = false;
}

export class LanProtocol {
  static integer(value: number): boolean {
    return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 1000000;
  }

  static address(value: string): boolean {
    // Use only private IPv4 LAN ranges, never DNS or an Internet endpoint.
    const parts: string[] = value.split('.');
    if (parts.length !== 4) { return false; }
    const octets: number[] = [];
    for (let i: number = 0; i < parts.length; i++) {
      if (!/^(0|[1-9][0-9]{0,2})$/.test(parts[i])) { return false; }
      const octet: number = Number(parts[i]);
      if (octet > 255) { return false; }
      octets.push(octet);
    }
    return octets[0] === 10 || (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] === 192 && octets[1] === 168);
  }

  static decode(value: string): LanPacket | null {
    if (value.length > 131072) { return null; }
    try {
      const packet: LanPacket = JSON.parse(value) as LanPacket;
      if (packet === null || Array.isArray(packet) || packet.version !== 1 ||
        !LAN_GAME_IDS.includes(packet.game) ||
        !['hello', 'welcome', 'state', 'input', 'restart', 'ready', 'ping', 'error'].includes(packet.type) ||
        !LanProtocol.integer(packet.round) || !LanProtocol.integer(packet.revision) ||
        !LanProtocol.integer(packet.sequence) || !LanProtocol.integer(packet.index) || packet.index > 1000 ||
        typeof packet.action !== 'string' || packet.action.length > 24 ||
        typeof packet.payload !== 'string' || packet.payload.length > 65536 ||
        typeof packet.hostReady !== 'boolean' || typeof packet.guestReady !== 'boolean') { return null; }
      return packet;
    } catch (e) { return null; }
  }
}
