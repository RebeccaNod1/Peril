🎲 PERIL DICE — PROFESSIONAL SINGLE LINKSET GAME SYSTEM FOR SECOND LIFE
========================================================

CREATED BY REBECCA NOD AND NOOSE THE BUNNY
CURRENT VERSION: 2.8.2 - SCOREBOARD SPAM & DISPLAY FIXES

OVERVIEW
--------
Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player's number is rolled, they lose a life. Players are eliminated when they reach zero lives.

NEW IN V2.8.2: Fixed critical scoreboard spam bug caused by eliminated players, plus re-fixed peril status display on floaters and elimination heart updates to show 0 hearts before player removal.

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
Current Version: 2.8.2
Last Updated: August 21, 2025
Status: Production Ready - Scoreboard Spam & Display Fixes

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
