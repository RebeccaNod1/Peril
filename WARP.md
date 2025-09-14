# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

**Peril Dice** is a multiplayer elimination game for Second Life, built using LSL (Linden Scripting Language). It's a professional-grade linkset system where players select numbers before dice rolls, with the peril player losing lives when their number comes up. The project features a single 74-prim linkset architecture with sophisticated inter-script communication.

**Current Version**: 2.8.4 - Disconnect Recovery & System-Wide Debug Control
**Technology**: LSL (Linden Scripting Language) for Second Life virtual world  
**Architecture**: Single linkset with 16 modular LSL scripts communicating via `llMessageLinked()`

## Development Commands

### LSL Validation & Processing
```bash
# Validate single LSL file syntax
python3 /home/richard/lsl-docs/tools/lsl_validator.py filename.lsl

# Validate all LSL files in project
python3 /home/richard/lsl-docs/tools/lsl_validator.py .

# Preprocess LSL file (includes/macros)
python3 /home/richard/lsl-docs/tools/lsl_preprocessor.py input.lsl processed_output.lsl
```

### Jenkins CI/CD Pipeline
The project uses automated CI/CD via `Jenkinsfile`:

```bash
# CI pipeline automatically runs on push:
# 1. LSL Validation - checks syntax and common errors
# 2. Preprocessing - handles includes/macros (main/develop branches)
# 3. Release Package Generation - creates versioned releases (main branch)
# 4. Documentation Updates - generates function lists (main branch)
```

### VS Code Development Tasks
Use VS Code Command Palette (`Ctrl+Shift+P`) → "Tasks: Run Task":

- **Validate LSL File** - Check current file syntax
- **Validate All LSL Files** - Check entire project
- **Open LSL Documentation** - Browser reference at https://lsl-docs.richardf.us
- **Search LSL Function** - Quick function lookup
- **Preprocess LSL File** - Process includes/macros

### Git Workflow
```bash
# Standard development workflow
git checkout -b feature/new-feature
# ... make changes to .lsl files ...
git add *.lsl README.md CHANGELOG.md
git commit -m "feat: description of changes"
git push origin feature/new-feature
# Create pull request to develop, then merge to main for releases
```

## Architecture Overview

### Single Linkset Design (v2.7.0+)
The system uses a unified 74-prim linkset eliminating all external communication:

```
Link 1: Main Controller (Root Prim)
├── Links 2-24: Scoreboard (23 prims)
│   ├── Link 2: Scoreboard Manager Script
│   ├── Link 3: Background Prim
│   ├── Link 4: Actions/Status Prim  
│   └── Links 5-24: Player Prims (20 slots with profile pics & hearts)
├── Links 25-72: XyzzyText Leaderboard (48 prims across 4 banks)
└── Links 73-74: Dice Display (2 prims for roll results)
```

### Core Script Architecture
**16 modular LSL scripts** with specific responsibilities:

**Core Controllers:**
- `Main_Controller_Linkset.lsl` - Central game state and coordination
- `Game_Manager.lsl` - Round management, pick validation, win conditions
- `Controller_Memory.lsl` - Memory monitoring and optimization
- `Controller_MessageHandler.lsl` - Message routing and communication

**Interface & Display:**
- `Player_DialogHandler.lsl` - Player UI and input processing
- `NumberPicker_DialogHandler.lsl` - Number picking interface
- `Game_Scoreboard_Manager_Linkset.lsl` - Visual player display (Link 2)
- `Floater_Manager.lsl` - Floating HUD displays for players
- `PlayerStatus_Float.lsl` - Individual player status displays

**Game Mechanics:**
- `Roll_ConfettiModule.lsl` - Dice rolling and particle effects
- `Bot_Manager.lsl` - AI player behavior and automation
- `Game_Calculator.lsl` - Dice type calculation and game math

**External Communication:**
- `Leaderboard_Communication_Linkset.lsl` - XyzzyText bridge (Link 25)
- `XyzzyText_Dice_Bridge_Linkset.lsl` - Roll result display (Link 73)

**Utilities:**
- `System_Debugger.lsl` - Development debugging tools
- `xyzzy_Master_script.lsl` - Legacy XyzzyText controller

