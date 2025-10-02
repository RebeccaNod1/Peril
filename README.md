# 🎲 Peril Dice — Professional Single Linkset Game System for Second Life

**Created by Rebecca Nod and Noose the Bunny**  
**Current Version: 2.8.7 - GitHub Update System & Linkset Analysis Tools**

## Overview

Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player's number is rolled, they lose a life. Players are eliminated when they reach zero lives.

**🔄 NEW in v2.8.7**: **GITHUB UPDATE SYSTEM** - Revolutionary in-world update checker that connects directly to GitHub releases, with smart file filtering and precise linkset deployment instructions. Includes Enhanced LinkScanner for complete 84-prim structure analysis.

**🏆 NEW in v2.8.6**: **WINNER GLOW CELEBRATION SYSTEM** - Revolutionary winner recognition with bright green glow effects on both scoreboard and floaters, plus 24-second victory celebration timer giving proper recognition to the Ultimate Survivor before game reset.

**🚨 NEW in v2.8.5**: **MEMORY OPTIMIZATION & ARCHITECTURE CLEANUP** - Major system cleanup eliminating dead code, fixing bot profile picture flickering, and optimizing memory usage across all scripts with measurable performance improvements.

**NEW in v2.8.4**: **DISCONNECT RECOVERY & DEBUG SYSTEM** - Revolutionary disconnect/reconnect recovery system eliminates need to kick players who disconnect during their turn, plus comprehensive system-wide verbose logging toggle.

**NEW in v2.8.3**: **CRITICAL BUG FIXES** - Fixed major shield detection logic error causing incorrect "NO SHIELD!" messages when shields were actually provided, plus complete initialization system overhaul eliminating the need for manual script reset after rezzing.

**NEW in v2.8.2**: Fixed critical scoreboard spam bug caused by eliminated players, plus re-fixed peril status display on floaters and elimination heart updates to show 0 hearts before player removal.

**NEW in v2.8.0**: Game lockout security system, automatic reset functionality, and enhanced player management with kick/leave fixes for complete ownership control and stability.

**NEW in v2.7.0**: Complete architectural overhaul featuring consolidated single linkset design (74 prims total) with bulletproof link message communication, eliminating all channel conflicts and deployment complexity.

## Major v2.8.7 Improvements 🔄

### 🔄 **GitHub Update System**
- **In-World Update Checker**: Revolutionary `Update_Checker.lsl` script provides direct GitHub integration
  - **GitHub API Integration**: Connects to `https://github.com/RebeccaNod1/Peril/releases` for automatic update detection
  - **Smart File Filtering**: Only downloads essential game files, excludes development/test files
  - **Precise Deployment Instructions**: Tells you exactly which link each script belongs on
  - **Owner Menu Integration**: Access via Owner Menu → Troubleshooting → Check for Updates
  - **Chat Commands**: `/1 check`, `/1 download ScriptName.lsl`, `/1 list` for direct access
- **Memory Optimized**: Fits perfectly in the slot freed by eliminated UpdateHelper.lsl (v2.8.5)
- **Professional Error Handling**: Clear feedback for network issues, missing releases, file validation

### 🔍 **Enhanced LinkScanner System**
- **Complete 84-Prim Analysis**: `Enhanced_LinkScanner.lsl` provides detailed linkset structure mapping
  - **VERIFIED Structure**: Based on actual linkset scan showing exact prim names and positions
  - **Script Placement Guide**: Shows which scripts belong on which links with verification
  - **XyzzyText Mapping**: Detailed analysis of all 48 leaderboard prims (Links 35-82)
  - **Update Deployment Guide**: Generates precise instructions for Update_Checker placement
- **Real-Time Validation**: Touch to scan and verify current linkset matches expected architecture
- **Professional Output**: Categorized analysis with deployment recommendations

### 🎯 **Smart File Classification**
- **Essential Game Files Only**: Update system intelligently filters files for end users
  - **✅ Included**: All LSL scripts, documentation (README, CHANGELOG, notecards)
  - **🚫 Excluded**: lsl_validator.py, debug_mcp.py, test_*.py, MCP files, templates
- **Link-Specific Instructions**: Downloads include verified deployment locations
  - **Link 1**: 13 root prim scripts + Update_Checker.lsl
  - **Link 12**: "scoreboard manager cube" - Game_Scoreboard_Manager_Linkset.lsl
  - **Link 35**: "leaderboard row 1 col 1" - Leaderboard_Communication_Linkset.lsl
  - **Links 35-82**: All 48 XyzzyText prims need xyzzy_Master_script.lsl
  - **Link 83**: "dice col 1" - XyzzyText_Dice_Bridge_Linkset.lsl

