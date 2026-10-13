const assert = require('node:assert/strict');
const fs = require('node:fs');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });

// Queue every delivery independently: callers do not share models or synchronous UI state.
class Wire {
  constructor() { this.queue = []; this.host = null; this.guest = null; this.packets = []; }
  flush() {
    let count = 0;
    while (this.queue.length) { assert(++count < 10000); this.queue.shift()(); }
  }
  connection() {
    const wire = this;
    return {
      observer: null, peer: null, open: false,
      setObserver(observer) { this.observer = observer; },
      async startHost() { this.open = true; wire.host = this; return '192.168.1.10'; },
      async join(address) {
        assert.equal(address, '192.168.1.10'); assert(wire.host?.open);
        wire.guest = this; this.open = true; this.peer = wire.host; this.peer.peer = this;
        const host = this.peer;
        wire.queue.push(() => host.open && host.observer.onConnected());
        wire.queue.push(() => this.open && this.observer.onConnected());
      },
      send(message) {
        const target = this.peer;
        wire.packets.push({ sender: this, packet: JSON.parse(message) });
        wire.queue.push(() => target?.open && target.observer.onMessage(message));
      },
      close() {
        const peer = this.peer; this.open = false; this.peer = null;
        if (peer?.open) { peer.peer = null; wire.queue.push(() => peer.open && peer.observer.onDisconnected()); }
      }
    };
  }
}

function player(id, wire, connection) {
  const f = fixture();
  const collection = !['dots', 'tug'].includes(id);
  const module = f.load(`entry/src/main/ets/viewmodel/${collection ? 'Collection' : 'Expansion'}ViewModel.ets`);
  const vm = new module[collection ? 'CollectionViewModel' : 'ExpansionViewModel']();
  vm.init(id); vm.startGame();
  const Adapter = module[collection ? 'CollectionLanAdapter' : 'ExpansionLanAdapter'];
  const { LanGameSession } = f.load('entry/src/main/ets/common/LanGameSession.ets');
  vm.lan = new LanGameSession(new Adapter(vm), connection);
  return { f, vm, lan: vm.lan, connection };
}

async function pair(id, guestId = id, hostDifficulty = 'normal', guestDifficulty = 'normal') {
  const wire = new Wire();
  const host = player(id, wire, wire.connection());
  const guest = player(guestId, wire, wire.connection());
  host.vm.changeDifficulty(hostDifficulty); guest.vm.changeDifficulty(guestDifficulty);
  await host.lan.host(); await guest.lan.join('192.168.1.10'); wire.flush();
  return { wire, host, guest, close() { host.lan.close(); guest.lan.close(); wire.flush(); } };
}

function same(pair) { assert.deepEqual(pair.host.vm.state, pair.guest.vm.state); }
function packetFrom(player, type) {
  const { LanPacket } = player.f.load('entry/src/main/ets/common/LanProtocol.ets');
  const packet = new LanPacket(); packet.game = player.vm.state.id; packet.type = type;
  packet.round = 1; packet.revision = player.lan.revision; return packet;
}

test('IPv4 and packet validation reject remote endpoints, missing fields and excessive data', () => {
  const f = fixture(); const { LanProtocol, LanPacket } = f.load('entry/src/main/ets/common/LanProtocol.ets');
  for (const ip of ['10.0.0.1', '172.16.0.1', '172.31.255.254', '192.168.1.10']) assert(LanProtocol.address(ip));
  for (const ip of ['8.8.8.8', '127.0.0.1', '0.0.0.0', '172.32.0.1', '192.168.1.256',
    '192.168.01.1', '192.168.1', 'example.com', '192.168.1.1:41237', '192.168.1.-1']) assert(!LanProtocol.address(ip), ip);
  for (const data of ['null', '[]', '{}', 'true', '{bad', 'x'.repeat(131073)]) assert.equal(LanProtocol.decode(data), null);
  const packet = new LanPacket(); packet.game = 'tictactoe'; packet.type = 'hello';
  assert(LanProtocol.decode(JSON.stringify(packet)));
  for (const mutation of [{version:2}, {game:'chess'}, {sequence:0.5}, {round:-1}, {index:1001},
    {payload:'x'.repeat(65537)}, {hostReady:1}, {type:'arbitrary'}, {action:2}]) {
    assert.equal(LanProtocol.decode(JSON.stringify({...packet, ...mutation})), null);
  }
});

