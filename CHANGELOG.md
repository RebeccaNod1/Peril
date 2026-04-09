# Changelog

**Peril Dice Game System - Created by Rebecca Nod and Noose the bunny**

All notable changes to Peril Dice will be documented in this file.

## [3.3.0] - 2026-04-09
### 🏁 **Final Production Sweep (Tournament Edition)**
- **Global Silence**: Implemented unconditional stripping of all debug string literals using the `DEBUG_LOGS 0` pre-processor macro across the entire codebase.
- **Memory Hardening**: Set `SHOW_MEMORY 0` to eliminate runtime memory reporting overhead during high-traffic tournament play.
- **Repository Sanitization**: Purged all legacy GitHub updater documentation and development tools (`lsl_validator`, etc.) for a clean production package.
- **Sentinel finalization**: Verified "Auto-Pilot" Sentinel 7.9.2 for automated, no-touch land diagnostics.

### 🎰 **v3.3.0: Final Production Sweep - Global Silence & Memory Hardening**
- **Personalized Gaming UI**: Human players now automatically receive a temporary, Experience-authorized HUD (Final Girlz I.N.C.) snapping to **Center 2**.
- **Spectator AI Visibility**: Bots continue to rez in-world floaters, ensuring spectators can follow along with the AI's performance.
- **Direct-Target Signaling**: Switched to `llRegionSayTo(avKey, ...)` for cleanup pulses, ensuring HUDs reliably hear their "Self-Destruct" command.
- **Auto-Cleanup Handshake**: Uses `llDetachFromAvatar()` to instantly purge temporary HUDs upon game end or reset without inventory clutter.
- **Root-Key Unification**: All channel calculations now use the **Root Link Key** (`llGetLinkKey(1)`), preventing "Signal Drift" between scripts in different prims.

## [3.2.6] - 2026-04-05

### 🛡️ **Experience Sentinel (Diag Prototype v7.3)**
- **Auto-Pilot Diagnostic (v7.9.2)**: Operates automatically on rez and reset—no manual touch-trigger required.
- **Logically Sequenced Status**: Reordered the diagnostic header to appear before the result, ensuring a professional chronological flow.
- **Definitive Denial Capture**: Silent watchdog catches land blocks (Reason 17) and reports them only when necessary.

## [3.2.0] - 2026-04-05

### 🛡️ **Sync Sanctity (Engine Core)**
- **Master Ledger Protocol**: Refactored the core synchronization engine to use the `Main_Controller` as the single source of truth for all player data.
- **Ghost Heal Elimination**: Permanently resolved the life-count desync between the `Roll_ConfettiModule` and the Controller by implementing a unified damage reporting system.
- **Victory Status Lock**: Added a `victoryInProgress` semaphore to protect the "Ultimate Victory" banner from being overwritten by final elimination messages.
- **Furware Compatibility Patch**: Switched to high-reliability ASCII `===` banners for status displays to ensure 100% rendering across all SL viewers.

### 🎰 **Virtualized Scoreboard**
- **3-Column Grid Management**: Re-organized Rank, Name, and Win/Loss records into a professional multi-column leaderboard format.
- **Dynamic Slot Hiding**: Implemented automatic **Alpha 0.0** (Invisibility) for unused player slots (Slots 7-10 in a 6-player session) to maintain a clean aesthetic.
- **Diagnostic Toolset**: Added `/1 testx` (Show All) and `/1 clearx` (Reset Alpha) for linkset layout verification.

### 🏹 **Human-Bot Parity (Shield Patch)**
- **Multi-Delimiter Parser**: Refactored pick-string analysis to support `,`, `;`, `|`, and spaces, ensuring human dialog picks are matched as accurately as automated bot picks.
- **Reconnect Resilience**: Enhanced `MSG_SYNC_GAME_STATE` listeners in all secondary modules to support immediate state recovery for crashed or reconnected players.

## [3.1.0] - 2026-04-04

### 🔍 **Dynamic Link Discovery System**
- **Architecture Decentralization**: Eliminated all hardcoded link indices across 15+ scripts. Systems now perform an automated "Link Discovery" scan on startup and `on_rez`.
- **Name-Based Mapping**: Implemented a robust pattern-matching system (`Scoreboard:0:0`, `profile:R:C`) to identify and bind to links regardless of their link-order in the set.
- **Improved Resilience**: Resolved persistent "Previously declared within scope" errors and stabilized inter-script communication during region crossings and teleports.

### 🧩 **Unified Constants & Centralized Logic**
- **Centralized `Peril_Constants.lsl`**: Shifted all system settings, message IDs, and macros to a single, shared constants file for 100% project consistency.
- **Pre-Processor Debugging**: Implemented a global `dbg()` macro system. Debug logging can now be toggled board-wide with a single switch, significantly reducing production bytecode size.

### 🎭 **FURWARE Text Mesh Migration**
- **Visual Display Overhaul**: Fully migrated the Dice Display and Leaderboard from legacy prim-based XYText to modern mesh-integrated **FURWARE Text**.
- **Sync Reliability**: New bridge scripts handle real-time data distribution to the FURWARE master, ensuring 0ms delay in visual updates.
- **Performance Optimization**: Reduced prim texture-flipping overhead by switching to mesh-offset mapping.

### 🧠 **Compiler & Execution Stability**
- **Scope Refactoring**: Moved all loop variable declarations (`refreshI`, `glowI`, etc.) to the top-level of their respective functions to ensure compatibility with strict LSL compiler versions.
- **Logic Robustness**: Replaced `continue` and range-check based validation with explicit "link-found" `if` blocks, preventing infinite loops and scope errors.
- **Mismatched Variable Fixes**: Resolved inconsistent renaming of local variables in the Scoreboard Manager's refresh logic.

## [3.0.0] - 2026-03-24

### 📦 **Commercial CasperVend Integration**
- **Professional Delivery**: Transitioned from the custom GitHub updater to the industry-standard CasperVend delivery system.
- **Legacy Code Removal**: Completely stripped the `Update_Receiver.lsl`, `Update_Checker.lsl`, and `Peril_Dice_Updater.lsl` systems and their UI endpoints.
- **Secure Distribution**: Game board and standalone scripts now fully compliant with CasperVend "No Modify/No Transfer" security requirements.

### 🧠 **Macro Memory Optimization**
- **Pre-Processor Directives**: Implemented a global `DEBUG_LOGS` pre-processor macro across core logic scripts.
- **Bytecode Reduction**: Converted over 170 verbose `llOwnerSay` debug statements to a conditionally compiled `dbg()` macro, reducing compiled bytecode size.
- **10-Player Load Stability**: Freed critical script memory limits within `Main_Controller_Linkset.lsl`, `Game_Manager.lsl`, and `Player_DialogHandler.lsl` to ensure rock-solid stability during maximum load.

### 🏆 **Experience-Based Leaderboard**
- **Persistent Storage**: Leaderboard data is now stored in Second Life Experience Keys (KVP), ensuring lifetime persistence of player statistics.
- **Region Independence**: Player wins and losses are tracked globally, surviving object resets and region changes.

### 🎨 **Z-Fighting & Alignment Fixes**
- **Initialization Stability**: Patched `Game_Scoreboard_Manager_Linkset.lsl`, `Leaderboard_Communication_Linkset.lsl`, and `XyzzyText_Dice_Bridge_Linkset.lsl` with `on_rez` auto-resets to guarantee synchronized texture deployment.
- **Microscopic Position Offsets**: Resolved persistent Z-fighting flickering on custom UI elements by applying meticulous microscopic local axis offsets (`+0.005m`, `+0.008m`).

