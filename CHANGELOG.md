# Changelog

All notable changes to Peril Dice will be documented in this file.

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
