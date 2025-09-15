🎲 PERIL DICE — PROFESSIONAL SINGLE LINKSET GAME SYSTEM FOR SECOND LIFE
========================================================

CREATED BY REBECCA NOD AND NOOSE THE BUNNY
CURRENT VERSION: 2.8.5 - MEMORY OPTIMIZATION & ARCHITECTURE CLEANUP

OVERVIEW
--------
Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player's number is rolled, they lose a life. Players are eliminated when they reach zero lives.

NEW IN V2.8.5: Major system cleanup eliminating dead code, fixing bot profile picture flickering, and optimizing memory usage across all scripts with measurable performance improvements.

NEW IN V2.8.4: Revolutionary disconnect/reconnect recovery system eliminates need to kick players who disconnect during their turn, plus comprehensive system-wide verbose logging toggle for production vs development modes.

NEW IN V2.8.3: Fixed critical shield detection bug that incorrectly reported "NO SHIELD!" when players had picked the rolled number, plus complete initialization system overhaul ensuring games are immediately playable after rezzing without manual script reset.

KEY FEATURES
============

🏆 VISUAL SCOREBOARD SYSTEM
- Real-Time Player Grid: Visual scoreboard showing all players with profile pictures and hearts
- Profile Picture Integration: Automatic avatar profile fetching from Second Life
- Heart Texture Display: Visual life representation (3, 2, 1, 0 hearts)
- Instant Updates: Hearts change immediately when lives are lost

🎭 ENHANCED STATUS DISPLAY
- Visual Status Actions: Large status prim with custom textures for each game event
- Specific Status Types: Direct Hit, No Shield, Plot Twist, Elimination, Victory, etc.
- Perfect Timing: 8-second display time with protective delays to prevent overwriting

🎯 COMPREHENSIVE LEADERBOARD
- Persistent Win Tracking: Player victories saved across sessions
- XyzzyText Display: Professional 3-prim text system for leaderboard
- Automatic Sorting: Top players by win count

🎮 CORE GAME FEATURES
- 🎯 Dynamic Player Management: Players can join at runtime (owner and other avatars)
- 🤖 Bot Support: Add AI bots for testing and gameplay variety  
- 📱 Floating HUD Display: Real-time stats for each player
- 🎮 Intelligent Dice Sizing: Automatic dice size based on player count
- 🔄 Ready State System: Players must be ready before games start
- 🎭 Dramatic Messaging: Immersive thematic announcements visible to all players
- 🎲 Context-Rich Rolls: Detailed dice information with type and result
- ⚡ Performance Optimized: Reduced lag with selective particle effects
- 🛡️ Robust Error Handling: Comprehensive game state synchronization
- 🚫 Game Protection: Prevents joining games in progress
- 📍 Position Management System: Coordinated movement of all game components

