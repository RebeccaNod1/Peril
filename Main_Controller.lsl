// === Main Controller - Peril Dice Game (Refactored with Modular Architecture) ===

// Helper function to get display name with fallback to username
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        // Fallback to legacy username if display name is unavailable
        displayName = llKey2Name(id);
    }
    return displayName;
}

//
// This version of the main game controller includes support for players (including
// the owner) joining the game at runtime via a MSG_REGISTER_PLAYER message. When
// a new player registers, they are added to the internal lists (players, names,
// lives and picksData), a floating display is rezzed for them, and helpers are
// updated. This mirrors the behaviour used when adding a test player, but now
// applies to any avatar joining the game via the dialog handler.

// =============================================================================
// DYNAMIC CHANNEL CONFIGURATION (replaces hardcoded channels)
// =============================================================================

// Base channel offset - change this to avoid conflicts with other objects
integer CHANNEL_BASE = -77000;

// Calculate channels dynamically to avoid hardcoded conflicts
integer calculateChannel(integer offset) {
    // Use BOTH owner's key AND object's key to make channels unique per game instance
    // This prevents interference when same owner has multiple game tables
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetKey();
    string combinedStr = ownerStr + objectStr;
    
    // Create a more unique hash using both keys
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2; // Creates 0-255 range
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Dynamic channel variables
integer SYNC_CHANNEL;
integer NUMBERPICK_CHANNEL;
integer ROLLDIALOG_CHANNEL; 
integer MAIN_DIALOG_CHANNEL;
integer BOT_COMMAND_CHANNEL;
integer SCOREBOARD_CHANNEL_1;
integer SCOREBOARD_CHANNEL_2;
integer SCOREBOARD_CHANNEL_3;
integer FLOATER_BASE_CHANNEL;

// Legacy channel variables (for backward compatibility during transition)
integer syncChannel;
integer numberPickChannel;
integer rollDialogChannel;
integer DIALOG_CHANNEL;

// Channel initialization function
initializeChannels() {
    SYNC_CHANNEL = calculateChannel(1);           // ~-77100 range
    NUMBERPICK_CHANNEL = calculateChannel(2);     // ~-77200 range  
    ROLLDIALOG_CHANNEL = calculateChannel(3);     // ~-77300 range
    MAIN_DIALOG_CHANNEL = calculateChannel(4);    // ~-77400 range
    BOT_COMMAND_CHANNEL = calculateChannel(5);    // ~-77500 range
    
    SCOREBOARD_CHANNEL_1 = calculateChannel(6);   // ~-77600 range
    SCOREBOARD_CHANNEL_2 = calculateChannel(7);   // ~-77700 range  
    SCOREBOARD_CHANNEL_3 = calculateChannel(8);   // ~-77800 range
    
    FLOATER_BASE_CHANNEL = calculateChannel(9);   // ~-77900 range
    
    // Set legacy variables for backward compatibility
    syncChannel = SYNC_CHANNEL;
    numberPickChannel = NUMBERPICK_CHANNEL;
    rollDialogChannel = ROLLDIALOG_CHANNEL;
    DIALOG_CHANNEL = MAIN_DIALOG_CHANNEL;
    
    // Report channels to owner for debugging
    llOwnerSay("🔧 [Main Controller] Dynamic channels initialized:");
    llOwnerSay("  Sync: " + (string)SYNC_CHANNEL);
    llOwnerSay("  Dialog: " + (string)MAIN_DIALOG_CHANNEL);  
    llOwnerSay("  Roll: " + (string)ROLLDIALOG_CHANNEL);
    llOwnerSay("  Scoreboard: " + (string)SCOREBOARD_CHANNEL_1);
    llOwnerSay("  Floater Base: " + (string)FLOATER_BASE_CHANNEL);
}

// Listen handle management
integer dialogHandle = -1;
integer botHandle = -1;
integer rollHandle = -1;

// Game timing settings to prevent dialog system overload
float BOT_PICK_DELAY = 2.0;      // Delay after bot picks before next action
float HUMAN_PICK_DELAY = 1.0;    // Delay after human picks before next action
float DIALOG_DELAY = 1.5;        // Delay before showing dialogs
integer gameTimer = 0;           // Timer for game flow delays

// Memory monitoring now handled by Controller_Memory.lsl helper script
integer MSG_MEMORY_CHECK = 6001;
integer MSG_MEMORY_STATS = 6002;
integer MSG_MEMORY_CLEANUP = 6003;
integer MSG_MEMORY_REPORT = 6004;
integer MSG_EMERGENCY_CLEANUP = 6005;
integer MSG_MEMORY_STATS_REQUEST = 6006;

// Unified Timer System - prevents conflicts between multiple timer needs
integer TIMER_IDLE = 0;
integer TIMER_STATUS = 1;
integer TIMER_TIMEOUT = 2;
integer TIMER_DISCOVERY = 3;
integer currentTimerMode = 0;    // Track what the timer is currently doing
float timerInterval = 1.0;       // How often timer() is called for checks

// Status message timing
float STATUS_DISPLAY_TIME = 8.0; // How long to show status messages on scoreboard
integer statusTimer = 0;         // Track when status messages were sent
string lastStatus = "";          // Track last status sent

// Discovery system now handled by Controller_Discovery.lsl helper script

list players = [];
list names = [];
list lives = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list picksData = [];
list readyPlayers = [];
list floaterChannels = []; // Track actual floater channels for cleanup

list pickQueue = [];
integer currentPickerIdx = 0;
integer diceType = 6;

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SHOW_MENU = 201;
integer MSG_TOGGLE_READY = 202;
integer MSG_QUERY_READY_STATE = 210;
integer MSG_READY_STATE_RESULT = 211;
integer MSG_CLEANUP_ALL_FLOATERS = 212;
integer MSG_SHOW_ROLL_DIALOG = 301;
integer MSG_GET_CURRENT_DIALOG = 302;
integer MSG_PLAYER_WON = 551;
integer MSG_RESET_LEADERBOARD = 553; // Custom message to reset leaderboard

// Display configuration
integer CONTROLLER_FACE = 1;  // Face to display start image on (front face)
string TEXTURE_START = "title_start";  // Start image texture
string TEXTURE_GAME_ACTIVE = "game_active";  // Optional: different texture during game

integer MSG_GET_DICE_TYPE = 1001;
integer MSG_GET_PICKS_REQUIRED = 1002;
integer MSG_GET_PICKER_INDEX = 1003;
integer MSG_DICE_TYPE_RESULT = 1005;
integer MSG_SERIALIZE_GAME_STATE = 1004;
integer MSG_SYNC_PICKQUEUE = 2001;

// Maximum number of players allowed (including test players). This should
// mirror the value used in Floater Manager to avoid inconsistencies.
integer MAX_PLAYERS = 10;

integer TIMEOUT_SECONDS = 600;
integer timeoutTimer;

integer warning2min = 120;
integer warning5min = 300;
integer warning9min = 540;
integer lastWarning = 0;

key currentPicker;

// Memory monitoring functions now delegated to Controller_Memory.lsl helper script
checkMemoryUsage(string context) {
    // Delegate to memory monitor helper
    llMessageLinked(LINK_SET, MSG_MEMORY_CHECK, context, NULL_KEY);
}

emergencyMemoryCleanup() {
    llOwnerSay("🎆 [Main Controller] Emergency memory cleanup initiated!");
    
    // Clean up temporary variables and optimize lists
    globalPickedNumbers = llListSort(globalPickedNumbers, 1, TRUE); // Remove duplicates
    
    // Force garbage collection by clearing and rebuilding critical lists
    list tempPlayers = players;
    list tempNames = names;
    list tempLives = lives;
    
    players = [];
    names = [];
    lives = [];
    
    players = tempPlayers;
    names = tempNames;
    lives = tempLives;
    
    llOwnerSay("🎆 [Main Controller] Emergency cleanup complete - memory: " + 
               (string)llGetUsedMemory() + " bytes");
}

reportMemoryStats() {
    // Request memory stats report from helper, provide our stats as well
    string statsData = (string)llGetUsedMemory() + "|" + 
                       (string)llGetListLength(players) + "|" + 
                       (string)llGetListLength(names) + "|" + 
                       (string)llGetListLength(lives) + "|" + 
                       (string)llGetListLength(picksData) + "|" + 
                       (string)llGetListLength(readyPlayers) + "|" + 
                       (string)llGetListLength(pickQueue) + "|" + 
                       (string)llGetListLength(globalPickedNumbers) + "|" + 
                       (string)llGetListLength(floaterChannels);
    
    // Send to memory monitor for comprehensive reporting
    llMessageLinked(LINK_SET, MSG_MEMORY_STATS_REQUEST, statsData, NULL_KEY);
    // Also request the helper to show its own stats
    llMessageLinked(LINK_SET, MSG_MEMORY_STATS, "REQUEST_REPORT", NULL_KEY);
}

// Send status message to scoreboard with timing
sendStatusMessage(string status) {
    statusTimer = llGetUnixTime();
    lastStatus = status;
    llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_STATUS|" + status);
    llOwnerSay("📢 Status: " + status + " (showing for " + (string)STATUS_DISPLAY_TIME + "s)");
    
    // Start unified timer for status message clearing
    currentTimerMode = TIMER_STATUS;
    llSetTimerEvent(STATUS_DISPLAY_TIME + 1.0); // Add 1 second buffer
}

// Forward game state to helpers when it changes - MEMORY OPTIMIZED
updateHelpers() {
    checkMemoryUsage("updateHelpers_start");
    
    string perilForSync = "NONE";
    if (roundStarted) perilForSync = perilPlayer;
    
    // Simplified picks data processing
    string picksDataStr = "EMPTY";
    integer dataCount = llGetListLength(picksData);
    if (dataCount > 0) {
        picksDataStr = llDumpList2String(picksData, "^");
        checkMemoryUsage("updateHelpers_after_picks_processing");
    }
    
    // Send core game state (now includes players list for dialog targeting)
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, 
        llList2CSV(lives) + "~" + picksDataStr + "~" + perilForSync + "~" + llList2CSV(names) + "~" + llList2CSV(players), NULL_KEY);
    // Don't sync pickQueue from Main to Game Manager - Game Manager manages its own pickQueue
    
    // Simplified scoreboard updates
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        llRegionSay(SCOREBOARD_CHANNEL_2, "PLAYER_UPDATE|" + llList2String(names, i) + "|" + 
            (string)llList2Integer(lives, i) + "|" + (string)llList2Key(players, i));
    }
}

