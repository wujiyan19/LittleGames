import { ExpansionState, ExpansionPiece, ExpansionPile } from './ExpansionState';
import { ExpansionPuzzle } from './ExpansionPuzzle';
import { ExpansionPhysics } from './ExpansionPhysics';
import { ExpansionAdventure } from './ExpansionAdventure';
import { ExpansionTable, CHARACTER_PARTS, CHARACTER_RECIPES } from './ExpansionTable';
import { ExpansionArcade } from './ExpansionArcade';
import { ExpansionMatching, MATCHING_IDS } from './ExpansionMatching';
import { ExpansionSorting, SORTING_IDS } from './ExpansionSorting';
import { ExpansionAction, ACTION_IDS } from './ExpansionAction';
import { ExpansionSports, SPORTS_IDS } from './ExpansionSports';
import { ExpansionChess, CHESS_IDS } from './ExpansionChess';
import { ExpansionPoker, POKER_IDS } from './ExpansionPoker';
import { ExpansionCards, CARD_IDS } from './ExpansionCards';
import { ExpansionBrain, BRAIN_IDS } from './ExpansionBrain';
import { ExpansionLife, LIFE_IDS } from './ExpansionLife';
import { RealRandom, RandomSource } from './RandomSource';
import { ContinuationValidation as V } from '../../common/GameSessionTransfer';

export const PLAYABLE_EXPANSION_IDS: string[] = ['blockfit', 'tilestack', 'bubbleshooter', 'fruitmerge', 'watersort', 'arrowclear', 'screwout', 'parkingjam',
  'runner', 'blackhole', 'fisheat', 'sokoban', 'pipes', 'differences', 'roomdefense', 'basketball', 'solitaire', 'characters', 'rhythm', 'restaurant', ...MATCHING_IDS, ...SORTING_IDS, ...ACTION_IDS, ...SPORTS_IDS, ...POKER_IDS, 'mahjong', ...CHESS_IDS, 'ludo', 'spider', 'freecell', ...BRAIN_IDS, ...LIFE_IDS];

