'use strict';
const $=id=>document.getElementById(id);
const COLORS=['#ffbd69','#72d6ba','#8eafff','#ff8ab0']; // P1-P4, same as the game
const HOST_GRACE_S=30; // server keeps the room this long while the laptop reconnects (HOST_RECONNECT_MS)
const CHECK='<svg width="18" height="18" viewBox="0 0 20 20" aria-hidden="true"><path d="M4 10.5 L8.5 15 L16 6" stroke="currentColor" stroke-width="3.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const CLOCK='<svg width="18" height="18" viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="7.5" fill="none" stroke="currentColor" stroke-width="2.5"/><path d="M10 6 V10.5 L13 12" stroke="currentColor" stroke-width="2.5" fill="none" stroke-linecap="round"/></svg>';
// Server join errors that get their own full screen instead of a line of text.
const JOIN_ERRORS={
  'Room not found':{art:'artNotFound',title:'Room not found',text:['No café is open with code ','. Check the big screen and try again.']},
  'Room full (4 players)':{art:'artFull',title:'Room is full',text:['All 4 aprons in ',' are taken. Wait for a seat to open, or join another room.']},
  'Round started. Only reconnecting players can join.':{art:'artStarted',title:'Round already started',text:['The baristas in ',' are mid-rush. Join once the host is back in the lobby.']},
};
let socket=null,code=null,number=0,role=null,phase='lobby',ready=false,retryTimer=null,hostAway=false,hostAwaySince=0,roster=[],joinError=null;
let axes={x:0,y:0},action=false,sabotage=false;
let cooldownEnd=0,cooldownTotal=18; // sabotage cooldown, sent privately by the game
let uprightOk=false; // player chose to keep the phone upright for this round
const portrait=window.matchMedia('(orientation: portrait)');
const send=data=>{if(socket?.readyState===WebSocket.OPEN)socket.send(JSON.stringify(data));};
const key=room=>`pandemoonium:${room}`;
// Rejoin tokens live in localStorage: iPhones often wipe sessionStorage when Safari is backgrounded (#5).
// Wrapped in try/catch because private browsing can block storage.
const store={
  get:k=>{try{return localStorage.getItem(k)||'';}catch{return '';}},
  set:(k,v)=>{try{localStorage.setItem(k,v);}catch{}},
  del:k=>{try{localStorage.removeItem(k);}catch{}},
};
// Keep only the current room's token so old ones don't pile up.
function forgetOtherRooms(room){try{for(const k of Object.keys(localStorage))if(k.startsWith('pandemoonium:')&&k!==key(room)&&k!=='pandemoonium:last')localStorage.removeItem(k);}catch{}}
function input(){if(!code||phase!=='playing')return;send({type:'input',...axes,action,sabotage});}
function release(){axes={x:0,y:0};action=false;sabotage=false;$('stick').style.transform='translate(-50%,-50%)';resetBase();for(const el of document.querySelectorAll('.pressed'))el.classList.remove('pressed');input();}

