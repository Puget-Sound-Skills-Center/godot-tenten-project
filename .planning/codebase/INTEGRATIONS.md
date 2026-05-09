# External Integrations

**Analysis Date:** 2026-05-08

## APIs & External Services

**AI / MCP Bridge:**
- Godot AI MCP Server (`addons/godot_ai`) - Exposes Godot editor over Model Context Protocol via local WebSocket
  - SDK/Client: Built-in GDScript + Python server (launched via `uv`)
  - Auth: None (local loopback only)
  - Source: [github.com/hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)

**Supported MCP Clients (editor-side configuration):**
- Claude Code (`addons/godot_ai/clients/claude_code.gd`) - HTTP transport MCP
- Claude Desktop (`addons/godot_ai/clients/claude_desktop.gd`) - JSON config strategy
- Cursor (`addons/godot_ai/clients/cursor.gd`)
- Windsurf (`addons/godot_ai/clients/windsurf.gd`)
- VS Code / VS Code Insiders (`addons/godot_ai/clients/vscode.gd`, `vscode_insiders.gd`)
- Codex (`addons/godot_ai/clients/codex.gd`)
- Gemini CLI (`addons/godot_ai/clients/gemini_cli.gd`)
- Qwen Code, Kimi Code, Kilo Code, Cline, Roo Code, Kiro, Trae, Zed, Cherry Studio, Antigravity, OpenCode (all in `addons/godot_ai/clients/`)

## Data Storage

**Databases:**
- None (no external database)

**File Storage:**
- Save system: Local `user://save_slot_N.cfg` files (N = 0–3, 4 slots)
  - Format: Godot `ConfigFile` (INI-like)
  - Managed by: `script/global.gd` (`save_to_slot`, `load_from_slot`, `slot_preview`)
  - Stores: scene, floor, money, player stats (damage/health/defense level), position, timestamp

**Caching:**
- None

## Authentication & Identity

**Auth Provider:**
- None — no user accounts, login, or online identity system

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry, Bugsnag, etc.)

**Logs:**
- Godot built-in `print()` / editor output panel
- MCP addon provides structured log ring and editor log buffer: `addons/godot_ai/utils/structured_log_ring.gd`, `editor_log_buffer.gd`, `game_log_buffer.gd`
- Runtime game logger autoloaded as `_mcp_game_helper`: `addons/godot_ai/runtime/game_helper.gd`

## CI/CD & Deployment

**Hosting:**
- Not applicable (standalone desktop game)

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- None for game runtime
- MCP server port managed internally by `addons/godot_ai/utils/port_resolver.gd` and `windows_port_reservation.gd`

**Secrets location:**
- No secrets — fully local/offline application

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- MCP server version check: `addons/godot_ai/utils/server_version_check.gd` (pings for addon updates)
- MCP server update manager: `addons/godot_ai/utils/update_manager.gd`

---

*Integration audit: 2026-05-08*
