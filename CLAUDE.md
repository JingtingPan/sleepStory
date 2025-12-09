# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SleepStory** is a first-person horror game built in Godot 4.4 where the player experiences a narrative through two distinct gameplay modes: standing exploration and bed-based survival. The game uses atmospheric horror elements, including lighting effects, monster encounters, and psychological horror mechanics.

## Project Structure

### Core Components

- **`scripts/`** - Main game logic and player controllers
  - `event_manager.gd` - Central event system managing all game events with dependencies
  - `player.gd` - Standing player controller (first-person movement, interactions)
  - `interactable/` - Interactive object scripts
  - `mirror.gd`, `monster.gd`, `lightning_control.gd`, `light_manager.gd` - Environment systems

- **`bed_mode/`** - Secondary gameplay mode (player in bed)
  - `script/player_state_controller.gd` - Autoload managing sleepiness/sanity systems
  - `script/player_sleep.gd` - Bed-based player controller

- **`scene/`** - Scene files (.tscn)
  - `child_room.tscn` - Main scene (entry point, see project.godot:14)
  - `player.tscn`, `light.tscn`, various room scenes

- **`Assets/`** - Game assets (models, textures)
- **`sfx/`** - Sound effects organized by category
- **`addons/`** - Third-party plugins:
  - `dialogue_manager` - Dialogue system
  - `ovani_ao` - Ambient occlusion
  - `Mirror` - Mirror rendering effects

## Autoload Singletons

Two autoload scripts are always available globally:

1. **EventManager** (`res://scripts/event_manager.gd`)
   - Manages event triggers, dependencies, and sequencing
   - Access via `EventManager.start_event("event_name")`

2. **PlayerStateController** (`res://bed_mode/script/player_state_controller.gd`)
   - Tracks sleepiness (0-100) and sanity (0-100)
   - Manages player state across scene transitions

## Architecture Patterns

### Event System

The game uses a dependency-based event system (`event_manager.gd`):
- Events are defined in `event_dependencies` dictionary with prerequisite events
- Events are tracked in `triggered_events` to prevent re-triggering
- Use `EventManager.start_event("event_name")` to trigger events
- Use `EventManager.can_trigger("event_name")` to check if prerequisites are met
- Events update task hints via `task_hint_manager`

Example event flow:
```gdscript
# In event_dependencies:
"balcony": [],           # No prerequisites
"flashy": ["balcony"],   # Requires "balcony" to complete first
```

### Player State Machine

The standing player (`scripts/player.gd`) uses an enum-based state system:
```gdscript
enum PlayerState { NORMAL, FROZEN, HALLUCINATING, DIALOGUE, PEE }
```
- **NORMAL**: Full movement and interaction
- **DIALOGUE**: Movement locked, mouse enabled
- **FROZEN**: All input disabled
- **PEE**: Special urination mechanic state

### Input Management

The player controller has multiple input control layers:
- `input_enabled` - Master switch for all input
- `mouse_can_move` - View rotation control
- `movement_enabled` - Movement-specific lock
- `allow_interact` - Interaction permission
- `view_lock_enabled` - Constrains camera rotation within bounds

Always use the appropriate setter methods rather than modifying directly:
- `set_input_enabled(bool)`
- `set_movement_enabled(bool)`
- `set_view_lock(enabled, center_yaw, half_yaw, center_pitch, half_pitch)`

### Cinematic Sequences

For scripted events involving player movement and camera control:

1. Lock player input: `player_stand.set_input_enabled(false)`
2. Move to position: `await player_stand.escort_to_spot(spot_node, look_target_node, move_time, face_time, lock_yaw, lock_pitch_center, lock_pitch_half)`
3. Perform event actions (animations, dialogue, effects)
4. Unlock controls: `player_stand.unlock_and_enable_control()` and `player_stand.set_input_enabled(true)`

See `event_manager.gd:352` (balcony event) for reference implementation.

### Audio System

Sound effects are preloaded as constants and assigned to AudioStreamPlayer nodes:
```gdscript
const GASP = preload("res://sfx/player/gasp-sfx-351568.mp3")
player_sound.stream = GASP
player_sound.play()
```

