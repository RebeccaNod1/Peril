# 🎲 Peril Dice — Professional Single Linkset Game System for Second Life

**Created by Rebecca Nod and Noose the Bunny**  
**Current Version: 2.8.2 - Scoreboard Spam & Display Fixes**

## Overview

Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player's number is rolled, they lose a life. Players are eliminated when they reach zero lives.

**NEW in v2.8.2**: Fixed critical scoreboard spam bug caused by eliminated players, plus re-fixed peril status display on floaters and elimination heart updates to show 0 hearts before player removal.

**NEW in v2.8.0**: Game lockout security system, automatic reset functionality, and enhanced player management with kick/leave fixes for complete ownership control and stability.

**NEW in v2.7.0**: Complete architectural overhaul featuring consolidated single linkset design (74 prims total) with bulletproof link message communication, eliminating all channel conflicts and deployment complexity.

## Major v2.8.1 Improvements 🔧

### 🎯 **Peril Status Display Fixes**
- **Fixed Floater Status Updates**: Peril status on floating displays now properly updates during gameplay
- **Enhanced Status Messages**: Improved peril player display with clear "YOU ARE IN PERIL!" messaging
- **Real-Time Status Sync**: Floaters immediately reflect current peril player changes during rounds
- **Better Status Logic**: Fixed "waiting for game to start" showing during active gameplay
- **Improved Peril Tracking**: Enhanced sync message handling for consistent peril status across all displays

### 💖 **Elimination Heart Display Fixes**
- **0 Hearts Before Elimination**: Players now show 0 hearts on scoreboard and floaters before being removed
- **Visual Elimination Sequence**: 1-second display of 0 hearts allows players to see their elimination status
- **Proper Heart Updates**: Hearts correctly update to 0 before player cleanup and removal
- **Enhanced Elimination Flow**: Better timing between heart display and player removal
- **Scoreboard Synchronization**: Both scoreboard and floaters show elimination hearts consistently

### 🐛 **Bug Fixes**
- **Sync Message Debugging**: Added debug logging to track peril player status changes
- **Floater Update Reliability**: Improved floater update triggers during game state changes
- **Elimination Timing**: Fixed race condition where players were removed before showing 0 hearts
- **Status Display Logic**: Enhanced peril status determination in floater manager

## Major v2.8.0 Improvements 🔐

### 🔒 **Game Lockout Security System**
- **Owner-Only Lockout**: Game owners can lock their tables to restrict all access to owner only
- **Complete Access Control**: When locked, only the owner can access any dialogs or game features
- **Visual Lock Indicators**: Floating text dynamically updates to show "🔒 GAME LOCKED" status
- **Lock/Unlock Toggle**: Easy-to-use admin menu options for controlling game access
- **Clear User Feedback**: Non-owners receive clear messages when attempting to access locked games
- **Persistent Lock State**: Lock status maintained during gameplay and between sessions
- **Dialog Prevention**: Non-owners cannot even see dialogs when game is locked

### 🔄 **Automatic Reset on Startup**
- **Clean State Guarantee**: Game automatically resets when Main Controller is rezzed or updated
- **Script Update Protection**: Game Manager triggers reset when core logic is updated
- **Leaderboard Preservation**: Game state resets but historical win records are preserved
- **Consistent Experience**: Every startup provides fresh, ready-to-play game state
- **Stale Data Elimination**: Removes leftover players, ready states, or partial game progress
- **System Integrity**: All linked components properly cleared and synchronized on startup

### 👥 **Enhanced Player Management**
- **Kick Player Functionality**: Owners can now kick any registered player from the game
- **Smart Name Handling**: Automatic truncation of long display names to fit dialog buttons
- **Leave Game Fixes**: Completely rebuilt leave game system with proper state synchronization
- **Clean Player Removal**: Players removed from all game lists, scoreboards, and displays
- **Floater Cleanup**: Player floating displays properly cleaned up when leaving/kicked
- **Ready State Management**: Leaving players automatically removed from ready lists
- **Scoreboard Synchronization**: Visual scoreboard updated immediately when players leave

### 🎯 **Enhanced Admin Controls**
- **Categorized Owner Menu**: Organized admin interface with Player Management, Reset Options, and Troubleshooting
- **Security-First Design**: Lock/unlock controls prominently displayed in admin menu
- **Player Management Section**: Dedicated area for Add Test Player and Kick Player functions
- **Granular Reset Options**: Choose between game-only reset, leaderboard reset, or complete reset
- **Improved Navigation**: Clear menu structure with back navigation and contextual options
- **Troubleshooting Tools**: Cleanup floaters and force floater creation for debugging