for (const id of ['tictactoe', 'gomoku', 'reversi', 'fourline', 'nim', 'dots', 'tug']) {
  test(`${id}: connect, synchronize difficulty, enforce own controls, close and return to local play`, async () => {
    const p = await pair(id); const { host, guest, wire } = p;
    assert.equal(host.lan.status, 'connected'); assert.equal(guest.lan.status, 'connected');
    assert.equal(host.lan.localPlayer, 1); assert.equal(guest.lan.localPlayer, 2); same(p);
    const before = JSON.stringify(host.vm.state);
    if (id === 'tug') { host.vm.tap(1); guest.vm.tap(0); }
    else { guest.vm.tap(0); guest.vm.choose(0); }
    wire.flush(); assert.equal(JSON.stringify(host.vm.state), before); same(p);
    let index = 0;
    if (id === 'reversi') index = host.vm.state.board.findIndex((_, i) => host.vm.legal(i));
    if (id === 'nim') host.vm.choose(index); else host.vm.tap(index);
    wire.flush(); assert.notEqual(JSON.stringify(host.vm.state), before); same(p);
    const changed = JSON.stringify(host.vm.state);
    // Offline-only actions and difficulty changes cannot mutate a live room.
    host.vm.changeDifficulty('hard'); guest.vm.changeDifficulty('easy'); host.vm.action(); guest.vm.action();
    if (!['dots', 'tug'].includes(id)) host.vm.move(0);
    else { host.vm.undo(); guest.vm.activate(); host.vm.aim(1, 1); }
    wire.flush(); assert.equal(JSON.stringify(host.vm.state), changed); same(p);
    assert.throws(() => host.vm.exportContinuation());
    host.lan.leave(); wire.flush(); assert.equal(guest.lan.status, 'disconnected');
    const frozen = JSON.stringify(guest.vm.state); guest.vm.tap(0); guest.vm.choose(0);
    assert.equal(JSON.stringify(guest.vm.state), frozen); assert.equal(guest.vm.isPlayTimeActive(), false);
    guest.lan.leave(); assert.equal(guest.lan.status, 'local');
    assert.equal(host.f.clock.count(), 0); assert.equal(guest.f.clock.count(), 0); p.close();
  });
}

test('tic-tac-toe: complete result agrees, repeat packets do not apply twice, rematch needs both players', async () => {
  const p = await pair('tictactoe'); const { wire, host, guest } = p;
  for (const index of [0,3,1,4,2]) { (host.vm.state.player === 1 ? host.vm : guest.vm).tap(index); wire.flush(); same(p); }
  assert.equal(host.vm.state.outcome, 1); const finished = JSON.stringify(host.vm.state);
  host.vm.tap(8); guest.vm.tap(7); wire.flush(); assert.equal(JSON.stringify(host.vm.state), finished);
  guest.vm.startGame(); wire.flush(); assert.equal(JSON.stringify(host.vm.state), finished);
  assert.equal(host.lan.peerWantsRestart, true); assert.equal(guest.lan.wantsRestart, true);
  host.vm.startGame(); wire.flush(); same(p); assert.equal(host.vm.state.outcome, 0);
  assert.equal(host.vm.state.moves, 0); assert.equal(host.lan.wantsRestart, false);
  assert.equal(guest.lan.wantsRestart, false); host.vm.tap(0); wire.flush();
  guest.vm.tap(3); wire.flush(); const moved = JSON.stringify(host.vm.state);
  const last = wire.packets.filter(item => item.packet.type === 'input').at(-1).packet;
  host.lan.onMessage(JSON.stringify(last)); wire.flush(); assert.equal(JSON.stringify(host.vm.state), moved);
  p.close();
});

test('an old-round intent already in flight is acknowledged and does not break the next sequence', async () => {
  const p = await pair('tictactoe'); p.host.vm.tap(0); p.wire.flush();
  // The host processes the restart before this queued guest move, while the guest
  // has not yet received either the consent flags or the new-round snapshot.
  p.host.lan.requestRestart(); p.guest.lan.requestRestart(); p.guest.vm.tap(3);
  p.wire.flush(); same(p); assert.equal(p.host.vm.state.moves, 0);
  assert.equal(p.guest.lan.status, 'connected'); assert.equal(p.guest.lan.pending, false);
  p.host.vm.tap(0); p.wire.flush(); p.guest.vm.tap(3); p.wire.flush();
  same(p); assert.equal(p.host.vm.state.moves, 2); assert.equal(p.guest.lan.status, 'connected'); p.close();
});