### 🚀 **Zero-Infrastructure Updates**
- **No Update Server Required**: Leverages existing GitHub + Jenkins CI/CD pipeline perfectly
- **Automatic Release Detection**: Finds new versions as soon as they're tagged and released
- **Individual File Updates**: Download specific scripts without full release packages
- **GitHub Raw Integration**: Direct access to latest files from main branch
- **Multi-Instance Safe**: Multiple game tables can check for updates independently

### 🎨 **Professional User Experience**
- **Clear Version Information**: Shows current vs latest versions with release dates
- **Release Notes Preview**: Displays first 200 characters of GitHub release notes
- **Download Progress**: File size reporting and content preview for verification
- **Deployment Verification**: Confirms updates are designed for verified 84-prim structure
- **Graceful Error Handling**: Helpful messages for GitHub rate limits, missing files, etc.

### 📊 **System Integration Benefits**
- **Replaces Eliminated UpdateHelper**: Perfect use of memory freed in v2.8.5 optimization
- **Existing Admin Menu**: Integrates seamlessly with current troubleshooting interface
- **Message Protocol Compatibility**: Uses established link message patterns and constants
- **Verbose Logging Support**: Follows existing debug toggle system
- **Memory Reporting**: Includes standard memory usage reporting like other scripts

### 💱 **Before vs After v2.8.7**
| **Before** | **After** |
|------------|----------|
| ❌ Manual update distribution via inventory | ✅ Automatic GitHub integration with update detection |
| ❌ No way to check for new versions | ✅ One-click update checking via `/1 check` or admin menu |
| ❌ Guessing which scripts go where | ✅ Precise deployment instructions verified by linkset scan |
| ❌ Development files mixed with game files | ✅ Smart filtering shows only essential files |
| ❌ No linkset structure validation | ✅ Complete 84-prim analysis and verification tools |

## Major v2.8.6 Improvements 🏆

### 🏆 **Winner Glow Celebration System**
- **Revolutionary Victory Recognition**: Comprehensive winner celebration with bright green glow effects
  - **Scoreboard Glory**: Winner's profile picture and hearts glow bright green with green tint
  - **Floater Celebration**: Winner's floating display shows green glow with victory text "✨ ULTIMATE VICTORY! ✨"
  - **Visual Priority System**: Winner glow (green) overrides peril glow (yellow) during victory celebration
  - **Professional Polish**: Eliminated players show red X while winner gets the spotlight
- **Extended Victory Moment**: 24-second celebration timer before game reset
  - **Before**: Winner announced → Instant reset → No recognition
  - **After**: Winner announced → Green glow celebration → 24 seconds of glory → Reset
  - **Player Experience**: Proper victory moment makes winning feel rewarding and celebrated

### 🎨 **Enhanced Visual Feedback System**
- **Improved Glow Colors**: Professional-grade color tinting system
  - **Winner Recognition**: Bright green glow + green tint for unmistakable victory celebration
  - **Peril Identification**: Yellow glow + yellow tint for clear peril player status
  - **Visual Clarity**: Replaced generic white glow with distinct colored feedback
- **Smart Winner Detection**: Floaters automatically detect victory conditions and display celebration text
- **Synchronized Effects**: Both scoreboard and floater systems celebrate winner simultaneously

### 🔧 **System Optimization**
- **Victory Timer System**: Dedicated timer mode for celebration delays without system interference
- **Memory Efficiency**: Removed unused timeout components to free up memory resources
- **Enhanced Communication**: Improved message routing for winner glow effects
- **Clean Architecture**: Streamlined systems focus on essential functionality

### 🎯 **Before vs After v2.8.6**
| **Before** | **After** |
|------------|----------|
| ❌ Winner announced but no visual celebration | ✅ Bright green glow celebration on scoreboard and floaters |
| ❌ Immediate reset after victory - no recognition | ✅ 24-second victory celebration timer for proper recognition |
| ❌ Generic white glow effects | ✅ Professional colored glow system (green/yellow/red) |
| ❌ Winners felt unrewarded | ✅ Ultimate Survivors get proper celebration and recognition |

## Major v2.8.5 Improvements 🚨