## [2.8.7] - 2026-03-23

### 🔄 **GitHub Update System**
- **In-World Update Checker**: Revolutionary `Update_Checker.lsl` script provides direct GitHub integration for releases.
- **Enhanced LinkScanner System**: Complete 84-prim analysis tools via `Enhanced_LinkScanner.lsl` for validating linksets.
- **Zero-Infrastructure Updates**: Automatically detects and fetches latest game scripts using raw GitHub downloads.

## [2.8.6] - 2025-09-16

### 🏆 **Winner Glow Celebration System**
- **Victory Visual Enhancement**: Added comprehensive winner celebration with green glow effects
  - **Scoreboard Glow**: Winner's profile picture and hearts display bright green glow with green tint
  - **Floater Glow**: Winner's floating display shows green glow with victory text "✨ ULTIMATE VICTORY! ✨" and "🏆 ULTIMATE SURVIVOR 🏆"
  - **Visual Priority**: Winner glow overrides peril glow - green takes priority over yellow during victory
  - **Clear Recognition**: Eliminated players show red X markers while winner gets celebration spotlight
- **Extended Victory Display**: 24-second timer delay before game reset allows players to appreciate the winner
  - **Before**: Winner declared → Immediate reset → No time to see who won
  - **After**: Winner declared → Green glow celebration → 24 seconds to admire → Then reset
  - **User Experience**: Proper victory moment with visual feedback before returning to lobby

### 🎨 **Enhanced Visual Feedback System** 
- **Improved Glow Colors**: Enhanced scoreboard glow system with proper color tinting
  - **Winner Glow**: Bright green glow + green color tint for unmistakable victory recognition
  - **Peril Glow**: Yellow glow + yellow color tint for clear peril player identification
  - **Visual Clarity**: Replaced generic white glow with distinct colored glows for better gameplay feedback
- **Floater Victory Detection**: Smart winner detection in floating displays
  - **Automatic Detection**: Floaters automatically detect when only one player remains alive
  - **Victory Text**: Winner's floater displays celebration text instead of standard game info
  - **Consistent Experience**: Both scoreboard and floater systems celebrate the winner simultaneously

### 🔧 **Timer System Optimization**
- **Victory Delay Timer**: Added dedicated timer mode for victory celebration delays
  - **Memory Efficiency**: Removed unused timeout system to free up memory resources
  - **Clean Architecture**: Streamlined timer system focuses on essential functionality
  - **Reliable Operation**: Victory display timing works consistently without interference from other systems
- **Message Communication Enhancement**: Improved winner glow message handling
  - **Scoreboard Integration**: Added proper MSG_UPDATE_WINNER message constant for clean communication
  - **Floater Integration**: Enhanced floater update system to trigger victory displays
  - **Synchronized Effects**: Both display systems receive winner updates simultaneously

### 🎮 **User Experience Improvements**
- **Victory Celebration**: Clear winner recognition with proper visual feedback
- **Extended Appreciation Time**: 24 seconds to see and congratulate the winner before reset
- **Visual Hierarchy**: Clean priority system - Winner (green) > Peril (yellow) > Eliminated (red X)
- **Consistent Display**: Winner celebration works on both scoreboard and personal floater displays

### 📊 **System Performance** 
- **Memory Optimization**: Removed unused timeout system components saving memory
- **Efficient Messaging**: Clean message routing for winner glow effects
- **Timer Efficiency**: Dedicated victory timer prevents conflicts with other timing systems

### 🎯 **Impact Summary**
- **Before**: Winners were announced but no visual celebration - immediate reset gave no recognition
- **After**: Winners get bright green glow celebration on both scoreboard and floaters with 24 seconds of recognition
- **Player Satisfaction**: Proper victory moment makes winning feel rewarding and celebrated
- **Visual Polish**: Professional-grade visual feedback system enhances the competitive gaming experience

## [2.8.5] - 2025-09-15

### 🧠 **Memory Optimization & Dead Code Cleanup**
- **UpdateHelper.lsl Elimination**: Completely removed vestigial UpdateHelper script that was consuming memory but providing no functionality
  - **Issue**: 204-line script existed but was never actually called - pure dead code consuming ~41KB memory
  - **Fix**: Removed UpdateHelper.lsl file and all supporting infrastructure from Main Controller
  - **Memory Impact**: Main Controller memory usage improved from ~83.8% to 81.4% (2.4 percentage point reduction)
  - **Cleaned Up**: `updateNewPlayer()` function, UpdateHelper message constants, variables, and handlers
  - **Simplified**: `updateHelpers()` function now performs direct scoreboard updates without delegation
- **Verbose_Logger Simplification**: Streamlined debug logging system by removing unused buffering infrastructure
  - **Removed**: Message buffering system, timer events, unused message handlers (MSG_VERBOSE_LOG)
  - **Size Reduction**: Simplified from 149 lines to 80 lines (~47% smaller)
  - **Kept**: Essential debug toggle functionality and system-wide logging coordination
  - **Performance**: Eliminated timer overhead and reduced message processing complexity

### 🎨 **Bot Profile Picture Fix**
- **Fixed Bot Visual Glitch**: Resolved issue where bot profile pictures would randomly turn into gray boxes mid-game
  - **Issue**: During scoreboard refresh (e.g., player removal), all profiles were reset to default gray texture before restoration
  - **Root Cause**: `refreshPlayerDisplay()` function reset ALL profile prims to default, causing visual flicker
  - **Fix**: Modified refresh logic to only reset unused player slots, preserving active player textures
  - **Enhanced Caching**: Bots now store `TEXTURE_BOT_PROFILE` directly in cache to prevent HTTP requests
  - **Result**: Bot avatars maintain consistent robot icon throughout entire game without gray box flicker

### 🏗️ **Direct Communication Architecture Update**
- **Link Number Reorganization**: Updated all scripts to use new optimized linkset architecture
  - **Scoreboard Manager**: Link 2 → Link 12 (moved to accommodate overlay prims)
  - **Leaderboard Manager**: Link 25 → Link 35 (updated prim range: links 35-82)
  - **Dice Display**: Link 73 → Link 83 (maintained 2-prim dice display)
  - **Affected Scripts**: 11 scripts updated with new link mappings and prim ranges
- **Optimized Prim Architecture**: Enhanced linkset structure for better performance and organization
  - **Overlay Prims**: Added dedicated overlay prims (links 2-11) for elimination markers
  - **Scoreboard Prims**: Profile and hearts prims properly mapped to new link structure
  - **XyzzyText Banks**: Updated leaderboard prim ranges to accommodate new architecture

### 🔧 **Enhanced Game Logic & Bug Fixes**
- **Number Picker Dialog Enhancement**: Improved parsing for mixed number formats
  - **Format Support**: Now handles both CSV ("1,2,3") and semicolon ("1;2;3") separated pick lists
  - **Whitespace Handling**: Added trimming for formats like "5, 6" vs "5,6" for consistent parsing
  - **Bot Integration**: Enhanced bot pick processing to work with avoid lists from human players
- **Bot Manager Improvements**: Enhanced round detection and pick avoidance logic
  - **Round Detection**: Better detection of new rounds through peril player and lives changes
  - **Command Processing**: Improved bot command handling and duplicate pick prevention
  - **Fair Play**: Bots now correctly avoid numbers already picked by human players