export class ExpansionModel {
  state: ExpansionState = new ExpansionState();
  puzzle: ExpansionPuzzle;
  physics: ExpansionPhysics;
  adventure: ExpansionAdventure;
  table: ExpansionTable;
  arcade: ExpansionArcade;
  matching: ExpansionMatching;
  sorting: ExpansionSorting;
  actionGames: ExpansionAction;
  sports: ExpansionSports;
  chess: ExpansionChess;
  poker: ExpansionPoker;
  cards: ExpansionCards;
  brain: ExpansionBrain;
  life: ExpansionLife;
  private history: string[] = [];
  constructor(random: RandomSource = new RealRandom()) {
    this.puzzle = new ExpansionPuzzle(random); this.physics = new ExpansionPhysics(random); this.adventure = new ExpansionAdventure(random);
    this.table = new ExpansionTable(random); this.arcade = new ExpansionArcade(random);
    this.matching = new ExpansionMatching(random); this.sorting = new ExpansionSorting(random);
    this.actionGames = new ExpansionAction(random); this.sports = new ExpansionSports(random);
    this.chess = new ExpansionChess(random); this.poker = new ExpansionPoker(random); this.cards = new ExpansionCards(random);
    this.brain = new ExpansionBrain(random); this.life = new ExpansionLife(random);
  }
  start(id: string, level: number): void {
    this.state = new ExpansionState(); this.state.id = id; this.state.level = level; this.history = [];
    if (BRAIN_IDS.includes(id)) { this.brain.start(this.state); } else if (LIFE_IDS.includes(id)) { this.life.start(this.state);
    } else if (CHESS_IDS.includes(id)) { this.chess.start(this.state); } else if (POKER_IDS.includes(id)) { this.poker.start(this.state); } else if (CARD_IDS.includes(id)) { this.cards.start(this.state);
    } else if (ACTION_IDS.includes(id)) { this.actionGames.start(this.state); } else if (SPORTS_IDS.includes(id)) { this.sports.start(this.state);
    } else if (MATCHING_IDS.includes(id)) { this.matching.start(this.state); } else if (SORTING_IDS.includes(id)) { this.sorting.start(this.state);
    } else if (this.isTable()) { this.table.start(this.state); } else if (this.isArcade()) { this.arcade.start(this.state);
    } else if (this.isAdventure()) { this.adventure.start(this.state); } else if (this.realtime()) { this.physics.start(this.state); } else { this.puzzle.start(this.state); }
  }
  private isAdventure(): boolean { return ['runner', 'blackhole', 'fisheat', 'sokoban', 'pipes', 'differences'].includes(this.state.id); }
  private isTable(): boolean { return this.state.id === 'solitaire' || this.state.id === 'characters'; }
  private isArcade(): boolean { return ['roomdefense', 'basketball', 'rhythm', 'restaurant'].includes(this.state.id); }
  realtime(): boolean { return this.brain.realtime(this.state.id) || this.state.id === 'fishing' || this.actionGames.realtime(this.state.id) || this.sports.realtime(this.state.id) || this.isArcade() || ['bubbleshooter', 'fruitmerge', 'runner', 'blackhole', 'fisheat'].includes(this.state.id); }
  tap(index: number): void {
    if (!V.integer(index, 0, 1000) || this.state.outcome !== 0 || (this.realtime() && this.state.id !== 'runner' && !this.isArcade() && !ACTION_IDS.includes(this.state.id) && !SPORTS_IDS.includes(this.state.id) && !BRAIN_IDS.includes(this.state.id) && !LIFE_IDS.includes(this.state.id))) { return; }
    if (this.realtime() && (ACTION_IDS.includes(this.state.id) || SPORTS_IDS.includes(this.state.id) || BRAIN_IDS.includes(this.state.id) || LIFE_IDS.includes(this.state.id))) {
      if (BRAIN_IDS.includes(this.state.id)) { this.brain.tap(this.state, index); } else if (LIFE_IDS.includes(this.state.id)) { this.life.tap(this.state, index);
      } else if (ACTION_IDS.includes(this.state.id)) { this.actionGames.tap(this.state, index); } else { this.sports.tap(this.state, index); } return;
    }
    if (this.isArcade()) { this.arcade.tap(this.state, index); this.state.pieces = this.state.pieces.filter((p: ExpansionPiece) => p.alive); return; }
    if (this.state.id === 'runner') { this.adventure.tap(this.state, index); return; }
    const previous: string = JSON.stringify(this.state);
    if (BRAIN_IDS.includes(this.state.id)) { this.brain.tap(this.state, index); } else if (LIFE_IDS.includes(this.state.id)) { this.life.tap(this.state, index);
    } else if (CHESS_IDS.includes(this.state.id)) { this.chess.tap(this.state, index); } else if (POKER_IDS.includes(this.state.id)) { this.poker.tap(this.state, index); } else if (CARD_IDS.includes(this.state.id)) { this.cards.tap(this.state, index);
    } else if (ACTION_IDS.includes(this.state.id)) { this.actionGames.tap(this.state, index); } else if (SPORTS_IDS.includes(this.state.id)) { this.sports.tap(this.state, index);
    } else if (MATCHING_IDS.includes(this.state.id)) { this.matching.tap(this.state, index); } else if (SORTING_IDS.includes(this.state.id)) { this.sorting.tap(this.state, index);
    } else if (this.isTable()) { this.table.tap(this.state, index); } else if (this.isAdventure()) { this.adventure.tap(this.state, index); } else { this.puzzle.tap(this.state, index); }
    if (JSON.stringify(this.state) !== previous) { this.history.push(previous); if (this.history.length > 120) { this.history.shift(); } }
  }
  choose(index: number): void {
    if (!V.integer(index, 0, 1000) || this.state.outcome !== 0) { return; }
    if (ACTION_IDS.includes(this.state.id)) { this.actionGames.choose(this.state, index); }
    if (CHESS_IDS.includes(this.state.id)) { this.chess.choose(this.state, index); }
    if (BRAIN_IDS.includes(this.state.id)) { this.brain.choose(this.state, index); }
    if (LIFE_IDS.includes(this.state.id)) { this.life.choose(this.state, index); }
    if (SORTING_IDS.includes(this.state.id) && this.state.outcome === 0 && V.integer(index, 0, 1000)) { this.sorting.choose(this.state, index); }
    if (this.state.id === 'blockfit' && this.state.outcome === 0 && V.integer(index, 0, 2) && this.state.tray[index] >= 0) { this.state.selected = index; }
  }
  action(): void {
    if (this.state.outcome !== 0) { return; }
    const previous: string = JSON.stringify(this.state);
    if (MATCHING_IDS.includes(this.state.id)) { this.matching.action(this.state); } else if (this.state.id === 'characters') { this.table.checkWord(this.state); }
    if (previous !== JSON.stringify(this.state)) { this.history.push(previous); if (this.history.length > 120) { this.history.shift(); } }
  }
  activate(): void {
    if (this.state.outcome !== 0) { return; }
    if (BRAIN_IDS.includes(this.state.id)) { this.brain.activate(this.state); } else if (LIFE_IDS.includes(this.state.id)) { this.life.activate(this.state);
    } else if (ACTION_IDS.includes(this.state.id)) { this.actionGames.activate(this.state); } else if (SPORTS_IDS.includes(this.state.id)) { this.sports.activate(this.state);
    } else if (this.isArcade()) { this.arcade.activate(this.state); } else if (this.state.id === 'runner') { this.adventure.activate(this.state); }
  }
  aim(x: number, y: number): void {
    if ((!this.realtime() && this.state.id !== 'untangle') || this.state.outcome !== 0 || !V.finite(x) || !V.finite(y) || x < 0 || x > 360 || y < 0 || y > 460) { return; }
    if (this.state.id === 'untangle') { this.sorting.aim(this.state, x, y); return; }
    if (ACTION_IDS.includes(this.state.id)) { this.actionGames.aim(this.state, x, y); return; }
    if (SPORTS_IDS.includes(this.state.id)) { this.sports.aim(this.state, x, y); return; }
    if (BRAIN_IDS.includes(this.state.id)) { this.brain.aim(this.state, x, y); return; }
    if (LIFE_IDS.includes(this.state.id)) { return; }
    if (this.isArcade()) { this.arcade.aim(this.state, x, y); } else if (this.isAdventure()) { this.adventure.aim(this.state, x, y); } else { this.physics.aim(this.state, x, y); }
  }
  releaseNode(): void { if (this.state.id === 'untangle') { this.state.selected = -1; } }
  releaseControls(): void { this.actionGames.release(this.state); this.sports.release(this.state); this.life.release(this.state); }
  step(dt: number): void {
    if (!this.realtime() || this.state.outcome !== 0 || this.state.phase === 0 || !V.finite(dt) || dt <= 0 || dt > 0.02) { return; }
    if (BRAIN_IDS.includes(this.state.id)) { this.brain.step(this.state, dt); } else if (LIFE_IDS.includes(this.state.id)) { this.life.step(this.state, dt);
    } else if (ACTION_IDS.includes(this.state.id)) { this.actionGames.step(this.state, dt); } else if (SPORTS_IDS.includes(this.state.id)) { this.sports.step(this.state, dt);
    } else if (this.isArcade()) { this.arcade.step(this.state, dt); } else if (this.isAdventure()) { this.adventure.step(this.state, dt); } else { this.physics.step(this.state, dt); }
  }
  canUndo(): boolean { return this.history.length > 0 && this.state.outcome === 0; }
  undo(): void { if (this.canUndo()) { this.state = JSON.parse(this.history.pop() ?? '') as ExpansionState; } }
  restore(s: ExpansionState): void { this.state = s; this.history = []; }

