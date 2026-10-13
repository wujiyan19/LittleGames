export const LAN_MAX_FRAME_BYTES: number = 131072;

/** TCP preserves byte order, but a message event is not a complete application frame. */
export class LanFrameBuffer {
  private bytes: Uint8Array = new Uint8Array(LAN_MAX_FRAME_BYTES);
  private length: number = 0;

  clear(): void {
    this.length = 0;
  }

  push(data: ArrayBuffer): Uint8Array[] {
    const incoming: Uint8Array = new Uint8Array(data);
    const frames: Uint8Array[] = [];
    for (let i: number = 0; i < incoming.length; i++) {
      const value: number = incoming[i];
      if (value === 10) {
        if (this.length > 0) {
          frames.push(this.bytes.slice(0, this.length));
        }
        this.length = 0;
      } else {
        if (this.length >= LAN_MAX_FRAME_BYTES) {
          this.clear();
          throw new Error('LAN frame exceeds the byte limit');
        }
        this.bytes[this.length] = value;
        this.length++;
      }
    }
    return frames;
  }
}

export class LanAddress {
  static isIPv4(address: string): boolean {
    const parts: string[] = address.split('.');
    if (parts.length !== 4) { return false; }
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i];
      if (!/^[0-9]{1,3}$/.test(part) || (part.length > 1 && part.charAt(0) === '0')) { return false; }
      const value: number = Number(part);
      if (value < 0 || value > 255) { return false; }
    }
    const first: number = Number(parts[0]);
    return first > 0 && first < 224 && first !== 127;
  }
}