- **Message Handler Fixes**: Improved region communication handling
  - **Communication Method**: Updated message broadcasting for better chat integration
  - **Player Feedback**: Enhanced player join/leave notifications

### 🛠️ **Technical Infrastructure**
- **Memory Reporting**: Added standardized memory usage reporting across core scripts
- **Code Quality**: Removed dead code paths and simplified complex functions
- **Error Handling**: Enhanced safety checks and boundary validation
- **Performance**: Reduced inter-script message traffic by eliminating unused communication paths

### 📊 **System Performance Impact**
- **Memory Usage**: Overall reduction in memory consumption across multiple scripts
- **Message Traffic**: Reduced unnecessary link messages between scripts
- **Visual Stability**: Eliminated profile picture flickering and display inconsistencies
- **Code Maintainability**: Cleaner, more focused codebase with reduced complexity
- **Link Architecture**: More organized and scalable linkset structure for future development

### 🎯 **Impact Summary**
- **Before**: Dead code consuming memory, bot profiles flickering, complex but unused systems
- **After**: Leaner memory usage, stable bot visuals, simplified but fully functional architecture
- **Performance**: Measurable memory improvements and cleaner system operation
- **Maintainability**: Easier to understand and modify codebase with eliminated dead code

## [2.8.4] - 2025-09-14

### 🔍 **System-Wide Verbose Logging Toggle**
- **Universal Debug Control**: Implemented comprehensive verbose logging system across all 14 game modules
  - **Owner Menu Integration**: Added "Toggle Verbose Logs" option in Troubleshooting menu for easy access
  - **Real-Time Toggle**: Instantly enable/disable detailed debug messages without script restart
  - **System-Wide Sync**: One toggle affects all modules simultaneously for consistent logging state
  - **Modules Updated**: Main Controller, Game Manager, Floater Manager, Bot Manager, Roll Module, NumberPicker Handler, Message Handler, Game Calculator, System Debugger, Memory Controller, Scoreboard Manager, Leaderboard Communication, Dice Bridge
  - **Clean Production Mode**: When disabled, only essential error messages and public announcements remain
  - **Full Debug Visibility**: When enabled, shows internal operations, sync messages, state changes, and diagnostic info

### 🔧 **Disconnect/Reconnect Recovery System**
- **Smart Player Return Detection**: Fixed major issue where disconnected players couldn't resume their turn
  - **Issue**: Players who disconnected during number picking (like Nooser) would get wrong menu when returning
  - **Before**: Disconnect → Return → Ready menu shown → Required kick to continue game
  - **After**: Disconnect → Return → "Welcome back! Restoring your number picking dialog..." → Game continues normally
- **Enhanced State Recovery**: Automatic detection and repair of corrupted game state from disconnections
  - Compares expected picker (from pick queue) with current picker state
  - Automatically fixes `currentPicker` corruption when players reconnect
  - Works for both number picking and dice rolling phases
- **Owner Emergency Recovery**: If game gets completely stuck, owner can touch board to force-resume
- **Debug Visibility**: Verbose logging shows state detection and recovery actions for troubleshooting

### 🎯 **Number Picker Dialog Protection System**
- **Stale Dialog Prevention**: Enhanced dialog validation to prevent outdated number selections
  - **Protection Against**: Players clicking cached dialog buttons after game state changed
  - **Validation Layers**: Session validation, player validation, number availability checking
  - **Smart Filtering**: Automatically rejects selections for numbers already picked by others
- **Enhanced Dialog Recovery**: Improved system for restoring number picking dialogs after disconnections
- **Session Management**: Better tracking of active dialog sessions to prevent conflicts

### 🔍 **Number Detection & Shield Logic Fixes**
- **Fixed "Numbers Not Showing" Issue**: Resolved major bug where system couldn't see numbers players had picked
  - **Issue**: Game would show "NO SHIELD!" even when players had actually picked the rolled number
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

### 🛡️ **Game State Desynchronization Fixes**
- **Sync Message Reliability**: Fixed various state sync issues that could cause game confusion
- **Pick Queue Protection**: Enhanced pick queue management to prevent corruption during disconnections
- **Display Consistency**: Fixed cases where different parts of the system showed conflicting game state
- **Race Condition Prevention**: Added proper sequencing for state updates during player disconnections

### 🐛 **Critical Bug Fixes**
- **LSL Syntax Corrections**: Fixed multiple mid-block variable declaration errors that prevented script compilation
  - **Issue**: LSL doesn't support variable declarations in middle of code blocks
  - **Fixed Files**: Main Controller, Floater Manager, Bot Manager, Roll Module, Game Manager, NumberPicker Handler, Message Handler, Game Calculator, System Debugger, Memory Controller, Leaderboard modules
  - **Solution**: Replaced problematic ternary operators and mid-block declarations with proper conditional statements
- **Ternary Operator Removal**: LSL doesn't support `condition ? value1 : value2` syntax - converted to if/else statements
- **Compilation Success**: All scripts now compile without syntax errors

### 🎮 **User Experience Improvements**
- **Seamless Reconnection**: Players can disconnect and return without disrupting game flow
- **Clear Status Messages**: Better feedback when verbose logging is toggled ("ENABLED"/"DISABLED" confirmations)
- **Graceful Recovery**: No more need to kick players just because they disconnected at wrong time
- **Owner Control**: Easy debug toggle access through familiar menu system

### 🔬 **Developer Experience Enhancements**
- **Comprehensive Debug Coverage**: Every major system component now supports verbose logging
- **Consistent Logging Format**: Standardized debug message format across all modules
- **Real-Time Diagnostics**: Live visibility into game state, sync operations, and recovery actions
- **Troubleshooting Tools**: Enhanced ability to diagnose and fix game state issues

### 🎯 **Impact Summary**
- **Before**: Player disconnections could break games, requiring kicks and manual intervention
- **After**: Players disconnect/reconnect seamlessly, games continue automatically  
- **Debug Control**: One-click verbose logging for production vs development modes
- **Stability**: Major reduction in game-breaking state corruption issues
- **Developer Productivity**: Rich diagnostic information available on demand

## [2.8.3] - 2025-09-01

### 🚨 **CRITICAL BUG FIXES** - Major Game Logic Issues Resolved

#### 🛡️ **Shield Detection Logic Fixed**
- **MAJOR BUG FIX**: Corrected shield detection that was incorrectly reporting "NO SHIELD!" when players had picked the rolled number
  - **Issue**: Game said "Nobody picked 1" even when Rebecca had picked "3, 1" - Taylor should have been shielded but took damage instead
  - **Root Cause**: Shield detection was checking if ONLY the peril player picked the number instead of checking if ANYONE picked it
  - **Fix**: Shield detection now correctly uses `matched` flag (anyone picked) instead of `perilPickedIt` flag (only peril player picked)
  - **Impact**: Players will no longer take undeserved damage when others provide proper shields
  - **Logic Update**: 
    - ✅ **NO SHIELD**: Only when nobody picked the rolled number (`!matched`)
    - ✅ **DIRECT HIT**: When peril player picked their own doom (`matched && perilPickedIt`)
    - ✅ **PLOT TWIST**: When someone else picked it but not peril player (handled upstream)