test('guest waits for acknowledgment; illegal moves acknowledge without changing the authoritative board', async () => {
  const p = await pair('tictactoe'); p.host.vm.tap(0); p.wire.flush();
  p.guest.vm.tap(0); assert.equal(p.guest.lan.pending, true);
  p.guest.vm.tap(3); p.wire.flush(); assert.equal(p.host.vm.state.moves, 1);
  assert.equal(p.guest.lan.pending, false); same(p);
  p.guest.vm.tap(3); p.wire.flush(); assert.equal(p.host.vm.state.moves, 2); same(p); p.close();
});

test('dots: completing a box keeps the same player across devices', async () => {
  const p = await pair('dots');
  const n = p.host.vm.state.cols, vertical = n * (n + 1);
  for (const edge of [0, n, vertical, vertical+1]) {
    (p.host.vm.state.cursor === 0 ? p.host.vm : p.guest.vm).tap(edge); p.wire.flush(); same(p);
  }
  assert.equal(p.host.vm.state.data[0], 2); assert.equal(p.host.vm.state.cursor, 1);
  p.guest.vm.tap(1); p.wire.flush(); same(p); assert.equal(p.host.vm.state.moves, 5); p.close();
});

test('tug: simultaneous taps keep both inputs despite stale revisions and reject impersonation', async () => {
  const p = await pair('tug');
  for (let i=0; i<4; i++) { p.guest.vm.tap(1); p.host.vm.tap(0); }
  p.wire.flush(); same(p); assert.equal(p.host.vm.state.moves, 8); assert.equal(p.host.vm.state.data[0], 50);
  const spoof = packetFrom(p.guest, 'input'); spoof.sequence = 5; spoof.action = 'tap'; spoof.index = 0;
  p.host.lan.onMessage(JSON.stringify(spoof)); p.wire.flush(); assert.equal(p.host.vm.state.moves, 8); p.close();
});

test('different games reject handshake; malformed snapshots and client-authored state freeze the room', async () => {
  const mismatch = await pair('gomoku', 'tictactoe');
  assert.equal(mismatch.host.lan.error, 'mismatch'); assert.equal(mismatch.guest.lan.error, 'mismatch'); mismatch.close();
  const bad = await pair('tictactoe'); const packet = packetFrom(bad.host, 'state'); packet.payload = '{}';
  bad.guest.lan.onMessage(JSON.stringify(packet)); assert.equal(bad.guest.lan.error, 'protocol'); bad.close();
  const spoof = await pair('nim'); const state = packetFrom(spoof.guest, 'state');
  state.payload = '{}'; spoof.host.lan.onMessage(JSON.stringify(state));
  assert.equal(spoof.host.lan.error, 'protocol'); spoof.close();
});

test('consent crossing in opposite directions survives an older ready packet', async () => {
  const p = await pair('tictactoe');
  p.host.lan.requestRestart(); p.guest.lan.requestRestart(); p.wire.flush();
  same(p); assert.equal(p.host.lan.status, 'connected'); assert.equal(p.guest.lan.status, 'connected');
  assert.equal(p.guest.lan.wantsRestart, false); p.close();
});

test('heartbeat, backgrounding and page teardown release timers and freeze inputs', async () => {
  for (const action of ['timeout', 'background', 'close']) {
    const p = await pair('tug'); const before = JSON.stringify(p.host.vm.state);
    if (action === 'timeout') p.host.f.clock.advance(12000);
    if (action === 'background') {
      const bus = p.host.f.load('entry/src/main/ets/common/GameLifecycleBus.ets').GameLifecycleBus;
      bus.attach(p.host.vm); bus.notifyHidden();
    }
    if (action === 'close') p.host.vm.lan.close();
    p.wire.flush(); p.host.vm.tap(0); p.guest.vm.tap(1); p.wire.flush();
    assert.equal(JSON.stringify(p.host.vm.state), before); assert.equal(p.host.f.clock.count(), 0);
    assert.equal(p.guest.f.clock.count(), 0); p.close();
  }
});

