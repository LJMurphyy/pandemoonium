'use strict';
// Phone controller: no bundler, no app install. Protocol matches server/index.js.
const $ = id => document.getElementById(id);
const Core = globalThis.PandeControllerCore;
const storagePrefix = 'pandemoonium:';
const store = {
  get(k) { try { return localStorage.getItem(k) || ''; } catch { return ''; } },
  set(k,v) { try { localStorage.setItem(k,v); } catch {} },
  del(k) { try { localStorage.removeItem(k); } catch {} }
};
const tokenKey = room => `${storagePrefix}${room}`;
let socket = null, generation = 0, reconnectTimer = null, attempts = 0, pendingRoom = null;
let code = null, number = 0, role = null, phase = 'lobby', ready = false;
let hostAway = false, connection = 'offline', statusOverride = '', eventTimeout = null;
const cancelPresses = [];
let axes = { x: 0, y: 0 }, action = false, sabotage = false;
let activePointer = null;
const heldKeys = new Set();
const joystick = $('joystick');
const stick = $('stick');
const keysForMove = {ArrowLeft:[-1,0],KeyA:[-1,0],ArrowRight:[1,0],KeyD:[1,0],ArrowUp:[0,-1],KeyW:[0,-1],ArrowDown:[0,1],KeyS:[0,1]};