#### 🎯 **Initialization System Overhaul**
- **MAJOR BUG FIX**: Complete fix for "can't join after rez" issue that required manual script reset
  - **Issue**: When rezzing game from inventory, players couldn't join until all scripts were manually reset
  - **Root Cause**: Critical scripts weren't properly resetting their state variables on rez, causing stale data conflicts
  - **Scripts Fixed**: Added comprehensive `on_rez()` handlers to all critical game scripts:
    - 🎯 **Game_Manager.lsl**: Core game logic and state management (20+ variables reset)
    - 🎲 **Roll_ConfettiModule.lsl**: Dice rolling and shield detection logic
    - 🎮 **NumberPicker_DialogHandler.lsl**: Player number selection dialogs
    - 🤖 **Bot_Manager.lsl**: Bot player automation and picking logic
    - 📦 **Floater_Manager.lsl**: Player status floating displays
    - 🎭 **Player_DialogHandler.lsl**: Player and owner menu systems
    - 🧮 **Game_Calculator.lsl**: Dice type and pick requirement calculations
  - **Each Fix Includes**:
    - ✅ Complete state variable reset to initial values
    - ✅ Dynamic channel re-initialization for unique instance communication
    - ✅ Old listener cleanup and fresh listener setup
    - ✅ Stale game data clearing (picks, player lists, dialog sessions)
    - ✅ Critical flag reinitialization (roundStarted, rollInProgress, etc.)
  - **Impact**: **Game is now immediately ready for players after rezzing - NO manual script reset required!**

### 🎮 **Player Experience Improvements**
- **Immediate Playability**: Games rezzed from inventory are instantly ready for player registration
- **Fair Shield Mechanics**: Players providing shields now properly protect the peril player from damage
- **Clean State Guarantee**: Every new game instance starts with completely fresh state
- **Reliable Dialog Systems**: Number picking and menu dialogs work immediately after rez

### 🔧 **Technical Infrastructure**
- **Enhanced Script Coordination**: All scripts now properly coordinate during initialization
- **Channel Isolation**: Each game instance uses unique communication channels
- **Memory Management**: Proper cleanup prevents memory leaks from stale game sessions
- **State Synchronization**: Consistent state across all game components from startup

### 🧪 **Testing and Validation**
- **Shield Detection Testing**: Verified correct shield behavior in various game scenarios
- **Rez Testing**: Confirmed immediate playability after rezzing from inventory
- **State Cleanup Testing**: Validated complete cleanup of previous game sessions
- **Cross-Script Communication**: Verified proper initialization coordination

### 🎯 **Impact Summary**
- **Before**: Required manual "Reset Scripts" + shield detection failed
- **After**: Rez → Immediately playable + shields work correctly
- **User Experience**: Seamless game setup + fair gameplay mechanics
- **Reliability**: 100% successful initialization + accurate damage calculation

## [2.8.2] - 2025-08-21

### 🔥 **Critical Scoreboard Spam Fix**
- **Eliminated Player Sync Loop**: Fixed major bug where eliminated players caused continuous scoreboard update spam
  - Main Controller now properly updates peril player variable immediately after player elimination
  - Prevents stale sync messages containing eliminated player data from being broadcast repeatedly
  - Eliminates infinite scoreboard update loops that occurred when peril player was eliminated
  - Fixed root cause where Main Controller kept sending outdated peril player references in sync messages
- **Peril Player Validation**: Enhanced peril player assignment during elimination sequences
  - Checks if eliminated player is currently the peril player before final sync
  - Assigns new valid living player as peril player or sets to "NONE" if no players remain
  - Ensures updateHelpers() always sends clean game state without stale player references
  - Prevents perpetual "Noose the Bunny" style spam messages after player elimination

### 🎯 **Peril Status Display Fixes (Re-Fixed)**
- **Enhanced Floater Peril Status**: Re-implemented and improved peril status display on floating displays
  - Fixed peril status showing "waiting for game to start" during active gameplay (again)
  - Enhanced peril player detection logic in floater management
  - Improved sync message processing to ensure consistent peril status across all displays
  - Better handling of peril player transitions during plot twist scenarios

### 💖 **Elimination Heart Display Fixes (Re-Fixed)**
- **0 Hearts Before Elimination**: Re-fixed elimination sequence to properly show 0 hearts before player removal
  - Enhanced Main Controller elimination logic to ensure 0 hearts display timing
  - Extended display delay to make 0 hearts clearly visible on both scoreboard and floaters
  - Improved coordination between heart updates and player cleanup processes
  - Fixed race conditions where players were removed before 0 hearts could be displayed
- **Visual Elimination Feedback**: Strengthened elimination experience for better player feedback
  - Players now consistently see their elimination status with 0 hearts before removal
  - Scoreboard and floaters maintain synchronized elimination heart display
  - Enhanced user experience during elimination events with proper visual timing

### 🛠️ **Technical Improvements**
- **Elimination Sequence Enhancement**: Improved coordination between player removal and sync message broadcasting
  - Added peril player validation step before final updateHelpers() call
  - Enhanced elimination handler to prevent sync message corruption during player cleanup
  - Better synchronization between Main Controller state updates and helper script notifications
- **Display System Reliability**: Strengthened display update mechanisms for consistent visual feedback
  - Enhanced floater update triggers during game state changes
  - Improved peril status determination and heart display coordination
  - Better error handling for edge cases during elimination sequences

## [2.8.1] - 2025-08-14

### 🎯 **Peril Status Display Fixes**
- **Fixed Floater Status Updates**: Resolved issue where peril status on floating displays showed "waiting for game to start" during active gameplay
  - Enhanced peril status logic in Floater Manager to properly handle active game states
  - Added clear "YOU ARE IN PERIL!" messaging for the current peril player
  - Improved status display to show "Peril Player: [Name]" for all other players
  - Fixed condition checking for peril player status determination
- **Real-Time Status Synchronization**: Enhanced sync message handling for consistent peril status across all displays
  - Added debug logging to track peril player status changes in Floater Manager
  - Improved floater update triggers during game state changes
  - Enhanced sync message processing to immediately update all floaters when peril status changes
  - Fixed "NONE" placeholder handling in peril player sync messages

### 💖 **Elimination Heart Display Fixes**
- **0 Hearts Before Elimination**: Fixed elimination sequence to properly show 0 hearts before player removal
  - Modified Main Controller elimination logic to set player lives to 0 first
  - Added 1-second display delay to make 0 hearts visible on both scoreboard and floaters
  - Enhanced elimination flow with proper timing between heart display and player cleanup
  - Fixed race condition where players were removed before 0 hearts could be displayed
- **Visual Elimination Sequence**: Improved elimination experience for better player feedback
  - Players now see their elimination status with 0 hearts before floater disappears
  - Scoreboard and floaters show elimination hearts consistently
  - Better coordination between heart updates and player removal
  - Enhanced user experience during elimination events

### 🐛 **Bug Fixes and Improvements**
- **Sync Message Debugging**: Added comprehensive debug logging for peril player status tracking
  - Debug messages show peril player changes from old to new values
  - Enhanced visibility into sync message processing
  - Better troubleshooting capabilities for peril status issues
- **Floater Update Reliability**: Improved floater update system for more consistent status display
  - Enhanced floater update triggers during game state changes
  - Better handling of peril status changes during rounds
  - Improved sync message reliability for real-time status updates
- **Elimination Timing Fixes**: Resolved timing issues in elimination sequence
  - Fixed race condition where elimination cleanup occurred before status display
  - Added proper delays to ensure visual feedback before player removal
  - Enhanced coordination between Main Controller and display systems

### 🛠️ **Technical Improvements**
- **Enhanced Floater Manager Logic**: Improved peril status determination and display
  - Better condition checking for active game states vs. waiting states
  - Enhanced handling of "NONE" and empty peril player values
  - Improved sync message processing for consistent status updates