GAME RULES
==========
1. Setup: 2-10 players join the game
2. Ready Phase: All players except starter must mark themselves ready
3. Picking Phase: Each player picks 1-3 numbers (based on peril player's remaining lives)
4. Rolling Phase: Peril player rolls the dice
5. Resolution: 
   - If rolled number matches another player's pick → that player becomes new peril player (⚡ PLOT TWIST!)
   - If peril player picked the rolled number → they lose a life (🩸 DIRECT HIT!)
   - If nobody picked the rolled number → peril player loses a life (🩸 NO SHIELD!)
6. Elimination: Players with 0 lives are eliminated
7. Victory: Last player standing wins! 🏆

HOW TO PLAY
===========

FOR OWNER:
- Touch object → Access owner menu
- Add Bot → Add AI players for testing
- Start Game → Begin when all players are ready
- Reset Game → Reset to initial state
- Manage Picks → View/modify player selections

FOR PLAYERS:
- Touch object → Register and join game
- Ready/Not Ready → Toggle your ready state
- Pick Numbers → Select your numbers when prompted
- Roll Dice → Roll when you're the peril player

ARCHITECTURE
============
The system uses a modular LSL architecture with inter-script communication:
- Main Controller: Core game logic and state management
- Dialog Handlers: User interface and input processing  
- Roll Module: Dice rolling and confetti effects
- Bot Manager: AI player behavior
- Floater Manager: Floating HUD display management
- Game Helpers: Utility functions and dice type calculation

DICE SCALING
============
Dice type is automatically chosen to ensure at least 3 picks per player:

Player Count | Dice Type
-------------|----------
1–2          | d6
3–4          | d12
5–6          | d20
7–10         | d30

RECENT IMPROVEMENTS (V2.8.5)
============================

🚨 MEMORY OPTIMIZATION & ARCHITECTURE CLEANUP

🧠 MEMORY OPTIMIZATION & DEAD CODE CLEANUP
- UpdateHelper.lsl Elimination: Completely removed vestigial 204-line script consuming ~41KB memory but providing zero functionality
  * Discovery: UpdateHelper existed but was never actually called - pure dead code waste
  * Impact: Main Controller memory usage improved from 83.8% to 81.4% (2.4% reduction)
  * Cleanup: Removed all supporting infrastructure, message constants, variables, handlers
  * Simplification: Direct scoreboard updates instead of complex but unused delegation system
- Verbose_Logger Streamlined: Simplified debug system by 47% while keeping essential functionality
  * Size Reduction: 149 lines → 80 lines by removing unused buffering system
  * Performance: Eliminated timer overhead and message processing complexity
  * Kept: Core debug toggle functionality that's actually used

🎨 BOT PROFILE PICTURE FIX
- Fixed Visual Glitch: Resolved bot avatars randomly turning into gray boxes mid-game
  * Issue: Scoreboard refresh would reset ALL profiles to gray before restoration
  * Root Cause: refreshPlayerDisplay() function caused visual flicker during player removal
  * Solution: Modified refresh to only reset unused slots, preserving active player textures
  * Enhancement: Bots now cache robot texture directly to prevent HTTP requests
  * Result: Consistent bot avatars throughout entire game without gray box flickering

🏗️ ARCHITECTURE OPTIMIZATION
- Link Number Reorganization: Updated entire system to optimized linkset structure
  * Scoreboard Manager: Link 2 → Link 12 (moved for overlay prim accommodation)
  * Leaderboard Manager: Link 25 → Link 35 (updated to links 35-82 range)
  * Dice Display: Link 73 → Link 83 (maintained 2-prim dice system)
  * System-Wide Update: 11 scripts updated with new mappings and prim ranges
- Enhanced Prim Structure: Better organized linkset for performance and future development
  * Overlay Prims: Dedicated elimination marker prims (links 2-11)
  * Scoreboard Optimization: Profile/hearts prims properly mapped to new structure
  * XyzzyText Enhancement: Leaderboard banks updated for new architecture

🔧 ENHANCED GAME LOGIC & BUG FIXES
- Number Picker Enhancement: Improved parsing for mixed number formats
  * Format Support: Handles both CSV ("1,2,3") and semicolon ("1;2;3") formats
  * Whitespace Handling: Trims formats like "5, 6" vs "5,6" for consistency
  * Bot Integration: Enhanced bot processing with avoid lists from human players
- Bot Manager Improvements: Better round detection and fair play mechanics
  * Round Detection: Enhanced detection through peril player and lives changes
  * Fair Play: Bots now properly avoid numbers picked by human players
  * Command Processing: Improved bot handling and duplicate pick prevention
- Communication Fixes: Enhanced region messaging and player feedback systems

📊 PERFORMANCE IMPACT
- Memory Efficiency: Measurable reduction in memory consumption across multiple scripts
- Visual Stability: Eliminated profile picture flickering and display inconsistencies
- Code Quality: Cleaner, more maintainable codebase with reduced complexity
- Message Traffic: Reduced unnecessary inter-script communication overhead
- Architecture: More organized and scalable linkset structure

🎯 IMPACT SUMMARY
- Before: Dead code consuming memory, bot profiles flickering, complex but unused systems
- After: Leaner memory usage, stable bot visuals, simplified but fully functional architecture
- Performance: Measurable memory improvements and cleaner system operation
- Maintainability: Easier to understand and modify codebase with eliminated dead code

RECENT IMPROVEMENTS (V2.8.4)
============================

🚨 DISCONNECT RECOVERY & DEBUG SYSTEM

🔍 SYSTEM-WIDE VERBOSE LOGGING TOGGLE
- Universal Debug Control: Comprehensive verbose logging system across all 14 game modules
- Owner Menu Integration: Added "Toggle Verbose Logs" option in Troubleshooting menu
- Real-Time Toggle: Enable/disable detailed debug messages instantly without script restart
- Production Mode: When disabled, only essential errors and public announcements shown
- Development Mode: When enabled, shows internal operations, sync messages, diagnostics
- Complete Coverage: All major game components support unified debug control

🔧 DISCONNECT/RECONNECT RECOVERY SYSTEM
- The Nooser Problem - SOLVED: Fixed major issue where disconnected players broke games
  * Before: Player disconnects during turn → Game stuck → Return shows wrong menu → Requires kick
  * After: Player disconnects during turn → Return automatically restores dialog → Continues seamlessly
- Smart State Recovery: Automatic detection and repair of corrupted game state
  * Compares who SHOULD be picking with who system THINKS is picking
  * Automatically fixes currentPicker corruption when players reconnect
  * Works for both number picking and dice rolling phases
- "Welcome Back" Experience: Clear feedback when players return to active games
- Owner Emergency Recovery: If completely stuck, owner touch forces resume
- No More Kicks: Eliminates need to kick players just because they disconnected

🎯 NUMBER PICKER DIALOG PROTECTION
- Stale Dialog Prevention: Enhanced validation prevents outdated number selections
- Multi-Layer Protection: Session validation, player validation, availability checking
- Smart Filtering: Automatically rejects numbers already picked by others
- Enhanced Dialog Recovery: Better system for restoring dialogs after disconnections

🔍 NUMBER DETECTION & SHIELD LOGIC FIXES
- Fixed "Numbers Not Showing" Issue: Resolved major bug where system couldn't see numbers players had picked
  * Problem: Game would show "NO SHIELD!" even when players had actually picked the rolled number
  * Root Cause: Pick data synchronization issues between modules causing invisible player selections
  * Solution: Enhanced pick data validation and sync message reliability across all game modules
  * Impact: Shield detection now works correctly - proper "PLOT TWIST!" and shield mechanics restored

❌ ENHANCED ELIMINATION VISUAL FEEDBACK
- Red X Elimination Marker: Added clear visual indicator for eliminated players on scoreboard
  * Visual Enhancement: Eliminated players now display a red X overlay on their profile picture
  * Immediate Feedback: Red X appears instantly when player reaches 0 lives for clear elimination status
  * Persistent Display: Red X remains visible on scoreboard until game reset for historical reference
  * User Experience: Players can easily see who has been eliminated without checking heart counts
  * Credit: Feature suggested by Pawkaf (pawkaf.lutrova)

🛡️ GAME STATE STABILITY IMPROVEMENTS
- Sync Message Reliability: Fixed state synchronization issues causing confusion
- Pick Queue Protection: Enhanced management prevents corruption during disconnections
- Display Consistency: Fixed conflicting game state between different systems
- Race Condition Prevention: Proper sequencing for state updates during disconnections

🐛 CRITICAL BUG FIXES
- LSL Syntax Corrections: Fixed compilation errors in all 14 game modules
- Ternary Operator Removal: LSL doesn't support condition ? value1 : value2 syntax
- Mid-Block Variable Fix: LSL requires variable declarations at function/state start
- 100% Compilation Success: All scripts now compile without syntax errors

🎮 USER EXPERIENCE REVOLUTION
- Seamless Reconnection: Players disconnect/return without disrupting game flow
- Graceful Recovery: Players return to exactly where they left off
- Clear Status Messages: Better feedback for debug logging toggle
- Owner Control: Easy debug access through familiar menu system
- Professional Operation: Clean, reliable gameplay for all participants

📈 IMPACT SUMMARY
- Before: Player disconnections broke games, requiring kicks and manual intervention
- After: Players disconnect/reconnect seamlessly, games continue automatically
- Debug Control: One-click verbose logging for production vs development modes
- Stability: Major reduction in game-breaking state corruption issues
- Developer Productivity: Rich diagnostic information available on demand

RECENT IMPROVEMENTS (V2.8.3)
============================

🚨 CRITICAL BUG FIXES - Major Game Logic Issues Resolved

🛡️ SHIELD DETECTION LOGIC FIXED
- MAJOR BUG FIX: Corrected shield detection that was incorrectly reporting "NO SHIELD!" when players had picked the rolled number
  * Issue: Game said "Nobody picked 1" even when Rebecca had picked "3, 1" - Taylor should have been shielded but took damage instead
  * Root Cause: Shield detection was checking if ONLY the peril player picked the number instead of checking if ANYONE picked it
  * Fix: Shield detection now correctly uses `matched` flag (anyone picked) instead of `perilPickedIt` flag (only peril player picked)
  * Impact: Players will no longer take undeserved damage when others provide proper shields
  * Logic Update:
    - ✅ NO SHIELD: Only when nobody picked the rolled number (!matched)
    - ✅ DIRECT HIT: When peril player picked their own doom (matched && perilPickedIt)
    - ✅ PLOT TWIST: When someone else picked it but not peril player (handled upstream)

🎯 INITIALIZATION SYSTEM OVERHAUL
- MAJOR BUG FIX: Complete fix for "can't join after rez" issue that required manual script reset
  * Issue: When rezzing game from inventory, players couldn't join until all scripts were manually reset
  * Root Cause: Critical scripts weren't properly resetting their state variables on rez, causing stale data conflicts
  * Scripts Fixed: Added comprehensive on_rez() handlers to all critical game scripts:
    - 🎯 Game_Manager.lsl: Core game logic and state management (20+ variables reset)
    - 🎲 Roll_ConfettiModule.lsl: Dice rolling and shield detection logic
    - 🎮 NumberPicker_DialogHandler.lsl: Player number selection dialogs
    - 🤖 Bot_Manager.lsl: Bot player automation and picking logic
    - 📦 Floater_Manager.lsl: Player status floating displays
    - 🎭 Player_DialogHandler.lsl: Player and owner menu systems
    - 🧮 Game_Calculator.lsl: Dice type and pick requirement calculations
  * Each Fix Includes:
    - ✅ Complete state variable reset to initial values
    - ✅ Dynamic channel re-initialization for unique instance communication
    - ✅ Old listener cleanup and fresh listener setup
    - ✅ Stale game data clearing (picks, player lists, dialog sessions)
    - ✅ Critical flag reinitialization (roundStarted, rollInProgress, etc.)
  * Impact: **Game is now immediately ready for players after rezzing - NO manual script reset required!**

🎮 PLAYER EXPERIENCE IMPROVEMENTS
- Immediate Playability: Games rezzed from inventory are instantly ready for player registration
- Fair Shield Mechanics: Players providing shields now properly protect the peril player from damage
- Clean State Guarantee: Every new game instance starts with completely fresh state
- Reliable Dialog Systems: Number picking and menu dialogs work immediately after rez

🔧 TECHNICAL INFRASTRUCTURE
- Enhanced Script Coordination: All scripts now properly coordinate during initialization
- Channel Isolation: Each game instance uses unique communication channels
- Memory Management: Proper cleanup prevents memory leaks from stale game sessions
- State Synchronization: Consistent state across all game components from startup

🎯 IMPACT SUMMARY
- Before: Required manual "Reset Scripts" + shield detection failed
- After: Rez → Immediately playable + shields work correctly
- User Experience: Seamless game setup + fair gameplay mechanics
- Reliability: 100% successful initialization + accurate damage calculation

RECENT IMPROVEMENTS (V2.8.2)
============================

🔥 CRITICAL SCOREBOARD SPAM FIX
- Eliminated Player Sync Loop: Fixed major bug where eliminated players caused continuous scoreboard update spam
- Peril Player Validation: Enhanced peril player assignment during elimination sequences
- Prevents stale sync messages containing eliminated player data from being broadcast repeatedly
- Eliminates infinite scoreboard update loops that occurred when peril player was eliminated
- Fixed root cause where Main Controller kept sending outdated peril player references

🎯 PERIL STATUS DISPLAY FIXES (RE-FIXED)
- Enhanced Floater Peril Status: Re-implemented and improved peril status display on floating displays
- Fixed peril status showing "waiting for game to start" during active gameplay (again)
- Enhanced peril player detection logic in floater management
- Improved sync message processing to ensure consistent peril status across all displays
- Better handling of peril player transitions during plot twist scenarios

💖 ELIMINATION HEART DISPLAY FIXES (RE-FIXED)
- 0 Hearts Before Elimination: Re-fixed elimination sequence to properly show 0 hearts before player removal
- Enhanced Main Controller elimination logic to ensure 0 hearts display timing
- Extended display delay to make 0 hearts clearly visible on both scoreboard and floaters
- Improved coordination between heart updates and player cleanup processes
- Fixed race conditions where players were removed before 0 hearts could be displayed

🛠️ TECHNICAL IMPROVEMENTS
- Elimination Sequence Enhancement: Improved coordination between player removal and sync message broadcasting
- Added peril player validation step before final updateHelpers() call
- Enhanced elimination handler to prevent sync message corruption during player cleanup
- Better synchronization between Main Controller state updates and helper script notifications
- Display System Reliability: Strengthened display update mechanisms for consistent visual feedback

RECENT IMPROVEMENTS (V2.8.1)
============================

🎯 PERIL STATUS DISPLAY FIXES
- Fixed Floater Status Updates: Peril status on floating displays now properly updates during gameplay
- Enhanced Status Messages: Improved peril player display with clear "YOU ARE IN PERIL!" messaging
- Real-Time Status Sync: Floaters immediately reflect current peril player changes during rounds
- Better Status Logic: Fixed "waiting for game to start" showing during active gameplay
- Improved Peril Tracking: Enhanced sync message handling for consistent peril status across all displays

💖 ELIMINATION HEART DISPLAY FIXES
- 0 Hearts Before Elimination: Players now show 0 hearts on scoreboard and floaters before being removed
- Visual Elimination Sequence: 1-second display of 0 hearts allows players to see their elimination status
- Proper Heart Updates: Hearts correctly update to 0 before player cleanup and removal
- Enhanced Elimination Flow: Better timing between heart display and player removal
- Scoreboard Synchronization: Both scoreboard and floaters show elimination hearts consistently

🐛 BUG FIXES AND IMPROVEMENTS
- Sync Message Debugging: Added debug logging to track peril player status changes
- Floater Update Reliability: Improved floater update triggers during game state changes
- Elimination Timing: Fixed race condition where players were removed before showing 0 hearts
- Status Display Logic: Enhanced peril status determination in floater manager

RECENT IMPROVEMENTS (V2.8.0)
============================

🔐 GAME LOCKOUT SECURITY SYSTEM
- Owner-Only Lockout: Game owners can lock their tables to restrict all access to owner only
- Complete Access Control: When locked, only the owner can access any dialogs or game features
- Visual Lock Indicators: Floating text dynamically updates to show "🔒 GAME LOCKED" status
- Lock/Unlock Toggle: Easy-to-use admin menu options for controlling game access
- Clear User Feedback: Non-owners receive clear messages when attempting to access locked games

🔄 AUTOMATIC RESET ON STARTUP SYSTEM
- Clean State Guarantee: Game automatically resets when Main Controller is rezzed or updated
- Script Update Protection: Game Manager triggers reset when core logic is updated
- Leaderboard Preservation: Game state resets but historical win records are preserved
- Consistent Experience: Every startup provides fresh, ready-to-play game state
- System Integrity: All linked components properly cleared and synchronized on startup

👥 ENHANCED PLAYER MANAGEMENT SYSTEM
- Kick Player Functionality: Owners can now kick any registered player from the game
- Smart Name Handling: Automatic truncation of long display names to fit dialog buttons
- Leave Game Fixes: Completely rebuilt leave game system with proper state synchronization
- Clean Player Removal: Players removed from all game lists, scoreboards, and displays
- Floater Cleanup: Player floating displays properly cleaned up when leaving/kicked

🎯 CATEGORIZED ADMIN INTERFACE
- Organized Owner Menu: Complete restructure of admin controls into logical categories
- Player Management: Add Test Player, Kick Player functions
- Reset Options: Game reset, Leaderboard reset, Complete reset
- Troubleshooting: Cleanup floaters, Force floaters creation
- Security Controls: Lock/Unlock game prominently displayed

RECENT IMPROVEMENTS (V2.7.0)
============================

🏠 SINGLE LINKSET ARCHITECTURE REVOLUTION
- Complete System Consolidation: Merged all 4 separate objects into unified 74-prim linkset
- One-Click Deployment: Single object rez replaces complex 4-object positioning system
- Elimination of Region Chat: All llRegionSay() communication replaced with instant llMessageLinked()
- Zero Channel Conflicts: Complete removal of hash-based dynamic channel system
- Multi-Instance Support: Multiple game tables operate without any interference
- 50%+ Performance Improvement: Link messages provide immediate, guaranteed delivery

🎯 DICE TYPE SYNCHRONIZATION FIXES
- Critical Race Condition Resolution: Fixed major bug where Game Manager and Roll Module independently requested dice types
- Consistent Dice Types: Eliminated scenarios where players rolled different dice types (e.g., d6 vs d30)
- Targeted Calculator Responses: Calculator now responds only to requesting module, preventing stale data
- Enhanced Game Flow: Improved round completion detection and win condition logic
- Bot Synchronization: Fixed bot behavior inconsistencies with dice type coordination

🔄 CLEAN MODULE COMMUNICATION ARCHITECTURE
- Link Message Routing: Established clear communication paths within linkset
- Module Independence: Each component operates independently without cross-dependencies
- Bulletproof Reliability: No discovery failures or communication timeouts
- Professional Operation: Clean console output without channel debugging noise

PREVIOUS IMPROVEMENTS (V2.6.0)
============================

📡 ADVANCED CHANNEL MANAGEMENT SYSTEM
- Dynamic Channel Calculation: Sophisticated channel assignment preventing conflicts between multiple game instances
- Multi-Instance Support: Multiple game tables can operate simultaneously without channel interference
- Hash-Based Uniqueness: MD5-based channel calculation using owner + object keys for complete isolation
- Automatic Channel Assignment: All components get unique channel ranges (~-78000 to ~-86000)
- Channel Debugging Tools: Detailed channel assignments reported to owner on startup

🧹 DEBUG OUTPUT CLEANUP CAMPAIGN
- Reduced Log Spam: Eliminated verbose debug messages causing console chat spam
- Professional Operation: Game now operates with minimal noise, focusing on essential information
- Performance Enhancement: Reduced string processing overhead from debug message removal
- Clean Monitoring: Easier to spot actual issues without debug noise overwhelming chat
- Production Ready: Professional-grade logging levels suitable for live deployment

🛠️ TECHNICAL INFRASTRUCTURE IMPROVEMENTS
- Channel Architecture: Robust system managing communication channels across all components
- Conflict Prevention: Eliminates channel conflicts that could cause cross-talk between games
- Instance Isolation: Each game table operates in completely isolated channel space
- Memory Optimization: Less memory usage from debug string concatenation removal
- System Reliability: Built-in channel reporting for troubleshooting communication issues

PREVIOUS IMPROVEMENTS (V2.5.0)
============================

🛡️ REGISTRATION SECURITY FIXES
- Duplicate Registration Prevention: Fixed critical bug where rapid clicking could create duplicate player entries
- Startup Sequence Protection: Eliminated timing window allowing unwanted joins during game initialization
- Enhanced Game Flow Control: Better state management and user feedback during registration processes
- Race Condition Resolution: Comprehensive fixes for all registration-related race conditions
- Duplicate Pick Prevention: Fixed intermittent duplicate number picks caused by data corruption in globalPickedNumbers
- Data Integrity: Enhanced continueCurrentRound() function to properly rebuild pick tracking with uniqueness validation
- Server-Side Pick Validation: Added robust validation to prevent duplicate number picks with immediate error feedback
- Enhanced Display Name Handling: Robust player name resolution with smart fallback system
  * Prioritizes modern display names for optimal user experience
  * Automatically falls back to legacy usernames when display names unavailable
  * Handles network issues, offline avatars, and viewer compatibility seamlessly
  * Ensures consistent name display across all game components and messages

PREVIOUS IMPROVEMENTS (V2.4.0)
==============================

📍 POSITION MANAGEMENT SYSTEM
- Master-Follower Architecture: Controller object manages position of all game components
- Automatic Position Sync: Scoreboard, leaderboard, and displays move with main controller
- Config-Based Setup: Position offsets and rotations defined in notecard configuration
- Position Reset Tools: Easy recalibration system for repositioning game components
- Coordinated Movement: All objects maintain relative positions when game is moved

🧹 PRODUCTION CODE CLEANUP
- Debug Code Removal: Complete removal of all debug logging and test messages for production deployment
- Syntax Error Fixes: Resolved critical syntax errors including missing braces in conditional blocks
- Code Optimization: Cleaner, more maintainable codebase without development artifacts
- Performance Enhancement: Reduced script memory usage and execution overhead

VERSION INFORMATION
===================
Current Version: 2.8.3
Last Updated: September 1, 2025
Status: Production Ready - Critical Game Logic Fixes

ORIGINAL GAME RULES CREDIT
==========================
Game rules were created by Noose the Bunny (djmusica28) in Second Life. This automated version builds upon their original manual gameplay concept.

ORIGINAL MANUAL RULES SUMMARY:
- Each player starts with 3 lives
- Players pick numbers based on peril player's remaining lives:
  - 3 Lives → Pick 1 number
  - 2 Lives → Pick 2 numbers  
  - 1 Life → Pick 3 numbers
- Roll dice to determine outcome
- Last player with lives wins

---
Peril Dice provides hours of entertainment for Second Life communities with its blend of strategy, luck, and social interaction!
