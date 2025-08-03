# Changelog

All notable changes to Peril Dice will be documented in this file.

## [2.1.0] - 2025-01-08

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

## [1.0.0] - 2024-XX-XX

### 🌟 Original Release
- Basic Peril Dice game implementation
- Manual gameplay mechanics
- Simple player tracking
- Basic dice rolling functionality

---

## Development Notes

### Known Issues
- **Bot Race Condition**: Bots may occasionally pick duplicate numbers when triggered simultaneously
- **Debug Output**: Extended games may experience minor lag from comprehensive logging

### Future Enhancements
- Serialized bot picking to eliminate race conditions
- Configurable debug levels
- Additional game modes and variants
- Enhanced visual effects and animations

### Credits
- **Original Game Design**: Noose the Bunny (djmusica28) - Second Life
- **Automation & Development**: Enhanced for automated gameplay
- **Architecture**: Modular LSL system for scalability and maintainability