- **Main Controller Elimination Enhancements**: Better elimination sequence coordination
  - Added explicit 0 hearts setting before player removal
  - Improved helper update timing during elimination
  - Enhanced coordination between elimination logic and display updates
- **Debug Logging Additions**: Added targeted debug messages for key status changes
  - Peril player change tracking in Floater Manager
  - Elimination sequence logging in Main Controller
  - Better visibility into sync message processing

## [2.8.0] - 2025-08-12

### 🔒 **Game Lockout Security System**
- **Owner-Only Access Control**: Implemented comprehensive lockout system allowing game owners to restrict all game functionality to owner only
  - Complete dialog prevention for non-owners when game is locked
  - Visual feedback through floating text showing "🔒 GAME LOCKED" status
  - Clear error messaging to non-owners attempting access during lockout
  - Lock status persists during gameplay and between sessions
- **Dynamic Admin Controls**: Added lock/unlock toggle buttons in categorized owner menu
  - 🔒 Lock Game: Restricts access to owner only
  - 🔓 Unlock Game: Restores normal player access
  - Visual indicators in admin menu show current lock state
- **System Integration**: Lockout state synchronized between Main Controller and Dialog Handler
  - Lock/unlock commands sent via link messages (9001/9002)
  - Floating text updates automatically based on lock state
  - Complete access restriction including dialog generation prevention

### 🔄 **Automatic Reset on Startup System**
- **Clean State Guarantee**: Game automatically resets when critical scripts are updated or rezzed
  - Main Controller triggers reset on `state_entry()` for consistent startup state
  - Game Manager requests reset on startup to handle core game logic updates
  - All game state cleared while preserving historical leaderboard data
- **Smart Reset Logic**: Automatic reset preserves leaderboard while clearing temporary game state
  - Players, lives, picks, ready states cleared on startup
  - Win/loss records maintained in leaderboard system
  - Scoreboard cleared but leaderboard rankings preserved
- **Script Update Protection**: Enhanced reliability when game logic is modified
  - Prevents stale game states from carrying over after script updates
  - Ensures consistent experience for players after system updates
  - Eliminates need for manual resets after deployments

### 👥 **Enhanced Player Management System**
- **Kick Player Functionality**: Complete implementation of owner-controlled player removal
  - New "Kick Player" option in Player Management admin section
  - Smart display name handling with automatic truncation for dialog buttons
  - Complete player removal from all game systems (lists, scoreboard, floaters)
  - Immediate visual feedback on scoreboard when players are kicked
- **Rebuilt Leave Game System**: Complete overhaul of voluntary player departure
  - Fixed state synchronization issues between Controller and Dialog Handler
  - Proper cleanup of player floaters when leaving
  - Automatic removal from ready player lists
  - Scoreboard updates immediately reflect departing players
- **Advanced Name Management**: Enhanced handling of long display names
  - Automatic truncation to fit within 24-character dialog button limits
  - Preservation of original names for game logic while showing truncated versions in UI
  - Proper mapping between display names and actual player identities

### 🎯 **Categorized Admin Interface**
- **Organized Owner Menu**: Complete restructure of admin controls into logical categories
  - **Player Management**: Add Test Player, Kick Player functions
  - **Reset Options**: Game reset, Leaderboard reset, Complete reset
  - **Troubleshooting**: Cleanup floaters, Force floaters creation
  - **Security Controls**: Lock/Unlock game prominently displayed
- **Improved Navigation**: Enhanced menu flow with clear back navigation
  - Consistent "⬅️ Back to Main" options in all sub-menus
  - "⬅️ Back to Game" option to return to player interface
  - Context-sensitive menu options based on current state
- **Enhanced User Experience**: Better organization and discoverability of admin functions
  - Security-first design with lock controls prominently featured
  - Logical grouping of related functions
  - Clear visual indicators for current system state

### 🛠️ **System Reliability and State Management**
- **Enhanced Message Synchronization**: Improved communication reliability between scripts
  - Better coordination between Main Controller and Dialog Handler for player operations
  - Proper message sequencing for kick/leave operations
  - Race condition prevention in player registration and removal
- **State Consistency Improvements**: Enhanced data integrity across all game components
  - All game lists maintain synchronization during player changes
  - Floater cleanup properly coordinated with player removal
  - Ready state management integrated with player lifecycle
- **Error Recovery Enhancement**: Better handling of edge cases and unexpected states
  - Improved validation of player operations
  - Enhanced cleanup procedures for interrupted operations
  - More robust handling of script restart scenarios

### 📊 **Memory Management and Performance**
- **Efficient Data Cleanup**: Proper memory management during player operations
  - Complete cleanup of all player-related data structures
  - Efficient list operations for player removal
  - Proper floater channel management and cleanup
- **Reduced Memory Footprint**: Optimized storage of player state information
  - Efficient mapping between display names and original names
  - Streamlined admin menu data structures
  - Better garbage collection during reset operations

### 🔧 **Technical Infrastructure Updates**
- **Link Message Protocol Extensions**: New message types for enhanced functionality
  - Message 9001: Lock game command from Dialog Handler to Main Controller
  - Message 9002: Unlock game command from Dialog Handler to Main Controller
  - Message -99998: Reset request system for script update coordination
- **Floating Text Management**: Dynamic text updates based on system state
  - Lock/unlock status reflected in floating text
  - Game progress indicators maintained
  - Clear visual feedback for all system states
- **Admin Security Model**: Comprehensive owner verification throughout system
  - All security-sensitive operations validate owner identity
  - Lock/unlock operations restricted to game owner only
  - Consistent security model across all admin functions

### 🎮 **User Experience Improvements**
- **Clear Feedback Systems**: Enhanced messaging for all user interactions
  - Lock status clearly communicated to all users
  - Kick/leave operations provide immediate feedback
  - Error messages are clear and actionable
- **Professional Admin Interface**: Polished owner experience with logical organization
  - Intuitive menu structure follows user workflow
  - Consistent visual design and button labeling
  - Context-appropriate options based on current game state
- **Seamless Player Experience**: Minimal disruption during admin operations
  - Quick player removal without game interruption
  - Smooth ready state management
  - Preserved game flow during player changes

## [2.7.0] - 2025-08-12

### 🏗️ **MAJOR ARCHITECTURAL OVERHAUL - Single Linkset Design**
- **Complete System Consolidation**: Merged all 4 separate objects into single linkset architecture
  - Main Controller + Roll Module: Link 1 (root prim)
  - Game Scoreboard: Links 2-24 (scoreboard background, actions display, player slots)
  - XyzzyText Leaderboard: Links 25-72 (48 prims for text display across 4 banks)
  - Dice Display: Links 73-74 (2 prims for XyzzyText dice results)
  - Total: 74-prim consolidated linkset replacing 4 separate rezzed objects
- **Elimination of Region Chat**: Replaced all `llRegionSay()` communication with `llMessageLinked()`
  - No more channel conflicts or discovery issues between multiple game instances
  - Instant, reliable communication within single linkset
  - Zero risk of cross-talk between multiple game tables
- **Simplified Deployment**: Single object rez instead of complex 4-object positioning system
  - No more Position Controller/Follower scripts needed
  - No more automatic rez positioning coordination
  - Instant setup - rez once and play