  valid(s: ExpansionState): boolean {
    if (s === null || !PLAYABLE_EXPANSION_IDS.includes(s.id) || s.id !== this.state.id || !V.integer(s.level, 0, 2) ||
      !V.integer(s.cols, 1, 15) || !V.integer(s.rows, 1, 15) || !V.integer(s.score, 0, 10000000) ||
      !V.integer(s.moves, 0, 1000000) || !V.integer(s.outcome, 0, 2) || !V.integer(s.selected, -1, s.id === 'mahjong' ? 135 : 120) || !V.integer(s.cursor, 0, 180) ||
      !V.integer(s.errors, 0, 100000) || !V.integer(s.goal, 0, 10000) || !V.integer(s.next, 0, 1000) ||
      !V.integer(s.phase, 0, 1) || !V.integer(s.serial, 1, 1000000) || !V.finite(s.time) || s.time < 0 ||
      !V.finite(s.cooldown) || s.cooldown < (s.id === 'beatjump' ? -0.18 : 0) || s.cooldown > 30 || !Array.isArray(s.board) || s.board.length > 180 ||
      !V.numbers(s.board, s.board.length, 0, 1000) || !Array.isArray(s.tray) || s.tray.length > 180 ||
      !V.numbers(s.tray, s.tray.length, -1, 180) || !Array.isArray(s.target) || s.target.length > 512 ||
      !V.numbers(s.target, s.target.length, 0, CHESS_IDS.includes(s.id) ? 1000002 : s.id === 'untangle' ? 438 : ACTION_IDS.includes(s.id) || s.id === 'linerescue' ? 460 : 180) || !Array.isArray(s.pieces) || s.pieces.length > (s.id === 'spider' ? 104 : 60) ||
      !Array.isArray(s.data) || s.data.length > (s.id === 'linktiles' ? 128 : s.id === 'dots' ? 25 : 20) || !V.numbers(s.data, s.data.length, 0, 1000000) || !Array.isArray(s.piles) || s.piles.length > (s.id === 'freecell' ? 16 : 13) ||
      (s.id !== 'solitaire' && !POKER_IDS.includes(s.id) && !CARD_IDS.includes(s.id) && s.piles.length !== 0)) { return false; }
    for (let i: number = 0; i < s.piles.length; i++) {
      const pile: ExpansionPile = s.piles[i]; if (pile === null || !Array.isArray(pile.cards) || pile.cards.length > 136 || !V.numbers(pile.cards, pile.cards.length, 0, 135)) { return false; }
    }
    const ids: number[] = [];
    for (let i: number = 0; i < s.pieces.length; i++) {
      const p: ExpansionPiece = s.pieces[i];
      if (p === null || !V.integer(p.id, 0, 1000000) || ids.includes(p.id) || !V.integer(p.kind, 0, LIFE_IDS.includes(s.id) ? 61 : BRAIN_IDS.includes(s.id) ? 58 : CARD_IDS.includes(s.id) ? 52 : ACTION_IDS.includes(s.id) || SPORTS_IDS.includes(s.id) ? 44 : 23) ||
        !V.integer(p.color, 0, 9) || !V.integer(p.owner, -1, 10) || typeof p.alive !== 'boolean' ||
        !V.finite(p.x) || !V.finite(p.y) || !V.finite(p.w) || !V.finite(p.h) || !V.finite(p.r) ||
        !V.finite(p.vx) || !V.finite(p.vy) || Math.abs(p.vx) > 1000 || Math.abs(p.vy) > 1000 ||
        !V.finite(p.age) || p.age < 0 || p.age > (s.id === 'grapple' ? 360 : 100)) { return false; } ids.push(p.id);
    }
    if (MATCHING_IDS.includes(s.id)) { return this.matching.valid(s); }
    if (SORTING_IDS.includes(s.id)) { return this.sorting.valid(s); }
    if (ACTION_IDS.includes(s.id)) { return this.actionGames.valid(s); }
    if (SPORTS_IDS.includes(s.id)) { return this.sports.valid(s); }
    if (CHESS_IDS.includes(s.id)) { return this.chess.valid(s); }
    if (POKER_IDS.includes(s.id)) { return this.poker.valid(s); }
    if (CARD_IDS.includes(s.id)) { return this.cards.valid(s); }
    if (BRAIN_IDS.includes(s.id)) { return this.brain.valid(s); }
    if (LIFE_IDS.includes(s.id)) { return this.life.valid(s); }
    if (s.id === 'solitaire') {
      if (s.piles.length !== 13 || s.pieces.length !== 52 || s.board.length !== 0 || s.target.length !== 0 || s.tray.length !== 0 || !V.integer(s.selected, -1, 51)) { return false; }
      const cards: number[] = [];
      for (let i: number = 0; i < 13; i++) {
        const pile: ExpansionPile = s.piles[i];
        if (pile === null || !Array.isArray(pile.cards) || pile.cards.length > 52 || !V.numbers(pile.cards, pile.cards.length, 0, 51)) { return false; }
        cards.push(...pile.cards);
        if (i >= 9 && !pile.cards.every((card: number, pos: number) => Math.floor(card / 13) === i - 9 && card % 13 === pos && s.pieces[card].w === 1)) { return false; }
      }
      return cards.length === 52 && new Set<number>(cards).size === 52 && s.pieces.every((p: ExpansionPiece, i: number) => p.id === i && p.kind === 12 && V.integer(p.w, 0, 1));
    }
    if (s.id === 'characters') { return V.integer(s.cursor, 0, CHARACTER_RECIPES.length - 1) && s.goal === 8 && s.pieces.length === 0 &&
      V.numbers(s.board, 6, 0, CHARACTER_PARTS.length - 1) && new Set<number>(s.board).size === 6 && s.tray.length <= 3 &&
      s.tray.every((v: number) => s.board.includes(v)) && s.target.join(',') === CHARACTER_RECIPES[s.cursor].parts.join(',') && s.errors <= 3; }
    if (['roomdefense', 'basketball', 'rhythm', 'restaurant'].includes(s.id)) {
      if (s.pieces.some((p: ExpansionPiece) => !p.alive || p.id >= s.serial)) { return false; }
      if (s.id === 'roomdefense') { return V.numbers(s.data, 2, 0, 1000000) && s.data[1] <= 100 && s.goal === 12 + s.level * 6 && s.cursor <= s.goal &&
        s.board.length === 0 && s.pieces.length >= 1 && s.pieces[0].kind === 13 && s.pieces.every((p: ExpansionPiece) => p.kind >= 13 && p.kind <= 15 && p.x >= 0 && p.x <= 360 && p.y >= -20 && p.y <= 460); }
      if (s.id === 'basketball') { return V.numbers(s.data, 1, 0, 7) && s.next === 16 && s.moves <= 16 && s.pieces.length >= 1 && s.pieces.length <= 2 &&
        s.pieces[0].kind === 16 && s.pieces.every((p: ExpansionPiece) => p.kind === 16 || p.kind === 17) && s.goal === 5 + s.level && s.board.length === 0; }
      if (s.id === 'rhythm') { return s.goal === 32 + s.level * 8 && V.numbers(s.target, s.goal, 0, 3) && s.cursor <= s.goal && s.errors <= 5 &&
        s.board.length === 0 && s.pieces.every((p: ExpansionPiece) => p.kind === 18 && V.integer(p.owner, 0, 3) && p.y >= -20 && p.y <= 442); }
      return V.numbers(s.data, 1, 0, 1000000) && V.numbers(s.board, 3, 0, 1000) && s.errors <= 5 && s.goal === 10 + s.level * 5 &&
        s.pieces.every((p: ExpansionPiece) => (p.kind === 19 || p.kind === 20) && V.integer(p.color, 0, 2) && p.age > 0 && p.age <= 30);
    }
    if (s.id === 'blockfit') { return s.cols === 6 + s.level && s.rows === s.cols && s.board.length === s.cols * s.rows &&
      V.numbers(s.board, s.board.length, 0, 3) && V.numbers(s.tray, 3, -1, 9) && V.integer(s.selected, -1, 2) &&
      s.goal === 800 + s.level * 400 && s.pieces.length === 0 && s.target.length === 0; }
    if (s.id === 'tilestack') {
      const n: number = 5 * (4 + s.level);
      return s.cols === 5 && s.rows === 4 + s.level && V.numbers(s.board, n * 3, 0, 4 + s.level) &&
        s.tray.length <= 7 && V.numbers(s.tray, s.tray.length, 1, 4 + s.level) && V.numbers(s.target, n * 3, 0, n - 1) && s.pieces.length === 0;
    }
    if (s.id === 'watersort') {
      if (s.cols !== 5 + s.level || s.rows !== 4 || !V.numbers(s.board, s.cols * 4, 0, 3 + s.level) || s.selected >= s.cols ||
        s.pieces.length !== 0 || s.tray.length !== 0 || s.target.length % 2 !== 0 || !V.numbers(s.target, s.target.length, 0, s.cols - 1)) { return false; }
      for (let color: number = 1; color <= 3 + s.level; color++) { if (s.board.filter((v: number) => v === color).length !== 4) { return false; } }
      for (let tube: number = 0; tube < s.cols; tube++) {
        const height: number = this.puzzle.height(s, tube); if (s.board.slice(tube * 4 + height, tube * 4 + 4).some((v: number) => v !== 0)) { return false; }
      } return true;
    }
    if (s.id === 'arrowclear') { return s.cols === 5 + s.level && s.rows === s.cols && V.numbers(s.board, s.cols * s.rows, 0, 4) &&
      V.numbers(s.target, s.cols * s.rows, 0, s.cols * s.rows - 1) && new Set<number>(s.target).size === s.target.length && s.errors <= 3 && s.pieces.length === 0; }
    if (s.id === 'screwout') {
      const expected: ExpansionState = new ExpansionState(); expected.id = s.id; expected.level = s.level; this.puzzle.start(expected);
      if (s.pieces.length !== expected.pieces.length || s.board.length !== 0 || !V.numbers(s.target, (3 + s.level) * 3, 3 + s.level, (3 + s.level) * 4 - 1) || s.tray.length > 3) { return false; }
      for (let i: number = 0; i < s.pieces.length; i++) {
        const p: ExpansionPiece = s.pieces[i]; const e: ExpansionPiece = expected.pieces[i];
        if (p.id !== e.id || p.kind !== e.kind || p.x !== e.x || p.y !== e.y || p.w !== e.w || p.h !== e.h || p.r !== e.r || p.owner !== e.owner) { return false; }
        if (p.kind === 0 && p.alive !== s.pieces.some((q: ExpansionPiece) => q.kind === 1 && q.owner === p.id && q.alive)) { return false; }
      }
      return new Set<number>(s.tray).size === s.tray.length && s.tray.every((id: number) => s.pieces.some((p: ExpansionPiece) => p.id === id && p.kind === 1 && !p.alive));
    }
    if (s.id === 'parkingjam') {
      if (s.cols !== 6 + s.level || s.rows !== s.cols || s.pieces.length < 1 || s.pieces.length > 9 + 4 * s.level || s.board.length !== 0 || s.tray.length !== 0) { return false; }
      const occupied: number[] = [];
      for (let i: number = 0; i < s.pieces.length; i++) {
        const p: ExpansionPiece = s.pieces[i];
        if (p.kind !== 2 || p.color > 3 || !V.integer(p.x, 0, s.cols - p.w) || !V.integer(p.y, 0, s.rows - p.h) ||
          (p.color % 2 === 0 ? p.w !== 1 || !V.integer(p.h, 2, 3) : p.h !== 1 || !V.integer(p.w, 2, 3))) { return false; }
        if (p.alive) { for (let y: number = p.y; y < p.y + p.h; y++) { for (let x: number = p.x; x < p.x + p.w; x++) {
          const cell: number = y * s.cols + x; if (occupied.includes(cell)) { return false; } occupied.push(cell);
        } } }
      } return true;
    }
    if (s.id === 'bubbleshooter') { return s.cols === 8 && s.rows === 15 && s.goal === 90 - 10 * s.level &&
      V.numbers(s.board, 120, 0, 3 + s.level) && V.integer(s.next, 1, 3 + s.level) && s.pieces.length <= 1 && s.tray.length === 0 && s.target.length === 0 &&
      (s.outcome !== 0 || (s.phase === 1) === (s.pieces.length === 1)) &&
      s.pieces.every((p: ExpansionPiece) => p.kind === 3 && p.r === 19 && p.x >= 19 && p.x <= 341 && p.y >= 0 && p.y <= 435 && V.integer(p.color, 1, 3 + s.level)); }
    if (s.id === 'sokoban') {
      if (s.cols !== 7 || s.rows !== 7 || !V.numbers(s.board, 49, 0, 2) || s.cursor >= 49 || s.board[s.cursor] === 1 ||
        s.goal !== (s.level === 0 ? 2 : s.level === 1 ? 3 : 4) || s.pieces.length !== s.goal || !V.numbers(s.target, s.target.length, 0, 3) || s.tray.length !== 0) { return false; }
      const cells: number[] = [];
      for (let i: number = 0; i < s.pieces.length; i++) {
        const p: ExpansionPiece = s.pieces[i]; const cell: number = p.y * 7 + p.x;
        if (p.kind !== 5 || !V.integer(p.x, 1, 5) || !V.integer(p.y, 1, 5) || s.board[cell] === 1 || cell === s.cursor || cells.includes(cell)) { return false; } cells.push(cell);
      } return s.board.filter((v: number) => v === 2).length === s.goal;
    }
    if (s.id === 'pipes') {
      return s.cols === 4 + s.level && s.rows === s.cols && V.numbers(s.board, s.cols * s.rows, 1, 15) &&
        V.numbers(s.target, s.board.length, 1, 15) && s.pieces.length === 0 && s.cursor < s.board.length &&
        V.numbers(s.tray, s.tray.length, 0, s.board.length - 1) && new Set<number>(s.tray).size === s.tray.length;
    }
    if (s.id === 'differences') { return s.cols === 5 && s.rows === 5 && V.numbers(s.board, 25, 1, 6) && s.pieces.length === 0 &&
      V.numbers(s.target, 3 + s.level, 0, 24) && new Set<number>(s.target).size === s.target.length &&
      s.tray.every((i: number) => s.target.includes(i)) && new Set<number>(s.tray).size === s.tray.length && s.errors <= 3; }
    if (['runner', 'blackhole', 'fisheat'].includes(s.id)) {
      const kind: number = s.id === 'runner' ? 6 : s.id === 'blackhole' ? 8 : 10;
      return s.board.length === 0 && s.tray.length === 0 && s.target.length === 0 && s.pieces.length >= 1 && s.pieces[0].kind === kind &&
        s.pieces.every((p: ExpansionPiece, i: number) => p.alive && p.id < s.serial && p.kind === (i === 0 ? kind : kind + 1) &&
          p.r >= 6 && p.r <= 70 && p.x >= -70 && p.x <= 430 && p.y >= -35 && p.y <= 500) && (s.id !== 'runner' || s.cursor <= 2);
    }
    return s.id === 'fruitmerge' && s.goal === 9 && s.board.length === 0 && s.tray.length === 0 && s.target.length === 0 && V.integer(s.next, 0, 2) &&
      s.pieces.every((p: ExpansionPiece) => p.kind === 4 && p.alive && p.id < s.serial && p.r === this.physics.fruitRadius(p.color) &&
        p.x >= p.r - 0.01 && p.x <= 360 - p.r + 0.01 && p.y <= 460 - p.r + 0.01 && p.y >= -100);
  }
}
