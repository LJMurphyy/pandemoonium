/* Dependency-free controller helpers. Shared by the browser and Node's test runner. */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.PandeControllerCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const ROOM = /^[A-F0-9]{6}$/;
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  function normalizeRoom(value) { return String(value || '').trim().toUpperCase(); }
  function validRoom(value) { return ROOM.test(normalizeRoom(value)); }
  function stickVector(x, y, width, height, knobDiameter, deadzone = 0.09) {
    const radius = Math.max(1, (Math.min(width, height) - knobDiameter) / 2);
    const px = Number.isFinite(x) ? x : 0;
    const py = Number.isFinite(y) ? y : 0;
    const length = Math.hypot(px, py);
    const raw = clamp(length / radius, 0, 1);
    const amount = raw <= deadzone ? 0 : (raw - deadzone) / (1 - deadzone);
    return { x: length ? px / length * amount : 0, y: length ? py / length * amount : 0,
      visualX: length ? px / length * raw * radius : 0,
      visualY: length ? py / length * raw * radius : 0 };
  }
  function retryDelay(attempt) { return Math.min(8000, 750 * Math.pow(1.7, Math.min(10, Math.max(0, attempt)))); }
  function status(phase, role, ready, hostAway) {
    if (hostAway) return 'Game host reconnecting. Controls paused.';
    if (phase === 'finished') return 'Round finished. See the game screen for results.';
    if (phase === 'playing') return role === 'impostor'
      ? 'IMPOSTOR · Blend in and sabotage when safe.'
      : role === 'barista' ? 'BARISTA · Prepare and serve drinks.' : 'Round starting…';
    return ready ? 'Ready! Waiting for the host to start.' : 'Lobby · Tap Ready when you are prepared.';
  }
  return { normalizeRoom, validRoom, stickVector, retryDelay, status };
});
