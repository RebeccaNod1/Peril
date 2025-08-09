# Changelog

All notable changes to Peril Dice will be documented in this file.

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