### Communication Protocol
**Link Messages Only** - No region chat or discovery:
```lsl
// Scoreboard messages (to link 2)
integer MSG_GAME_STATUS = 3001;
integer MSG_PLAYER_UPDATE = 3002;
integer MSG_CLEAR_GAME = 3003;

// Leaderboard messages (to link 25)  
integer MSG_GAME_WON = 3010;
integer MSG_RESET_LEADERBOARD = 3012;

// Dice messages (to link 73)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;
```

**Benefits of this architecture:**
- **Zero Channel Conflicts** - Multiple game instances operate independently
- **50%+ Performance Improvement** - Instant message delivery vs. region chat
- **Bulletproof Reliability** - No discovery failures or timeouts
- **One-Click Deployment** - Single linkset rez replaces 4-object positioning

### Game State Management
**Critical synchronized data across scripts:**
- `players[]` - Avatar keys of registered players
- `names[]` - Display names of players  
- `lives[]` - Current life counts (3, 2, 1, 0)
- `perilPlayer` - Current player in peril
- `globalPickedNumbers[]` - Numbers chosen this round
- `picksData[]` - Player pick history ("PlayerName|1,2,3")

**State Synchronization Pattern:**
```lsl
// In any script modifying game state:
syncStateToMain(); // Updates Main Controller
llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, "", NULL_KEY); // Broadcast
```

### Dynamic Dice Scaling
Automatic dice selection ensures fair gameplay:
- 1-2 players → d6 (6 numbers)
- 3-4 players → d12 (12 numbers)  
- 5-6 players → d20 (20 numbers)
- 7-10 players → d30 (30 numbers)

*Guarantees exactly 3 numbers per player available*

## Key Architectural Principles

### 1. Link Message Communication
**All inter-script communication** uses `llMessageLinked()` for guaranteed delivery within the linkset. No external channels or discovery protocols.

### 2. Modular Script Responsibility
Each script has **single responsibility** - Game Manager handles rounds, Scoreboard Manager handles display, etc. No cross-dependencies.

### 3. State Synchronization
**Centralized state management** in Main Controller with broadcast synchronization to prevent data inconsistencies.

### 4. Race Condition Prevention
**Duplicate registration protection**, **timing controls**, and **request deduplication** prevent common LSL concurrency issues.

### 5. Professional Error Handling
**Comprehensive validation**, **graceful failures**, and **debug logging** ensure stable operation in Second Life's unpredictable environment.

## Important Implementation Details

### Display Name Handling
```lsl
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        displayName = llKey2Name(id); // Fallback to legacy username
    }
    return displayName;
}
```

### Memory Management
Controller_Memory.lsl actively monitors script memory usage and triggers cleanup when thresholds are exceeded. Critical for long-running Second Life objects.

### Security Features (v2.8.0+)
- **Game Lockout System** - Owner can restrict access to owner only
- **Kick Player Functionality** - Remove disruptive players
- **Automatic Reset on Startup** - Prevents stale data issues

### Critical Fixes (v2.8.2)
- **Scoreboard Spam Elimination** - Fixed major bug where eliminated players caused infinite sync loops
- **Peril Player Validation** - Enhanced elimination sequence to prevent stale sync messages
- **Main Controller Fix** - Updates peril player variable immediately after elimination before final sync
- **Re-Fixed Display Systems** - Peril status and 0 hearts display needed additional stabilization

### Enhanced Elimination Display (v2.8.1)
- Players see **0 hearts before elimination** with 1-second display
- **Real-time peril status updates** on floating displays
- **Proper elimination sequence** with visual feedback

## File Naming Conventions

**Do not rename files** - LSL scripts have specific names expected by the linkset architecture. The `_Linkset` suffix indicates scripts designed for specific link numbers.

**Script-to-Link Mapping:**
- `*_Linkset.lsl` → Specific link number scripts
- `*_Manager.lsl` → Core system controllers  
- `*_Handler.lsl` → UI and input processors
- `*_Module.lsl` → Specialized functionality (dice, confetti, etc.)

## Testing and Deployment

### Local Testing
Use **Bot Manager** to add AI players for testing game mechanics without requiring multiple avatars.

### CI/CD Pipeline
Jenkins automatically validates syntax and creates release packages on main branch pushes. Manual deployment to Second Life required.

### Version Management
Versions follow semantic versioning (v2.8.2) with detailed changelogs in `CHANGELOG.md` and `README.md`. Recent releases show the iterative nature of complex system maintenance, including addressing regressions in display systems.
