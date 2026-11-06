'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const publicDir = path.resolve(__dirname, 'public');
const MAX_PLAYERS = 4;
const RECONNECT_MS = 30000;
const rooms = new Map();
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.svg':'image/svg+xml' };
const send = (ws, data) => { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data)); };
function freshCode() { let code; do { code = crypto.randomBytes(3).toString('hex').toUpperCase(); } while (rooms.has(code)); return code; }
function members(room) { return [...room.players.values()].sort((a,b)=>a.number-b.number).map(p=>({id:p.id, number:p.number, name:p.name, ready:p.ready, connected:!!p.ws, role:undefined})); }
function roster(room) { const message = {type:'players', players:members(room), phase:room.phase}; send(room.host,message); for (const p of room.players.values()) send(p.ws,message); }
function destroyRoom(room) { for (const p of room.players.values()) { clearTimeout(p.timer); send(p.ws,{type:'room_closed'}); if(p.ws) p.ws.roomCode=null; } rooms.delete(room.code); }
function leave(ws, holdSlot=false) {
  if (!ws.roomCode) return;
  const room=rooms.get(ws.roomCode);
  if (!room) { ws.roomCode=null; return; }
  if (ws.kind==='host' && room.host===ws) destroyRoom(room);
  else if (ws.kind==='player') {
    const p=room.players.get(ws.playerId);
    if (p && p.ws===ws) {
      p.ws=null; p.lastInput=0;
      send(room.host,{type:'player_left',playerId:p.id});
      if(holdSlot) p.timer=setTimeout(()=>{ if(!p.ws) { room.players.delete(p.id); roster(room); } },RECONNECT_MS);
      else { clearTimeout(p.timer); room.players.delete(p.id); }
      roster(room);
    }
  }
  ws.roomCode=null;
  ws.kind=null;
}
function handle(ws,msg) {
  if(!msg || typeof msg!=='object' || Array.isArray(msg)) return send(ws,{type:'error',message:'Invalid message'});
  if(msg.type==='create_room') {
    if(ws.roomCode) return send(ws,{type:'error',message:'Already in a room'});
    const code=freshCode(); const room={code,host:ws,phase:'lobby',players:new Map()}; rooms.set(code,room);
    ws.kind='host'; ws.roomCode=code; send(ws,{type:'room_created',code}); roster(room); return;
  }
  if(msg.type==='join_room') {
    if(ws.roomCode) return send(ws,{type:'error',message:'Already in a room'});
    const code=String(msg.code||'').trim().toUpperCase(); const room=rooms.get(code);
    if(!room) return send(ws,{type:'error',message:'Room not found'});
    const token=String(msg.token||'');
    let player=[...room.players.values()].find(p=>p.token===token && token.length>=32 && !p.ws);
    if(player) { clearTimeout(player.timer); player.timer=null; }
    else {
      if(room.phase!=='lobby') return send(ws,{type:'error',message:'Round started. Only reconnecting players can join.'});
      if(room.players.size>=MAX_PLAYERS) return send(ws,{type:'error',message:'Room full (4 players)'});
      const occupied=new Set([...room.players.values()].map(p=>p.number));
      const number=[1,2,3,4].find(n=>!occupied.has(n));
      player={id:crypto.randomUUID(), token:crypto.randomBytes(24).toString('hex'), number, name:`Player ${number}`, ready:false, ws:null, timer:null, role:null, lastInput:0};
      room.players.set(player.id,player);
    }
    player.ws=ws; ws.kind='player'; ws.roomCode=code; ws.playerId=player.id;
    send(ws,{type:'joined',code,playerId:player.id,number:player.number,token:player.token,phase:room.phase,role:player.role});
    send(room.host,{type:'player_joined',playerId:player.id,number:player.number,name:player.name,ready:player.ready});
    roster(room); return;
  }
  if(!ws.roomCode) return send(ws,{type:'error',message:'Join or create a room first'});
  const room=rooms.get(ws.roomCode); if(!room) return;
  if(ws.kind==='host' && room.host===ws) {
    if(msg.type==='start_game') {
      const ps=[...room.players.values()];
      if(room.phase!=='lobby' || ps.length<2 || !ps.every(p=>p.ready && p.ws)) return send(ws,{type:'error',message:'Need 2–4 connected, ready players'});
      room.phase='playing'; send(ws,{type:'game_started'}); roster(room); return;
    }
    if(msg.type==='assign_roles' && room.phase==='playing') {
      const roles=msg.roles;
      if(!roles || typeof roles!=='object') return;
      for(const p of room.players.values()) {
        p.role=roles[p.id]==='impostor'?'impostor':'barista';
        send(p.ws,{type:'role',role:p.role});
      }
      return;
    }
    if(msg.type==='game_event' && room.phase==='playing') {
      const payload={type:'game_event',event:String(msg.event||'').slice(0,80)};
      for(const p of room.players.values()) send(p.ws,payload);
      return;
    }
    return;
  }
  const p=room.players.get(ws.playerId);
  if(!p || p.ws!==ws) return;
  if(msg.type==='ready' && room.phase==='lobby') { p.ready=msg.ready===true; roster(room); return; }
  if(msg.type==='input' && room.phase==='playing') {
    const x=Number(msg.x),y=Number(msg.y);
    if(!Number.isFinite(x)||!Number.isFinite(y)) return;
    const length=Math.max(1,Math.hypot(x,y));
    const now=Date.now(); if(now-p.lastInput<12) return; p.lastInput=now;
    send(room.host,{type:'input',playerId:p.id,x:Math.max(-1,Math.min(1,x/length)),y:Math.max(-1,Math.min(1,y/length)),action:msg.action===true,sabotage:msg.sabotage===true && p.role==='impostor'});
    return;
  }
  if(msg.type==='leave_room') { leave(ws); send(ws,{type:'left_room'}); return; }
}
const server=http.createServer((req,res)=>{
  let pathname;
  try { pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname); } catch { res.writeHead(400).end('Bad URL'); return; }
  const resolved=path.resolve(publicDir,'.'+(pathname==='/'?'/index.html':pathname));
  if(!resolved.startsWith(publicDir+path.sep)) { res.writeHead(403).end('Forbidden'); return; }
  fs.readFile(resolved,(err,content)=>{
    if(err) {res.writeHead(404).end('Not found'); return;}
    res.writeHead(200,{'Content-Type':mime[path.extname(resolved)]||'application/octet-stream','Cache-Control':'no-store'}); res.end(content);
  });
});
const wss=new WebSocketServer({server,path:'/ws',maxPayload:2048});
wss.on('connection',ws=>{
  ws.isAlive=true; ws.on('pong',()=>{ws.isAlive=true;});
  ws.on('message',data=>{try{handle(ws,JSON.parse(data.toString()));}catch{send(ws,{type:'error',message:'Invalid JSON'});}});
  ws.on('close',()=>leave(ws,true)); ws.on('error',()=>leave(ws,true));
});
const heartbeat=setInterval(()=>{for(const ws of wss.clients){if(!ws.isAlive){ws.terminate();continue;} ws.isAlive=false;ws.ping();}},15000);
server.on('close',()=>clearInterval(heartbeat));
if(require.main===module) server.listen(PORT,HOST,()=>console.log(`PandeMOOnium: http://localhost:${PORT} (phones: http://YOUR-LAPTOP-IP:${PORT})`));
module.exports={server,rooms};