// --- Screens ---------------------------------------------------------------
function ui(){
  const inRoom=!!code;
  $('joinPanel').hidden=inRoom||!!joinError;
  $('errorPanel').hidden=inRoom||!joinError;
  $('controller').hidden=!inRoom;
  // The round is played sideways; everything before it stays upright.
  const playing=inRoom&&!hostAway&&phase==='playing';
  document.body.classList.toggle('playing',playing);
  $('controller').classList.toggle('playing',playing);
  $('rotateHint').hidden=!(playing&&portrait.matches&&!uprightOk);
  if(!inRoom)return;
  document.documentElement.style.setProperty('--me',COLORS[number-1]||COLORS[0]);
  $('playerLabel').textContent=`Player ${number}`;
  $('roomLabel').textContent=code;
  const cow=`/img/cow_p${number}.png`;
  for(const id of ['cow','miniCow'])if(!$(id).src.endsWith(cow))$(id).src=cow;
  $('miniLabel').textContent=`P${number}`;
  $('controller').classList.toggle('dimmed',hostAway);
  $('hostPanel').hidden=!hostAway;
  $('readyPanel').hidden=hostAway||phase!=='lobby';
  $('playPanel').hidden=hostAway||phase!=='playing';
  $('sabotageBtn').hidden=role!=='impostor';
  $('buttonZone').classList.toggle('noSabotage',role!=='impostor');
  $('readyBtn').classList.toggle('on',ready);
  $('readyBtn').setAttribute('aria-pressed',String(ready));
  $('readyTitle').textContent=ready?'Ready!':"I'm Ready";
  $('readySub').textContent=ready?'Tap to undo':"Tap when you're set";
  $('roleLabel').textContent=role==='impostor'?'IMPOSTOR · Sabotage secretly':role==='barista'?'BARISTA · Make drinks':'ROUND STARTING';
  $('roleLabel').classList.toggle('impostor',role==='impostor');
  renderRoster();
  tickHost();
}
function renderRoster(){
  const byNumber=new Map(roster.map(p=>[p.number,p]));
  $('roster').replaceChildren(...[1,2,3,4].map(n=>{
    const p=byNumber.get(n);
    const st=!p?'empty':!p.connected?'disc':p.ready?'ready':'joined';
    const el=document.createElement('div');
    el.className=`chip ${st}${n===number?' you':''}`;
    el.style.setProperty('--c',COLORS[n-1]);
    el.setAttribute('role','listitem');
    el.setAttribute('aria-label',`Player ${n}${n===number?' (you)':''}, ${{ready:'ready',joined:'not ready',empty:'open seat',disc:'reconnecting'}[st]}`);
    el.innerHTML=`<span>P${n}</span>${st==='ready'?CHECK:st==='joined'?CLOCK:''}`;
    return el;
  }));
}
// Countdown ring while the laptop is reconnecting.
function tickHost(){
  if(!hostAway)return;
  const left=Math.max(0,HOST_GRACE_S-(Date.now()-hostAwaySince)/1000);
  $('hostSecs').textContent=Math.ceil(left);
  $('hostRing').setAttribute('stroke-dasharray',`${(289*left/HOST_GRACE_S).toFixed(1)} 289`);
}
function setHostAway(away){if(away&&!hostAway)hostAwaySince=Date.now();hostAway=away;}
function showJoinError(message,room){
  const e=JOIN_ERRORS[message];
  joinError=message;
  for(const id of ['artNotFound','artFull','artStarted'])$(id).hidden=id!==e.art;
  $('errorTitle').textContent=e.title;
  const c=document.createElement('span');c.className='mono';c.textContent=room;
  $('errorText').replaceChildren(e.text[0],c,e.text[1]);
  ui();
}
// Show each cow sprite at exactly 3x its pixel size so the pixel art stays crisp.
for(const img of document.querySelectorAll('#cow,#miniCow,.cows img')){
  const scale=img.id==='cow'?3:img.id==='miniCow'?1:2;
  const size=()=>{if(img.naturalWidth){img.width=img.naturalWidth*scale;img.height=img.naturalHeight*scale;}};
  img.addEventListener('load',size);size();
}

// --- Connection --------------------------------------------------------------
function openRoom(room){
  if(socket){socket.onclose=null;socket.close();}
  $('joinStatus').textContent='Connecting…';
  socket=new WebSocket(`${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws`);
  socket.onopen=()=>send({type:'join_room',code:room,token:store.get(key(room))});
  socket.onmessage=event=>{
    const m=JSON.parse(event.data);
    if(m.type==='joined') {setHostAway(m.hostConnected===false);joinError=null;code=m.code;number=m.number;role=m.role||null;phase=m.phase||'lobby';store.set(key(code),m.token);store.set('pandemoonium:last',code);forgetOtherRooms(code);$('roomCode').value=code;$('joinStatus').textContent='';$('status').textContent='';ui();input();}
    else if(m.type==='players') {phase=m.phase||phase;roster=m.players||[];const me=roster.find(p=>p.number===number);if(me)ready=me.ready;ui();}
    else if(m.type==='role'){role=m.role;cooldownEnd=0;ui();}
    else if(m.type==='game_event'){if(phase!=='playing')$('status').textContent=m.event;} // no text hints during a round
    else if(m.type==='sabotage_cooldown'){cooldownTotal=Math.max(1,Number(m.total)||18);cooldownEnd=Date.now()+Math.max(0,Number(m.seconds)||0)*1000;sabotage=false;$('sabotageBtn').classList.remove('pressed');tickCooldown();}
    else if(m.type==='room_closed'){forget(code);disconnect('Host closed the room.');}
    else if(m.type==='host_disconnected'){setHostAway(true);release();ui();}
    else if(m.type==='host_reconnected'){setHostAway(false);ui();}
    else if(m.type==='error'){
      if(m.message==='Room not found'){forget(code||room);if(code){disconnect('That room has closed. Enter a new code.');return;}}
      if(!code&&JOIN_ERRORS[m.message]){const old=socket;socket=null;if(old){old.onclose=null;old.close();}$('joinStatus').textContent='';showJoinError(m.message,room);return;}
      $('joinStatus').textContent=m.message;$('status').textContent=m.message;
    }
  };
  socket.onclose=()=>{if(code){release();$('status').textContent='Connection lost. Reconnecting…';clearTimeout(retryTimer);retryTimer=setTimeout(()=>openRoom(code),1300);}else $('joinStatus').textContent='Server disconnected.';};
  socket.onerror=()=>{$('joinStatus').textContent='Could not reach the server.';};
}
function forget(room){if(!room)return;store.del(key(room));if(store.get('pandemoonium:last')===room)store.del('pandemoonium:last');}
function disconnect(message){hostAway=false;uprightOk=false;cooldownEnd=0;const old=socket;socket=null;clearTimeout(retryTimer);release();code=null;role=null;phase='lobby';ready=false;roster=[];ui();$('joinStatus').textContent=message;if(old){old.onclose=null;old.close();}}

