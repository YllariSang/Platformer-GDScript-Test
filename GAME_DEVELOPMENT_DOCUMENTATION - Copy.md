# Crescere - Game Development Documentation

**Project Name:** Crescere  
**Engine:** Godot 4.5 stable
**Language:** GDScript  
**Project Type:** 2D Platformer  
**Platform:** Mobile (Android)  
**Status:** Educational Project (3rd Year BSIT)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Core Systems](#core-systems)
4. [Game Mechanics](#game-mechanics)
5. [File Structure](#file-structure)
6. [Autoload Managers](#autoload-managers)
7. [Scene Guide](#scene-guide)
8. [Input System](#input-system)
9. [Gameplay Elements](#gameplay-elements)
10. [Development Guidelines](#development-guidelines)

---

## Project Overview

**Crescere** is a 2D platformer game with advanced player mechanics including dashing, variable jumping, crouching, and plunging attacks. The game focuses on collectibles (fragments) and level progression with checkpoint/respawn systems.

### Key Features

- **Advanced Movement Mechanics**: Dash, variable jump height, crouch mechanics, plunge attacks
- **Collectible System**: Coins and fragments for progression tracking
- **Checkpoint System**: Respawn points throughout levels
- **Dialogue System**: NPC interactions and story elements
- **Mobile Support**: Touch controls and mobile-optimized gameplay
- **Audio Management**: Centralized SFX and music handling
- **Transition System**: Smooth scene transitions with fade effects

---

## Architecture

### High-Level Structure

```
Crescere/
├── Scripts/           # All GDScript game logic
├── Scenes/            # All scene files (.tscn)
├── Assets/            # Images, audio, sprites
├── android/           # Android build configuration
└── project.godot      # Main project configuration
```

### Design Pattern: Autoload (Singleton)

This project uses Godot's autoload system for global managers:

```gdscript
Game                  # game_state.gd     - Global game state
DialogManager         # dialog_manager.gd - Dialogue UI handling
Transition            # Transition.gd     - Scene transitions
AudioManager          # audio_manager.gd  - Sound management
```

These are automatically available globally without instantiation.

---

## Core Systems

### 1. Game State Manager (`game_state.gd`)

**Purpose:** Manages global game state, collectibles, and progression

**Key Variables:**
```gdscript
var coins: int = 0                      # Player's collected coins
var fragments: int = 0                  # Collected fragments
var total_fragments: int = 0            # Total fragments in level
var fragments_submitted: int = 0        # Fragments turned in
var suppress_jump: bool = false         # Disable jump input (cutscenes)
```

**Key Methods:**
```gdscript
add_coin(amount: int = 1)              # Increment coin count
add_fragment(amount: int = 1)           # Increment fragment count
submit_fragments()                      # Turn in collected fragments
get_submission_percentage() -> float    # Calculate completion %
load_credits_scene()                    # Load credits with stats
```

**Signals:**
```gdscript
signal coins_changed(coins)
signal fragments_changed(fragments)
```

---

### 2. Transition Manager (`Transition.gd`)

**Purpose:** Handles smooth scene transitions with fade effects

**Key Methods:**
```gdscript
fade_and_change_scene(scene_path: String)  # Fade to new scene
```

---

### 3. Dialog Manager (`dialog_manager.gd`)

**Purpose:** Manages NPC dialogue and story text

**Features:**
- Displays dialogue UI
- Handles text progression
- Controls input during dialogue sequences

---

### 4. Audio Manager (`audio_manager.gd`)

**Purpose:** Centralized audio control

**Handles:**
- Sound effects (SFX)
- Background music
- Audio playback

---

## Game Mechanics

### Player Movement System (`player.gd`)

The player is a `CharacterBody2D` with comprehensive movement mechanics.

#### Basic Movement

```gdscript
const SPEED = 300.0                    # Horizontal movement speed
velocity = velocity.lerp(target_v, 0.1)  # Smooth acceleration
```

#### Jumping Mechanics

**Variable Jump (Hold to Jump Higher)**
```gdscript
const JUMP_VELOCITY = -500.0
const JUMP_HOLD_TIME = 0.14            # Duration of variable jump boost
const JUMP_HOLD_STRENGTH = -700.0      # Additional upward force while holding
```

**Jump Buffer & Coyote Time**
```gdscript
const COYOTE_TIME = 0.12               # Grace period after leaving ground
const JUMP_BUFFER_TIME = 0.12          # Allows jumping before landing
```

#### Crouch Mechanics

**Crouch Toggle**
```gdscript
is_crouching: bool                     # Current crouch state
CROUCH_SCALE = 0.5                     # Sprite scale when crouching
CROUCH_TRANSITION = 0.12               # Time to crouch/uncrouch
```

**Collision Swap**
- Standing collision: `CollisionShape2D`
- Crouch collision: `CrouchCollisionShape2D`
- Automatically swaps based on crouch state

**Crouch States**
```gdscript
CROUCH_STATE_NONE = 0      # Not crouching
CROUCH_STATE_ENTERING = 1  # Transitioning down
CROUCH_STATE_IN = 2        # Fully crouched
CROUCH_STATE_EXITING = 3   # Transitioning up
```

#### Dash Ability

**Dash Attack**
```gdscript
const DASH_SPEED = 1200.0              # Dash movement speed
const DASH_DURATION = 0.12             # How long dash lasts
const DASH_COOLDOWN = 0.3              # Cooldown before next dash
```

**Properties**
- Can dash in any direction
- Has cooldown period
- Used for traversal and dodging

#### Plunge Attack

**Downward Attack**
```gdscript
const PLUNGE_SPEED = 1200.0            # Downward movement speed
const PLUNGE_DURATION = 0.12           # Attack duration
const PLUNGE_COOLDOWN = 0.6            # Cooldown before reuse
```

**Restrictions**
- Cannot plunge while crouched
- Fast downward movement for damage/traversal

#### Respawn System

```gdscript
var last_safe_position: Vector2        # Auto-save position
var checkpoint_position: Vector2       # Explicit checkpoint position
var has_checkpoint: bool               # Whether checkpoint is set

func die() -> void                     # Trigger respawn
```

#### Camera System

```gdscript
@export var camera_scale_follow_sprite: bool = true
@export var camera_scale_smoothing: float = 8.0
@export var camera_min_scale_x: float = 0.01
```

- Camera zooms with crouch state
- Smooth interpolation

---

## File Structure

### Scripts Directory

**Core Game Logic**
- `player.gd` - Player character controller (755 lines)
- `game_state.gd` - Global state manager
- `main.gd` - Level initialization

**UI & Interaction**
- `menu.gd` - Main menu logic
- `hud.gd` - Heads-up display
- `dialog_manager.gd` - Dialogue system
- `dialogue_trigger.gd` - Dialogue triggers (Area2D)
- `credits.gd` - Credits scene

**Managers**
- `audio_manager.gd` - Sound management
- `Transition.gd` - Scene transitions
- `mobile_controls.gd` - Touch controls

**Level Objects**
- `block.gd` - Static platform blocks
- `platform.gd` - Moving platforms
- `spring.gd` - Spring bounce pads
- `spike.gd` - Damaging spikes
- `coin.gd` - Collectible coins
- `fragment.gd` - Fragment collectibles
- `checkpoint.gd` - Respawn points
- `submission_terminal.gd` - Fragment submission point

**Visual Effects**
- `eye.gd` - Eye visual element

### Scenes Directory

**UI Scenes**
- `menu.tscn` - Main menu
- `credits.tscn` - Credits
- `dialog_ui.tscn` - Dialogue UI
- `mobile_controls.tscn` - Mobile button layout

**Player & Core**
- `player.tscn` - Player character
- `main.tscn` - Level/game scene
- `front.tscn` - Foreground elements

**Level Objects**
- `block.tscn` - Platform block
- `platform.tscn` - Moving platform
- `spring.tscn` - Spring pad
- `spike.tscn` - Spike obstacle
- `coin.tscn` - Coin item
- `fragment.tscn` - Fragment item
- `checkpoint.tscn` - Checkpoint
- `submission_terminal.tscn` - Fragment submission

**Effects**
- `invis_block.tscn` - Invisible trigger block
- `skell.tscn` - Skeleton sprite
- `eye.tscn` - Eye element
- `techplat.tscn` - Moving platform

### Assets Directory

**Sprites**
- `block.png` - Platform block
- `cloud*.png` - Background clouds
- `platform.png` - Platform sprite
- `spike.png` - Spike sprite
- `spring.png` - Spring sprite
- `coinmoon.png` - Coin sprite
- `16-bit-spike-Sheet.png` - Sprite sheet

**Audio** (`Audio/` subfolder)
- SFX files for game events
- Music files

**UI & Text** (`Text/` subfolder)
- Font files
- UI graphics

**Effects** (`VFX/` subfolder)
- Visual effect assets

---

## Autoload Managers

### 1. Game State (Singleton)

**Access:** `Game.coins`, `Game.add_coin()`, etc.

```gdscript
# Usage Example
Game.add_coin(1)
Game.add_fragment(1)
var percentage = Game.get_submission_percentage()
```

### 2. Dialog Manager

**Access:** `DialogManager` (CanvasLayer)

Manages dialogue UI and story text display.

### 3. Transition Manager

**Access:** `Transition` (Node)

```gdscript
Transition.fade_and_change_scene("res://Scenes/menu.tscn")
```

### 4. Audio Manager

**Access:** `AudioManager` (Node)

Handles all sound playback.

---

## Scene Guide

### Main Game Scene (`main.tscn`)

**Hierarchy:**
- Main (Node2D) - Root node
- Player - Player character
- TileMap/Platforms - Level platforms
- Coins/Fragments - Collectibles
- Spikes/Hazards - Obstacles
- HUD - Game UI
- Checkpoints - Respawn points

**Initialization:**
```gdscript
# In main.gd _ready():
Game.total_fragments = 19  # Set total fragments for this level
```

### Player Scene (`player.tscn`)

**Hierarchy:**
- Player (CharacterBody2D)
  - Sprite2D - Character sprite
  - CollisionShape2D - Standing collision
  - CrouchCollisionShape2D - Crouch collision
  - Camera2D - Game camera
  - AudioStreamPlayer2D - SFX player

### Platform Objects

All platform-type objects follow this pattern:

```
ObjectName (Area2D or Node2D)
├── Sprite2D - Visual representation
├── CollisionShape2D - Physics collision
└── AudioStreamPlayer2D - Sound effects (optional)
```

---

## Input System

### Configured Input Actions

**Keyboard (from `project.godot`)**

| Action | Key | Usage |
|--------|-----|-------|
| `left` | A | Move left |
| `right` | D | Move right |
| `dash` | K | Execute dash ability |

**Additional Actions (Mobile)**
- Jump - Space or Touch
- Crouch - Custom button or gesture

### Mobile Touch Controls

`mobile_controls.gd` provides TouchScreenButton input for mobile platforms.

---

## Gameplay Elements

### Collectibles

#### Coins (`coin.gd`)

```gdscript
# When collected:
Game.add_coin(1)
# Signals: coins_changed(coins)
```

#### Fragments (`fragment.gd`)

```gdscript
# When collected:
Game.add_fragment(1)
# Signals: fragments_changed(fragments)
```

### Obstacles

#### Spikes (`spike.gd`)

```gdscript
# On collision with player:
player.die()  # Triggers respawn
```

- One-hit kill
- Respawns player at last checkpoint or safe position

#### Platforms (`platform.gd`, `block.gd`)

- Static and moving platforms
- Physics-based interaction with player

#### Springs (`spring.gd`)

```gdscript
# On collision (crouch-dependent):
bounce_player()  # Applies upward velocity boost
```

- Can be crouch-activated
- Provides height boost for traversal

### Checkpoints (`checkpoint.gd`)

```gdscript
# On collision with player:
player.checkpoint_position = global_position
player.has_checkpoint = true
```

- Sets respawn point
- Preferred over `last_safe_position`

### Submission Terminal (`submission_terminal.gd`)

```gdscript
# Allows player to submit collected fragments
Game.submit_fragments()
Game.load_credits_scene()
```

- Calculates completion percentage
- Transitions to credits

---

## Development Guidelines

### Adding New Mechanics

1. **Define Constants**
   ```gdscript
   const NEW_SPEED = 200.0
   const NEW_DURATION = 0.5
   ```

2. **Add Variables**
   ```gdscript
   var new_mechanic_active: bool = false
   var new_mechanic_timer: float = 0.0
   ```

3. **Implement in `_physics_process()`**
   ```gdscript
   func _physics_process(delta: float) -> void:
       if new_mechanic_active:
           # Update mechanic
   ```

### Creating New Scenes

1. Create scene file in `Scenes/`
2. Attach script from `Scripts/`
3. Add to level by instantiating in `main.tscn`
4. Test collision layers/masks

### Best Practices

- **Collision Layers & Masks**: Use distinct layers for player, obstacles, hazards
- **Signals**: Use signals for major game events (coins, fragments, state changes)
- **Physics**: Use `CharacterBody2D` for moving entities, `Area2D` for triggers
- **Audio**: Play SFX through `AudioManager` for consistency
- **Transitions**: Always use `Transition.fade_and_change_scene()` for scene changes

### Export Variables

Mark tunable parameters with `@export` for easy tweaking:

```gdscript
@export var JUMP_VELOCITY: float = -500.0
@export var camera_scale_smoothing: float = 8.0
```

These appear in the Godot Inspector for live adjustment.

### Debugging

Print important state to console:

```gdscript
print("Game ready. coins=%d fragments=%d" % [coins, fragments])
print("Player at position: %v" % global_position)
```

Check `Output` tab in Godot editor for debug messages.

---

## Game Flow

1. **Start** → Menu Scene (`menu.tscn`)
2. **Play** → Main Game Level (`main.tscn`)
3. **Collect** → Coins & Fragments scattered throughout level
4. **Progress** → Reach checkpoints for respawn points
5. **Submit** → Reach submission terminal with fragments
6. **End** → Credits Scene with completion percentage
7. **Return** → Main menu option

---

## Technical Specifications

- **Godot Version:** 4.5 stable
- **GDScript Version:** 2.0
- **Render Mode:** Forward Plus
- **Target FPS:** 60
- **Screen Stretch Mode:** Viewport
- **Mobile:** Android-optimized

---

## Future Enhancement Ideas

- [ ] Enemy AI patrol system
- [ ] Boss encounters
- [ ] Power-up system
- [ ] Difficulty modes
- [ ] Level editor
- [ ] Leaderboard integration
- [ ] More complex puzzle mechanics
- [ ] Story expansion

---

## Contact & Credits

**Project:** Crescere
**Platform:** Google Play Store (Pending)  
**Institution:** Rizal Technological University | 3rd Year BSIT Program  
**Engine:** Godot Engine 4.5 stable

---

**Last Updated:** December 9, 2025