### 📡 **Dynamic Channel System Removal**
- **Channel System Elimination**: Removed entire hash-based dynamic channel calculation system
  - No more `calculateChannel(offset)` functions across scripts
  - No more MD5-based hash generation for channel uniqueness
  - No more owner key + object key channel calculations
  - Eliminated ~78000 to ~86000 channel range management
- **Communication Simplification**: All inter-component communication now uses link messages
  - Scoreboard communication via link messages to specific prim numbers
  - Leaderboard updates via link messages to bridge scripts
  - Dice display updates via link messages within linkset
  - Zero external channel dependencies

### 🎯 **Dice Type Synchronization Fixes**
- **Critical Race Condition Resolution**: Fixed major bug where Game Manager and Roll Module independently requested dice types
  - Eliminated inconsistent dice types between human players and bots (e.g., player rolling d6 when expecting d30)
  - Prevented double rolls with different dice types from conflicting module requests
  - Removed duplicate dice type calculation across multiple modules
- **Targeted Communication System**: Calculator sends dice type responses only to requesting module
  - Game Calculator responds directly to sender using link numbers
  - Eliminated `LINK_SET` broadcasts that caused race conditions and stale data
  - Each module requests dice type independently when needed, preventing conflicts

### 🔄 **Clean Module Communication Architecture**
- **Link Message Routing**: Established clear communication paths within linkset
  - Main Controller ↔ Scoreboard: Link 1 → Link 2
  - Scoreboard → Leaderboard Bridge: Link 2 → Link 25
  - Roll Module → Dice Bridge: Link 1 → Link 73
  - All communication uses `llMessageLinked()` with specific link numbers
- **Module Responsibilities**:
  - **Game Calculator**: Calculates dice types on request; sends targeted responses only
  - **Game Manager**: Requests dice type for pick phase coordination and dialog building
  - **Roll Module**: Requests dice type independently when performing actual rolls
  - **Scoreboard Manager**: Handles player display and leaderboard formatting
  - **Bridge Scripts**: Handle XyzzyText display distribution for leaderboard and dice

### 🛠️ **Game Flow Improvements**
- **Win Condition Protection**: Enhanced Game Manager to detect single remaining player and stop rounds
  - Prevents infinite game loops where bot fights itself after human elimination
  - Game properly ends when only one player remains instead of continuing indefinitely
- **Round Completion Logic**: Improved detection of round completion across all scenarios
  - Handles Direct Hit, No Shield, and Plot Twist outcomes correctly
  - Enhanced sync protection against empty pickQueue overwrites during active rounds
- **Pick Dialog Synchronization**: Game Manager uses correct dice type for human pick dialogs
  - Ensures number selection dialogs show appropriate range (1-6 for d6, 1-30 for d30)
  - Maintains consistency between dialog options and actual roll dice type

### 📊 **Display System Integration**
- **Scoreboard Integration**: Scoreboard prims now part of main linkset (Links 3-24)
  - BACKGROUND_PRIM: Link 3, ACTIONS_PRIM: Link 4, FIRST_PLAYER_PRIM: Link 5
  - Player prims span Links 5-24 (20 player slots with profile pictures and hearts)
  - Direct link message communication for instant updates
- **Leaderboard Integration**: XyzzyText leaderboard integrated as Links 25-72
  - 48 prims across 4 banks of 12 characters each for "TOP BATTLE RECORDS" display
  - Formatted leaderboard shows positions 1-11 with wins/losses in "W:X/L:Y" format
  - Communication via Leaderboard Bridge script on Link 25
- **Dice Display Integration**: Dice results display as Links 73-74
  - Real-time dice roll results showing "Player: rolled X" format
  - Victory displays showing "PlayerName|WON" for game winners
  - Communication via Dice Bridge script on Link 73

### 🏃‍♂️ **Performance and Reliability**
- **Zero Channel Conflicts**: Complete elimination of region chat channel issues
- **Instant Communication**: Link messages provide immediate, guaranteed delivery
- **Multi-Instance Support**: Multiple game tables can operate without any interference
- **Simplified Maintenance**: Single object to manage instead of 4-object coordination
- **Memory Efficiency**: Removed channel calculation overhead and hash generation processing

### 🗑️ **Removed Systems**
- **Dynamic Channel Management**: Entire hash-based channel system removed
- **Position Controller/Follower**: No longer needed with single linkset design
- **Automatic Rez Positioning**: Eliminated complex multi-object positioning scripts
- **Region Chat Dependencies**: All `llRegionSay()` calls replaced with `llMessageLinked()`
- **Channel Discovery**: No more channel assignment reporting or debugging tools needed

### 🎮 **User Experience**
- **One-Click Deployment**: Single object rez for complete game setup
- **Reliable Operation**: No communication failures or channel conflicts
- **Clean Console**: No channel debugging messages or communication errors
- **Professional Presentation**: Integrated display components work seamlessly together

## [2.6.0] - 2025-08-09

### 📡 Advanced Channel Management System
- **Dynamic Channel Calculation**: Implemented sophisticated channel assignment system to prevent conflicts
  - Channels calculated using combined hash of owner key + object key for uniqueness
  - Prevents interference between multiple game tables owned by same person
  - Each game instance gets completely unique channel space
  - MD5-based hash generation creates 0-255 range offsets for channel distribution
- **Multi-Instance Support**: Multiple game tables can now operate simultaneously without channel conflicts
- **Automatic Channel Assignment**: 
  - Main Controller: ~-78000 range (CHANNEL_BASE - offset - hash)
  - Dialog Handler: ~-79000 range
  - Roll Module: ~-80000 range  
  - Bot Manager: ~-81000 range
  - Scoreboard: ~-83000 range
  - Leaderboard: ~-84000 range
  - Position System: ~-85000 range
  - Floater Base: ~-86000 range (with per-player offsets)
- **Channel Debugging**: Owner receives detailed channel assignments on startup for troubleshooting

### 🧹 Debug Output Cleanup Campaign
- **Main Controller Noise Reduction**: Removed verbose debug messages causing chat spam
  - Eliminated touch event logging (`"DEBUG: touch_start - sender: X"`)
  - Removed dice type result debug output (`"DEBUG: Roll result: X on dY"`)
  - Cleaned up excessive state change notifications
  - Preserved essential error messages and critical game flow information
- **Floater Manager Debug Cleanup**: Significantly reduced verbose owner messages
  - Removed detailed picks data logging from `getPicksFor()` function calls
  - Eliminated floater cleanup debug messages (channel, index, player data confirmations)
  - Removed sync state debug information showing counts of lives, picks, and names
  - Maintained important error reporting for malformed data and critical issues
- **Professional Operation Standards**: Game now operates with minimal console noise

### 🎯 Enhanced User Experience
- **Reduced Log Spam**: Console output now focuses on meaningful information only
- **Essential Information Preserved**: Error messages and critical game events still logged
- **Clean Monitoring**: Easier to spot actual issues without debug noise overwhelming chat
- **Multi-Table Deployment**: Support for running multiple game instances without interference

### 🛠️ Technical Infrastructure Improvements
- **Performance Enhancement**: Reduced string processing overhead from debug output removal
- **Memory Optimization**: Less memory usage from debug string concatenation and storage
- **Channel Architecture**: Robust system for managing communication channels across components
- **Hash-Based Uniqueness**: Cryptographically sound channel assignment preventing collisions
- **Maintainability**: Cleaner codebase easier to debug when real issues occur