// --- Join form -----------------------------------------------------------------
const validCode=v=>/^[A-F0-9]{6}$/.test(v);
$('roomCode').addEventListener('input',()=>{const v=$('roomCode').value.toUpperCase().replace(/[^A-F0-9]/g,'').slice(0,6);if(v!==$('roomCode').value)$('roomCode').value=v;$('joinBtn').disabled=!validCode(v);});
$('joinForm').addEventListener('submit',e=>{e.preventDefault();const room=$('roomCode').value.trim().toUpperCase();if(!validCode(room)){$('joinStatus').textContent='Enter the six-character room code.';return;}openRoom(room);});
$('retryBtn').onclick=()=>{joinError=null;$('roomCode').value='';$('joinBtn').disabled=true;ui();$('roomCode').focus();};
$('uprightBtn').onclick=()=>{uprightOk=true;ui();};
portrait.addEventListener('change',()=>{release();ui();});
$('readyBtn').onclick=()=>send({type:'ready',ready:!ready});
$('leaveBtn').onclick=()=>{if(phase==='playing'&&!window.confirm('Leave the round? You can rejoin with the same room code.'))return;send({type:'leave_room'});forget(code);disconnect('Left room.');};

// --- Controls --------------------------------------------------------------------
// Floating joystick: touch anywhere in the left zone and the stick appears under the thumb.
// It stays put while dragging; past its edge the knob just holds at full tilt.
const zone=$('stickZone'),joystick=$('joystick'),stick=$('stick');let activePointer=null,base=null;
function resetBase(){base=null;joystick.style.left='';joystick.style.top='';joystick.classList.remove('active');}
function movePointer(e){
  if(!base)return;
  const z=zone.getBoundingClientRect(),reach=(joystick.offsetWidth-stick.offsetWidth)/2;
  const dx=e.clientX-z.left-base.x,dy=e.clientY-z.top-base.y,dist=Math.max(1,Math.hypot(dx,dy)),scale=Math.min(1,dist/reach);
  axes={x:dx/dist*scale,y:dy/dist*scale};
  stick.style.transform=`translate(calc(-50% + ${axes.x*reach}px),calc(-50% + ${axes.y*reach}px))`;
  input();
}
zone.onpointerdown=e=>{
  if(activePointer!==null)return;
  e.preventDefault();activePointer=e.pointerId;zone.setPointerCapture(e.pointerId);
  joystick.classList.add('active');zone.classList.add('used'); // 'active' first: no slide-in animation
  const z=zone.getBoundingClientRect(),r=joystick.offsetWidth/2;
  base={x:Math.min(Math.max(e.clientX-z.left,r),z.width-r),y:Math.min(Math.max(e.clientY-z.top,r),z.height-r)};
  joystick.style.left=`${base.x}px`;joystick.style.top=`${base.y}px`;
  movePointer(e);
};
zone.onpointermove=e=>{if(e.pointerId===activePointer)movePointer(e);};
function stopPad(e){if(e.pointerId!==activePointer)return;activePointer=null;resetBase();axes={x:0,y:0};stick.style.transform='translate(-50%,-50%)';input();}
zone.onpointerup=stopPad;zone.onpointercancel=stopPad;zone.onlostpointercapture=stopPad;
function bindPress(id,set){const b=$(id);b.onpointerdown=e=>{e.preventDefault();b.setPointerCapture(e.pointerId);set(true);b.classList.add('pressed');input();};const up=()=>{set(false);b.classList.remove('pressed');input();};b.onpointerup=up;b.onpointercancel=up;b.onlostpointercapture=up;}
bindPress('actionBtn',v=>action=v);bindPress('sabotageBtn',v=>sabotage=v);
window.addEventListener('blur',release);document.addEventListener('visibilitychange',()=>{if(document.hidden)release();});document.addEventListener('contextmenu',e=>e.preventDefault());
// Sabotage button: faded with a shrinking clock sweep until it is available again.
function tickCooldown(){const left=Math.max(0,cooldownEnd-Date.now());const b=$('sabotageBtn');b.classList.toggle('cooling',left>0);b.style.setProperty('--cool',(left/(cooldownTotal*1000)).toFixed(3));}
setInterval(input,100);setInterval(tickHost,250);setInterval(tickCooldown,100);ui();
// Stop double-tap and pinch zoom. CSS touch-action covers most browsers; older iOS Safari
// still zooms on a quick second tap or a pinch, so cancel those here (inputs still work).
let lastTouchEnd=0;
document.addEventListener('touchend',e=>{const now=Date.now();if(now-lastTouchEnd<350&&!e.target.closest('input'))e.preventDefault();lastTouchEnd=now;},{passive:false});
for(const g of ['gesturestart','gesturechange'])document.addEventListener(g,e=>e.preventDefault());
// After Safari reloads the tab, pre-fill the last room so the player just taps Join to get their slot back.
if(store.get('pandemoonium:last')){$('roomCode').value=store.get('pandemoonium:last');$('joinBtn').disabled=!validCode($('roomCode').value);}
