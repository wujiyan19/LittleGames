/** Serializable values only: no timers, native handles or UI references. */
export class ExpansionPiece {
  id: number = 0;
  kind: number = 0;
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;
  r: number = 0;
  color: number = 0;
  owner: number = -1;
  alive: boolean = true;
  vx: number = 0;
  vy: number = 0;
  age: number = 0;
}

export class ExpansionState {
  id: string = '';
  level: number = 1;
  cols: number = 6;
  rows: number = 6;
  board: number[] = [];
  tray: number[] = [];
  target: number[] = [];
  pieces: ExpansionPiece[] = [];
  piles: ExpansionPile[] = [];
  data: number[] = [];
  score: number = 0;
  moves: number = 0;
  outcome: number = 0;
  selected: number = -1;
  cursor: number = 0;
  errors: number = 0;
  goal: number = 0;
  next: number = 1;
  phase: number = 0;
  serial: number = 1;
  time: number = 0;
  cooldown: number = 0;
}

export class ExpansionPile { cards: number[] = []; }

export class BlockShape {
  cols: number = 1;
  rows: number = 1;
  cells: number[] = [0];
  constructor(cols: number, rows: number, cells: number[]) {
    this.cols = cols; this.rows = rows; this.cells = cells;
  }
}

export const BLOCK_SHAPES: BlockShape[] = [
  new BlockShape(1, 1, [0]), new BlockShape(2, 1, [0, 1]), new BlockShape(1, 2, [0, 1]),
  new BlockShape(3, 1, [0, 1, 2]), new BlockShape(1, 3, [0, 1, 2]),
  new BlockShape(2, 2, [0, 1, 2, 3]), new BlockShape(2, 2, [0, 2, 3]),
  new BlockShape(2, 2, [0, 1, 2]), new BlockShape(3, 2, [0, 1, 2, 4]),
  new BlockShape(3, 3, [1, 3, 4, 5, 7])
];
