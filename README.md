# 🎲 Peril Dice — Modular Game System for Second Life

## Overview

Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player's number is rolled, they lose a life. Players are eliminated when they reach zero lives.

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
- **Touch object** → Access owner menu
- **Add Bot** → Add AI players for testing
- **Start Game** → Begin when all players are ready
- **Reset Game** → Reset to initial state
- **Manage Picks** → View/modify player selections

### For Players
- **Touch object** → Register and join game
- **Ready/Not Ready** → Toggle your ready state
- **Pick Numbers** → Select your numbers when prompted
- **Roll Dice** → Roll when you're the peril player

## Architecture

The system uses a modular LSL architecture with inter-script communication:

- **Main Controller**: Core game logic and state management
- **Dialog Handlers**: User interface and input processing  
- **Roll Module**: Dice rolling and confetti effects
- **Bot Manager**: AI player behavior
- **Floater Manager**: Floating HUD display management
- **Game Helpers**: Utility functions and dice type calculation

## Dice Scaling

Dice type is automatically chosen to ensure at least 3 picks per player:

| Player Count | Dice Type |
|--------------|-----------|
| 1–2          | d6        |
| 3–4          | d12       |
| 5–6          | d20       |
| 7–10         | d30       |

## Recent Improvements (v2.3.0)

### 🏆 Visual Scoreboard Revolution
- **Real-Time Visual Display**: Complete visual overhaul with player grid showing profile pictures and hearts
- **Instant Heart Updates**: Hearts change immediately when lives are lost, before any dialogs appear
- **Profile Picture Fetching**: Automatic HTTP requests to get actual Second Life avatar pictures
- **0-Hearts Display**: Shows elimination sequence visually before player removal

### 🎭 Enhanced Status System
- **Specific Status Types**: Separate textures for Direct Hit, No Shield, Plot Twist, Elimination, Victory
- **Perfect Timing**: 8-second display with 2-second protective delays prevent status overwriting
- **Visual Impact**: Large action prim displays current game status with custom textures

### 🎯 Comprehensive Leaderboard
- **Persistent Win Tracking**: Player victories saved across game sessions using linkset data
- **Professional Display**: XyzzyText 3-prim system for clean leaderboard presentation
- **Flexible Reset Options**: Separate commands for game reset, leaderboard reset, or complete reset

### 🔧 Critical Fixes
- **Heart Update Timing**: Fixed hearts not updating until after next-turn dialog
- **Status Conflicts**: All status messages now have protective delays to prevent overwriting
- **Victory/Elimination Flow**: Proper 6.4-second delay between elimination and victory status

## Version

**Current Version**: 2.3.0  
**Last Updated**: August 5, 2025  
**Status**: Stable - Complete visual scoreboard system with enhanced status display

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