test('host difficulty replaces guest preference and own exit confirmation survives remote moves', async () => {
  for (const id of ['nim', 'dots']) {
    const p = await pair(id, id, 'hard', 'easy');
    same(p); assert.equal(p.guest.vm.difficulty, 'hard'); assert.equal(p.guest.vm.state.level, 2);
    p.guest.vm.requestBack(); assert.equal(p.guest.vm.confirmExit, true);
    if (id === 'nim') p.host.vm.choose(0); else p.host.vm.tap(0);
    p.wire.flush(); same(p); assert.equal(p.guest.vm.confirmExit, true);
    assert.equal(p.host.lan.status, 'connected'); assert.equal(p.guest.lan.status, 'connected'); p.close();
  }
});

test('temporary foreground page/settings hide preserves a live room', async () => {
  const p = await pair('tug'); p.host.vm.onAppHidden();
  assert.equal(p.host.lan.status, 'connected'); p.host.vm.onAppShown();
  p.host.vm.tap(0); p.wire.flush(); same(p); assert.equal(p.host.vm.state.moves, 1); p.close();
});

test('remote consent cannot dismiss either player\'s own exit confirmation', async () => {
  for (const id of ['tictactoe', 'tug']) {
    const p = await pair(id); p.host.vm.tap(0); p.wire.flush();
    p.host.vm.startGame(); p.host.vm.requestBack(); p.guest.vm.requestBack();
    assert.equal(p.host.vm.confirmExit, true); assert.equal(p.guest.vm.confirmExit, true);
    p.guest.vm.startGame(); p.wire.flush(); same(p);
    assert.equal(p.host.vm.state.moves, 0); assert.equal(p.host.vm.confirmExit, true); assert.equal(p.guest.vm.confirmExit, true);
    p.host.lan.leave(); assert.equal(p.host.vm.confirmExit, false); p.close();
  }
});

test('both devices record a result once despite duplicate terminal snapshots', async () => {
  const p = await pair('tictactoe');
  for (const index of [0,3,1,4,2]) { (p.host.vm.state.player === 1 ? p.host.vm : p.guest.vm).tap(index); p.wire.flush(); }
  const score = player => player.f.data().getGameById('tictactoe').highScore;
  assert.equal(score(p.host), 1); assert.equal(score(p.guest), 1);
  const final = p.wire.packets.filter(item => item.packet.type === 'state').at(-1).packet;
  p.guest.lan.onMessage(JSON.stringify(final)); assert.equal(score(p.guest), 1); p.close();
});

test('handshake timeout and canceled join cannot resurrect an abandoned room', async () => {
  const wire = new Wire(); const host = player('tictactoe', wire, wire.connection());
  await host.lan.host(); host.lan.onConnected(); host.f.clock.advance(10000);
  assert.equal(host.lan.status, 'error'); assert.equal(host.f.clock.count(), 0);
  host.lan.leave(); host.lan.onConnected(); assert.equal(host.lan.status, 'local');
  const connection = wire.connection(); let complete;
  connection.startHost = () => new Promise(resolve => { complete = resolve; });
  const late = player('nim', wire, connection); const pending = late.lan.host(); late.lan.leave();
  complete('192.168.1.10'); await pending; assert.equal(late.lan.status, 'local'); assert.equal(late.lan.address, '');
});

test('LAN resources cover all languages and required network permissions are declared', () => {
  const panel = fs.readFileSync('entry/src/main/ets/components/LanRoomPanel.ets', 'utf8');
  const names = [...new Set([...panel.matchAll(/app\.string\.(lan_[a-z_]+)/g)].map(match => match[1]))];
  assert(names.length > 10);
  for (const locale of ['base', 'en_US', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`)).string;
    assert.equal(strings.length, new Set(strings.map(item => item.name)).size);
    for (const name of [...names, 'lan_replay_wait']) assert(strings.some(item => item.name === name && item.value), `${locale}:${name}`);
  }
  const manifest = fs.readFileSync('entry/src/main/module.json5', 'utf8');
  for (const permission of ['INTERNET', 'GET_NETWORK_INFO']) assert(manifest.includes(`ohos.permission.${permission}`));
});

(async () => {
  let failed = 0;
  for (const entry of tests) {
    try { await entry.run(); }
    catch (error) { failed++; console.error(`FAIL ${entry.name}\n${error.stack}`); }
  }
  console.log(`${tests.length - failed}/${tests.length} LAN multiplayer regressions passed.`);
  process.exitCode = failed ? 1 : 0;
})();
