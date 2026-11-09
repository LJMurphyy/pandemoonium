'use strict';
const $=id=>document.getElementById(id);
let socket=null,code=null,number=0,role=null,phase='lobby',ready=false,retryTimer=null,hostAway=false;
let axes={x:0,y:0},action=false,sabotage=false;
const send=data=>{if(socket?.readyState===WebSocket.OPEN)socket.send(JSON.stringify(data));};
const key=room=>`pandemoonium:${room}`;
function input(){if(!code||phase!=='playing')return;send({type:'input',...axes,action,sabotage});}
function release(){axes={x:0,y:0};action=false;sabotage=false;$('stick').style.transform='translate(-50%,-50%)';for(const el of document.querySelectorAll('.pressed'))el.classList.remove('pressed');input();}
function ui(){ $('joinPanel').hidden=!!code;$('controller').hidden=!code;$('readyPanel').hidden=phase!=='lobby';$('playPanel').hidden=phase!=='playing';$('sabotageBtn').hidden=role!=='impostor';$('readyBtn').textContent=ready?'Ready ✓ (tap to unready)':"I'm Ready"; $('status').textContent=hostAway?'Host reconnecting…':phase==='playing'?(role==='impostor'?'You are the IMPOSTOR. Sabotage secretly!':'You are a BARISTA. Complete orders!'):(ready?'Ready. Waiting for host…':'Lobby: tap Ready when prepared.');}
function openRoom(room){
  if(socket){socket.onclose=null;socket.close();}
  $('joinStatus').textContent='Connecting…';
  socket=new WebSocket(`${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws`);
  socket.onopen=()=>send({type:'join_room',code:room,token:sessionStorage.getItem(key(room))||''});
  socket.onmessage=event=>{
    const m=JSON.parse(event.data);
    if(m.type==='joined') {hostAway=m.hostConnected===false;code=m.code;number=m.number;role=m.role||null;phase=m.phase||'lobby';sessionStorage.setItem(key(code),m.token);$('roomCode').value=code;$('playerLabel').textContent=`Player ${number}`;$('roomLabel').textContent=`Room ${code}`;ui();input();}
    else if(m.type==='players') {phase=m.phase||phase;const me=m.players.find(p=>p.number===number);if(me)ready=me.ready;$('roster').replaceChildren(...m.players.map(p=>{const e=document.createElement('span');e.textContent=`P${p.number}: ${p.connected?'●':'○'} ${p.ready?'Ready':'Waiting'}`;return e;}));ui();}
    else if(m.type==='role'){role=m.role;ui();}
    else if(m.type==='game_event'){$('status').textContent=m.event;}
    else if(m.type==='room_closed'){disconnect('Host closed the room.');}
    else if(m.type==='host_disconnected'){hostAway=true;release();ui();}
    else if(m.type==='host_reconnected'){hostAway=false;ui();}
    else if(m.type==='error'){$('joinStatus').textContent=m.message;$('status').textContent=m.message;}
  };
  socket.onclose=()=>{if(code){release();$('status').textContent='Connection lost. Reconnecting…';clearTimeout(retryTimer);retryTimer=setTimeout(()=>openRoom(code),1300);}else $('joinStatus').textContent='Server disconnected.';};
  socket.onerror=()=>{$('joinStatus').textContent='Could not reach the server.';};
}
function disconnect(message){hostAway=false;const old=socket;socket=null;clearTimeout(retryTimer);release();code=null;role=null;phase='lobby';ready=false;ui();$('joinStatus').textContent=message;if(old){old.onclose=null;old.close();}}
$('joinBtn').onclick=()=>{const room=$('roomCode').value.trim().toUpperCase();if(!/^[A-F0-9]{6}$/.test(room)){$('joinStatus').textContent='Enter the six-character room code.';return;}openRoom(room);};
$('roomCode').onkeydown=e=>{if(e.key==='Enter')$('joinBtn').click();};
$('readyBtn').onclick=()=>send({type:'ready',ready:!ready});
$('leaveBtn').onclick=()=>{send({type:'leave_room'});if(code)sessionStorage.removeItem(key(code));disconnect('Left room.');};
const pad=$('joystick');let activePointer=null;
function movePointer(e){const rect=pad.getBoundingClientRect(),cx=rect.left+rect.width/2,cy=rect.top+rect.height/2;const range=(rect.width-76)/2;const dx=e.clientX-cx,dy=e.clientY-cy,dist=Math.max(1,Math.hypot(dx,dy));const scale=Math.min(1,dist/range);axes={x:dx/dist*scale,y:dy/dist*scale};$('stick').style.transform=`translate(calc(-50% + ${axes.x*range}px),calc(-50% + ${axes.y*range}px))`;input();}
pad.onpointerdown=e=>{e.preventDefault();activePointer=e.pointerId;pad.setPointerCapture(e.pointerId);movePointer(e);};
pad.onpointermove=e=>{if(e.pointerId===activePointer)movePointer(e);};
function stopPad(e){if(e.pointerId!==activePointer)return;activePointer=null;axes={x:0,y:0};$('stick').style.transform='translate(-50%,-50%)';input();}
pad.onpointerup=stopPad;pad.onpointercancel=stopPad;pad.onlostpointercapture=stopPad;
function bindPress(id,set){const b=$(id);b.onpointerdown=e=>{e.preventDefault();b.setPointerCapture(e.pointerId);set(true);b.classList.add('pressed');input();};const up=()=>{set(false);b.classList.remove('pressed');input();};b.onpointerup=up;b.onpointercancel=up;b.onlostpointercapture=up;}
bindPress('actionBtn',v=>action=v);bindPress('sabotageBtn',v=>sabotage=v);
window.addEventListener('blur',release);document.addEventListener('visibilitychange',()=>{if(document.hidden)release();});document.addEventListener('contextmenu',e=>e.preventDefault());
setInterval(input,100);ui();