### 🧠 **Memory Optimization & Dead Code Cleanup**
- **UpdateHelper.lsl Elimination**: Completely removed vestigial 204-line script consuming ~41KB memory but providing zero functionality
  - **Discovery**: UpdateHelper existed but was never actually called - pure dead code waste
  - **Impact**: Main Controller memory usage improved from 83.8% to 81.4% (2.4% reduction)
  - **Cleanup**: Removed all supporting infrastructure, message constants, variables, handlers
  - **Simplification**: Direct scoreboard updates instead of complex but unused delegation system
- **Verbose_Logger Streamlined**: Simplified debug system by 47% while keeping essential functionality
  - **Size Reduction**: 149 lines → 80 lines by removing unused buffering system
  - **Performance**: Eliminated timer overhead and message processing complexity
  - **Kept**: Core debug toggle functionality that's actually used

### 🎨 **Bot Profile Picture Fix** 
- **Fixed Visual Glitch**: Resolved bot avatars randomly turning into gray boxes mid-game
  - **Issue**: Scoreboard refresh would reset ALL profiles to gray before restoration
  - **Root Cause**: `refreshPlayerDisplay()` function caused visual flicker during player removal
  - **Solution**: Modified refresh to only reset unused slots, preserving active player textures
  - **Enhancement**: Bots now cache robot texture directly to prevent HTTP requests
  - **Result**: Consistent bot avatars throughout entire game without gray box flickering

### 🏗️ **Architecture Optimization**
- **Link Number Reorganization**: Updated entire system to optimized linkset structure
  - **Scoreboard Manager**: Link 2 → Link 12 (moved for overlay prim accommodation)
  - **Leaderboard Manager**: Link 25 → Link 35 (updated to links 35-82 range)
  - **Dice Display**: Link 73 → Link 83 (maintained 2-prim dice system)
  - **System-Wide Update**: 11 scripts updated with new mappings and prim ranges
- **Enhanced Prim Structure**: Better organized linkset for performance and future development
  - **Overlay Prims**: Dedicated elimination marker prims (links 2-11)
  - **Scoreboard Optimization**: Profile/hearts prims properly mapped to new structure
  - **XyzzyText Enhancement**: Leaderboard banks updated for new architecture

### 🔧 **Enhanced Game Logic & Bug Fixes**
- **Number Picker Enhancement**: Improved parsing for mixed number formats
  - **Format Support**: Handles both CSV ("1,2,3") and semicolon ("1;2;3") formats
  - **Whitespace Handling**: Trims formats like "5, 6" vs "5,6" for consistency
  - **Bot Integration**: Enhanced bot processing with avoid lists from human players
- **Bot Manager Improvements**: Better round detection and fair play mechanics
  - **Round Detection**: Enhanced detection through peril player and lives changes
  - **Fair Play**: Bots now properly avoid numbers picked by human players
  - **Command Processing**: Improved bot handling and duplicate pick prevention
- **Communication Fixes**: Enhanced region messaging and player feedback systems

### 📊 **Performance Impact**
- **Memory Efficiency**: Measurable reduction in memory consumption across multiple scripts
- **Visual Stability**: Eliminated profile picture flickering and display inconsistencies  
- **Code Quality**: Cleaner, more maintainable codebase with reduced complexity
- **Message Traffic**: Reduced unnecessary inter-script communication overhead
- **Architecture**: More organized and scalable linkset structure

### 📊 **Before vs After v2.8.5**
| **Before** | **After** |
|------------|----------|
| ❌ Dead UpdateHelper consuming 41KB memory | ✅ Eliminated dead code, 2.4% memory improvement |
| ❌ Bot profiles flicker to gray boxes | ✅ Stable bot avatars throughout game |
| ❌ Complex unused buffering systems | ✅ Streamlined, focused functionality |
| ❌ Scattered link architecture | ✅ Organized, optimized linkset structure |
| ❌ Inconsistent number format handling | ✅ Robust parsing for all formats |

## Major v2.8.4 Improvements

### 🔍 **System-Wide Verbose Logging Toggle**
- **One-Click Debug Control**: Comprehensive verbose logging system across all 14 game modules
  - **Easy Access**: Added "Toggle Verbose Logs" in Owner Menu → Troubleshooting for instant access
  - **Real-Time Toggle**: Enable/disable detailed debug messages instantly without script restart
  - **Universal Sync**: One toggle affects all modules simultaneously for consistent logging state
  - **Production Mode**: When disabled, only essential errors and public announcements shown
  - **Development Mode**: When enabled, shows internal operations, sync messages, state changes, diagnostics
