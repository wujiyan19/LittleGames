/* Native socket and timer boundaries are controlled; no network permission or device is needed. */
const assert = require('node:assert/strict');
const { fixture } = require('./test-performance.cjs');
const tests = [];
const test = (name, run) => tests.push({ name, run });
const drain = async () => { for (let i = 0; i < 24; i++) { await Promise.resolve(); } };
const bytes = text => Uint8Array.from(Buffer.from(text, 'utf8')).buffer;

function setup(options = {}) {
  const f = fixture();
  const sockets = [];
  const servers = [];
  const pending = [];
  const events = [];
  class NativeSocket {
    constructor() { this.listeners = new Map(); this.sent = []; this.closed = 0; this.bound = null; }
    on(event, callback) { this.listeners.set(event, callback); }
    off(event) { this.listeners.delete(event); }
    emit(event, value) { this.listeners.get(event)?.(value); }
    bind(address) { this.bound = address; return Promise.resolve(); }
    connect(address) {
      this.target = address;
      return new Promise((resolve, reject) => { this.connection = { resolve, reject }; });
    }
    send(data) {
      this.sent.push(Buffer.from(data.data).toString('utf8'));
      return new Promise((resolve, reject) => pending.push({ resolve, reject }));
    }
    listen(address) { this.bound = address; return Promise.resolve(); }
    close() { this.closed++; this.emit('close'); return Promise.resolve(); }
  }
  f.native['@kit.NetworkKit'] = {
    socket: {
      constructTCPSocketInstance() { const value = new NativeSocket(); sockets.push(value); return value; },
      constructTCPSocketServerInstance() { const value = new NativeSocket(); servers.push(value); return value; }
    },
    connection: {
      NetBearType: { BEARER_WIFI: 1, BEARER_ETHERNET: 3 },
      async getAllNets() { if (options.networkError) { throw options.networkError; } return [{ netId: 1 }, { netId: 2 }]; },
      async getNetCapabilities(net) { return { bearerTypes: [net.netId === 1 ? 0 : 1] }; },
      async getConnectionProperties(net) {
        assert.equal(net.netId, 2, 'must exclude cellular interfaces');
        return { linkAddresses: [{ address: { address: 'fe80::1' } },
          { address: { address: options.localAddress || '192.168.1.8' } }] };
      }
    }
  };
  f.native['@kit.ArkTS'].util = {
    TextEncoder: class { encodeInto(text) { return new TextEncoder().encode(text); } },
    TextDecoder: { create(encoding, config) {
      const decoder = new TextDecoder(encoding, config);
      return { decodeToString(data) { return decoder.decode(data); } };
    } }
  };
  const { LanTransport } = f.load('entry/src/main/ets/common/LanTransport.ets');
  const { LanFrameBuffer, LAN_MAX_FRAME_BYTES, LanAddress } = f.load('entry/src/main/ets/common/LanFraming.ets');
  const transport = new LanTransport();
  transport.setObserver({ onConnected() { events.push('connected'); }, onDisconnected() { events.push('disconnected'); },
    onMessage(value) { events.push(value); }, onError(value) { events.push('error:' + value); } });
  return { f, transport, sockets, servers, pending, events, NativeSocket, LanFrameBuffer, LAN_MAX_FRAME_BYTES, LanAddress };
}

async function joinReady(fixture) {
  const joining = fixture.transport.join('192.168.1.8');
  await drain();
  const native = fixture.sockets.at(-1);
  native.connection.resolve();
  await joining;
  return native;
}

test('framing preserves Unicode over every possible byte split and multiple combined frames', () => {
  const f = setup();
  const input = Buffer.from('{"name":"棋手😀"}\n{"turn":2}\n', 'utf8');
  for (let split = 0; split <= input.length; split++) {
    const framing = new f.LanFrameBuffer();
    const first = framing.push(Uint8Array.from(input.subarray(0, split)).buffer);
    const second = framing.push(Uint8Array.from(input.subarray(split)).buffer);
    assert.deepEqual([...first, ...second].map(value => Buffer.from(value).toString('utf8')),
      ['{"name":"棋手😀"}', '{"turn":2}']);
  }
});

test('framing accepts the 128 KB boundary, rejects an unterminated oversized frame, and can clear partial input', () => {
  const f = setup(); const framing = new f.LanFrameBuffer();
  assert.equal(framing.push(bytes('x'.repeat(f.LAN_MAX_FRAME_BYTES) + '\n'))[0].length, f.LAN_MAX_FRAME_BYTES);
  assert.throws(() => framing.push(bytes('x'.repeat(f.LAN_MAX_FRAME_BYTES + 1))), /byte limit/);
  framing.push(bytes('partial')); framing.clear();
  assert.equal(Buffer.from(framing.push(bytes('new\n'))[0]).toString(), 'new');
});

test('IPv4 validation rejects URLs, ports, loopback, multicast, octal ambiguity and invalid octets', () => {
  const f = setup();
  for (const address of ['192.168.1.8', '10.0.0.1', '169.254.1.2', '172.16.0.1']) { assert(f.LanAddress.isIPv4(address)); }
  for (const address of ['192.168.1.256', '1.2.3', '1..2.3', 'http://1.2.3.4', '192.168.1.8:41237',
    '127.0.0.1', '224.0.0.1', '0.0.0.0', '192.168.01.8']) { assert.equal(f.LanAddress.isIPv4(address), false); }
});