Player has separate audio nodes for:
- `player_sound` - General one-shot sounds
- `sound_breathing` - Breathing loops
- `sound_heartbeat` - Heartbeat loops
- `player_footstep_sound` - Footstep audio

### Lighting and Horror Effects

**Lightning System** (`lightning_control.gd`):
- `play_lightning_once(duration, delay)` - Single flash
- `lightning_on` property - Toggle automatic strikes

**Light Flickering** (`scene/light_flicker.gd`):
- `trigger_flicker(count, min_energy, max_energy, restore_energy)`

**Camera Effects** (player.gd):
- `start_camera_shake(intensity, duration)` - Screen shake
- `start_dynamic_heartbeat(start_bpm, end_bpm, duration, sustain)` - Ramping heartbeat

## Common Development Commands

### Running the Project
Open the project in Godot Editor and press F5, or use the Godot command line:
```bash
godot --path . --editor  # Open in editor
godot --path .           # Run main scene directly
```

### Exporting Builds
The project has two export presets configured (see `export_presets.cfg`):
- **Web** - Exports to `export/html/index.html`
- **Windows Desktop** - Exports to `export/exe/sleep.exe`

Export via Godot Editor: Project > Export, or command line:
```bash
godot --export "Web" export/html/index.html
godot --export "Windows Desktop" export/exe/sleep.exe
```

### Scene Management
Main scene is configured at `project.godot:14` as `res://scene/child_room.tscn`. To change:
```
[application]
run/main_scene="res://scene/child_room.tscn"
```

## Global Groups

Objects can be tagged with groups for raycasting and detection:
- `WoodTerrain` - Wood surface footsteps
- `MetalTerrain` - Metal surface footsteps
- `TileTerrain` - Tile surface footsteps
- `Interactable` - Interactive objects (must implement `action_use()`)
- `toilet_surface` - Urination detection
- `floor_surface` - Urination detection

## Display Configuration

The game uses a low-resolution aesthetic:
- Viewport: 426x240
- Window mode: Fullscreen (mode=2)
- Stretch mode: "viewport" - maintains pixel-perfect scaling

## Input Actions

Configured in `project.godot`:
- `up` / `down` / `left` / `right` - WASD movement
- `jump` - Spacebar
- `sprint` - Shift
- `interact` - E key
- `F` - Special action key

## Key Technical Details

### Player Movement and Animation
The standing player uses a custom animation system:
- Footsteps are distance-based, not animation-driven
- Surface detection via `FloorDetectRayCast` → checks collision groups
- Different step distances for walking vs sprinting (`walk_step_distance`, `sprint_step_distance`)
- Barefoot mode toggles between surface-specific and barefoot sounds

### Sleepiness and Sanity Mechanics
Managed by `PlayerStateController` (autoload):
- Sleepiness increases when eyes closed, decreases when open
- Sanity increases when eyes open, decreases when closed
- Being covered (blanket) modifies rates via `cover_rate` multiplier
- Both values clamped 0-100
- Signals emitted on change: `sanity_changed(new_value)`, `sleepiness_changed(new_value)`

### Interactable Objects Pattern
All interactive objects must:
1. Be in the `Interactable` group
2. Have a `type` property (string displayed in UI)
3. Implement `action_use()` method
4. Typically call `EventManager.start_event()` in their action

See `scripts/interactable/` for examples.

### Monster Appearance System
Monsters have appear/disappear methods with tweening:
```gdscript
await slender.appear_and_move(from_pos, to_pos, duration)
slender.play_animation("idle")
# ... event logic ...
await slender.disappear()  # or slender.visible = false
```

## Important Notes

- The codebase contains Chinese comments and dialogue strings
- Event timing relies heavily on `await get_tree().create_timer(seconds).timeout`
- Camera and player rotation use radians internally, degrees for exports/parameters
- Tween animations are extensively used for smooth transitions
- The player's `kid` node contains the character mesh and skeleton