- **Complete Coverage**: Main Controller, Game Manager, Floater Manager, Bot Manager, Roll Module, NumberPicker Handler, Message Handler, Game Calculator, System Debugger, Memory Controller, Scoreboard Manager, Leaderboard Communication, Dice Bridge

### 🔧 **Revolutionary Disconnect/Reconnect Recovery**
- **The Nooser Problem - SOLVED**: Fixed major issue where disconnected players broke games
  - **Before**: Player disconnects during turn → Game stuck → Return shows wrong menu → Requires kick to continue
  - **After**: Player disconnects during turn → Return automatically restores correct dialog → Game continues seamlessly
- **Smart State Recovery**: Automatic detection and repair of corrupted game state
  - **Intelligent Detection**: Compares who SHOULD be picking with who system THINKS is picking  
  - **Auto-Repair**: Fixes `currentPicker` corruption when players reconnect
  - **Universal Coverage**: Works for both number picking and dice rolling phases
- **"Welcome Back" Experience**: Clear feedback when players return ("Welcome back! Restoring your number picking dialog...")
- **Owner Emergency Recovery**: If game gets completely stuck, owner touch forces resume
- **No More Kicks**: Eliminates need to kick players just because they disconnected

### 🎯 **Enhanced Dialog Protection System**
- **Stale Dialog Prevention**: Advanced validation prevents outdated number selections
  - **Multi-Layer Protection**: Session validation, player validation, number availability checking
  - **Smart Rejection**: Automatically blocks selections for numbers already picked by others
  - **Race Condition Prevention**: Protects against players clicking cached dialog buttons after state changes
- **Improved Dialog Recovery**: Better system for restoring dialogs after disconnections
- **Session Management**: Enhanced tracking prevents dialog conflicts and confusion

### 🔍 **Number Detection & Shield Logic Fixes**
- **Fixed "Numbers Not Showing" Issue**: Resolved major bug where system couldn't see numbers players had picked
  - **Problem**: Game would show "NO SHIELD!" even when players had actually picked the rolled number
  - **Root Cause**: Pick data synchronization issues between modules causing invisible player selections
  - **Solution**: Enhanced pick data validation and sync message reliability across all game modules
  - **Impact**: Shield detection now works correctly - proper "PLOT TWIST!" and shield mechanics restored

### ❌ **Enhanced Elimination Visual Feedback**
- **Red X Elimination Marker**: Added clear visual indicator for eliminated players on scoreboard
  - **Visual Enhancement**: Eliminated players now display a red X overlay on their profile picture
  - **Immediate Feedback**: Red X appears instantly when player reaches 0 lives for clear elimination status
  - **Persistent Display**: Red X remains visible on scoreboard until game reset for historical reference
  - **User Experience**: Players can easily see who has been eliminated without checking heart counts
  - **Credit**: Feature suggested by Pawkaf (pawkaf.lutrova)

### 🛡️ **Game State Stability Improvements**
- **Sync Message Reliability**: Fixed various state synchronization issues causing game confusion
- **Pick Queue Protection**: Enhanced management prevents corruption during disconnections  
- **Display Consistency**: Fixed cases where different systems showed conflicting game state
- **Race Condition Prevention**: Proper sequencing for state updates during player disconnections

### 🐛 **Critical Compilation Fixes**
- **LSL Syntax Corrections**: Fixed multiple script compilation errors
  - **Issue**: Mid-block variable declarations and ternary operators not supported in LSL
  - **Files Fixed**: All 14 game modules corrected for proper LSL syntax
  - **Solution**: Converted problematic code to proper LSL conditional statements
- **100% Compilation Success**: All scripts now compile without errors

### 🎮 **Seamless User Experience** 
- **No More Game Breaking**: Player disconnections no longer disrupt game flow
- **Graceful Recovery**: Players return to exactly where they left off
- **Clear Feedback**: Status messages show when debug logging is toggled
- **Owner Control**: Easy debug access through familiar menu system
- **Professional Operation**: Clean, reliable gameplay for all participants

