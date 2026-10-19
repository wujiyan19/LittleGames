import { ExpansionPiece, ExpansionState } from './ExpansionState';
import { RandomSource, SeededRandom } from './RandomSource';

class ScrewBeam {
  x: number; y: number; w: number; h: number;
  constructor(x: number, y: number, w: number, h: number) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }
}

/** Overlapping plates unlock screws; only three screws of the same color free tray space. */
export class ExpansionScrews {
  static capacity(s: ExpansionState): number { return s.phase === 0 ? 3 : s.level === 2 ? 5 : 6; }

  static free(s: ExpansionState, screw: ExpansionPiece): boolean {
    // Include the head radius: a partly covered screw must not look selectable.
    const radius: number = s.phase === 0 ? 0 : screw.r;
    return screw.alive && screw.kind === 1 && !s.pieces.some((p: ExpansionPiece) =>
      p.kind === 0 && p.alive && p.id > screw.owner && screw.x + radius > p.x &&
      screw.x - radius < p.x + p.w && screw.y + radius > p.y && screw.y - radius < p.y + p.h);
  }

  static start(s: ExpansionState, random: RandomSource): void {
    let seed: number = 1 + Math.min(999998, Math.max(0, Math.floor(random.next() * 999999)));
    for (let attempt: number = 0; attempt < 32; attempt++) {
      ExpansionScrews.build(s, seed);
      if (s.level !== 2 || !ExpansionScrews.greedyClears(s)) { return; }
      seed = (seed + 7918) % 999999 + 1;
    }
    // A verified planning deal bounds generation time even for a constant random source.
    ExpansionScrews.build(s, 55464);
  }

  private static pick(random: RandomSource, count: number): number {
    return Math.min(count - 1, Math.max(0, Math.floor(random.next() * count)));
  }

  private static shuffle(values: number[], random: RandomSource): void {
    for (let i: number = values.length - 1; i > 0; i--) {
      const j: number = ExpansionScrews.pick(random, i + 1);
      const value: number = values[i]; values[i] = values[j]; values[j] = value;
    }
  }

