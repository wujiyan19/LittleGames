// Independent FreeCell search over cards read from rendered face-up UI.
// Outputs normal card-to-pile moves; it has no device or application access.
const fs = require('node:fs');
const input = JSON.parse(fs.readFileSync(process.argv[2]));
const rank = c => c % 13, suit = c => Math.floor(c / 13), red = c => suit(c) === 1 || suit(c) === 2;
const key = s => s.home.join(',') + '|' + s.piles.slice(0, 8).map(p => p.join(',')).sort().join('|') + '|' + s.piles.slice(8, 12).flat().sort((a, b) => a - b).join(',');
const clone = s => ({ piles: s.piles.map(p => p.slice()), home: s.home.slice() });
function normalize(s) {
  const moves = []; let changed;
  do {
    changed = false;
    for (let i = 0; i < 12; i++) if (s.piles[i].length) {
      const card = s.piles[i].at(-1), r = rank(card), color = suit(card);
      const safe = r <= 1 || [0, 1, 2, 3].filter(k => (k === 1 || k === 2) !== red(card)).every(k => s.home[k] >= r);
      if (r === s.home[color] && safe) { s.piles[i].pop(); s.home[color]++; moves.push({ from: i, card, to: 12 + color }); changed = true; }
    }
  } while (changed); return moves;
}
function weight(s, depth) {
  let blocked = 0;
  for (const pile of s.piles.slice(0, 8)) for (let i = 0; i < pile.length; i++) blocked += (pile.length - i - 1) / (rank(pile[i]) + 1);
  const remaining = 52 - s.home.reduce((a, b) => a + b, 0), empty = s.piles.slice(0, 8).filter(p => !p.length).length;
  return remaining * 8 + blocked * 2 - empty * 3 + depth * .12;
}
const states = [], heap = [], seen = new Set();
function push(node) {
  node.score = weight(node.s, node.depth); const index = states.push(node) - 1; heap.push(index); let pos = heap.length - 1;
  while (pos) { const p = (pos - 1) >> 1; if (states[heap[p]].score <= node.score) break; heap[pos] = heap[p]; pos = p; } heap[pos] = index;
}
function pop() {
  const head = heap[0], tail = heap.pop(); if (heap.length) { let pos = 0; while (pos * 2 + 1 < heap.length) { let j = pos * 2 + 1; if (j + 1 < heap.length && states[heap[j + 1]].score < states[heap[j]].score) j++; if (states[tail].score <= states[heap[j]].score) break; heap[pos] = heap[j]; pos = j; } heap[pos] = tail; } return head;
}
const initial = clone(input), first = normalize(initial); push({ s: initial, parent: -1, moves: first, depth: 0 }); seen.add(key(initial));
let goal = -1;
while (heap.length && states.length < 400000) {
  const parent = pop(), node = states[parent], s = node.s;
  if (s.home.every(v => v === 13)) { goal = parent; break; }
  const free = s.piles.slice(8, 12).filter(p => !p.length).length, emptyColumns = s.piles.slice(0, 8).filter(p => !p.length).length;
  const moves = [];
  for (let from = 0; from < 12; from++) {
    const pile = s.piles[from]; if (!pile.length) continue; const top = pile.at(-1);
    if (rank(top) === s.home[suit(top)]) moves.push({ from, card: top, to: 12 + suit(top), count: 1 });
    let run = 1; if (from < 8) while (run < pile.length && rank(pile[pile.length - run - 1]) === rank(pile[pile.length - run]) + 1 && red(pile[pile.length - run - 1]) !== red(pile[pile.length - run])) run++;
    let emptyUsed = false;
    for (let to = 0; to < 8; to++) if (to !== from) {
      const dest = s.piles[to]; if (!dest.length) { if (emptyUsed) continue; emptyUsed = true; }
      for (let count = 1; count <= run; count++) {
        const card = pile[pile.length - count], capacity = (free + 1) * 2 ** (emptyColumns - +!dest.length);
        if (count > capacity || !dest.length && count === pile.length && from < 8 || dest.length && (rank(dest.at(-1)) !== rank(card) + 1 || red(dest.at(-1)) === red(card))) continue;
        moves.push({ from, card, to, count });
      }
    }
    if (from < 8 && free) moves.push({ from, card: top, to: s.piles.findIndex((p, i) => i >= 8 && !p.length), count: 1 });
  }
  for (const move of moves) {
    const next = clone(s); if (move.to >= 12) { next.piles[move.from].pop(); next.home[move.to - 12]++; }
    else next.piles[move.to].push(...next.piles[move.from].splice(-move.count));
    const steps = [move, ...normalize(next)], hash = key(next); if (seen.has(hash)) continue; seen.add(hash);
    push({ s: next, parent, moves: steps, depth: node.depth + 1 });
  }
}
if (goal < 0) throw Error('FreeCell search did not solve actual deal within ' + states.length + ' states');
const route = []; for (let i = goal; i >= 0; i = states[i].parent) route.unshift(states[i].moves);
process.stdout.write(JSON.stringify({ explored: states.length, moves: route.flat() }));