### 🔧 System Reliability
- **Conflict Prevention**: Eliminates channel conflicts that could cause cross-talk between games
- **Instance Isolation**: Each game table operates in completely isolated channel space
- **Debugging Tools**: Built-in channel reporting for troubleshooting communication issues
- **Production Ready**: Professional-grade logging levels suitable for live deployment

### 📋 Implementation Details
- **Channel Calculation Function**: `calculateChannel(offset)` in all major scripts
- **Initialization Reporting**: Detailed channel assignments logged on script startup
- **Cross-Script Consistency**: All components use same channel calculation method
- **Owner Transparency**: Clear visibility into assigned channels for admin purposes

## [2.5.0] - 2025-08-08

### 🛡️ Registration Security Fixes
- **Duplicate Registration Prevention**: Fixed critical bug where players could register multiple times by rapid clicking
  - Added `pendingRegistrations` list to track registration requests in progress
  - Prevents duplicate registration messages from being sent while first registration processes
  - Automatic cleanup of pending registrations after completion or timeout
- **Startup Sequence Protection**: Fixed bug allowing player joins during game initialization
  - Added `gameStarting` flag to block registrations immediately when "Start Game" is clicked
  - Eliminates timing window between game start and `roundStarted` flag activation
  - Maintains owner exception for admin menu access during gameplay

### 🎮 Improved Game Flow Control
- **Enhanced Touch Handler**: Better handling of registration status with user feedback
- **State Management**: Proper cleanup of both `gameStarting` and `pendingRegistrations` during reset
- **User Experience**: Clear messaging when registration attempts are blocked during active periods

### 🐛 Critical Bug Fixes
- **Race Condition Resolution**: Eliminated duplicate player entries from rapid multiple touches
- **Game Disruption Prevention**: Stopped unwanted joins during critical game startup phase
- **Consistent Game State**: All registration paths now properly validate timing and prevent duplicates
- **Duplicate Pick Prevention**: Fixed `continueCurrentRound()` function to properly rebuild `globalPickedNumbers` with uniqueness checks
- **Data Corruption Fix**: Resolved issue where `globalPickedNumbers` could contain duplicates, causing inconsistent bot pick validation
- **Delimiter Handling**: Enhanced parsing to correctly handle both comma (human) and semicolon (bot) pick delimiters
- **Server-Side Pick Validation**: Added robust server-side validation in `Main.lsl` to prevent duplicate picks from being accepted
  - Human picks are now validated against `globalPickedNumbers` before acceptance
  - Invalid picks are rejected with clear error messaging to the player
  - Player receives new dialog with updated available numbers after rejection
  - Eliminates client-side bypass vulnerabilities in duplicate prevention
- **Loss Tracking**: Fixed missing loss records in leaderboard when players are eliminated
  - Added `GAME_LOST|` message broadcast when players are eliminated
  - Eliminated players now properly appear in leaderboard with loss counts
  - Provides complete game statistics showing both wins and losses
- **Enhanced Display Name Handling**: Implemented robust player name resolution with fallback system
  - Added `getPlayerName(key id)` helper function in all scripts (Main.lsl, Dialog Handler, StatFloat)
  - Prioritizes modern `llGetDisplayName()` for better user experience
  - Falls back to legacy `llKey2Name()` when display names are unavailable
  - Handles network issues, offline avatars, and viewer compatibility problems
  - Ensures no player is ever shown as blank or missing name
  - Consistent name handling across all game components and messages

## [2.4.0] - 2025-08-08

### 📍 Position Management System
- **Master-Follower Architecture**: Complete position synchronization system for all game components
- **Position Controller Script**: Main controller object manages movement of scoreboard, leaderboard, and displays
- **Follower Script Template**: Generic follower script that reads position settings from config notecard
- **Config-Based Positioning**: Position offsets and rotations defined in "config" notecard for easy customization
- **Automatic Movement Sync**: When controller moves, all linked objects maintain relative positions
- **Position Reset Tools**: Built-in recalibration system for repositioning knocked-out components
- **Multi-Object Coordination**: Seamless movement of entire game system as single unit

### 🧹 Production Code Cleanup
- **Debug Code Removal**: Complete removal of all debug logging statements and test messages
  - Removed `llOwnerSay("DEBUG: ...)` calls throughout Main.lsl (lines 147, 161, 479, 517, 523, 527, 874, 1163)
  - Eliminated development-time diagnostic messages and empty debug blocks
  - Cleaner, more professional game experience without debug clutter
- **Syntax Error Fixes**: 
  - Fixed critical missing closing brace on line 835 in Main.lsl causing compilation failure
  - Resolved LSL syntax errors that prevented script execution
  - All scripts now compile cleanly without warnings or errors

### 🛠️ Development Quality Improvements
- **Production Readiness**: Scripts optimized for live deployment without development artifacts
- **Performance Enhancement**: Eliminated unnecessary debug output reducing execution overhead
- **Memory Optimization**: Reduced script memory footprint by removing debug string operations
- **Code Maintainability**: Cleaner codebase structure for future development
- **Professional Polish**: Game system ready for production deployment

### 🔧 Technical Improvements
- **LSL Compliance**: All scripts pass Second Life LSL compilation standards
- **Execution Efficiency**: Faster script performance without debug processing overhead
- **Position Synchronization**: Robust communication system for coordinated object movement
- **Config System**: Flexible notecard-based configuration for easy position adjustments
- **Error Resolution**: Fixed all syntax issues preventing proper game operation

### 📚 Documentation Updates
- **Position System Guide**: Comprehensive instructions for setting up position management
- **Reset Tools Documentation**: Step-by-step guide for recalibrating positions
- **Version Tracking**: Updated to semantic versioning 2.4.0
- **Change History**: Detailed tracking of all modifications and improvements

## [2.3.0] - 2025-08-05


### 🏆 Visual Scoreboard System
- **Dynamic Player Grid**: Real-time visual scoreboard displaying all players with profile pictures and heart count
- **Profile Picture Integration**: Automatic fetching of Second Life avatar profile pictures via HTTP requests
- **Heart Texture Display**: Visual life representation using custom heart textures (3, 2, 1, 0 hearts)
- **Bot Profile Support**: Special profile texture for TestBot players
- **Immediate Updates**: Hearts update instantly when lives change, before any dialogs appear

### 🎭 Enhanced Status Display System
- **Visual Status Actions**: Large action prim displaying current game status with custom textures
- **Specific Status Messages**:
  - **Direct Hit**: When peril player picks their own rolled number
  - **No Shield**: When nobody picks the rolled number
  - **Plot Twist**: When peril switches to a new player
  - **Elimination**: When a player is eliminated
  - **Victory**: When someone wins the game
  - **Peril Selected**: When a new peril player is chosen
  - **Title**: Default/idle state

### ⚡ Perfect Status Timing
- **Protected Display Time**: Each status shows for 8 seconds with automatic clearing
- **Strategic Delays**: 2-second delays after status messages prevent overwriting
- **Sequential Flow**: Elimination → 6.4s delay → Victory → 9s delay → Reset
- **Immediate Visual Feedback**: Hearts and status update instantly, delays protect display time

### 🎯 Comprehensive Leaderboard
- **Persistent Win Tracking**: Player victories saved across game sessions
- **XyzzyText Integration**: Three-prim text display system for leaderboard
- **Automatic Sorting**: Top players by win count with formatted display
- **Separate Reset Options**: Game reset vs. leaderboard reset vs. complete reset