  private static build(s: ExpansionState, seed: number): void {
    s.pieces = []; s.target = [];
    s.cols = 3; s.rows = 3; s.phase = 1; s.data = [seed]; s.goal = 5 + s.level * 2;
    const random: SeededRandom = new SeededRandom(seed);
    const beams: ScrewBeam[] = [new ScrewBeam(26, 66, 264, 68), new ScrewBeam(226, 70, 68, 310),
      new ScrewBeam(40, 314, 274, 68), new ScrewBeam(36, 62, 68, 310), new ScrewBeam(24, 190, 292, 68),
      new ScrewBeam(136, 48, 68, 340), new ScrewBeam(54, 80, 264, 68), new ScrewBeam(242, 48, 68, 340),
      new ScrewBeam(24, 326, 292, 68)];
    const order: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8]; ExpansionScrews.shuffle(order, random);
    const mirrorX: boolean = random.next() < 0.5; const mirrorY: boolean = random.next() < 0.5;
    for (let p: number = 0; p < s.goal; p++) {
      const beam: ScrewBeam = beams[order[p]];
      const plate: ExpansionPiece = new ExpansionPiece(); plate.id = p;
      plate.x = mirrorX ? 360 - beam.x - beam.w : beam.x;
      plate.y = mirrorY ? 460 - beam.y - beam.h : beam.y;
      plate.w = beam.w; plate.h = beam.h; plate.color = p % 5 + 1; s.pieces.push(plate);
      for (let j: number = 0; j < 3; j++) {
        const screw: ExpansionPiece = new ExpansionPiece(); screw.id = s.goal + p * 3 + j;
        screw.kind = 1; screw.owner = p; screw.r = 16;
        // Match the three authored recesses in the plate sprite, including its clockwise rotation.
        const along: number = (26 + j * 78) / 220;
        screw.x = plate.w > plate.h ? plate.x + along * plate.w : plate.x + (1 - 30 / 96) * plate.w;
        screw.y = plate.w > plate.h ? plate.y + 30 / 96 * plate.h : plate.y + along * plate.h;
        s.pieces.push(screw);
      }
    }
    // First construct a physically legal removal route. Its color sequence below is
    // balanced in threes and has a known bounded tray occupancy, so every deal is solvable.
    for (let i: number = 0; i < s.goal * 3; i++) {
      const exposed: ExpansionPiece[] = s.pieces.filter((p: ExpansionPiece) => ExpansionScrews.free(s, p));
      const screw: ExpansionPiece = exposed[ExpansionScrews.pick(random, exposed.length)];
      s.target.push(screw.id); screw.alive = false;
      ExpansionScrews.dropPlate(s, screw.owner);
    }
    s.pieces.forEach((p: ExpansionPiece) => { p.alive = true; });
    const palette: number[] = [];
    for (let c: number = 1; c <= 3 + s.level; c++) { palette.push(c); }
    ExpansionScrews.shuffle(palette, random);
    // These schedules require interleaving unfinished color groups. The hard schedule
    // fits a five-slot tray; filling the last slot is legal only if it completes a triple.
    const pattern: number[] = s.level === 0 ? [0, 0, 1, 0, 1, 2, 1, 2, 2] :
      s.level === 1 ? [0, 1, 0, 2, 1, 0, 2, 1, 2] : [0, 1, 0, 1, 0, 2, 1, 2, 2];
    for (let i: number = 0; i < s.target.length; i++) {
      const chunk: number = Math.floor(i / 9); const remaining: number = s.target.length - chunk * 9;
      const symbol: number = remaining >= 9 ? pattern[i % 9] : remaining === 6 ? i % 2 : 0;
      const screw: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === s.target[i]);
      if (screw) { screw.color = palette[(chunk * 2 + symbol) % palette.length]; }
    }
  }

  private static greedyClears(s: ExpansionState): boolean {
    const trial: ExpansionState = JSON.parse(JSON.stringify(s)) as ExpansionState;
    while (trial.outcome === 0) {
      const counts: number[] = new Array<number>(6).fill(0);
      trial.tray.forEach((id: number) => {
        const held: ExpansionPiece | undefined = trial.pieces.find((p: ExpansionPiece) => p.id === id);
        if (held) { counts[held.color]++; }
      });
      const exposed: ExpansionPiece[] = trial.pieces.filter((p: ExpansionPiece) => ExpansionScrews.free(trial, p));
      exposed.sort((a: ExpansionPiece, b: ExpansionPiece) => counts[b.color] - counts[a.color] || b.owner - a.owner);
      ExpansionScrews.tap(trial, exposed[0].id);
    }
    return trial.outcome === 1;
  }

  private static dropPlate(s: ExpansionState, owner: number): boolean {
    if (s.pieces.some((p: ExpansionPiece) => p.kind === 1 && p.alive && p.owner === owner)) { return false; }
    const plate: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.kind === 0 && p.id === owner);
    if (plate) { plate.alive = false; }
    return true;
  }

  static tap(s: ExpansionState, id: number): void {
    const screw: ExpansionPiece | undefined = s.pieces.find((p: ExpansionPiece) => p.id === id);
    if (!screw || !ExpansionScrews.free(s, screw) || s.tray.length >= ExpansionScrews.capacity(s)) { return; }
    screw.alive = false; s.tray.push(id); s.moves++; s.score += 30;
    const dropped: boolean = ExpansionScrews.dropPlate(s, screw.owner);
    if (dropped) { s.score += 100; }
    if (s.phase === 0) {
      // Keep already saved pre-upgrade rounds playable until the next new game.
      if (dropped) { s.tray = s.tray.filter((parked: number) =>
        s.pieces.find((p: ExpansionPiece) => p.id === parked)?.owner !== screw.owner); }
    } else {
      const matching: number[] = s.tray.filter((parked: number) =>
        s.pieces.find((p: ExpansionPiece) => p.id === parked)?.color === screw.color);
      if (matching.length === 3) { s.tray = s.tray.filter((parked: number) => !matching.includes(parked)); s.score += 60; }
    }
    if (!s.pieces.some((p: ExpansionPiece) => p.kind === 0 && p.alive)) { s.outcome = 1; }
    else if (s.phase === 1 && s.tray.length >= ExpansionScrews.capacity(s)) { s.outcome = 2; }
  }

  private static legacy(s: ExpansionState): void {
    const plates: number = 3 + s.level; s.cols = 3; s.rows = 3;
    for (let p: number = 0; p < plates; p++) {
      const plate: ExpansionPiece = new ExpansionPiece(); plate.id = p;
      plate.x = 22 + p * 22; plate.y = 48 + p * 52; plate.w = 220; plate.h = 96; plate.color = p + 1; s.pieces.push(plate);
      for (let j: number = 0; j < 3; j++) {
        const screw: ExpansionPiece = new ExpansionPiece(); screw.id = plates + p * 3 + j; screw.kind = 1;
        screw.owner = p; screw.x = plate.x + 26 + j * 78; screw.y = plate.y + 30; screw.r = 16; screw.color = p + 1; s.pieces.push(screw);
      }
    }
    s.target = s.pieces.filter((p: ExpansionPiece) => p.kind === 1)
      .sort((a: ExpansionPiece, b: ExpansionPiece) => b.owner - a.owner).map((p: ExpansionPiece) => p.id);
  }

  static valid(s: ExpansionState): boolean {
    const expected: ExpansionState = new ExpansionState(); expected.id = s.id; expected.level = s.level;
    if (s.phase === 0) { if (s.data.length !== 0) { return false; } ExpansionScrews.legacy(expected); }
    else {
      if (s.data.length !== 1 || !Number.isInteger(s.data[0]) || s.data[0] < 1 || s.data[0] > 999999) { return false; }
      ExpansionScrews.build(expected, s.data[0]);
    }
    if (s.cols !== 3 || s.rows !== 3 || s.goal !== expected.goal || s.board.length !== 0 ||
      s.pieces.length !== expected.pieces.length || s.target.join(',') !== expected.target.join(',') ||
      s.tray.length > ExpansionScrews.capacity(s) || new Set<number>(s.tray).size !== s.tray.length) { return false; }
    let removed: number = 0; let dropped: number = 0;
    for (let i: number = 0; i < s.pieces.length; i++) {
      const p: ExpansionPiece = s.pieces[i]; const e: ExpansionPiece = expected.pieces[i];
      if (p.id !== e.id || p.kind !== e.kind || p.x !== e.x || p.y !== e.y || p.w !== e.w || p.h !== e.h ||
        p.r !== e.r || p.owner !== e.owner || p.color !== e.color) { return false; }
      if (p.kind === 0) {
        if (p.alive !== s.pieces.some((q: ExpansionPiece) => q.kind === 1 && q.owner === p.id && q.alive)) { return false; }
        if (!p.alive) { dropped++; }
      } else if (!p.alive) { removed++; }
    }
    if (!s.tray.every((id: number) => s.pieces.some((p: ExpansionPiece) => p.id === id && p.kind === 1 && !p.alive))) { return false; }
    let recycled: number = 0;
    if (s.phase === 1) {
      for (let color: number = 1; color <= 3 + s.level; color++) {
        const count: number = s.pieces.filter((p: ExpansionPiece) => p.kind === 1 && !p.alive && p.color === color).length;
        const holding: number = s.tray.filter((id: number) => s.pieces.some((p: ExpansionPiece) => p.id === id && p.color === color)).length;
        if (holding !== count % 3) { return false; } recycled += Math.floor(count / 3);
      }
    } else if (s.tray.length !== removed - dropped * 3 || s.tray.some((id: number) =>
      s.pieces.some((p: ExpansionPiece) => p.kind === 0 && !p.alive &&
        s.pieces.some((q: ExpansionPiece) => q.id === id && q.owner === p.id)))) { return false; }
    const outcome: number = dropped * 4 === s.pieces.length ? 1 :
      s.phase === 1 && s.tray.length === ExpansionScrews.capacity(s) ? 2 : 0;
    return s.moves === removed && s.score === removed * 30 + dropped * 100 + recycled * 60 && s.outcome === outcome;
  }
}
