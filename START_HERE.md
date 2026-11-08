# PandeMOOnium — multiplayer milestone 2

This package upgrades the previously tested phone-controller prototype to a room lobby and playable mini-loop.

1. Start Node server: in `server/` run `npm.cmd install` then `npm.cmd start`.
2. Open `game/project.godot` in Godot 4.7 and press **F5**.
3. Click **Create Room**. On phones visit `http://YOUR-PC-IP:3000` over the same Wi-Fi and enter the room code.
4. Join with at least **two** phones and tap **I'm Ready** on each.
5. Click **Start Game** in Godot. Move with the analog joystick; INTERACT near INGREDIENTS → MIX DRINK → SERVE.
6. The randomly designated impostor gets a **SABOTAGE** button. Sabotage near a station to lower satisfaction (18-second cooldown).

Run relay unit tests with `npm.cmd test` from `server/`. The previous `game/scenes/NetworkTest.tscn` remains available. See `docs/NETWORK.md` for the protocol, code structure, and limitations.

**GitHub:** Put these files into a fresh branch of the latest `LJMurphyy/pandemoonium` repo and open a pull request rather than uploading the ZIP as a commit. This avoids accidentally replacing teammates' newer changes.
