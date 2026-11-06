'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const Module = require('node:module');
const originalLoad = Module._load;
let instance;
class FakeSocket extends EventEmitter {
  static OPEN = 1;
  readyState = 1;
  sent = [];
  send(raw) { this.sent.push(JSON.parse(raw)); }
  emitMessage(value) { this.emit('message', Buffer.from(JSON.stringify(value))); }
  last(type) { return [...this.sent].reverse().find(m => m.type === type); }
  ping() { this.emit('pong'); }
}
class FakeWSS extends EventEmitter {
  constructor() { super(); this.clients = new Set(); instance = this; }
  connect() { const s = new FakeSocket(); this.clients.add(s); this.emit('connection', s); return s; }
}
Module._load = function(request, parent, isMain) {
  if (request === 'ws') return { WebSocketServer: FakeWSS, WebSocket: FakeSocket };
  return originalLoad.call(this, request, parent, isMain);
};
const relay = require('../index.js');
Module._load = originalLoad;
test('room, ready checks, secret role, input validation, and reconnect', async () => {
  try {
    const host = instance.connect();
    host.emitMessage({type:'create_room'});
    const code = host.last('room_created').code;
    assert.match(code, /^[A-F0-9]{6}$/);
    const p1 = instance.connect(), p2 = instance.connect();
    p1.emitMessage({type:'join_room',code}); p2.emitMessage({type:'join_room',code});
    assert.equal(host.last('players').players.length, 2);
    host.emitMessage({type:'start_game'});
    assert.match(host.last('error').message, /ready/);
    p1.emitMessage({type:'ready',ready:true}); p2.emitMessage({type:'ready',ready:true});
    host.emitMessage({type:'start_game'});
    assert.equal(host.last('game_started').type,'game_started');
    const id1 = p1.last('joined').playerId;
    const id2 = p2.last('joined').playerId;
    const token = p1.last('joined').token;
    host.emitMessage({type:'assign_roles',roles:{[id1]:'impostor',[id2]:'barista'}});
    assert.equal(p1.last('role').role,'impostor');
    assert.equal(p2.last('role').role,'barista');
    p2.emitMessage({type:'input',x:50,y:0,action:true,sabotage:true});
    assert.equal(host.last('input').x,1);
    assert.equal(host.last('input').sabotage,false);
    p1.emit('close');
    assert.equal(host.last('player_left').playerId,id1);
    const resumed=instance.connect();resumed.emitMessage({type:'join_room',code,token});
    assert.equal(resumed.last('joined').playerId,id1);
    assert.equal(resumed.last('joined').number,1);
    assert.equal(resumed.last('joined').role,'impostor');
  } finally {
    relay.server.emit('close');
    for(const room of relay.rooms.values()) for(const player of room.players.values()) clearTimeout(player.timer);
  }
});
