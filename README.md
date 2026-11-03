# PandeMOOnium

A fast-paced 4-player co-op café game set in the UC Davis Coffee House (CoHo) during a campus rush. Three players are baristas racing to fill drink orders and keep customer satisfaction above zero until the shift ends. One player is secretly an impostor who sabotages equipment and orders without getting caught. Players can call an emergency meeting and vote to fire whoever they suspect.

The game runs in the browser on a shared screen (laptop, exported to itch.io). Players use their phones as controllers by opening a web page and entering a room code. A lightweight Node.js relay server passes messages between the phones and the game over WebSockets.

## Engine

**Everyone must use Godot 4.7.** Opening the project in a different version can rewrite project and scene files and cause merge conflicts.

## Folder Structure

```
pandemoonium/
├── game/                  Godot project (open game/project.godot)
│   ├── scenes/            .tscn scenes (Main, Level, Player, Workstation, UI, ...)
│   ├── scripts/           GDScript files
│   ├── assets/
│   │   ├── sprites/       Character, tile, station, ingredient, and UI art
│   │   ├── audio/         Sound effects and music
│   │   └── fonts/
│   └── resources/
│       └── recipes/       Recipe data resources
├── server/                Node.js WebSocket relay server
│   └── public/            Phone controller web page
└── docs/
    └── NETWORK.md         Networking design notes
```

## Team Workflow

1. **Never commit directly to `main`.** Pull the latest `main`, then create a feature branch:
   ```
   git checkout main
   git pull
   git checkout -b feature/short-description
   ```
2. Commit small, focused changes to your branch and push it.
3. Open a **pull request** into `main` and get a teammate to review it before merging.
4. **Avoid two people editing the same `.tscn` file at once.** Godot scene files merge badly. Tell the team in chat before you start working on a shared scene (especially `Main.tscn`), and prefer splitting work into separate, reusable scenes.
5. Pull `main` often to stay up to date.

Do not commit `.DS_Store`, `.godot/`, `node_modules/`, `.env`, or build/export files. The `.gitignore` files handle this, but check `git status` before committing.
