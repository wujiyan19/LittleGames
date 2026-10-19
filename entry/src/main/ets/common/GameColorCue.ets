/** Same non-color identity in water, yarn, sand and matching tiles. */
export class GameColorCue {
  static symbol(value: number): string {
    return value <= 0 ? '' : ['◆', '●', '★', '▲', '♥', '✿'][(value - 1) % 6];
  }
}