function vibrate(ms = 15) {
  if ($('haptics').checked && navigator.vibrate) navigator.vibrate(ms);
}
function setConnection(value) {
  connection = value;
  $('connectionLabel').textContent = value === 'online' ? 'Connected to server' : value === 'connecting' ? 'Connecting to server…' : value === 'reconnecting' ? 'Reconnecting automatically…' : 'Disconnected';
  $('connectionDot').className = 'connectionDot' + (value === 'online' ? ' online' : value === 'offline' ? ' offline' : '');
  render();
}
function canControl() { return !!code && phase === 'playing' && !hostAway && connection === 'online' && !document.hidden; }
function send(data) {
  if (socket && socket.readyState === WebSocket.OPEN) {
    try { socket.send(JSON.stringify(data)); return true; } catch { /* socket closing */ }
  }
  return false;
}
function input(force = false) {
  if (!code || phase !== 'playing' || (connection !== 'online' && !force)) return;
  send({type:'input', x: canControl() ? axes.x : 0, y: canControl() ? axes.y : 0,
    action: canControl() && action, sabotage: canControl() && sabotage && role === 'impostor'});
}
function release() {
  axes = {x:0,y:0}; action = false; sabotage = false; activePointer = null; heldKeys.clear();
  for (const cancel of cancelPresses) cancel();
  stick.style.transform = 'translate(-50%,-50%)';
  for (const el of document.querySelectorAll('.pressed')) el.classList.remove('pressed');
  input(true);
}
function render() {
  $('joinPanel').hidden = !!code;
  $('controller').hidden = !code;
  $('readyPanel').hidden = phase !== 'lobby';
  $('playPanel').hidden = phase !== 'playing' && phase !== 'finished';
  $('controls').hidden = phase === 'finished';
  $('controls').classList.toggle('disabled', !canControl());
  $('sabotageBtn').hidden = role !== 'impostor';
  $('readyBtn').textContent = ready ? '✓ Ready · Tap to unready' : "I'm Ready";
  $('readyBtn').disabled = connection !== 'online' || hostAway;
  $('status').textContent = statusOverride || Core.status(phase, role, ready, hostAway);
  $('roleBanner').textContent = phase === 'finished' ? 'ROUND COMPLETE' : role === 'impostor' ? '🕵️ IMPOSTOR' : role === 'barista' ? '🥤 BARISTA' : 'ROUND STARTING';
  $('roleBanner').classList.toggle('impostor', role === 'impostor');
  $('playerLabel').textContent = `Player ${number || '—'}`;
  $('roomLabel').textContent = code ? `ROOM ${code}` : '';
}
function clearRetry() { if (reconnectTimer !== null) clearTimeout(reconnectTimer); reconnectTimer = null; }
function forget(room) {
  if (!room) return;
  store.del(tokenKey(room));
  if (store.get('pandemoonium:last') === room) store.del('pandemoonium:last');
}
function disconnect(message, clearToken = false) {
  const old = socket;
  ++generation;
  clearRetry();
  if (clearToken) forget(code);
  release();
  code = null; pendingRoom = null; number = 0; role = null; phase = 'lobby'; ready = false; hostAway = false;
  statusOverride = ''; clearTimeout(eventTimeout); attempts = 0;
  socket = null;
  if (old) { old.onclose = null; old.onmessage = null; old.onerror = null; try { old.close(); } catch {} }
  setConnection('offline');
  $('joinStatus').textContent = message;
  $('joinBtn').disabled = false;
}
function reconnect() {
  if ((!code && !pendingRoom) || reconnectTimer !== null) return;
  const room = code || pendingRoom;
  const delay = Core.retryDelay(attempts++);
  setConnection('reconnecting');
  reconnectTimer = setTimeout(() => { reconnectTimer = null; if ((code || pendingRoom) === room) openRoom(room, true); }, delay);
}
function openRoom(room, isRetry = false) {
  pendingRoom = room;
  clearRetry();
  const old = socket;
  const current = ++generation;
  if (old) { old.onclose = null; old.onmessage = null; old.onerror = null; try { old.close(); } catch {} }
  if (!isRetry) { attempts = 0; statusOverride = ''; $('joinStatus').textContent = 'Connecting to the game server… (free hosting may take a moment)'; }
  setConnection(isRetry ? 'reconnecting' : 'connecting');
  $('joinBtn').disabled = true;
  try { socket = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws`); }
  catch { socket = null; reconnect(); return; }
  const ws = socket;
  ws.onopen = () => { if (current !== generation) return; send({type:'join_room',code:room,token:store.get(tokenKey(room))}); };
  ws.onmessage = event => {
    if (current !== generation) return;
    let m;
    try { m = JSON.parse(event.data); } catch { return; }
    if (!m || typeof m !== 'object') return;
    if (m.type === 'joined') {
      code = m.code; pendingRoom = null; number = m.number; role = m.role || null; phase = m.phase || 'lobby';
      hostAway = m.hostConnected === false;
      statusOverride = ''; clearTimeout(eventTimeout); attempts = 0; ready = false;
      store.set(tokenKey(code), m.token); store.set('pandemoonium:last', code);
      $('roomCode').value = code;
      $('joinBtn').disabled = false;
      setConnection('online');
      input();
    } else if (m.type === 'players') {
      phase = m.phase || phase;
      const players = Array.isArray(m.players) ? m.players : [];
      const me = players.find(p => p.number === number);
      if (me) ready = !!me.ready;
      $('roster').replaceChildren(...players.map(p => {
        const item = document.createElement('span');
        item.textContent = `P${p.number}: ${p.connected ? '●' : '○'} ${p.ready ? 'Ready' : 'Waiting'}`;
        if (p.number === number) item.classList.add('self');
        return item;
      }));
      render();
    } else if (m.type === 'role') {
      role = m.role; statusOverride = ''; render(); vibrate(35);
    } else if (m.type === 'game_event') {
      clearTimeout(eventTimeout);
      statusOverride = String(m.event || '').slice(0,120); render();
      eventTimeout = setTimeout(() => { statusOverride = ''; render(); }, 4500);
    } else if (m.type === 'room_closed') {
      disconnect('The host closed this room. Enter a new room code.', true);
    } else if (m.type === 'host_disconnected') {
      hostAway = true; statusOverride = ''; release(); render();
    } else if (m.type === 'host_reconnected') {
      hostAway = false; statusOverride = ''; release(); render();
    } else if (m.type === 'error') {
      const message = String(m.message || 'Unknown server error');
      if (message === 'Room not found' || message === 'Round started. Only reconnecting players can join.' || message === 'Room full (4 players)' || message === 'Join or create a room first') {
        disconnect(message, message === 'Room not found');
      } else {
        $('joinStatus').textContent = message;
        if (code) { statusOverride = message; render(); }
        else { ws.close(); $('joinBtn').disabled = false; }
      }
    }
  };
  ws.onclose = () => {
    if (current !== generation) return;
    release();
    if (code || pendingRoom) { statusOverride = ''; reconnect(); }
    else { setConnection('offline'); $('joinBtn').disabled = false; $('joinStatus').textContent = 'Connection lost. Try joining again.'; }
  };
  ws.onerror = () => { if (current === generation && !code) $('joinStatus').textContent = 'Cannot reach the server. Check Wi-Fi or mobile data.'; };
}
$('joinBtn').onclick = () => {
  const room = Core.normalizeRoom($('roomCode').value);
  if (!Core.validRoom(room)) { $('joinStatus').textContent = 'Enter the six hexadecimal characters shown in the game (0–9, A–F).'; return; }
  openRoom(room);
};
$('roomCode').addEventListener('keydown', event => { if (event.key === 'Enter') $('joinBtn').click(); });
$('readyBtn').onclick = () => { if (connection === 'online' && !hostAway) { send({type:'ready',ready:!ready}); vibrate(); } };
$('leaveBtn').onclick = () => { send({type:'leave_room'}); disconnect('You left the room.', true); };
function movePointer(e) {
  const rect = joystick.getBoundingClientRect();
  const knob = stick.getBoundingClientRect();
  const v = Core.stickVector(e.clientX - (rect.left + rect.width / 2), e.clientY - (rect.top + rect.height / 2), rect.width, rect.height, knob.width);
  axes = {x:v.x,y:v.y};
  stick.style.transform = `translate(calc(-50% + ${v.visualX}px),calc(-50% + ${v.visualY}px))`;
  input();
}
joystick.addEventListener('pointerdown', e => {
  if (!canControl() || activePointer !== null) return;
  e.preventDefault(); activePointer = e.pointerId;
  joystick.setPointerCapture(e.pointerId);
  movePointer(e);
});
joystick.addEventListener('pointermove', e => { if (e.pointerId === activePointer) movePointer(e); });
function stopPad(e) {
  if (e.pointerId !== activePointer) return;
  activePointer = null;
  axes = {x:0,y:0}; stick.style.transform = 'translate(-50%,-50%)'; input();
}
for (const event of ['pointerup','pointercancel','lostpointercapture']) joystick.addEventListener(event, stopPad);
function bindPress(id, assign) {
  const element = $(id); let pointer = null;
  element.addEventListener('pointerdown', e => {
    if (!canControl() || pointer !== null) return;
    e.preventDefault(); pointer = e.pointerId;
    element.setPointerCapture(e.pointerId);
    assign(true); element.classList.add('pressed'); input(); vibrate();
  });
  const up = e => {
    if (pointer !== e.pointerId) return;
    pointer = null; assign(false); element.classList.remove('pressed'); input();
  };
  for (const event of ['pointerup','pointercancel','lostpointercapture']) element.addEventListener(event, up);
  cancelPresses.push(() => { pointer = null; element.classList.remove('pressed'); });
}
bindPress('actionBtn', value => action = value);
bindPress('sabotageBtn', value => sabotage = value);
function updateKeyboard() {
  let x = 0, y = 0;
  for (const code of heldKeys) if (keysForMove[code]) { x += keysForMove[code][0]; y += keysForMove[code][1]; }
  const length = Math.max(1, Math.hypot(x,y));
  axes = {x:x/length,y:y/length};
  action = heldKeys.has('Space') || heldKeys.has('KeyE'); sabotage = heldKeys.has('KeyQ');
  input();
}
window.addEventListener('keydown', e => {
  if (!canControl() || e.target instanceof HTMLInputElement || e.target instanceof HTMLButtonElement || e.target instanceof HTMLTextAreaElement || e.metaKey || e.ctrlKey || e.altKey) return;
  if (keysForMove[e.code] || ['Space','KeyE','KeyQ'].includes(e.code)) { e.preventDefault(); heldKeys.add(e.code); updateKeyboard(); }
});
window.addEventListener('keyup', e => { if (heldKeys.delete(e.code)) { e.preventDefault(); updateKeyboard(); } });
window.addEventListener('blur', release);
document.addEventListener('visibilitychange', () => { if (document.hidden) release(); else if (code && connection === 'online') input(); });
window.addEventListener('pagehide', release);
window.addEventListener('online', () => { if ((code || pendingRoom) && connection !== 'online') { clearRetry(); openRoom(code || pendingRoom,true); } });
window.addEventListener('offline', () => { if (code || pendingRoom) { release(); setConnection('reconnecting'); } });
document.addEventListener('contextmenu', e => { if (e.target.closest('#controls')) e.preventDefault(); });
$('leftHanded').checked = store.get('pandemoonium:swap') === '1';
$('haptics').checked = store.get('pandemoonium:haptics') !== '0';
$('controls').classList.toggle('swapped',$('leftHanded').checked);
$('leftHanded').onchange = () => { store.set('pandemoonium:swap',$('leftHanded').checked ? '1':'0'); $('controls').classList.toggle('swapped',$('leftHanded').checked); };
$('haptics').onchange = () => store.set('pandemoonium:haptics',$('haptics').checked ? '1':'0');
const lastRoom = store.get('pandemoonium:last');
if (Core.validRoom(lastRoom)) $('roomCode').value = lastRoom;
setInterval(() => { if (canControl()) input(); }, 100);
setConnection('offline');
