// Plan only from cards already observed through normal phone UI.
const fs = require('node:fs');
const initial = JSON.parse(fs.readFileSync(process.argv[2]));
const rank = c => c % 13, suit = c => Math.floor(c / 13), red = c => suit(c) === 1 || suit(c) === 2;
const clone = s => ({ stock: s.stock.slice(), waste: s.waste.slice(), piles: s.piles.map(p => p.slice()), home: s.home.slice() });
const key = s => s.stock.join(',') + '/' + s.waste.join(',') + '/' + s.home.join(',') + '/' + s.piles.map(p => p.join(',')).sort().join('|');
const hidden = s => s.piles.reduce((n, p) => n + p.filter(c => c < 0).length, 0);
const firstHidden = hidden(initial);
const states = [], heap = [], seen = new Set();
function push(s, parent, move, depth, reveal, unsafePromotions = 0) {
  const hash = key(s); if (seen.has(hash)) return; seen.add(hash);
  let disorder = 0;
  for (const pile of s.piles) for (let i = 1; i < pile.length; i++) if (pile[i] >= 0 && pile[i - 1] >= 0 && (rank(pile[i - 1]) !== rank(pile[i]) + 1 || red(pile[i - 1]) === red(pile[i]))) disorder++;
  const score = (52 - s.home.reduce((a, b) => a + b, 0)) * 4 + disorder * 2 + depth * .2 - s.piles.filter(p => !p.length).length * 3 + unsafePromotions * 20;
  const index = states.push({ s, parent, move, depth, reveal, score, unsafePromotions }) - 1;
  heap.push(index); let pos = heap.length - 1;
  while (pos) { const p = (pos - 1) >> 1; if (states[heap[p]].score <= score) break; heap[pos] = heap[p]; pos = p; } heap[pos] = index;
}
function pop() {
  const head = heap[0], tail = heap.pop();
  if (heap.length) { let pos = 0; while (pos * 2 + 1 < heap.length) { let j = pos * 2 + 1; if (j + 1 < heap.length && states[heap[j + 1]].score < states[heap[j]].score) j++; if (states[tail].score <= states[heap[j]].score) break; heap[pos] = heap[j]; pos = j; } heap[pos] = tail; }
  return head;
}
push(clone(initial), -1, null, 0, false); let goal = -1;
while (heap.length && states.length < 300000) {
  const parent = pop(), node = states[parent], s = node.s;
  if (node.reveal || s.home.every(n => n === 13)) { goal = parent; break; }
  const sources = [];
  for (let from = 0; from < 7; from++) {
    const p = s.piles[from];
    for (let pos = p.length - 1; pos >= 0 && p[pos] >= 0; pos--) {
      if (pos < p.length - 1 && (rank(p[pos]) !== rank(p[pos + 1]) + 1 || red(p[pos]) === red(p[pos + 1]))) break;
      sources.push({ from, pos, card: p[pos], count: p.length - pos });
    }
  }
  if (s.waste.length) sources.push({ from: 7, pos: s.waste.length - 1, card: s.waste.at(-1), count: 1 });
  const moves = [];
  for (const src of sources) {
    if (src.count === 1 && rank(src.card) === s.home[suit(src.card)]) moves.push({ ...src, to: 8 + suit(src.card) });
    let emptyUsed = false;
    for (let to = 0; to < 7; to++) if (to !== src.from) {
      const dest = s.piles[to], top = dest.at(-1);
      if (top === undefined) { if (emptyUsed || rank(src.card) !== 12 || src.from < 7 && src.pos === 0) continue; emptyUsed = true; }
      else if (top < 0 || rank(top) !== rank(src.card) + 1 || red(top) === red(src.card)) continue;
      moves.push({ ...src, to });
    }
  }
  for (const move of moves) {
    const next = clone(s), source = move.from === 7 ? next.waste : next.piles[move.from], moving = source.splice(move.pos);
    if (move.to >= 8) next.home[move.to - 8]++; else next.piles[move.to].push(...moving);
    const reveal = move.from < 7 && source.length > 0 && source.at(-1) < 0;
    // Until hidden cards are exposed, prefer keeping a card available to build
    // on when the opposite-color lower ranks are still outside foundations.
    const opposite = red(move.card) ? [0, 3] : [1, 2];
    const unsafe = move.to >= 8 && firstHidden > 0 && opposite.some(index => s.home[index] < rank(move.card));
    push(next, parent, move, node.depth + 1, reveal, node.unsafePromotions + (unsafe ? 1 : 0));
  }
  if (s.stock.length || s.waste.length) {
    const next = clone(s);
    if (next.stock.length) next.waste.push(next.stock.pop());
    else { next.stock = next.waste.reverse(); next.waste = []; }
    push(next, parent, { draw: true }, node.depth + 1, false, node.unsafePromotions);
  }
}
const route = [];
if (goal >= 0) for (let i = goal; states[i].parent >= 0; i = states[i].parent) route.unshift(states[i].move);
process.stdout.write(JSON.stringify({ solved: goal >= 0, reveal: goal >= 0 && states[goal].reveal, explored: states.length, hidden: firstHidden, moves: route, final: goal >= 0 ? states[goal].s : null }));