### 🎮 Enhanced User Interface
- **Categorized Owner Menus**: Organized into Game Control, Player Management, Reset Options, etc.
- **Dialog Recovery**: Players can recover lost dialogs by touching the controller
- **Admin Menu Access**: Owner can access admin functions during gameplay
- **Improved Menu Flow**: Streamlined navigation with clear categorization

### 🔧 Technical Improvements
- **Multi-Object Architecture**: Scoreboard and leaderboard as separate linked objects
- **HTTP Profile Fetching**: Robust system for retrieving avatar profile pictures
- **Texture Caching**: Profile pictures cached to avoid repeated HTTP requests
- **Region-Based Communication**: Cross-object messaging using `llRegionSay`
- **Elimination Sequence**: Visual 0-hearts display before player removal

### 🐛 Critical Fixes
- **Heart Update Timing**: Fixed hearts not updating until after next-turn dialog
- **Victory Overwriting Elimination**: Added proper delay between elimination and victory status
- **Status Message Conflicts**: All status messages now have protective delays
- **Profile Picture Fallbacks**: Proper handling of failed HTTP requests
- **Scoreboard Reset**: Fixed scoreboard not clearing when game resets

## [2.2.0] - 2025-08-04

### 🎭 Major UX/Presentation Improvements
- **Dramatic Messaging System**: Complete overhaul of game messages with thematic styling
- **Public Announcements**: Key game events now visible to all players in public chat
- **Context-Rich Roll Messages**: Dice rolls now show both dice type and result
- **Split Hit Messages**: Different messages for "picked own doom" vs "no shield" scenarios

### 🎮 Enhanced Player Experience
- **Player Join Messages**: `💀 PlayerName has entered the deadly game! Welcome to your potential doom! 💀`
- **Ready State Messages**: 
  - `👑 PlayerName steps forward as the game master - automatically ready for the deadly challenge! 👑`
  - `⚔️ PlayerName steels themselves for the deadly challenge ahead! ⚔️`
  - `🏃 PlayerName loses their nerve and backs away from the challenge! 🏃`
- **Pick Announcements**: `🎯 PlayerName stakes their life on numbers: 1, 2, 3 🎲`
- **Game Start**: `⚡ ALL PARTICIPANTS READY! THE DEADLY PERIL DICE GAME BEGINS! ⚡`

### 🎲 Improved Roll Messages
- **Main Roll**: `🎲 THE D6 OF FATE! PlayerName rolled a 5 on the 6-sided die! 🎲`
- **Plot Twist**: `⚡ PLOT TWIST! PlayerName picked 5 (rolled on d6) and is now in ULTIMATE PERIL! ⚡`
- **Direct Hit**: `🩸 DIRECT HIT! PlayerName picked their own doom - the d6 landed on 5! 🩸`
- **No Shield**: `🩸 NO SHIELD! Nobody picked 5 - PlayerName takes the hit from the d6! 🩸`

### 🔧 Critical Bug Fixes
- **StatFloat Duplication**: Fixed bug where new StatFloat objects were created on every life loss instead of updating existing ones
- **Duplicate Message Handling**: Removed duplicate `HUMAN_PICKED` handlers that caused double processing
- **Malformed Entry Warnings**: Fixed LSL parsing issues with empty picks entries
- **Cleanup Optimization**: Reduced excessive StatFloat cleanup messages during reset

### 🛠️ Technical Improvements
- **Debug Message Cleanup**: Removed excessive debug output while preserving essential error reporting
- **Message Handler Optimization**: Streamlined communication between scripts
- **LSL Parsing Fixes**: Better handling of trailing empty elements in data parsing
- **Memory Management**: Improved StatFloat lifecycle management

## [2.1.0] - 2025-08-03

### ✨ Major Features Added
- **Ready State System**: Players must mark themselves ready before games can start
- **Game Protection**: Prevents players from joining games in progress
- **Performance Optimization**: Reduced lag by limiting confetti to wins only
- **Enhanced Bot Intelligence**: Improved bot behavior and duplicate number avoidance

### 🔧 Core Fixes
- **Complete Game Flow**: Fixed end-to-end gameplay from start to finish
- **Elimination Logic**: Proper handling of player elimination and game continuation
- **Win Condition**: Fixed victory detection and game ending
- **Data Synchronization**: Resolved corruption in pick data between scripts
- **Peril Player Assignment**: Fixed race conditions in peril player transitions

### 🎮 Gameplay Improvements
- **Dynamic Picking**: Number of picks now properly based on peril player's lives
- **Duplicate Prevention**: Enhanced system to prevent duplicate number selection
- **Dialog Pagination**: Improved number selection interface for d30 dice
- **Floater Updates**: Real-time HUD updates throughout gameplay
- **Bot Continuation**: Bots now properly continue games when humans are eliminated

### 🛠️ Technical Enhancements
- **Modular Communication**: Improved inter-script messaging system
- **Error Handling**: Comprehensive validation and error recovery
- **Memory Management**: Better floater cleanup and channel tracking
- **Data Encoding**: Fixed CSV conflicts with semicolon encoding system
- **State Management**: Robust game state synchronization across modules

### 🐛 Bug Fixes
- Fixed missing pick dialogs after game events
- Resolved duplicate message issues between scripts
- Fixed lives reset problems between rounds
- Corrected floater display inconsistencies
- Fixed bot confusion during player elimination
- Resolved pick data corruption issues
- Fixed peril player variable sync problems

### ⚡ Performance
- Removed confetti from life loss (keeping only victory confetti)
- Optimized debug output to reduce lag
- Improved floater management efficiency
- Enhanced bot processing speed

## [2.0.0] - 2024-12-XX

### 🎉 Initial Modular Release
- **Modular Architecture**: Separated functionality into specialized scripts
- **Bot System**: Added AI players for testing and gameplay variety
- **Floating HUD**: Real-time player statistics display
- **Dynamic Dice**: Automatic dice sizing based on player count
- **Player Management**: Runtime player joining and leaving
- **Owner Controls**: Administrative functions for game management

### 🎲 Core Game Features
- **Pick System**: Number selection with validation
- **Rolling Mechanism**: Automated dice rolling with visual effects
- **Life Management**: 3-life system with elimination
- **Peril Tracking**: Dynamic peril player assignment
- **Victory Conditions**: Last player standing wins

### 🏗️ Architecture
- **Main Controller**: Central game logic and state management
- **Dialog Handlers**: User interface and input processing
- **Roll Module**: Dice mechanics and particle effects
- **Bot Manager**: AI player behavior and automation
- **Floater Manager**: HUD display coordination
- **Game Helpers**: Utility functions and calculations

## [1.0.0] - 2025-XX-XX

### 🌟 Original Release
- Basic Peril Dice game implementation
- Manual gameplay mechanics
- Simple player tracking
- Basic dice rolling functionality

---

## Development Notes

### Known Issues
- **Debug Output**: Extended games may experience minor lag from comprehensive logging

### Recent Fixes (2025-01-08)
- **Bot Race Condition**: Fixed critical bug where duplicate message handlers prevented proper `globalPickedNumbers` updates
- **Enhanced Bot Logging**: Added detailed pick tracking and duplicate detection in Bot Manager
- **Message Handler Separation**: Separated bot and human pick handling to prevent conflicts

### Future Enhancements  
- Configurable debug levels
- Additional game modes and variants
- Enhanced visual effects and animations

### Credits
- **Original Game Design**: Noose the Bunny (djmusica28) - Second Life
- **Automation & Development**: Enhanced for automated gameplay
- **Architecture**: Modular LSL system for scalability and maintainability
