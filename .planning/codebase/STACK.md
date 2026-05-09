# Technology Stack

**Analysis Date:** 2026-05-08

## Languages

**Primary:**
- GDScript 4.x - All game logic and editor tooling (`script/*.gd`, `addons/godot_ai/**/*.gd`)

**Secondary:**
- Python (server-side) - MCP server backend launched by `addons/godot_ai` via `uv` (see plugin README)

## Runtime

**Environment:**
- Godot Engine 4.6 (declared in `project.godot` `config/features`)

**Package Manager:**
- None (Godot project — no npm/pip manifests in project root)
- Python MCP server managed by `uv` (installed separately, not committed)
- Lockfile: Not applicable

## Frameworks

**Core:**
- Godot 4.6 - Game engine, scene system, physics, rendering
- Godot AI addon v2.4.2 - MCP server + AI-editor bridge (`addons/godot_ai/plugin.cfg`)

**Testing:**
- None detected (no test runner config; `addons/godot_ai` contains `test_handler.gd` for editor-side test execution via MCP)

**Build/Dev:**
- Godot Editor (standalone) - Scene editing, export
- Godot AI MCP server - WebSocket server connecting AI clients to the live editor

## Key Dependencies

**Critical:**
- Godot Engine 4.6 - Required runtime; targets `Forward Plus` renderer
- Jolt Physics (3D engine) - Configured in `project.godot` `[physics]` section
- `uv` (Python package runner) - Required to launch the MCP server; installed separately

**Infrastructure:**
- `addons/godot_ai` v2.4.2 - Provides MCP protocol bridge; auto-starts WebSocket server on editor open

## Configuration

**Environment:**
- No `.env` files detected
- Game state persisted to `user://save_slot_N.cfg` (Godot `ConfigFile` format, 4 slots) — see `script/global.gd`
- No external environment variables required for game runtime

**Build:**
- `project.godot` - Main project config (engine version, main scene, autoloads, input map, renderer)
- `addons/godot_ai/plugin.cfg` - Plugin metadata
- `.import/` files - Auto-generated Godot asset import metadata (committed per standard Godot practice)

## Platform Requirements

**Development:**
- Godot 4.6+ editor (Windows; rendering backend: Direct3D 12 `d3d12`)
- `uv` installed for AI/MCP features
- An MCP client (Claude Code, Codex, Antigravity, Cursor, etc.)

**Production:**
- Godot export templates for target platform
- Viewport: 1920x1080 logical, scale 4.0 (pixel-art scaling)
- Renderer: Forward Plus (GPU required)

---

*Stack analysis: 2026-05-08*