test('construction is lazy and host binds a LAN interface; second guest is rejected', async () => {
  const f = setup(); assert.equal(f.sockets.length + f.servers.length, 0);
  assert.equal(await f.transport.startHost(), '192.168.1.8');
  assert.deepEqual(f.servers[0].bound, { address: '192.168.1.8', family: 1, port: 41237 });
  const first = new f.NativeSocket(); const second = new f.NativeSocket();
  f.servers[0].emit('connect', first); f.servers[0].emit('connect', second);
  await drain(); assert.equal(second.closed, 1); assert.equal(first.closed, 0);
  assert.deepEqual(f.events, ['connected']);
  f.transport.close(); await drain(); assert.equal(first.closed, 1); assert.equal(f.servers[0].closed, 1);
  assert.equal(first.listeners.size + f.servers[0].listeners.size, 0);
  assert.deepEqual(f.events, ['connected'], 'intentional close does not emit a disconnect');
});

test('client uses native bind/connect and receives split/coalesced UTF-8 frames', async () => {
  const f = setup(); const native = await joinReady(f);
  assert.deepEqual(native.bound, { address: '0.0.0.0', family: 1, port: 0 });
  assert.equal(native.target.address.port, 41237); assert.equal(native.target.timeout, 8000);
  const frame = Buffer.from('{"name":"棋手😀"}\n{"turn":2}\n', 'utf8');
  for (const value of frame) { native.emit('message', { message: Uint8Array.of(value).buffer }); }
  assert.deepEqual(f.events, ['connected', '{"name":"棋手😀"}', '{"turn":2}']);
  assert.equal(f.f.clock.count(), 0);
});

test('send waits for each native completion and uses newline framing in order', async () => {
  const f = setup(); const native = await joinReady(f);
  f.transport.send('{"turn":1}'); f.transport.send('{"turn":2}'); f.transport.send('{"turn":3}');
  assert.deepEqual(native.sent, ['{"turn":1}\n']);
  f.pending[0].resolve(); await drain(); assert.deepEqual(native.sent, ['{"turn":1}\n', '{"turn":2}\n']);
  f.pending[1].resolve(); await drain(); f.pending[2].resolve(); await drain();
  assert.deepEqual(native.sent, ['{"turn":1}\n', '{"turn":2}\n', '{"turn":3}\n']);
});

test('disconnect removes listeners, queued work and prevents stale callbacks from reaching a new room', async () => {
  const f = setup(); const first = await joinReady(f);
  const staleMessage = first.listeners.get('message'); const staleClose = first.listeners.get('close');
  f.transport.send('{"old":1}'); f.transport.send('{"old":2}'); first.emit('close');
  await drain(); assert.deepEqual(f.events, ['connected', 'disconnected']);
  const second = await joinReady(f);
  staleMessage({ message: bytes('stale\n') }); staleClose(); f.pending[0].resolve(); await drain();
  assert.deepEqual(f.events, ['connected', 'disconnected', 'connected']);
  assert.deepEqual(first.sent, ['{"old":1}\n']); assert.deepEqual(second.sent, []);
});

test('connect timeout rejects once, closes native handles and ignores late native completion', async () => {
  const f = setup(); const joining = f.transport.join('192.168.1.8');
  const rejected = assert.rejects(joining, /timeout/); await drain(); const native = f.sockets[0];
  f.f.clock.advance(8000); await rejected; await drain();
  assert.deepEqual(f.events, ['error:timeout']); assert.equal(native.closed, 1); assert.equal(f.f.clock.count(), 0);
  native.connection.resolve(); await drain(); assert.deepEqual(f.events, ['error:timeout']);
});

test('closing a connecting room rejects its pending operation immediately', async () => {
  const f = setup(); const joining = f.transport.join('192.168.1.8');
  const rejected = assert.rejects(joining, /cancelled/); await drain(); f.transport.close();
  await rejected; await drain(); assert.equal(f.f.clock.count(), 0); assert.deepEqual(f.events, []);
  assert.equal(f.sockets[0].closed, 1);
});

test('malformed UTF-8 and oversized incoming data terminate the room with a frame error', async () => {
  for (const input of [Uint8Array.of(0xc3, 0x0a).buffer, bytes('x'.repeat(131073))]) {
    const f = setup(); const native = await joinReady(f); native.emit('message', { message: input }); await drain();
    assert.deepEqual(f.events, ['connected', 'error:frame']); assert.equal(native.closed, 1);
  }
});

test('native failures and bounded outgoing backlog clean up once', async () => {
  const denied = setup({ networkError: { code: 201 } });
  await assert.rejects(denied.transport.startHost()); assert.deepEqual(denied.events, ['error:permission']);
  const invalid = setup(); await assert.rejects(invalid.transport.join('1.2.3.999'));
  assert.deepEqual(invalid.events, ['error:address']); assert.equal(invalid.sockets.length, 0);
  const backlog = setup(); const native = await joinReady(backlog);
  for (let i = 0; i < 8; i++) { backlog.transport.send('x'.repeat(131072)); }
  await drain(); assert.deepEqual(backlog.events, ['connected', 'error:send']); assert.equal(native.closed, 1);
});

test('host skips public interface addresses and reports no_address without opening a listener', async () => {
  const f = setup({ localAddress: '8.8.8.8' });
  await assert.rejects(f.transport.startHost(), /No local IPv4/);
  assert.deepEqual(f.events, ['error:no_address']); assert.equal(f.servers.length, 0);
  const joining = setup(); await assert.rejects(joining.transport.join('8.8.8.8'));
  assert.deepEqual(joining.events, ['error:address']); assert.equal(joining.sockets.length, 0);
});

(async () => {
  let failures = 0;
  for (const test of tests) {
    try { await test.run(); console.log('PASS ' + test.name); }
    catch (error) { failures++; console.error('FAIL ' + test.name, error); }
  }
  console.log(`${tests.length - failures}/${tests.length} LAN transport tests passed`);
  process.exitCode = failures ? 1 : 0;
})();