// Request helper-calculated values
requestDiceType() {
    llMessageLinked(LINK_SET, MSG_GET_DICE_TYPE, (string)llGetListLength(names), NULL_KEY);
}

requestPicksRequired(integer idx) {
    llMessageLinked(LINK_SET, MSG_GET_PICKS_REQUIRED, llList2String(names, idx), NULL_KEY);
}

requestPickerIndex(string name) {
    llMessageLinked(LINK_SET, MSG_GET_PICKER_INDEX, name, NULL_KEY);
}

string generateSerializedState() {
    return llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
}

// Clean up listen handles
cleanupListeners() {
    if (dialogHandle != -1) {
        llListenRemove(dialogHandle);
        dialogHandle = -1;
    }
    if (botHandle != -1) {
        llListenRemove(botHandle);
        botHandle = -1;
    }
    if (rollHandle != -1) {
        llListenRemove(rollHandle);
        rollHandle = -1;
    }
}

// Re-initialize listen handles
initListeners() {
    dialogHandle = llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
    botHandle = llListen(BOT_COMMAND_CHANNEL, "", NULL_KEY, ""); // Listen for bot responses
    rollHandle = llListen(rollDialogChannel, "", NULL_KEY, ""); // Listen for roll dialog responses
}

resetGame() {
    // Clean up listeners first
    cleanupListeners();
    
    // UNIVERSAL CLEANUP: Always clean ALL possible floater channels regardless of tracked state
    // This ensures cleanup works even after script resets destroy tracking data
    integer i;
    for (i = 0; i < MAX_PLAYERS; i++) {
        integer ch = FLOATER_BASE_CHANNEL + i;
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    
    // Give floater cleanup time to process BEFORE clearing state
    llSleep(2.0);
    
    // Reset all game state variables
    players = names = lives = picksData = globalPickedNumbers = readyPlayers = [];
    floaterChannels = []; // Clear the tracked channels
    pendingRegistrations = []; // Clear pending registrations
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    roundStarted = FALSE; // Reset round flag
    gameStarting = FALSE; // Reset game starting flag
    diceTypeProcessed = FALSE; // Reset dice type processing flag
    currentPicker = NULL_KEY; // Reset current picker
    timeoutTimer = 0; // Reset timeout timer
    lastWarning = 0; // Reset warning timer
    diceType = 6; // Reset dice type to default
    
    // Send reset message to all other scripts to clear their state
    llMessageLinked(LINK_SET, -99999, "FULL_RESET", NULL_KEY);
    llSay(syncChannel, "RESET");
    
    // Send CLEAR_GAME message to scoreboard to reset display
    llRegionSay(SCOREBOARD_CHANNEL_1, "CLEAR_GAME");
    // Clear dice display
    llRegionSay(SCOREBOARD_CHANNEL_3, "CLEAR_DICE");
    llOwnerSay("🎮 Game reset! All state cleared (including scoreboard).");
    
    // Clear status tracking
    statusTimer = 0;
    lastStatus = "";
    
    // Reset controller display to start image
    llSetTexture(TEXTURE_START, CONTROLLER_FACE);
    llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
    
    llSleep(0.5); // Give other scripts time to process reset
    llSetTimerEvent(0);
    
    // Re-initialize listeners after reset
    initListeners();
    
    updateHelpers();
}

// continueCurrentRound() removed - handled by Game Manager

// startNextRound() removed - handled by Game Manager

// showNextPickerDialog() removed - handled by Game Manager

integer roundStarted = FALSE;
integer gameStarting = FALSE;  // Track when game is in startup sequence
integer diceTypeProcessed = FALSE;  // Track if we've already processed initial dice type

// CONTINUE_ROUND logic now handled entirely by Game Manager

// Prevent duplicate registration by tracking pending registrations
list pendingRegistrations = [];  // Keys of players who have registration in progress
integer REGISTRATION_TIMEOUT = 10;  // Seconds to keep pending registration

default {
    state_entry() {
        llOwnerSay("🎮 Main Controller ready!");
        llOwnerSay("🎮 Main Controller key: " + (string)llGetKey());
        llOwnerSay("🎮 Main Controller position: " + (string)llGetPos());
        
        // Initialize dynamic channel configuration
        initializeChannels();
        
        // Set the start image on the controller prim
        llSetTexture(TEXTURE_START, CONTROLLER_FACE);
        llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
        
        // Clean up any existing listeners
        if (dialogHandle != -1) llListenRemove(dialogHandle);
        if (botHandle != -1) llListenRemove(botHandle);
        if (rollHandle != -1) llListenRemove(rollHandle);
        
        // Set up managed listeners with dynamic channels
        dialogHandle = llListen(MAIN_DIALOG_CHANNEL, "", NULL_KEY, "");
        botHandle = llListen(BOT_COMMAND_CHANNEL, "", NULL_KEY, ""); // Listen for bot responses
        rollHandle = llListen(ROLLDIALOG_CHANNEL, "", NULL_KEY, ""); // Listen for roll dialog responses
        
        // Discovery system now handled by Controller_Discovery.lsl helper script
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        
// Check if player has a current dialog they can recover
if (idx != -1 && toucher != llGetOwner() && roundStarted) {
    string playerName = llList2String(names, idx);
    // Check if this player is the current picker waiting for a dialog
    if (currentPicker == toucher) {
        llRegionSayTo(toucher, 0, "🔄 Restoring your number picking dialog...");
        llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, playerName, toucher);
        return;
    }
    // Check if this player is the peril player who might need a roll dialog
    else if (playerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
        llRegionSayTo(toucher, 0, "🔄 Restoring your roll dialog...");
        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, toucher);
        return;
    }
}

// Special handling for owner during gameplay
if (toucher == llGetOwner() && roundStarted) {
    string ownerName = getPlayerName(toucher);
    list options = [];
    string menuText = "Game in progress. What would you like to do?";
    
    // Check if owner has active dialogs they can recover
    integer hasActiveDialog = FALSE;
    if (currentPicker == toucher) {
        options += ["🔄 Recover Pick Dialog"];
        hasActiveDialog = TRUE;
    }
    if (ownerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
        options += ["🔄 Recover Roll Dialog"];
        hasActiveDialog = TRUE;
    }
    
    // Always offer admin menu
    options += ["🔧 Admin Menu"];
    
    // If no active dialogs, just show admin menu directly
    if (!hasActiveDialog) {
        llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", toucher);
        return;
    }
    
    // Show choice dialog
    llDialog(toucher, menuText, options, DIALOG_CHANNEL);
    return;
}
        
        if (toucher == llGetOwner()) {
            // Determine if this will be the first registered player (starter) before registration
            integer isStarter = FALSE;
            if (idx == -1) {
                // Check if registration is already pending for this player
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    llOwnerSay("⏳ Registration already in progress for " + getPlayerName(toucher));
                    return;
                }
                
                // No index found; the owner is not yet registered.
                // Owner becomes starter if there are no existing human players (excluding bots)
                isStarter = TRUE;  // Default to TRUE for owner
                integer j;
                for (j = 0; j < llGetListLength(names) && isStarter; j++) {
                    string existingName = llList2String(names, j);
                    // If there's already a human player (not a bot), owner is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                    }
                }
                string ownerName = getPlayerName(toucher);
                // Add to pending registrations
                pendingRegistrations += [toucher];
                // Send a registration request; Main.lsl will handle adding them and rezzing a float
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, ownerName + "|" + (string)toucher, NULL_KEY);
            } else {
                // Already registered; check if owner is the first human player
                // Owner is starter if they are at index 0 OR if all players before them are bots
                isStarter = TRUE;  // Default to TRUE for owner
                integer k;
                for (k = 0; k < idx && isStarter; k++) {
                    string existingName = llList2String(names, k);
                    // If there's a human player before the owner, owner is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                    }
                }
                // Special case: if owner is at index 0, they are definitely the starter
                if (idx == 0) {
                    isStarter = TRUE;
                }
            }
            // Show the owner menu with the appropriate starter flag
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, toucher);
        } else if (idx != -1) {
            // For non-owner players, check if they're the first human player
            integer isStarter = TRUE;  // Default to TRUE
            integer m;
            for (m = 0; m < idx && isStarter; m++) {
                string existingName = llList2String(names, m);
                // If there's a human player before this player, they're not starter
                if (llSubStringIndex(existingName, "TestBot") != 0) {
                    isStarter = FALSE;
                }
            }
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
        } else {
            // Unregistered non-owner player - register them and show menu
            string playerName = getPlayerName(toucher);
            if (playerName != "") {
                // Check if registration is already pending for this player
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    llOwnerSay("⏳ Registration already in progress for " + playerName);
                    return;
                }
                
                // Add to pending registrations
                pendingRegistrations += [toucher];
                // Send a registration request; Main.lsl will handle adding them and rezzing a float
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, playerName + "|" + (string)toucher, NULL_KEY);
                // Determine if this will be the first human player (starter)
                integer isStarter = TRUE;  // Default to TRUE
                integer n;
                for (n = 0; n < llGetListLength(names) && isStarter; n++) {
                    string existingName = llList2String(names, n);
                    // If there's already a human player (not a bot), this player is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                    }
                }
                // Show the player menu with the appropriate starter flag
                llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
            } else {
                llOwnerSay("⚠️ Could not get name for toucher: " + (string)toucher);
            }
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        // Player list and pick data handling now delegated to Controller_MessageHandler.lsl
        // Handle dice type result from helper - forward to Game Manager once
        if (num == MSG_DICE_TYPE_RESULT) {
            // Prevent duplicate processing of the same dice type result
            if (diceTypeProcessed) {
                return;
            }
            
            diceType = (integer)str;
            diceTypeProcessed = TRUE;
            
            // Set round started flag and update helpers
            roundStarted = TRUE;
            updateHelpers();
            
            // Forward to Game Manager ONCE
            llMessageLinked(LINK_SET, MSG_DICE_TYPE_RESULT, (string)diceType, NULL_KEY);
            return;
        }
        if (num == MSG_GET_PICKS_REQUIRED) {
            integer picksRequired = (integer)str;
            llOwnerSay(" Picks required: " + str);
            return;
        }
        if (num == MSG_GET_PICKER_INDEX) {
            integer pickIndex = (integer)str;
            llOwnerSay(" Picker index: " + str);
            return;
        }
        if (num == MSG_SERIALIZE_GAME_STATE) {
            string serialized = str;
            llOwnerSay(" Serialized game state: " + serialized);
            return;
        }
        // Pick actions now delegated to Controller_MessageHandler.lsl
        // New: handle dynamic registration of players (owner or players) via MSG_REGISTER_PLAYER
        if (num == MSG_REGISTER_PLAYER) {
            checkMemoryUsage("player_registration_start");
            
            // str is in the format "Name|<key>"
            list parts = llParseString2List(str, ["|"], []);
            string newName = llList2String(parts, 0);
            key newKey = (key)llList2String(parts, 1);
            
            // Prevent joining game in progress or during startup (except owner accessing menu)
            if ((roundStarted || gameStarting) && newKey != llGetOwner()) {
                llOwnerSay("🚫 " + newName + " cannot join - the killing game has begun!");
                llRegionSayTo(newKey, 0, "🚫 The killing game has already begun! Wait for the current game to end.");
                return;
            }
            
            // Do not register if already present
            integer existingIdx = llListFindList(players, [newKey]);
            if (existingIdx == -1) {
                // Add to local lists
                players += [newKey];
                names += [newName];
                lives += [3];
                // Don't create empty picks entries - they will be added when players actually pick
                checkMemoryUsage("player_registration_after_list_additions");
                
                // Track the floater channel for this player
                integer newPlayerIdx = llGetListLength(names) - 1;
                integer ch = FLOATER_BASE_CHANNEL + newPlayerIdx;
                floaterChannels += [ch];
                // Auto-mark bots as ready, leave humans as not ready
                if (llSubStringIndex(newName, "TestBot") == 0) {
                    readyPlayers += [newName];
                    llSay(0, "🤖 " + newName + " boots up with deadly precision - ready to play! 🤖");
                } else {
                    // Check if this is the first human player (starter - automatically ready only if owner)
                    integer humanCount = 0;
                    integer i;
                    for (i = 0; i < llGetListLength(names); i++) {
                        string playerName = llList2String(names, i);
                        if (llSubStringIndex(playerName, "TestBot") != 0) {
                            humanCount++;
                        }
                    }
                    if (humanCount == 1) { // This is the first human player
                        if (newKey == llGetOwner()) {
                            // Owner is auto-ready as starter
                            readyPlayers += [newName];
                            llSay(0, "👑 " + newName + " steps forward as the game master - automatically ready for the deadly challenge! 👑");
                        } else {
                            // Non-owner starter can toggle ready state
                            llSay(0, "👑 " + newName + " steps forward as the game master! Touch to set your ready status.");
                        }
                    }
                }
                // The float will be rezzed by the Floater Manager after it processes
                // this registration.  Avoid sending MSG_REZ_FLOAT here to prevent
                // race conditions; instead, request the float from Floater Manager
                // after it has updated its own lists.  Immediately propagate
                // helper updates now.
                updateHelpers();
                // Notify owner of registration
                llOwnerSay("🔔 Added player: " + newName);
            }
            
            // Remove from pending registrations whether successful or not
            integer pendingIdx = llListFindList(pendingRegistrations, [newKey]);
            if (pendingIdx != -1) {
                pendingRegistrations = llDeleteSubList(pendingRegistrations, pendingIdx, pendingIdx);
            }
            return;
        }
        // Handle elimination requests
        if (num == 999) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "ELIMINATE_PLAYER") {
                string eliminatedPlayer = llList2String(parts, 1);
                integer idx = llListFindList(names, [eliminatedPlayer]);
                if (idx != -1) {
                    // Remove player's float using the tracked channel
                    integer ch = llList2Integer(floaterChannels, idx);
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // Remove from all lists
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    
                    llOwnerSay("🗑️ Eliminated " + eliminatedPlayer + ". Remaining players: " + (string)llGetListLength(names));
                    
                    // Record the loss in the leaderboard
                    llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_LOST|" + eliminatedPlayer);
                    
                    // Show elimination status when someone is actually eliminated
                    sendStatusMessage("Elimination");
                    
                    // Update all scripts with the new player lists after elimination
                    updateHelpers();
                    
                    // Check if game should end (1 or fewer players remaining)
                    if (llGetListLength(names) <= 1) {
if (llGetListLength(names) == 1) {
string winner = llList2String(names, 0);
llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
// Trigger victory confetti and record win
llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_WON|" + winner); // Send winner info to scoreboard
                            // Wait for elimination status to display before showing victory
                            llSleep(STATUS_DISPLAY_TIME * 0.8); // Wait 80% of status display time (~6.4 seconds)
sendStatusMessage("Victory");  // Show victory status
                            // Wait for victory status to display before reset
                            llSleep(STATUS_DISPLAY_TIME + 1.0);
                        } else {
                            llSay(0, "💀 DESPAIR WINS! No Ultimate Survivors remain!");
                            // Wait for elimination status to display before reset (elimination already sent above)
                            llSleep(STATUS_DISPLAY_TIME + 1.0);
                        }
                        resetGame();
                        return;
                    }
                    
                    // If the eliminated player was the peril player, assign a new one and continue game
                    if (eliminatedPlayer == perilPlayer) {
                        // Find first remaining alive player to be new peril player
                        perilPlayer = "";
                        integer k;
                        for (k = 0; k < llGetListLength(names) && perilPlayer == ""; k++) {
                            string candidateName = llList2String(names, k);
                            if (llList2Integer(lives, k) > 0) {
                                perilPlayer = candidateName;
                                llOwnerSay("🔄 After elimination, new peril player: " + perilPlayer);
                            }
                        }
                        
                        // Continue the game with the new peril player (don't reset roundStarted)
                        if (perilPlayer != "") {
                            llOwnerSay("🎯 Continuing game with " + perilPlayer + " as new peril player");
                            // Reset picks and queue for new round, but keep roundStarted = TRUE
                            picksData = [];
                            globalPickedNumbers = [];
                            pickQueue = [perilPlayer];
                            integer i;
                            for (i = 0; i < llGetListLength(names); i++) {
                                string playerName = llList2String(names, i);
                                if (playerName != perilPlayer) {
                                    pickQueue += [playerName];
                                }
                            }
                            currentPickerIdx = 0;
                            updateHelpers();
                            requestDiceType();
                        }
                    } else {
                        // Continue with existing peril player
                        updateHelpers();
                    }
                }
            }
            return;
        }
        // Handle game won
        if (num == 998) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "GAME_WON") {
string winner = llList2String(parts, 1);
llRegionSay(SCOREBOARD_CHANNEL_3, "GAME_WON|" + winner); // Send winner info to scoreboard
llSleep(2.0); // Let celebration message display
resetGame();
            }
            return;
        }
        // Handle incoming sync updates from Roll Confetti Module (only after rolls)
        if (num == MSG_SYNC_GAME_STATE) {
            // Only accept sync if it contains different data than what we have
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                string currentLivesStr = llList2CSV(lives);
                string newLivesStr = llList2CSV(newLives);
                
                // Check if we need to update (lives changed OR peril player changed)
                string newPerilPlayerCheck = llList2String(parts, 2);
                
                // Don't accept "NONE" as a valid peril player if we already have a real one,
                // UNLESS the eliminated player is trying to be set as peril player
                if (newPerilPlayerCheck == "NONE" && perilPlayer != "" && perilPlayer != "NONE") {
                    // Check if current peril player is still in the game
                    integer perilStillInGame = llListFindList(names, [perilPlayer]) != -1;
                    if (perilStillInGame) {
                        return; // Don't process this sync update
                    }
                }
                
                integer perilChanged = (perilPlayer != newPerilPlayerCheck);
                integer livesChanged = (newLivesStr != currentLivesStr);
                
                if (livesChanged || perilChanged) {
                    // Decode the pickData from the encoded format
                    string encodedPicksDataStr = llList2String(parts, 1);
                    list newPicksData = [];
                    if (encodedPicksDataStr != "") {
                        list encodedEntries = llParseString2List(encodedPicksDataStr, ["^"], []);
                        integer i;
                        for (i = 0; i < llGetListLength(encodedEntries); i++) {
                            string entry = llList2String(encodedEntries, i);
                            list entryParts = llParseString2List(entry, ["|"], []);
                            if (llGetListLength(entryParts) >= 2) {
                                string playerName = llList2String(entryParts, 0);
                                string picks = llList2String(entryParts, 1);
                                // Convert semicolons back to commas
                                picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                                newPicksData += [playerName + "|" + picks];
                            } else {
                                newPicksData += [entry];
                            }
                        }
                    }
                    string newPerilPlayer = llList2String(parts, 2);
                    list newNames = llCSV2List(llList2String(parts, 3));
                    
                    
                    // Update our game state with the new data
                    lives = newLives;
                    picksData = newPicksData;
                    perilPlayer = newPerilPlayer;
                    names = newNames;
                    
                    // Check if this is a post-roll state update and we need to start a new picking round
                    // Only trigger if lives changed (indicating a roll occurred) and we have a valid peril player
                    // Also check that all picks are empty (indicating this is after a roll, not during picking)
                    integer allPicksEmpty = TRUE;
                    integer i;
                    for (i = 0; i < llGetListLength(newPicksData) && allPicksEmpty; i++) {
                        string entry = llList2String(newPicksData, i);
                        list parts = llParseString2List(entry, ["|"], []);
                        if (llGetListLength(parts) >= 2 && llList2String(parts, 1) != "") {
                            allPicksEmpty = FALSE;
                        }
                    }
                    
                    // Main Controller no longer sends CONTINUE_ROUND messages
                    // Game Manager handles all round continuation logic internally
                    if (livesChanged && newPerilPlayer != "" && newPerilPlayer != "NONE" && roundStarted && allPicksEmpty) {
                        llOwnerSay("🎯 Post-roll state update detected - Game Manager will handle round continuation");
                    }
                    
                    // Don't call updateHelpers() here to avoid loop - other modules already have the data
                }
            }
            return;
        }
        // Handle start next round request - delegate to Game Manager
        if (num == 997) {
            // Additional protection against round start spam
            if (roundStarted && str == "START_NEXT_ROUND") {
                llOwnerSay("⚠️ [Main Controller] Round already in progress, ignoring START_NEXT_ROUND");
                return;
            }
            // Forward the request to Game Manager
            llMessageLinked(LINK_SET, num, str, id);
            // Don't request dice type here - it's handled in the "Start Game" listener below
            return;
        }
        // Dice type requests and leave game handling now delegated to Controller_MessageHandler.lsl
        // Handle ready state toggle
        if (num == MSG_TOGGLE_READY) {
            string playerName = str;
            integer idx = llListFindList(names, [playerName]);
            if (idx != -1) {
                // Don't allow bots to toggle ready state (they're always ready)
                if (llSubStringIndex(playerName, "TestBot") == 0) {
                    llOwnerSay("🤖 Bots are always ready and cannot change state");
                    return;
                }
                
                integer readyIdx = llListFindList(readyPlayers, [playerName]);
                if (readyIdx == -1) {
                    // Player is not ready, make them ready
                    readyPlayers += [playerName];
                    llSay(0, "⚔️ " + playerName + " steels themselves for the deadly challenge ahead! ⚔️");
                } else {
                    // Player is ready, make them not ready
                    readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    llSay(0, "🏃 " + playerName + " loses their nerve and backs away from the challenge! 🏃");
                }
            }
            return;
        }
        // Handle ready state queries
        if (num == MSG_QUERY_READY_STATE) {
            // Parse player name and optional request ID
            list queryParts = llParseString2List(str, ["|"], []);
            string playerName;
            integer requestID = 0;
            
            if (llGetListLength(queryParts) >= 2) {
                // New format with request ID
                playerName = llList2String(queryParts, 0);
                requestID = (integer)llList2String(queryParts, 1);
            } else {
                // Legacy format - just player name
                playerName = str;
            }
            
            integer isReady = llListFindList(readyPlayers, [playerName]) != -1;
            integer isBot = llSubStringIndex(playerName, "TestBot") == 0;
            string result = playerName + "|" + (string)isReady + "|" + (string)isBot + "|" + (string)requestID;
            llMessageLinked(LINK_SET, MSG_READY_STATE_RESULT, result, id);
            return;
        }
        // Handle aggressive floater cleanup
        if (num == MSG_CLEANUP_ALL_FLOATERS) {
            integer i;
            for (i = 0; i < MAX_PLAYERS; i++) {
                integer ch = FLOATER_BASE_CHANNEL + i;
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                // Also try some potential duplicate channels
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 100), NULL_KEY);
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 1000), NULL_KEY);
            }
            // Reset our tracked channels list
            floaterChannels = [];
            return;
        }
        // Handle HUMAN_PICKED messages - no forwarding needed since NumberPicker sends to LINK_SET
        if (num == -9998 && llSubStringIndex(str, "HUMAN_PICKED:") == 0) {
            // No need to forward - Game Manager receives directly from NumberPicker
            // Forwarding here creates an infinite loop!
            return;
        }
        // Handle BOT_PICKED messages - no forwarding needed since Bot Manager sends to LINK_SET
        if (num == -9997 && llSubStringIndex(str, "BOT_PICKED:") == 0) {
            // No need to forward - Game Manager receives directly from Bot Manager
            // Forwarding here creates an infinite loop!
            return;
        }
        
        // Handle memory monitor messages
        if (num == MSG_EMERGENCY_CLEANUP) {
            // Memory monitor is requesting emergency cleanup
            emergencyMemoryCleanup();
            return;
        }
    }


    listen(integer channel, string name, key id, string msg) {
        
        // Discovery system now handled by Controller_Discovery.lsl helper script
        
        if (channel == rollDialogChannel) {
            if (msg == "Start Next Round" || msg == "BEGIN KILLING GAME") {
                // Prevent duplicate round starts
                if (roundStarted) {
                    llOwnerSay("⚠️ Round already in progress, ignoring duplicate round start from roll dialog");
                    return;
                }
                
                llSay(0, "⚡ THE KILLING GAME CONTINUES! " + perilPlayer + " begins the next deadly round!");
                // Delegate to Game Manager
                llMessageLinked(LINK_SET, 997, "START_NEXT_ROUND", NULL_KEY);
                return;
            }
        }
        
        if (channel == DIALOG_CHANNEL) {
            // Handle owner choice dialog responses during gameplay
            if (id == llGetOwner() && roundStarted) {
                if (msg == "🔄 Recover Pick Dialog") {
                    string ownerName = getPlayerName(id);
                    llRegionSayTo(id, 0, "🔄 Restoring your number picking dialog...");
                    llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, ownerName, id);
                    return;
                }
                else if (msg == "🔄 Recover Roll Dialog") {
                    llRegionSayTo(id, 0, "🔄 Restoring your roll dialog...");
                    llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, id);
                    return;
                }
                else if (msg == "🔧 Admin Menu") {
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", id);
                    return;
                }
            }
            
            // Owner-specific commands: only owner messages in the dialog should be processed here.
            if (id == llGetOwner()) {
                if (msg == "Reset Game") {
resetGame(); // Only reset current game, keep leaderboard
                    return;
                }
                if (msg == "Reset Leaderboard") {
llRegionSay(SCOREBOARD_CHANNEL_1, "RESET_LEADERBOARD"); // Reset only leaderboard scores
                    llOwnerSay("🏆 Leaderboard scores reset - game wins cleared!");
                    return;
                }
                if (msg == "Reset All") {
                    resetGame(); // Reset current game
llRegionSay(SCOREBOARD_CHANNEL_1, "RESET_LEADERBOARD"); // Reset leaderboard scores
                    llOwnerSay("🔄 Complete reset - game and leaderboard cleared!");
                    return;
                }
                if (msg == "Memory Stats") {
                    reportMemoryStats();
                    return;
                }
                // Note: do not handle "Start Game" here; allow the generic start logic below to apply,
                // so that minimum player checks are enforced and non-owner starters can initiate the game.
                if (msg == "Add Test Player") {
                    // Ensure we do not exceed the maximum allowed players
                    if (llGetListLength(players) >= MAX_PLAYERS) {
                        llOwnerSay("⚠️ Cannot add test player; the game is full (max " + (string)MAX_PLAYERS + ").");
                        return;
                    }
                    // Generate a unique name and key for the test player
                    string testName = "TestBot" + (string)llGetUnixTime();
                    key fake = llGenerateKey();
                    // Delegate registration to the MSG_REGISTER_PLAYER handler; it will add to lists and rez a float
                    llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, testName + "|" + (string)fake, NULL_KEY);
                    // Show the owner menu again - owner should still be starter after adding bots
                    integer ownerIdx = llListFindList(players, [llGetOwner()]);
                    integer ownerIsStarter = TRUE;  // Default to TRUE for owner
                    integer n;
                    for (n = 0; n < ownerIdx && ownerIsStarter; n++) {
                        string existingName = llList2String(names, n);
                        // If there's a human player before the owner, owner is not starter
                        if (llSubStringIndex(existingName, "TestBot") != 0) {
                            ownerIsStarter = FALSE;
                        }
                    }
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)ownerIsStarter, llGetOwner());
                    return;
                }
            }
            // Allow the first registered player (index 0) or the owner to start the game.
            // When the starter clicks "Start Game", begin the round.
            if (msg == "Start Game") {
                // Enforce a minimum of 2 players before starting
                if (llGetListLength(players) < 2) {
                    llOwnerSay("⚠️ Need at least 2 players to start the game.");
                    return;
                }
                
                // Check if all non-starter players are ready
                string starterName = "";
                if (id == llGetOwner()) {
                    starterName = getPlayerName(llGetOwner());
                } else if (llGetListLength(players) > 0) {
                    key firstPlayer = llList2Key(players, 0);
                    if (id == firstPlayer) {
                        starterName = getPlayerName(firstPlayer);
                    }
                }
                
                if (starterName == "") {
                    llOwnerSay("⚠️ Only the game starter can start the game.");
                    return;
                }
                
                // Check if all non-starter human players are ready
                list notReadyPlayers = [];
                integer i;
                for (i = 0; i < llGetListLength(names); i++) {
                    string playerName = llList2String(names, i);
                    // Skip the starter and bots (bots are auto-ready)
                    if (playerName != starterName && llSubStringIndex(playerName, "TestBot") != 0) {
                        if (llListFindList(readyPlayers, [playerName]) == -1) {
                            notReadyPlayers += [playerName];
                        }
                    }
                }
                
                if (llGetListLength(notReadyPlayers) > 0) {
                    llOwnerSay("⚠️ Cannot start game. These players are not ready: " + llList2CSV(notReadyPlayers));
                    return;
                }
                
                // All checks passed, start the game
                gameStarting = TRUE; // Prevent new players from joining during startup
                llSay(0, "⚡ ALL PARTICIPANTS READY! THE DEADLY PERIL DICE GAME BEGINS! ⚡");
                
                // Change controller display to show game is active
                llSetText("🎮 GAME IN PROGRESS\nRound " + (string)(llGetListLength(names)) + " players", <1.0, 0.2, 0.2>, 1.0);
                
                sendStatusMessage("Title");  // Show title status at game start
                // Delegate to Game Manager
                llMessageLinked(LINK_SET, 997, "START_NEXT_ROUND", NULL_KEY);
                // Don't request dice type here - let Game Manager handle it to avoid duplicate requests
            }
            // If the message text matches a player name, request their pick list
            if (llListFindList(names, [msg]) != -1) {
                llMessageLinked(LINK_SET, 206, msg, id);
            }
        }
    }
    
    timer() {
        if (currentTimerMode == TIMER_STATUS) {
            // Handle status message clearing
            if (statusTimer > 0 && (llGetUnixTime() - statusTimer) >= STATUS_DISPLAY_TIME) {
                statusTimer = 0;
                lastStatus = "";
                llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_STATUS|Title");
                llOwnerSay("📢 Status cleared - reverted to Title");
                currentTimerMode = TIMER_IDLE;
                llSetTimerEvent(0);
            }
        }
        else if (currentTimerMode == TIMER_TIMEOUT) {
            // Handle dialog timeout warnings
            if (timeoutTimer > 0) {
                integer elapsed = llGetUnixTime() - timeoutTimer;
                if (elapsed >= TIMEOUT_SECONDS) {
                    llOwnerSay("⏰ Dialog timeout reached!");
                    timeoutTimer = 0;
                    currentTimerMode = TIMER_IDLE;
                    llSetTimerEvent(0);
                } else {
                    integer remaining = TIMEOUT_SECONDS - elapsed;
                    if (remaining <= warning2min && lastWarning < warning2min) {
                        llOwnerSay("⚠️ " + (string)(remaining / 60) + " minutes remaining for dialog response");
                        lastWarning = warning2min;
                    } else if (remaining <= warning5min && lastWarning < warning5min) {
                        llOwnerSay("⚠️ " + (string)(remaining / 60) + " minutes remaining for dialog response");
                        lastWarning = warning5min;
                    } else if (remaining <= warning9min && lastWarning < warning9min) {
                        llOwnerSay("⚠️ " + (string)(remaining / 60) + " minutes remaining for dialog response");
                        lastWarning = warning9min;
                    }
                }
            }
        }
        // Discovery timer handling now delegated to Controller_Discovery.lsl helper script
    }
}