### 🛠️ **System Reliability Improvements**
- **Race Condition Prevention**: Enhanced protection against duplicate registrations and state conflicts
- **Message Synchronization**: Improved communication between scripts for player state changes
- **Error Recovery**: Better handling of edge cases during player removal and registration
- **State Consistency**: All game components maintain synchronized player lists and states
- **Memory Management**: Proper cleanup of all player-related data structures

## Major v2.7.0 Improvements ✨

### 🏗️ **Single Linkset Architecture Revolution**
- **Complete System Consolidation**: Merged all 4 separate objects into unified 74-prim linkset
  - Controller (Link 1) + Scoreboard (Links 2-24) + Leaderboard (Links 25-72) + Dice Display (Links 73-74)
- **One-Click Deployment**: Single object rez replaces complex 4-object positioning system
- **Elimination of Region Chat**: All `llRegionSay()` communication replaced with instant `llMessageLinked()`
- **Zero Channel Conflicts**: Complete removal of hash-based dynamic channel system
- **Multi-Instance Support**: Multiple game tables operate without any interference
- **50%+ Performance Improvement**: Link messages provide immediate, guaranteed delivery

### 🎯 **Dice Type Synchronization Fixes**
- **Critical Race Condition Resolution**: Fixed major bug where Game Manager and Roll Module independently requested dice types
- **Consistent Dice Types**: Eliminated scenarios where players rolled different dice types (e.g., d6 vs d30)
- **Targeted Calculator Responses**: Calculator now responds only to requesting module, preventing stale data
- **Enhanced Game Flow**: Improved round completion detection and win condition logic
- **Bot Synchronization**: Fixed bot behavior inconsistencies with dice type coordination

### 🔄 **Clean Module Communication**
- **Link Message Routing**: Established clear communication paths within linkset
- **Module Independence**: Each component operates independently without cross-dependencies  
- **Bulletproof Reliability**: No discovery failures or communication timeouts
- **Professional Operation**: Clean console output without channel debugging noise

## Key Features

### 🏆 Visual Scoreboard System
- **Real-Time Player Grid**: Visual scoreboard showing all players with profile pictures and hearts
- **Profile Picture Integration**: Automatic avatar profile fetching from Second Life
- **Heart Texture Display**: Visual life representation (3, 2, 1, 0 hearts)
- **Instant Updates**: Hearts change immediately when lives are lost

### 🎭 Enhanced Status Display
- **Visual Status Actions**: Large status prim with custom textures for each game event
- **Specific Status Types**: Direct Hit, No Shield, Plot Twist, Elimination, Victory, etc.
- **Perfect Timing**: 8-second display time with protective delays to prevent overwriting

### 🎯 Comprehensive Leaderboard
- **Persistent Win Tracking**: Player victories saved across sessions
- **XyzzyText Display**: Professional 3-prim text system for leaderboard
- **Automatic Sorting**: Top players by win count

### 🎮 Core Game Features
- **🎯 Dynamic Player Management**: Players can join at runtime (owner and other avatars)
- **🤖 Bot Support**: Add AI bots for testing and gameplay variety  
- **📱 Floating HUD Display**: Real-time stats for each player
- **🎮 Intelligent Dice Sizing**: Automatic dice size based on player count
- **🔄 Ready State System**: Players must be ready before games start
- **🎭 Dramatic Messaging**: Immersive thematic announcements visible to all players
- **🎲 Context-Rich Rolls**: Detailed dice information with type and result
- **⚡ Performance Optimized**: Reduced lag with selective particle effects
- **🛡️ Robust Error Handling**: Comprehensive game state synchronization
- **🚫 Game Protection**: Prevents joining games in progress

## Game Rules