### 📈 **Before vs After v2.8.4**
| **Before** | **After** |
|------------|----------|
| ❌ Player disconnects → Game breaks | ✅ Player disconnects → Returns seamlessly |
| ❌ Must kick disconnected players | ✅ Auto-recovery, no kicks needed |
| ❌ Debug info always on or always off | ✅ One-click verbose logging toggle |
| ❌ State corruption from disconnections | ✅ Automatic state detection and repair |
| ❌ Compilation errors in multiple scripts | ✅ All scripts compile successfully |

## Major v2.8.3 Improvements

### 🛡️ **Shield Detection Logic - CRITICAL BUG FIX**
- **MAJOR ISSUE FIXED**: Shield detection was incorrectly reporting "NO SHIELD!" when shields were actually provided
  - **Example Bug**: Game said "Nobody picked 1" even when Rebecca had picked "3, 1" - Taylor took undeserved damage
  - **Root Cause**: Shield logic was checking if ONLY the peril player picked the number instead of if ANYONE picked it
  - **Fix**: Shield detection now uses correct `matched` flag (anyone picked) instead of `perilPickedIt` flag (only peril player)
  - **Impact**: Players no longer take undeserved damage when others provide proper shields
- **Logic Correction**:
  - ✅ **NO SHIELD**: Only when nobody picked the rolled number (`!matched`)
  - ✅ **DIRECT HIT**: When peril player picked their own doom (`matched && perilPickedIt`)
  - ✅ **PLOT TWIST**: When someone else picked it but not peril player

### 🎯 **Complete Initialization System Overhaul**
- **MAJOR ISSUE FIXED**: "Can't join after rez" problem requiring manual script reset
  - **Problem**: When rezzing from inventory, players couldn't join until all scripts were manually reset
  - **Root Cause**: Critical scripts weren't resetting their state variables on rez, causing stale data conflicts
- **Comprehensive Script Fixes**: Added complete `on_rez()` handlers to all critical scripts:
  - 🎯 **Game_Manager.lsl**: Core game logic (20+ variables reset)
  - 🎲 **Roll_ConfettiModule.lsl**: Dice rolling and shield detection  
  - 🎮 **NumberPicker_DialogHandler.lsl**: Player number selection dialogs
  - 🤖 **Bot_Manager.lsl**: Bot player automation
  - 📦 **Floater_Manager.lsl**: Player status floating displays
  - 🎭 **Player_DialogHandler.lsl**: Player and owner menu systems
  - 🧮 **Game_Calculator.lsl**: Dice type calculations
- **Each Fix Includes**:
  - ✅ Complete state variable reset to initial values
  - ✅ Dynamic channel re-initialization for unique instance communication  
  - ✅ Old listener cleanup and fresh listener setup
  - ✅ Stale game data clearing (picks, player lists, dialog sessions)
  - ✅ Critical flag reinitialization (roundStarted, rollInProgress, etc.)
- **🎮 IMPACT**: **Game is now immediately ready for players after rezzing - NO manual script reset required!**

### 🏆 **Player Experience Revolution**
- **Instant Playability**: Games rezzed from inventory work immediately
- **Fair Shield Mechanics**: Shields now work correctly - no more undeserved damage
- **Clean State Guarantee**: Every game instance starts completely fresh
- **Reliable Dialog Systems**: Number picking works immediately after rez
- **Zero Setup Time**: Rez → Touch → Join → Play (no waiting, no resets)

### 📈 **Before vs After**
| **Before v2.8.3** | **After v2.8.3** |
|------------------|-------------------|
| ❌ Required manual "Reset Scripts" | ✅ Immediate playability after rez |
| ❌ Shield detection failed | ✅ Shields work correctly |
| ❌ Stale data from previous sessions | ✅ Clean state every time |
| ❌ "Join" button didn't work | ✅ Players can join immediately |
| ❌ Inconsistent game behavior | ✅ 100% reliable initialization |

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

**Current Version**: 2.8.3  
**Last Updated**: September 1, 2025  
**Status**: Production Ready - Shield Detection & Initialization Fixes

### Key Achievements in v2.8.3:
- ✅ **CRITICAL FIX**: Shield detection logic corrected - no more undeserved damage when shields are provided
- ✅ **MAJOR FIX**: Complete initialization system overhaul - games work immediately after rezzing
- ✅ Added comprehensive `on_rez()` handlers to all critical scripts (7 scripts updated)
- ✅ Each script now properly resets 20+ state variables on rez for clean game state
- ✅ Dynamic channel re-initialization ensures unique communication per game instance
- ✅ Eliminated need for manual "Reset Scripts" - games are instantly ready after rez

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
