# 🎲 Peril Dice — Modular Game System for Second Life

## Overview

Peril Dice is a multiplayer elimination game where each player selects numbers before a die is rolled. If the peril player's number is rolled, they lose a life. Players are eliminated when they reach zero lives.

## Key Features

- **🎯 Dynamic Player Management**: Players can join at runtime (owner and other avatars)
- **🤖 Bot Support**: Add AI bots for testing and gameplay variety  
- **📱 Floating HUD Display**: Real-time stats for each player
- **🎮 Intelligent Dice Sizing**: Automatic dice size based on player count
- **🔄 Ready State System**: Players must be ready before games start
- **⚡ Performance Optimized**: Reduced lag with selective particle effects
- **🛡️ Robust Error Handling**: Comprehensive game state synchronization
- **🚫 Game Protection**: Prevents joining games in progress

## Game Rules

1. **Setup**: 2-10 players join the game
2. **Ready Phase**: All players except starter must mark themselves ready
3. **Picking Phase**: Each player picks 1-3 numbers (based on peril player's remaining lives)
4. **Rolling Phase**: Peril player rolls the dice
5. **Resolution**: 
   - If rolled number matches another player's pick → that player becomes new peril player
   - If no match or peril player hits themselves → peril player loses a life
6. **Elimination**: Players with 0 lives are eliminated
7. **Victory**: Last player standing wins! 🏆

## Installation

1. Rez the main controller object in your desired location
2. Ensure all scripts are loaded:
   - `Main.lsl` (Main Controller)
   - `Owner and Player Dialog Handler.lsl`
   - `Number Picker Dialog Handler.lsl`
   - `Roll Confetti Module.lsl`
   - `Bot Manager.lsl`
   - `Floater Manager.lsl`
   - `StatFloat.lsl` (for the floating HUD objects)
3. Touch the object to register as a player and start playing!

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

## Known Issues

- **Minor Bot Collision**: Bots may occasionally pick duplicate numbers in rapid succession (race condition)
- **Performance**: Extended games with many bots may experience some lag due to debug output

## Version

**Current Version**: 2.1.0  
**Last Updated**: January 2025  
**Status**: Stable - Full game flow functional

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