1. **Setup**: 2-10 players join the game
2. **Ready Phase**: All players except starter must mark themselves ready
3. **Picking Phase**: Each player picks 1-3 numbers (based on peril player's remaining lives)
4. **Rolling Phase**: Peril player rolls the dice
5. **Resolution**: 
   - If rolled number matches another player's pick → that player becomes new peril player (`⚡ PLOT TWIST!`)
   - If peril player picked the rolled number → they lose a life (`🩸 DIRECT HIT!`)
   - If nobody picked the rolled number → peril player loses a life (`🩸 NO SHIELD!`)
6. **Elimination**: Players with 0 lives are eliminated
7. **Victory**: Last player standing wins! 🏆



## How to Play

### For Owner
- **Touch object** → Access owner menu with categorized options
- **Lock/Unlock Game** → Restrict access to owner only or allow all players
- **Add Bot** → Add AI players for testing
- **Kick Player** → Remove any registered player from the game
- **Start Game** → Begin when all players are ready
- **Reset Game** → Reset to initial state (preserves leaderboard)
- **Reset Leaderboard** → Clear historical win records
- **Reset All** → Complete reset including leaderboard
- **Manage Picks** → View/modify player selections
- **Force Floaters** → Debug tool to recreate floating displays

### For Players
- **Touch object** → Register and join game
- **Ready/Not Ready** → Toggle your ready state
- **Pick Numbers** → Select your numbers when prompted
- **Roll Dice** → Roll when you're the peril player

## Single Linkset Architecture (v2.7.0)

The system now uses a unified 74-prim linkset with modular LSL scripts communicating via link messages:

### **Link Structure:**
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

### **Script Components:**
- **Main Controller (Link 1)**: Core game logic, state management, and central coordination
- **Game Manager**: Round management, pick validation, and win condition detection
- **Dialog Handlers**: User interface and input processing  
- **Roll Module**: Dice rolling, confetti effects, and result distribution
- **Bot Manager**: AI player behavior and automated gameplay
- **Floater Manager**: Floating HUD display management for all players
- **Game Calculator**: Dice type calculation and targeted responses
- **Scoreboard Manager (Link 2)**: Visual player display with hearts and profile pictures
- **Leaderboard Bridge (Link 25)**: XyzzyText distribution for win/loss tracking
- **Dice Bridge (Link 73)**: Real-time dice roll result display

### **Communication Flow:**
- **Link Messages Only**: All communication uses `llMessageLinked()` within the linkset
- **Zero External Dependencies**: No region chat channels or object discovery
- **Instant Delivery**: Guaranteed message delivery without network delays
- **Multi-Instance Safe**: Multiple game tables operate independently

## Dice Scaling

Dice type is automatically chosen to ensure at least 3 picks per player:

| Player Count | Dice Type |
|--------------|-----------|
| 1–2          | d6        |
| 3–4          | d12       |
| 5–6          | d20       |
| 7–10         | d30       |

## Previous Improvements (v2.6.0) - **SUPERSEDED by v2.7.0**

> **⚠️ Note**: The v2.6.0 channel management system was completely replaced in v2.7.0 with the single linkset architecture. All channel-related features have been removed in favor of link message communication.

### 📡 Advanced Channel Management System *(REMOVED in v2.7.0)*
- **Dynamic Channel Calculation**: Sophisticated channel assignment preventing conflicts between multiple game instances
- **Multi-Instance Support**: Multiple game tables can operate simultaneously without channel interference
- **Hash-Based Uniqueness**: MD5-based channel calculation using owner + object keys for complete isolation
- **Automatic Channel Assignment**: All components get unique channel ranges (~-78000 to ~-86000)
- **Channel Debugging Tools**: Detailed channel assignments reported to owner on startup

### 🧹 Debug Output Cleanup Campaign *(RETAINED & ENHANCED)*
- **Reduced Log Spam**: Eliminated verbose debug messages causing console chat spam
- **Professional Operation**: Game now operates with minimal noise, focusing on essential information
- **Performance Enhancement**: Reduced string processing overhead from debug message removal
- **Clean Monitoring**: Easier to spot actual issues without debug noise overwhelming chat
- **Production Ready**: Professional-grade logging levels suitable for live deployment

## Previous Improvements (v2.5.0)

### 🛡️ Registration Security Fixes
- **Duplicate Registration Prevention**: Fixed critical bug where rapid clicking could create duplicate player entries
- **Startup Sequence Protection**: Eliminated timing window allowing unwanted joins during game initialization
- **Enhanced Game Flow Control**: Better state management and user feedback during registration processes
- **Race Condition Resolution**: Comprehensive fixes for all registration-related race conditions
- **Duplicate Pick Prevention**: Fixed intermittent duplicate number picks caused by data corruption in `globalPickedNumbers`
- **Data Integrity**: Enhanced `continueCurrentRound()` function to properly rebuild pick tracking with uniqueness validation
- **Server-Side Pick Validation**: Added robust server-side validation to prevent duplicate number picks with immediate error feedback
- **Enhanced Display Name Handling**: Robust player name resolution with smart fallback system
  - Prioritizes modern display names for optimal user experience
  - Automatically falls back to legacy usernames when display names unavailable
  - Handles network issues, offline avatars, and viewer compatibility seamlessly
  - Ensures consistent name display across all game components and messages

## Previous Improvements (v2.4.0)

### 📍 Position Management System
- **Master-Follower Architecture**: Controller object manages position of all game components
- **Automatic Position Sync**: Scoreboard, leaderboard, and displays move with main controller
- **Config-Based Setup**: Position offsets and rotations defined in notecard configuration
- **Position Reset Tools**: Easy recalibration system for repositioning game components
- **Coordinated Movement**: All objects maintain relative positions when game is moved

### 🧹 Production Code Cleanup
- **Debug Code Removal**: Complete removal of all debug logging and test messages for production deployment
- **Syntax Error Fixes**: Resolved critical syntax errors including missing braces in conditional blocks
- **Code Optimization**: Cleaner, more maintainable codebase without development artifacts
- **Performance Enhancement**: Reduced script memory usage and execution overhead

### 🏆 Visual Scoreboard Revolution (v2.3.0)
- **Real-Time Visual Display**: Complete visual overhaul with player grid showing profile pictures and hearts
- **Instant Heart Updates**: Hearts change immediately when lives are lost, before any dialogs appear
- **Profile Picture Fetching**: Automatic HTTP requests to get actual Second Life avatar pictures
- **0-Hearts Display**: Shows elimination sequence visually before player removal

### 🎭 Enhanced Status System (v2.3.0)
- **Specific Status Types**: Separate textures for Direct Hit, No Shield, Plot Twist, Elimination, Victory
- **Perfect Timing**: 8-second display with 2-second protective delays prevent status overwriting
- **Visual Impact**: Large action prim displays current game status with custom textures

### 🎯 Comprehensive Leaderboard (v2.3.0)
- **Persistent Win Tracking**: Player victories saved across game sessions using linkset data
- **Professional Display**: XyzzyText 3-prim system for clean leaderboard presentation
- **Flexible Reset Options**: Separate commands for game reset, leaderboard reset, or complete reset

### 🔧 Critical Fixes
- **Heart Update Timing**: Fixed hearts not updating until after next-turn dialog
- **Status Conflicts**: All status messages now have protective delays to prevent overwriting
- **Victory/Elimination Flow**: Proper 6.4-second delay between elimination and victory status
- **Syntax Errors**: Fixed missing braces and other LSL compilation issues

## Version

**Current Version**: 2.8.2  
**Last Updated**: August 21, 2025  
**Status**: Production Ready - Scoreboard Spam & Display Fixes

### Key Achievements in v2.8.2:
- ✅ Fixed critical scoreboard spam bug caused by eliminated players
- ✅ Enhanced peril player validation during elimination sequences
- ✅ Re-fixed peril status display on floating HUDs during gameplay
- ✅ Re-fixed elimination sequence to show 0 hearts before player removal
- ✅ Improved sync message reliability to prevent stale data broadcasts
- ✅ Enhanced elimination timing and coordination between display systems

### Key Achievements in v2.8.1:
- ✅ Fixed peril status display on floating HUDs during gameplay
- ✅ Enhanced elimination sequence to show 0 hearts before player removal
- ✅ Improved real-time status synchronization across all displays
- ✅ Added debug tracking for peril player status changes
- ✅ Enhanced floater update reliability during game state changes
- ✅ Fixed race conditions in elimination heart display timing

### Key Achievements in v2.8.0:
- ✅ Implemented owner-only game lockout system
- ✅ Added automatic game reset on startup (preserves leaderboard)
- ✅ Added Kick Player functionality to admin menu
- ✅ Rebuilt Leave Game system for proper state synchronization
- ✅ Enhanced admin controls with categorized menus
- ✅ Improved system reliability with race condition prevention

---

## Original Game Rules Credit

Game rules were created by **Noose the Bunny** (djmusica28) in Second Life. This automated version builds upon their original manual gameplay concept.

### Original Manual Rules Summary:
- Each player starts with 3 lives
- Players pick numbers based on peril player's remaining lives:
  - 3 Lives → Pick 1 number
  - 2 Lives → Pick 2 numbers  
  - 1 Life → Pick 3 numbers
- Roll dice to determine outcome
- Last player with lives wins

---

*Peril Dice provides hours of entertainment for Second Life communities with its blend of strategy, luck, and social interaction!*
