# Direct Communication Architecture

## Overview
To reduce Main Controller memory pressure (from 92% usage), we've implemented direct system-to-system communication, bypassing the Main Controller for specific operations.

## Direct Communication Flows

### ✅ Implemented Direct Connections

#### 1. **Roll Module → Scoreboard** (Status & Life Updates)
```lsl
// Life updates during gameplay
llMessageLinked(12, 3002, perilPlayer + "|" + (string)lives + "|NULL_KEY", NULL_KEY);

// Game status updates
llMessageLinked(12, 3001, "Plot Twist", NULL_KEY);    // When player picks rolled number
llMessageLinked(12, 3001, "Direct Hit", NULL_KEY);    // When peril player picks their doom
llMessageLinked(12, 3001, "No Shield", NULL_KEY);     // When nobody picks rolled number
```
**Benefit**: Real-time scoreboard updates without Main Controller memory overhead.

#### 2. **Roll Module → Dice Display** (Roll Results)
```lsl
// Display roll results directly
llMessageLinked(83, 3020, perilPlayer + "|" + rollResult, NULL_KEY);

// Clear dice display
llMessageLinked(83, 3021, "", NULL_KEY);
```
**Benefit**: Eliminates dice message routing through Main Controller.

#### 3. **Main Controller → Scoreboard → Leaderboard** (Win/Loss Tracking)
```lsl
// Elimination tracking (already optimized)
llMessageLinked(SCOREBOARD_LINK, MSG_GAME_LOST, eliminatedPlayer, NULL_KEY);

// Victory tracking (already optimized) 
llMessageLinked(SCOREBOARD_LINK, MSG_GAME_WON, winner, NULL_KEY);
```
**Benefit**: Scoreboard handles leaderboard updates internally, reducing Main Controller load.

## Architecture Benefits

### Memory Savings
- **Main Controller**: Reduced from 92% to estimated ~85% memory usage
- **Eliminated routing logic**: No more message forwarding for status/dice/scoreboard updates
- **Reduced string operations**: Direct messages avoid CSV building/parsing in Main Controller

### Performance Improvements
- **Real-time updates**: Scoreboard updates immediately when lives change
- **Reduced latency**: No message forwarding delays
- **Better reliability**: Fewer message hops = fewer failure points

### System Resilience
- **Distributed processing**: Each system handles its own display updates
- **Reduced bottlenecks**: Main Controller no longer central routing point
- **Memory stability**: Less memory pressure on critical controller script

## Message Flow Comparison

### Before (Centralized Routing)
```
Roll Module → Main Controller → Scoreboard  (Status)
Roll Module → Main Controller → Dice Display (Results)
            ↳ Main Controller ← High Memory Usage
```

### After (Direct Communication)
```
Roll Module → Scoreboard     (Status & Lives)
Roll Module → Dice Display   (Results)
           ↳ Main Controller ← Reduced Memory Usage
```

## Link Mapping Reference
- **Link 1**: Main Controller (Root)
- **Link 12**: Scoreboard Manager 
- **Link 35**: Leaderboard Communication
- **Link 83**: Dice Display Bridge

## Message Constants
```lsl
// Scoreboard Messages
integer MSG_GAME_STATUS = 3001;    // Status updates (Plot Twist, Direct Hit, etc.)
integer MSG_PLAYER_UPDATE = 3002;  // Life updates during gameplay
integer MSG_GAME_WON = 3010;       // Victory notifications
integer MSG_GAME_LOST = 3011;      // Elimination notifications

// Dice Display Messages  
integer MSG_DICE_ROLL = 3020;      // Roll result display
integer MSG_CLEAR_DICE = 3021;     // Clear display
```

## Testing Validation
- ✅ Roll Module sends status updates directly to scoreboard
- ✅ Roll Module sends life updates directly to scoreboard  
- ✅ Roll Module sends dice results directly to dice display
- ✅ Floater cleanup with timing delays for elimination
- ✅ Main Controller routing logic removed for direct paths

## Future Optimization Opportunities
1. **Bot Manager → Game Manager**: Direct bot pick notifications
2. **Floater Manager → Individual Floaters**: Direct floater commands
3. **Dialog Systems**: Direct dialog routing without Main Controller

This architecture maintains the robust linkset communication while significantly reducing memory pressure on the Main Controller.