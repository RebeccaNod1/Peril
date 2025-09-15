# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

**Peril Dice** is a multiplayer elimination game for Second Life, built using LSL (Linden Scripting Language). It's a professional-grade linkset system where players select numbers before dice rolls, with the peril player losing lives when their number comes up. The project features a single 74-prim linkset architecture with sophisticated inter-script communication.

**Current Version**: 2.8.5 - Memory Optimization & Direct Communication Architecture
**Technology**: LSL (Linden Scripting Language) for Second Life virtual world  
**Architecture**: Single linkset with 16+ modular LSL scripts using optimized direct communication

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

### Core Script Architecture (OPTIMIZED v2.8.5)
**17 modular LSL scripts** with memory-optimized direct communication:

**Core Controllers:**
- `Main_Controller_Linkset.lsl` - Master game state coordination (87% memory usage)
- `Game_Manager.lsl` - Round management and game flow logic  
- `Controller_Memory.lsl` - Memory monitoring and optimization
- `Controller_MessageHandler.lsl` - Message routing and communication

**Player Management (NEW OPTIMIZATION):**
- `Player_RegistrationManager.lsl` - **Authoritative player registry and dialog forwarding** (23% memory usage)
- `Player_DialogHandler.lsl` - Player UI and admin menu processing
- `NumberPicker_DialogHandler.lsl` - Number picking interface

**Interface & Display:**
- `Game_Scoreboard_Manager_Linkset.lsl` - Visual player display (Link 12)
- `Floater_Manager.lsl` - Floating HUD displays for players
- `PlayerStatus_Float.lsl` - Individual player status displays

**Game Mechanics:**
- `Roll_ConfettiModule.lsl` - **Direct dice rolling, scoreboard & dice display updates**
- `Bot_Manager.lsl` - AI player behavior with direct Game Manager communication
- `Game_Calculator.lsl` - **Direct dice type calculation and distribution**
- `UpdateHelper.lsl` - Batch update processing for memory efficiency

**External Communication:**
- `Leaderboard_Communication_Linkset.lsl` - XyzzyText bridge (Link 35)
- `XyzzyText_Dice_Bridge_Linkset.lsl` - Roll result display (Link 83)

**Utilities:**
- `System_Debugger.lsl` - Development debugging tools
- `Verbose_Logger.lsl` - **Memory-efficient logging system**

### Communication Protocol (OPTIMIZED DIRECT ARCHITECTURE)
**Direct Script-to-Script Communication** - Eliminates Main Controller routing bottlenecks:

```lsl
// DIRECT COMMUNICATION FLOWS:

// Game Manager → NumberPicker (bypasses Main Controller)
integer MSG_SHOW_DIALOG = 101;

// Game Manager → Roll Module (bypasses Main Controller)  
integer MSG_SHOW_ROLL_DIALOG = 301;

// Roll Module → Scoreboard (bypasses Main Controller)
integer MSG_PLAYER_UPDATE = 3002;  // Link 12
integer MSG_GAME_STATUS = 3001;

// Roll Module → Dice Display (bypasses Main Controller)
integer MSG_DICE_ROLL = 3020;       // Link 83

// Player Registration → Dialog Forwarding
integer MSG_DIALOG_FORWARD_REQUEST = 9060;

// Calculator → Direct Distribution
integer MSG_DICE_TYPE_RESULT = 1005;
```

**Revolutionary Architecture Benefits:**
- **4-5% Memory Reduction** in Main Controller (from 92%+ to 87.68%)
- **Real-time Updates** - Direct scoreboard and display communication
- **Load Balancing** - Heavy processing distributed across specialized scripts
- **Authoritative Data Sources** - Player_RegistrationManager maintains player keys
- **Zero Message Routing Overhead** - Scripts communicate directly when possible

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

### Memory Optimization Architecture (v2.8.5)
- **Direct Communication Pathways** - Eliminated Main Controller routing bottlenecks
- **Player_RegistrationManager** - Dedicated player key management and dialog forwarding
- **Load-Balanced Processing** - Heavy operations distributed across scripts with available memory
- **Authoritative Data Sources** - Each script maintains its area of expertise
- **4-5% Memory Recovery** - Main Controller reduced from 92%+ to 87.68% usage

### Registration & Dialog Flow Optimization (v2.8.5)
```lsl
// OPTIMIZED REGISTRATION FLOW:
// 1. Main Controller → Player_RegistrationManager (registration request)
// 2. Player_RegistrationManager → Handles ALL heavy processing
// 3. Player_RegistrationManager → Scoreboard (direct player update)
// 4. Player_RegistrationManager → Main Controller (minimal essential data)

// OPTIMIZED DIALOG FLOW:
// 1. Game Manager → Player_RegistrationManager (dialog request with player name)
// 2. Player_RegistrationManager → NumberPicker/Roll Module (with correct player key)
```

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
