'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../public/controller-v2-core.js');
for (const [source,expected] of [[' abc123 ','ABC123'],['a0b0ff','A0B0FF'],['xyz123','XYZ123'],['', '']]) {
 test(`room normalization ${JSON.stringify(source)}`,()=>assert.equal(C.normalizeRoom(source),expected));
}
for(const [room,valid] of [['A0B1C2',true],['abcdef',true],['12345',false],['1234567',false],['GHIJKL',false],['000000',true],['ab12cd ',true],['ABC-12',false]]) {
 test(`room validation ${room}`,()=>assert.equal(C.validRoom(room),valid));
}
test('joystick centered is neutral',()=>{const v=C.stickVector(0,0,190,190,76);assert.equal(v.x,0);assert.equal(v.y,0);});
test('joystick deadzone blocks micro-motion',()=>{const v=C.stickVector(2,2,190,190,76);assert.equal(v.x,0);});
test('joystick movement is normalized and clamped',()=>{const v=C.stickVector(500,0,190,190,76);assert.equal(v.x,1);assert.equal(v.y,0);assert.equal(v.visualX,57);});
test('joystick respects diagonals',()=>{const v=C.stickVector(100,100,190,190,76);assert.ok(Math.abs(Math.hypot(v.x,v.y)-1)<1e-10);assert.ok(Math.abs(v.x-v.y)<1e-10);});
test('joystick handles malformed coordinates',()=>{const v=C.stickVector(NaN,Infinity,190,190,76);assert.equal(v.x,0);assert.equal(v.y,0);});
test('joystick supports landscape geometry',()=>{const v=C.stickVector(0,-100,140,180,60);assert.equal(v.y,-1);});
test('retry uses capped exponential delay',()=>{assert.equal(C.retryDelay(0),750);assert.ok(C.retryDelay(1)>C.retryDelay(0));assert.equal(C.retryDelay(100),8000);});
for(const [phase,role,ready,away,fragment] of [['lobby',null,false,false,'Ready'],['lobby',null,true,false,'Waiting'],['playing','impostor',false,false,'IMPOSTOR'],['playing','barista',false,false,'BARISTA'],['finished',null,false,false,'finished'],['playing','barista',false,true,'paused']]) {
 test(`status ${phase} ${role||'none'} ${ready} ${away}`,()=>assert.match(C.status(phase,role,ready,away),new RegExp(fragment,'i')));
}
