#include "Peril_Constants.lsl"

// === Game Manager - Game Flow Logic ===

// Helper function to get display name with fallback to username
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        // Fallback to legacy username if display name is unavailable
        displayName = llKey2Name(id);
    }
    return displayName;
}

// Game state - synced from Main Controller
list players = [];
list names = [];
list lives = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list picksData = [];
list pickQueue = [];
integer currentPickerIdx = 0;
integer diceType = 6;
key currentPicker;
integer roundStarted = FALSE;
integer diceTypeProcessed = FALSE;  // Track if we've already processed dice type for this round
integer ignorePicksSync = FALSE;     // Temporarily ignore picks data sync during round initialization
integer roundContinueInProgress = FALSE;  // Prevent multiple rapid calls to continueCurrentRound
integer lastPlayerCount = 0;         // Memory for dice type calculation (skips redundant requests)
integer lastSyncProcessTime = 0;     // Track when we last processed a sync to prevent rapid duplicates

// Duplicate request prevention
string lastHumanPickMessage = "";
string lastBotPickMessage = "";
integer lastProcessTime = 0;

// Build complete avoidance list from all current picks
list buildCompleteAvoidanceList() {
    list allPicks = [];
    integer i;
    
    // Add all picks from picksData (current round)
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list entryParts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(entryParts) >= 2) {
            string picks = llList2String(entryParts, 1);
            if (picks != "") {
                // Split multiple picks (comma or semicolon separated)
                list playerPicks = llParseString2List(picks, [","], []);
                if (llGetListLength(playerPicks) == 1) {
                    // Also try semicolon separator
                    playerPicks = llParseString2List(picks, [";"], []);
                }
                integer j;
                for (j = 0; j < llGetListLength(playerPicks); j++) {
                    string pick = llStringTrim(llList2String(playerPicks, j), STRING_TRIM);
                    if (pick != "" && llListFindList(allPicks, [pick]) == -1) {
                        allPicks += [pick];
                    }
                }
            }
        }
    }
    
    // Also add any picks from globalPickedNumbers as backup
    for (i = 0; i < llGetListLength(globalPickedNumbers); i++) {
        string globalPick = llList2String(globalPickedNumbers, i);
        if (globalPick != "" && llListFindList(allPicks, [globalPick]) == -1) {
            allPicks += [globalPick];
        }
    }
    
    return allPicks;
}

// Memory reporting function
integer reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    dbg("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
    return 0;
}

// Build complete avoidance list from all current picks

integer continueCurrentRound() {
    // MEMORY OPTIMIZED: Skip complex validation - trust game state
    // Main Controller handles all game ending validation
    
    // Check for eliminated players (0 lives) - don't continue if any exist
    integer continueIdx;
    for (continueIdx = 0; continueIdx < llGetListLength(names); continueIdx++) {
        string continueName = llList2String(names, continueIdx);
        integer continuePlayerIdx = llListFindList(names, [continueName]);
        if (continuePlayerIdx != -1 && continuePlayerIdx < llGetListLength(lives)) {
            integer continuePlayerLives = llList2Integer(lives, continuePlayerIdx);
            if (continuePlayerLives <= 0) {
                dbg("🛑 [Game Manager] continueCurrentRound: Found eliminated player " + continueName + " with " + (string)continuePlayerLives + " lives - aborting round start");
                return 0;
            }
        }
    }
    
    if (perilPlayer == "" || perilPlayer == "NONE") {
        dbg("🛑 [Game Manager] continueCurrentRound: Invalid peril player (" + perilPlayer + ") - aborting round start");
        return 0;
    }
    
    // Verify peril player exists and has lives
    integer perilIdx = llListFindList(names, [perilPlayer]);
    if (perilIdx == -1) {
        dbg("🛑 [Game Manager] continueCurrentRound: Peril player " + perilPlayer + " not found in names list - aborting round start");
        return 0;
    }
    if (perilIdx >= llGetListLength(lives)) {
        dbg("🛑 [Game Manager] continueCurrentRound: Peril player " + perilPlayer + " index out of bounds - aborting round start");
        return 0;
    }
    integer perilLives = llList2Integer(lives, perilIdx);
    if (perilLives <= 0) {
        dbg("🛑 [Game Manager] continueCurrentRound: Peril player " + perilPlayer + " has " + (string)perilLives + " lives - aborting round start");
        return 0;
    }
    
    // Start fresh for a new round - clear picks data
    // globalPickedNumbers will be cleared when first player picks
    picksData = [];
    
    dbg("🔄 [Game Manager] continueCurrentRound: All validation passed, starting fresh round with " + (string)llGetListLength(names) + " players");
    
    // Set round as started for the new round
    roundStarted = TRUE;
    diceTypeProcessed = FALSE; // Reset dice type processing for new round
    
    // Create new pick queue with peril player first
    pickQueue = [perilPlayer];
    for (continueIdx = 0; continueIdx < llGetListLength(names); continueIdx++) {
        string continuePlayerName = llList2String(names, continueIdx);
        if (continuePlayerName != perilPlayer) {
            pickQueue += [continuePlayerName];
        }
    }
    currentPickerIdx = 0;
    
    dbg("🎯 [Game Manager] Pick queue created: " + llList2CSV(pickQueue) + ", checking dice memory...");
    
    integer currentPlayerCount = llGetListLength(names);
    if (currentPlayerCount == lastPlayerCount && diceType > 0) {
        dbg("🎯 [Game Manager] Player count unchanged (" + (string)currentPlayerCount + "), reusing stored dice type: d" + (string)diceType);
        
        // NEW: Add a brief buffer to let the previous outcome status stay on screen
        llSleep(DELAY_MEDIUM_SYNC);
        
        // Reuse stored dice type and skip redundant request/status Flicker
        diceTypeProcessed = TRUE;
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "NEW ROUND STARTING!\nPeril: <!c=red>" + perilPlayer, NULL_KEY);
        showNextPickerDialog();
    } else {
        lastPlayerCount = currentPlayerCount;
        // NEW: Update status bar for new round initialization
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "NEW ROUND STARTING!\nPeril: <!c=red>" + perilPlayer, NULL_KEY);
        // Request dice type directly from Calculator for the new round
        llMessageLinked(LINK_SET, MSG_GET_DICE_TYPE, (string)currentPlayerCount, NULL_KEY);
    }
    
    // Note: showNextPickerDialog() will be called when dice type result is received (or immediately if cached)
    return 0;
}

integer startNextRound() {
    // Prevent multiple calls to start round
    if (roundStarted) {
        dbg("⚠️ Round already started, ignoring duplicate start request");
        return 0;
    }
    
    if (llGetListLength(names) < 2) {
        dbg("⚠️ Need at least 2 players to start the game.");
        return 0;
    }
    
    if (llGetListLength(names) == 1) {
        string winner = llList2String(names, 0);
        llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
        
        // Send winner glow update to scoreboard
        llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_WINNER, winner, NULL_KEY);  // MSG_UPDATE_WINNER
        
        llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
        llMessageLinked(LINK_SET, MSG_EFFECT_CONFETTI, "VICTORY_CONFETTI", NULL_KEY);
        
        // NEW: Update status bar with 2-line victory message
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "ULTIMATE VICTORY!\n" + winner + " is the survivor!", NULL_KEY);
        
                // Don't use hardcoded channel here - let Main Controller handle scoreboard updates
                // Main Controller will send the proper GAME_WON message to scoreboard
        // Let main controller handle reset
        return 0;
    }
    
    dbg("🎯 Game Manager starting new round...");
    
    // Set roundStarted immediately to prevent duplicate calls
    roundStarted = TRUE;
    diceTypeProcessed = FALSE;  // Reset for new round
    
    // Select random peril player if none is set
    if (perilPlayer == "" || perilPlayer == "NONE") {
        integer randomIdx = (integer)llFrand(llGetListLength(names));
        perilPlayer = llList2String(names, randomIdx);
        llSay(0, "🎯 " + perilPlayer + " has been randomly selected and is now in peril!");
        
        // Send peril player update to scoreboard for glow effect
        llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_PERIL_PLAYER, perilPlayer, NULL_KEY);  // MSG_UPDATE_PERIL_PLAYER
        
        // Sync state to floater manager first, then update floaters to show new peril player immediately
        dbg("🔄 [Game Manager] Syncing state and updating floaters for new peril player: " + perilPlayer);
        syncStateToMain(); // Sync the peril player to all modules first
        llSleep(DELAY_SHORT_SYNC); // Brief delay to ensure sync propagates
        integer startJ;
        for (startJ = 0; startJ < llGetListLength(names); startJ++) {
            string startPlayerName = llList2String(names, startJ);
            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, startPlayerName, NULL_KEY);
        }
        
        // NEW: Update status bar with 2-line round start message and color highlight
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "ROUND STARTING!\nPeril: <!c=red>" + perilPlayer, NULL_KEY);

        // Dramatic pause to let the first peril player be seen before round prep begins
        llSleep(DELAY_LONG_SYNC);
    }
    
    picksData = [];
    // globalPickedNumbers will be cleared when first player picks
    
    // Create pick queue with peril player first
    dbg("🎯 Debug - Creating pickQueue. names: " + llList2CSV(names) + ", perilPlayer: " + perilPlayer);
    pickQueue = [perilPlayer];
    integer k;
    for (k = 0; k < llGetListLength(names); k++) {
        string startName = llList2String(names, k);
        if (startName != perilPlayer) {
            pickQueue += [startName];
        }
    }
    currentPickerIdx = 0;
    dbg("🎯 Debug - Created pickQueue: " + llList2CSV(pickQueue) + ", currentPickerIdx: " + (string)currentPickerIdx);
    
    integer currentPlayerCount = llGetListLength(names);
    if (currentPlayerCount == lastPlayerCount && diceType > 0) {
        dbg("🎯 [Game Manager] Player count unchanged (" + (string)currentPlayerCount + "), reusing stored dice type: d" + (string)diceType);
        
        // NEW: Add a brief buffer to let the previous outcome status stay on screen
        llSleep(DELAY_MEDIUM_SYNC);
        
        diceTypeProcessed = TRUE;
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "ROUND STARTING!\nPeril: <!c=red>" + perilPlayer, NULL_KEY);
        showNextPickerDialog();
    } else {
        lastPlayerCount = currentPlayerCount;
        // Request dice type for this round
        llMessageLinked(LINK_SET, MSG_GET_DICE_TYPE, (string)currentPlayerCount, NULL_KEY);
        // NEW: Update status bar for round start
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "ROUND STARTING!\nPeril: <!c=red>" + perilPlayer, NULL_KEY);
    }
    
    dbg("🎯 Game Manager round setup complete.");
    return 0;
}

integer showNextPickerDialog() {
    // MEMORY OPTIMIZED: Skip complex validation - trust that game is active
    // Main Controller handles all game ending logic
    
    // Clear globalPickedNumbers if this is the first picker of a new round
    if (currentPickerIdx == 0 && llGetListLength(picksData) == 0) {
        globalPickedNumbers = [];
        dbg("🔄 [Game Manager] Cleared globalPickedNumbers at start of new round");
    }
    
    if (diceType <= 0) {
        dbg("❌ Cannot show picker dialog: diceType not set (" + (string)diceType + ")");
        return 0;
    }
    
    if (currentPickerIdx >= llGetListLength(pickQueue)) {
        dbg("❌ Cannot show picker dialog: currentPickerIdx (" + (string)currentPickerIdx + ") >= pickQueue length (" + (string)llGetListLength(pickQueue) + ")");
        return 0;
    }
    
    string firstName = llList2String(pickQueue, currentPickerIdx);
    if (firstName == "") {
        dbg("❌ Cannot show picker dialog: empty player name at index " + (string)currentPickerIdx);
        return 0;
    }
    
    // CRITICAL: Verify this player is still alive and in the game
    integer showPlayerIdx = llListFindList(names, [firstName]);
    if (showPlayerIdx == -1) {
        dbg("❌ Cannot show picker dialog: player " + firstName + " not found in current game");
        return 0;
    }
    
    if (showPlayerIdx >= llGetListLength(lives)) {
        dbg("❌ Cannot show picker dialog: player " + firstName + " index out of bounds for lives list");
        return 0;
    }
    
    integer showPlayerLives = llList2Integer(lives, showPlayerIdx);
    if (showPlayerLives <= 0) {
        dbg("❌ Cannot show picker dialog: player " + firstName + " has been eliminated (" + (string)showPlayerLives + " lives)");
        return 0;
    }
    
    // CHECK: Don't show dialog if this player already has picks to prevent loops
    integer alreadyHasPicks = FALSE;
    integer showIdx;
    for (showIdx = 0; showIdx < llGetListLength(picksData) && !alreadyHasPicks; showIdx++) {
        if (llSubStringIndex(llList2String(picksData, showIdx), firstName + "|") == 0) {
            string existingPicks = llGetSubString(llList2String(picksData, showIdx), llStringLength(firstName) + 1, -1);
            if (existingPicks != "") {
                alreadyHasPicks = TRUE;
                dbg("🎯 Game Manager: " + firstName + " already has picks (" + existingPicks + "), advancing to next player");
            }
        }
    }
    
        if (alreadyHasPicks) {
            // Skip to next player to prevent infinite loops
            currentPickerIdx++;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                showNextPickerDialog();
            } else {
            // All picked, show roll dialog through Player_RegistrationManager
            string firstRollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
            llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, firstRollRequest, NULL_KEY);
            }
            return 0;
        }
    
    integer nameIdx = llListFindList(names, [firstName]);
    if (nameIdx == -1) {
        dbg("❌ Cannot show picker dialog: player " + firstName + " not found in names list");
        return 0;
    }
    
        // SIMPLE FIX: Send dialog request to Main Controller with player name
        // Main Controller has the player keys and can forward to NumberPicker with correct key
        
        llSleep(DIALOG_DELAY);
        
        if (llSubStringIndex(firstName, "Bot") == 0) {
        // Bot picking - but first double-check this bot doesn't already have picks
        integer botAlreadyHasPicks = FALSE;
        integer showJ;
        for (showJ = 0; showJ < llGetListLength(picksData) && !botAlreadyHasPicks; showJ++) {
            if (llSubStringIndex(llList2String(picksData, showJ), firstName + "|") == 0) {
                string existingBotPicks = llGetSubString(llList2String(picksData, showJ), llStringLength(firstName) + 1, -1);
                if (existingBotPicks != "") {
                    botAlreadyHasPicks = TRUE;
                    dbg("⚠️ [Game Manager] Bot " + firstName + " already has picks, skipping bot command: " + existingBotPicks);
                }
            }
        }
        
        if (!botAlreadyHasPicks) {
            integer showPerilIdx = llListFindList(names, [perilPlayer]);
            integer showPerilLives = 3;
            if (showPerilIdx != -1) {
                showPerilLives = llList2Integer(lives, showPerilIdx);
            }
            integer showPicksNeeded = 4 - showPerilLives;
            
            // Send proper avoid list to bots so they don't pick human numbers
            list showCompleteAvoidList = buildCompleteAvoidanceList();
            string showAvoidListStr = llList2CSV(showCompleteAvoidList);
            string botCommand = "BOT_PICK:" + firstName + ":" + (string)showPicksNeeded + ":" + (string)diceType + ":" + showAvoidListStr;
            dbg("🎯 [Game Manager] Sending bot command with complete avoid list (" + (string)llGetListLength(showCompleteAvoidList) + " numbers): " + showAvoidListStr);
            llMessageLinked(LINK_SET, MSG_BOT_COMMAND, botCommand, NULL_KEY);
            dbg("🤖 " + firstName + " is automatically picking " + (string)showPicksNeeded + " numbers...");
            
            // NEW: Update status bar for bot picking
            llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "BOTS CALCULATING...\n" + firstName + " is deciding...", NULL_KEY);
        } else {
            // Bot already has picks, advance to next player immediately
            currentPickerIdx++;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                showNextPickerDialog();
            } else {
                // All picked, show roll dialog through Player_RegistrationManager
                string humanRollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
                llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, humanRollRequest, NULL_KEY);
            }
        }
    } else {
        // Human picking
        integer humanPerilIdx = llListFindList(names, [perilPlayer]);
        integer humanPerilLives = 3;
        if (humanPerilIdx != -1) {
            humanPerilLives = llList2Integer(lives, humanPerilIdx);
        }
        integer humanPicksNeeded = 4 - humanPerilLives;
        
        // Send dialog payload with complete avoid list for humans too
        list humanCompleteAvoidList = buildCompleteAvoidanceList();
        string humanAvoidListStr = llList2CSV(humanCompleteAvoidList);
        string dialogPayload = firstName + "|" + (string)diceType + "|" + (string)humanPicksNeeded + "|" + humanAvoidListStr;
        
        dbg("🎯 Showing pick dialog for " + firstName);
        llSleep(DELAY_ANTI_SPAM);  // Brief delay to prevent spam
        
        // Send dialog request through Player_RegistrationManager (it has the correct player keys)
        string dialogRequest = "SHOW_DIALOG|" + firstName + "|" + dialogPayload;
        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, dialogRequest, NULL_KEY);
        
        // NEW: Update status bar for human picking
        llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "PICKING NUMBERS...\n" + firstName + " is choosing...", NULL_KEY);
    }
    return 0;
}

// requestDiceType() removed - Game Manager no longer requests dice type directly
// This prevents loops. Main Controller handles all dice type requests.

integer syncStateToMain() {
    // MEMORY OPTIMIZED: Skip ALL sync operations to prevent corrupting Main Controller's data
    // Main Controller is the master - Game Manager should not send sync messages
    return 0;
}

default {
    state_entry() {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("🎯 Game Manager ready - discovery complete! Scoreboard: " + (string)LINK_SCOREBOARD);
        
        // Initialize/reset all game state variables
        players = [];
        names = [];
        lives = [];
        perilPlayer = "";
        globalPickedNumbers = [];
        picksData = [];
        pickQueue = [];
        currentPickerIdx = 0;
        diceType = 6;
        currentPicker = NULL_KEY;
        roundStarted = FALSE;
        diceTypeProcessed = FALSE;
        ignorePicksSync = FALSE;
        roundContinueInProgress = FALSE;
        lastHumanPickMessage = "";
        lastBotPickMessage = "";
        lastProcessTime = 0;
        
        dbg("🎯 Game Manager ready!");
    }
    
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("🔄 Game Manager reset via rez...");
        
        // Reset all game state variables on rez
        players = [];
        names = [];
        lives = [];
        perilPlayer = "";
        globalPickedNumbers = [];
        picksData = [];
        pickQueue = [];
        currentPickerIdx = 0;
        diceType = 6;
        currentPicker = NULL_KEY;
        roundStarted = FALSE;
        diceTypeProcessed = FALSE;
        ignorePicksSync = FALSE;
        roundContinueInProgress = FALSE;
        lastHumanPickMessage = "";
        lastBotPickMessage = "";
        lastProcessTime = 0;
        
        dbg("✅ Game Manager reset complete after rez!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        
        // Handle incoming sync updates from Roll Confetti Module and other sources
        if (num == MSG_SYNC_GAME_STATE) {
            // Only skip sync messages if we're explicitly ignoring them
            // Allow player registration syncs even when game is not active
            
            list parts = llParseStringKeepNulls(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                string currentLivesStr = llList2CSV(lives);
                string newLivesStr = llList2CSV(newLives);
                
                string newPerilPlayerCheck = llList2String(parts, 2);
                list newNames = llCSV2List(llList2String(parts, 3));
                
                // MEMORY OPTIMIZED: Skip complex validation that causes circular sync issues
                // Trust that sender sends valid data
                
                if (newPerilPlayerCheck == "NONE" && perilPlayer != "" && perilPlayer != "NONE") {
                    integer perilStillInGame = llListFindList(names, [perilPlayer]) != -1;
                    if (perilStillInGame) {
                        return;
                    }
                }
                
                integer perilChanged = (perilPlayer != newPerilPlayerCheck);
                integer livesChanged = (newLivesStr != currentLivesStr);
                
                if (livesChanged || perilChanged) {
                    string encodedPicksDataStr = llList2String(parts, 1);
                    list newPicksData = [];
                    if (encodedPicksDataStr != "" && encodedPicksDataStr != "~EMPTY~") {
                        list encodedEntries = llParseString2List(encodedPicksDataStr, ["^"], []);
                        integer syncI;
                        for (syncI = 0; syncI < llGetListLength(encodedEntries); syncI++) {
                            string syncEntry = llList2String(encodedEntries, syncI);
                            list entryParts = llParseString2List(syncEntry, ["|"], []);
                            if (llGetListLength(entryParts) >= 2) {
                                string syncPlayerName = llList2String(entryParts, 0);
                                string picks = llList2String(entryParts, 1);
                                picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                                newPicksData += [syncPlayerName + "|" + picks];
                            } else {
                                newPicksData += [syncEntry];
                            }
                        }
                    }
                    string newPerilPlayer = llList2String(parts, 2);
                    list newNames = llCSV2List(llList2String(parts, 3));
                    
                    lives = newLives;
                    picksData = newPicksData;
                    perilPlayer = newPerilPlayer;
                    names = newNames;
                    
                    // Send lightweight update to Main Controller for floating text (only if substantial change)
                    // Use the NEW names list count (after elimination has been processed)
                    if (perilChanged && perilPlayer != "" && perilPlayer != "NONE") {
                        integer currentPlayerCount = llGetListLength(newNames);  // Use the updated count
                        string lightUpdate = "PERIL_UPDATE|" + perilPlayer + "|" + (string)currentPlayerCount;
                        llMessageLinked(LINK_SET, MSG_SYNC_LIGHTWEIGHT, lightUpdate, NULL_KEY);
                    }
                    
                    integer allPicksEmpty = TRUE;
                    integer checkI;
                    for (checkI = 0; checkI < llGetListLength(newPicksData) && allPicksEmpty; checkI++) {
                        string checkEntry = llList2String(newPicksData, checkI);
                        list checkParts = llParseString2List(checkEntry, ["|"], []);
                        if (llGetListLength(checkParts) >= 2 && llList2String(checkParts, 1) != "") {
                            allPicksEmpty = FALSE;
                        }
                    }
                    
                    // Note: Round continuation is now handled by the Main Controller's explicit MSG_CONTINUE_ROUND signal
                    // This prevents duplicate round starts and race conditions during Plot Twists.
                }
            }
            return;
        }
        
        // Receive legacy game state updates from main controller (simplified version)
        if (num == MSG_SYNC_LEGACY) {
            dbg("🔧 [Game Manager] Received sync: " + str);
            list parts = llParseString2List(str, ["~"], []);
            dbg("🔧 [Game Manager] Parsed into " + (string)llGetListLength(parts) + " parts");
            
            // MEMORY OPTIMIZED: Skip heavy validation that causes sync rejections
            // Trust that Main Controller sends valid data
            
            // Handle special RESET sync message
            if (llGetListLength(parts) >= 5 && llList2String(parts, 0) == "RESET") {
                dbg("🔄 [Game Manager] Received reset sync - ignoring during reset");
                return;
            }
            
            if (llGetListLength(parts) < 4) {
                dbg("⚠️ [Game Manager] Incomplete sync message received, parts: " + (string)llGetListLength(parts) + " - IGNORING");
                return;
            }
            {
                // MEMORY OPTIMIZED: Handle compatible format efficiently
                if (llGetListLength(parts) >= 4) {
                    // Parse names from part 3 (compatible with standard format)
                    string namesStr = llList2String(parts, 3);
                    
                    // CRITICAL: Must use real player names for dialog system
                    if (llSubStringIndex(namesStr, ",") != -1) {
                        // Multiple players - extract real names and trim spaces
                        integer commaPos = llSubStringIndex(namesStr, ",");
                        string firstName = llStringTrim(llGetSubString(namesStr, 0, commaPos - 1), STRING_TRIM);
                        string secondName = llStringTrim(llGetSubString(namesStr, commaPos + 1, -1), STRING_TRIM);
                        
                        names = [firstName, secondName];
                        // Parse lives from sync message instead of hardcoding
                        string multiLivesStr = llList2String(parts, 0);
                        if (llSubStringIndex(multiLivesStr, ",") != -1) {
                            lives = llCSV2List(multiLivesStr);
                        } else {
                            lives = [3, 3]; // Fallback for single player
                        }
                    } else {
                        // Single player - use real name and trim spaces
                        names = [llStringTrim(namesStr, STRING_TRIM)];
                        // Parse lives from sync message instead of hardcoding
                        string livesStr = llList2String(parts, 0);
                        if (livesStr != "") {
                            lives = llCSV2List(livesStr);
                        } else {
                            lives = [3]; // Fallback
                        }
                    }
                    
                    dbg("🎯 [Game Manager] Updated: " + (string)llGetListLength(names) + " players (minimal parsing)");
                }
                
                // Update peril player
                string receivedPerilPlayer = llList2String(parts, 2);
                if (receivedPerilPlayer != "NONE" && receivedPerilPlayer != "") {
                    perilPlayer = receivedPerilPlayer;
                    dbg("🎯 [Game Manager] Peril player updated to: " + perilPlayer);
                }
                
                // MEMORY OPTIMIZED: Skip all other complex processing
            }
            return;
        }
        
        // Receive pick queue updates
        if (num == MSG_SYNC_PICKQUEUE) {
            list newPickQueue = llCSV2List(str);
            string senderStr = (string)sender;
            string queueLenStr = (string)llGetListLength(newPickQueue);
            dbg("🔍 [Game Manager] Received pickQueue sync from sender " + senderStr + ": '" + str + "' (" + queueLenStr + " items)");
            
            // STRONGEST PROTECTION: Never accept empty pickQueues during any active round
            if (roundStarted && llGetListLength(pickQueue) > 0 && (str == "" || llGetListLength(newPickQueue) == 0)) {
                dbg("🔍 [Game Manager] REJECTING empty/invalid pickQueue sync during active round - keeping: " + llList2CSV(pickQueue));
                return;
            }
            
            // Additional protection: Don't accept pickQueue syncs if we just created a valid one
            if (llGetListLength(pickQueue) > 0 && (str == "" || llGetListLength(newPickQueue) == 0)) {
                dbg("🔍 [Game Manager] REJECTING empty pickQueue sync - keeping valid queue: " + llList2CSV(pickQueue));
                return;
            }
            
            // Only accept valid non-empty pickQueues
            if (llGetListLength(newPickQueue) > 0) {
                pickQueue = newPickQueue;
                dbg("🔍 [Game Manager] pickQueue updated to: " + llList2CSV(pickQueue));
            } else {
                dbg("🔍 [Game Manager] Ignoring invalid pickQueue sync - keeping current: " + llList2CSV(pickQueue));
            }
            return;
        }
        
        // Handle dice type result from Calculator
        if (num == MSG_DICE_TYPE_RESULT) {
            // Prevent duplicate processing of dice type results
            if (diceTypeProcessed) {
                dbg("🎲 Ignoring duplicate dice type result: " + str);
                return;
            }
            
            diceType = (integer)str;
            diceTypeProcessed = TRUE;
            dbg("🎲 Game Manager received dice type: d" + str + " from Calculator");
            
            // NEW: Update status bar when dice is ready
            llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "DICE READY!\nRolling a d" + str + " this round", NULL_KEY);
            
            // Dramatic pause to let players see the dice type before picking starts
            llSleep(DELAY_LONG_SYNC);
            
            // Start dialog if round has been started and we have a queue
            if (roundStarted && currentPickerIdx < llGetListLength(pickQueue) && llGetListLength(pickQueue) > 0 && diceType > 0) {
                // Check if current picker already has picks to avoid duplicate dialogs
                string currentPlayerName = llList2String(pickQueue, currentPickerIdx);
                
                integer alreadyHasPicks = FALSE;
                integer i;
                for (i = 0; i < llGetListLength(picksData); i++) {
                    if (llSubStringIndex(llList2String(picksData, i), currentPlayerName + "|") == 0) {
                        string picks = llGetSubString(llList2String(picksData, i), llStringLength(currentPlayerName) + 1, -1);
                        if (picks != "") {
                            alreadyHasPicks = TRUE;
                        }
                    }
                }
                
                if (!alreadyHasPicks) {
                    dbg("🎯 Starting picks for " + currentPlayerName);
                    llSleep(DELAY_ANTI_SPAM);
                    showNextPickerDialog();
                }
            }
            return;
        }
        
        // Legacy 997 message handler removed - now using direct MSG_CONTINUE_ROUND (998) communication
        
        // Handle human picks
        if (num == MSG_HUMAN_PICKED && llSubStringIndex(str, "HUMAN_PICKED:") == 0) {
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                dbg("👤 HUMAN: " + playerName + " picking " + picksStr + " (global has: " + llList2CSV(globalPickedNumbers) + ")");
                
                // Check if this player already has picks to prevent duplicate processing
                integer alreadyHasPicks = FALSE;
                integer existingPicksIdx = -1;
                integer m;
                for (m = 0; m < llGetListLength(picksData) && !alreadyHasPicks; m++) {
                    if (llSubStringIndex(llList2String(picksData, m), playerName + "|") == 0) {
                        string existingPicks = llGetSubString(llList2String(picksData, m), llStringLength(playerName) + 1, -1);
                        if (existingPicks != "") {
                            dbg("⚠️ [Game Manager] " + playerName + " already has picks: " + existingPicks + ", ignoring duplicate HUMAN_PICKED");
                            alreadyHasPicks = TRUE;
                        }
                    }
                }
                
                if (alreadyHasPicks) {
                    return; // Ignore duplicate human picks
                }
                
                // Validate picks against complete avoidance list (all current picks from all players)
                list completeAvoidList = buildCompleteAvoidanceList();
                list newPicks = llParseString2List(picksStr, [","], []);
                list validPicks = [];
                list duplicatePicks = [];
                integer i;
                
                dbg("🔍 [Game Manager] Validating " + playerName + "'s picks against complete avoid list (" + (string)llGetListLength(completeAvoidList) + " numbers): " + llList2CSV(completeAvoidList));
                
                for (i = 0; i < llGetListLength(newPicks); i++) {
                    string pick = llStringTrim(llList2String(newPicks, i), STRING_TRIM);
                    if (pick != "") {
                        if (llListFindList(completeAvoidList, [pick]) == -1) {
                            validPicks += [pick];
                            globalPickedNumbers += [pick];
                        } else {
                            duplicatePicks += [pick];
                        }
                    }
                }
                
                if (llGetListLength(duplicatePicks) > 0) {
                    dbg("❌ DUPLICATE PICKS REJECTED: " + playerName + " tried to pick: " + llList2CSV(duplicatePicks));
                    integer idx = llListFindList(names, [playerName]);
                    if (idx != -1) {
                        llRegionSayTo(llList2Key(players, idx), 0, "❌ Some picks were already taken. Please pick again.");
                        
                        // Remove valid picks we added
                        integer j;
                        for (j = 0; j < llGetListLength(validPicks); j++) {
                            string validPick = llList2String(validPicks, j);
                            integer globalIdx = llListFindList(globalPickedNumbers, [validPick]);
                            if (globalIdx != -1) {
                                globalPickedNumbers = llDeleteSubList(globalPickedNumbers, globalIdx, globalIdx);
                            }
                        }
                        // Re-show the dialog with updated globally picked numbers
                        dbg("⚠️ [Game Manager] Re-showing pick dialog for " + playerName + " with updated picks");
                        
                        // Calculate picks needed based on peril player's lives
                        integer perilIdx = llListFindList(names, [perilPlayer]);
                        integer perilLives = 3;
                        if (perilIdx != -1) {
                            perilLives = llList2Integer(lives, perilIdx);
                        }
                        integer picksNeeded = 4 - perilLives;
                        
                        // Use complete avoid list for re-shown dialog too
                        list updatedCompleteAvoidList = buildCompleteAvoidanceList();
                        string dialogPayload = playerName + "|" + (string)diceType + "|" + (string)picksNeeded + "|" + llList2CSV(updatedCompleteAvoidList);
                        string dialogRequest = "SHOW_DIALOG~" + playerName + "~" + dialogPayload;
                        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, dialogRequest, NULL_KEY);
                    }
                    return;
                }
                
                // Update picks data
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    integer picksIdx = -1;
                    integer k;
                    for (k = 0; k < llGetListLength(picksData); k++) {
                        if (llSubStringIndex(llList2String(picksData, k), playerName + "|") == 0) {
                            picksIdx = k;
                        }
                    }
                    string newEntry = playerName + "|" + picksStr;
                    if (picksIdx == -1) {
                        picksData += [newEntry];
                    } else {
                        picksData = llListReplaceList(picksData, [newEntry], picksIdx, picksIdx);
                    }
                    dbg("🟢 " + playerName + " picks saved: " + picksStr);
                    
                    llSay(0, "🎯 " + playerName + " stakes their life on numbers: " + picksStr + " 🎲");
                    
                    // IMMEDIATE FLOATER UPDATE: Update this player's floater right after their pick is saved
                    // First sync the picks data so Floater Manager has the latest picks, then update the floater
                    // Send just the updated picks data to Floater Manager (lightweight sync)
                    // MEMORY OPTIMIZED: Direct sync message construction
                    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, 
                        llList2CSV(lives) + "~" + 
                        llDumpList2String(picksData, "^") + "~" + 
                        perilPlayer + "~" + 
                        llList2CSV(names), NULL_KEY);
                    
                    // Brief delay to ensure sync reaches Floater Manager before update request
                    llSleep(DELAY_SHORT_SYNC);
                    
                    // Now update the floater
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, playerName, llList2Key(players, idx));
                    
                    llSleep(HUMAN_PICK_DELAY);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        dbg("🔍 [Game Manager] More players in queue, showing next dialog");
                        showNextPickerDialog();
                    } else {
                        // All picked, show roll dialog
                        dbg("🎯 [Game Manager] All players have picked! Showing roll dialog to " + perilPlayer);
                        
                        // CRITICAL: Sync the updated picks data to all modules before roll phase
                        dbg("🔄 [Game Manager] Syncing final picks data before roll phase...");
                        syncStateToMain();
                        llSleep(DELAY_MEDIUM_SYNC); // Longer delay to ensure sync propagates to all modules
                        
                        // Send roll dialog through Player_RegistrationManager
                        dbg("🎯 [Game Manager] Sending roll dialog request for: " + perilPlayer);
                        string rollRequest = "SHOW_ROLL_DIALOG~" + perilPlayer + "~" + perilPlayer;
                        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, rollRequest, NULL_KEY);
                    }
                }
            }
            return;
        }
        
// Handle bot picks
        if (num == MSG_BOT_PICKED && llSubStringIndex(str, "BOT_PICKED:") == 0) {
            dbg("🔍 [Game Manager] BOT_PICKED message received: " + str);
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                dbg("🤖 BOT: " + playerName + " picking " + picksStr + " (global had: " + llList2CSV(globalPickedNumbers) + ")");
                
                // Check if this bot has already made picks this round to prevent duplicates
                integer existingPicksIdx = -1;
                integer m;
                for (m = 0; m < llGetListLength(picksData); m++) {
                    if (llSubStringIndex(llList2String(picksData, m), playerName + "|") == 0) {
                        string existingPicks = llGetSubString(llList2String(picksData, m), llStringLength(playerName) + 1, -1);
                        if (existingPicks != "") {
                            dbg("⚠️ [Game Manager] Ignoring duplicate BOT_PICKED for " + playerName + " (already has picks: " + existingPicks + ")");
                            
                            // IMPORTANT: Even though this is a duplicate, check if all players have now picked
                            // Count how many players have picks
                            integer playersWithPicks = 0;
                            integer p;
                            for (p = 0; p < llGetListLength(names); p++) {
                                string checkPlayerName = llList2String(names, p);
                                integer q;
                                for (q = 0; q < llGetListLength(picksData); q++) {
                                    if (llSubStringIndex(llList2String(picksData, q), checkPlayerName + "|") == 0) {
                                        string checkPicks = llGetSubString(llList2String(picksData, q), llStringLength(checkPlayerName) + 1, -1);
                                        if (checkPicks != "") {
                                            playersWithPicks++;
                                            // Don't break - continue to avoid double counting
                                        }
                                    }
                                }
                            }
                            
                    // If all players have picks, advance to roll phase
                    if (playersWithPicks >= llGetListLength(names)) {
                        dbg("🎯 [Game Manager] All players have picks! Moving to roll phase...");
                        
                        // CRITICAL: Sync the updated picks data to all modules before roll phase
                        dbg("🔄 [Game Manager] Syncing final picks data before roll phase...");
                        syncStateToMain();
                        llSleep(DELAY_MEDIUM_SYNC); // Longer delay to ensure sync propagates to all modules
                        
                        // Force close any active number picker dialogs
                        dbg("🚫 [Game Manager] Sending CLOSE_ALL_DIALOGS command");
                        llMessageLinked(LINK_SET, MSG_BOT_COMMAND, "CLOSE_ALL_DIALOGS", NULL_KEY);
                        
                        // Send roll dialog through Player_RegistrationManager
                        string rollRequest = "SHOW_ROLL_DIALOG~" + perilPlayer + "~" + perilPlayer;
                        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, rollRequest, NULL_KEY);
                    }
                            return; // Ignore duplicate - bot already has real picks
                        }
                        existingPicksIdx = m;
                        // Don't break - continue to make sure there are no other entries with picks
                    }
                }
                
                // VALIDATE: Check for duplicate picks before saving
                if (picksStr != "" && llListFindList(globalPickedNumbers, [picksStr]) != -1) {
                    dbg("❌ [Game Manager] Bot " + playerName + " tried to pick duplicate number: " + picksStr + " - REJECTING");
                    dbg("🙄 [Game Manager] Sending new pick command to Bot Manager for " + playerName);
                    
                    // Calculate picks needed for bot retry
                    integer perilIdx = llListFindList(names, [perilPlayer]);
                    integer perilLives = 3;
                    if (perilIdx != -1) {
                        perilLives = llList2Integer(lives, perilIdx);
                    }
                    integer picksNeeded = 4 - perilLives;
                    
                    // Send new bot command with complete updated avoid list
                    list completeAvoidList = buildCompleteAvoidanceList();
                    string avoidListStr = llList2CSV(completeAvoidList);
                    string botCommand = "BOT_PICK:" + playerName + ":" + (string)picksNeeded + ":" + (string)diceType + ":" + avoidListStr;
                    dbg("🎯 [Game Manager] Sending retry bot command with complete avoid list (" + (string)llGetListLength(completeAvoidList) + " numbers): " + avoidListStr);
                    llMessageLinked(LINK_SET, MSG_BOT_COMMAND, botCommand, NULL_KEY);
                    return; // Don't save this pick
                }
                
                // Update picks data
                integer idx = llListFindList(names, [playerName]);
                dbg("🔧 [Game Manager] Looking for bot " + playerName + " in names list: " + llList2CSV(names) + " (idx: " + (string)idx + ")");
                if (idx != -1) {
                    integer picksIdx = -1;
                    integer k;
                    for (k = 0; k < llGetListLength(picksData); k++) {
                        if (llSubStringIndex(llList2String(picksData, k), playerName + "|") == 0) {
                            picksIdx = k;
                        }
                    }
                    string newEntry = playerName + "|" + picksStr;
                    if (picksIdx == -1) {
                        picksData += [newEntry];
                    } else {
                        picksData = llListReplaceList(picksData, [newEntry], picksIdx, picksIdx);
                    }
                    
                    // Update global picked numbers - bot picks are single numbers (already validated above)
                    globalPickedNumbers += [picksStr];
                    
                    llSay(0, "🎯 " + playerName + " (bot) stakes their digital life on numbers: " + picksStr + " 🎲");
                    
                    // IMMEDIATE FLOATER UPDATE: Update this bot's floater right after their pick is saved
                    // First sync the picks data so Floater Manager has the latest picks, then update the floater
                    // Send just the updated picks data to Floater Manager (lightweight sync)
                    // MEMORY OPTIMIZED: Direct sync message construction
                    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, 
                        llList2CSV(lives) + "~" + 
                        llDumpList2String(picksData, "^") + "~" + 
                        perilPlayer + "~" + 
                        llList2CSV(names), NULL_KEY);
                    
                    // Brief delay to ensure sync reaches Floater Manager before update request
                    llSleep(DELAY_SHORT_SYNC);
                    
                    // Now update the floater
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, playerName, NULL_KEY);
                    
                    // Don't do full sync to Main here - it creates loops, but targeted floater update is safe
                    llSleep(BOT_PICK_DELAY);
                    
                    // Check if all players now have picks (more reliable than picker index)
                    integer playersWithPicks = 0;
                    integer p;
                    for (p = 0; p < llGetListLength(names); p++) {
                        string checkPlayerName = llList2String(names, p);
                        integer playerHasPicks = FALSE;
                        integer q;
                        for (q = 0; q < llGetListLength(picksData) && !playerHasPicks; q++) {
                            if (llSubStringIndex(llList2String(picksData, q), checkPlayerName + "|") == 0) {
                                string checkPicks = llGetSubString(llList2String(picksData, q), llStringLength(checkPlayerName) + 1, -1);
                                if (checkPicks != "") {
                                    playerHasPicks = TRUE;
                                }
                            }
                        }
                        if (playerHasPicks) {
                            playersWithPicks++;
                        }
                    }
                    
                    dbg("🔍 [Game Manager] Bot pick complete - players with picks: " + (string)playersWithPicks + "/" + (string)llGetListLength(names));
                    
                    // If all players have picks, advance to roll phase
                    if (playersWithPicks >= llGetListLength(names)) {
                        dbg("🎯 [Game Manager] All players have picks! Moving to roll phase...");
                        
                        // CRITICAL: Sync the updated picks data to all modules before roll phase
                        dbg("🔄 [Game Manager] Syncing final picks data before roll phase...");
                        syncStateToMain();
                        llSleep(DELAY_DIALOG_REFRESH); // Brief delay to ensure sync propagates
                        
                        // Force close any active number picker dialogs
                        dbg("🚫 [Game Manager] Sending CLOSE_ALL_DIALOGS command");
                        llMessageLinked(LINK_SET, MSG_BOT_COMMAND, "CLOSE_ALL_DIALOGS", NULL_KEY);
                        
                        // Send roll dialog through Player_RegistrationManager
                        string rollRequest = "SHOW_ROLL_DIALOG~" + perilPlayer + "~" + perilPlayer;
                        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, rollRequest, NULL_KEY);
                    } else {
                        // Move to next picker
                        currentPickerIdx++;
                        if (currentPickerIdx < llGetListLength(pickQueue)) {
                            showNextPickerDialog();
                        }
                    }
                }
            }
            return;
        }
        
        // Handle continue round requests from Main Controller
        if (num == MSG_CONTINUE_ROUND) {
            dbg("🎯 [Game Manager] Received continue round request with peril player: '" + str + "'");
            
            // Update peril player from the continue message if provided
            if (str != "" && str != "NONE") {
                perilPlayer = str;
                dbg("🎯 [Game Manager] Updated peril player to: " + perilPlayer);
                
                // Reset round state and continue with existing peril player
                roundStarted = FALSE;
                currentPickerIdx = 0;
                diceTypeProcessed = FALSE;
                roundContinueInProgress = FALSE;
                
                // Continue current round with assigned peril player
                continueCurrentRound();
            } else {
                // Empty peril player means this is initial game start - use startNextRound()
                dbg("🎯 [Game Manager] Empty peril player - starting initial game round");
                
                // Reset round state
                roundStarted = FALSE;
                currentPickerIdx = 0;
                diceTypeProcessed = FALSE;
                roundContinueInProgress = FALSE;
                
                // Start initial round (will select random peril player)
                startNextRound();
            }
            return;
        }
        
        
        // Handle reset
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            players = names = lives = picksData = globalPickedNumbers = pickQueue = [];
            perilPlayer = "";
            currentPickerIdx = 0;
            diceType = 6;
            currentPicker = NULL_KEY;
            roundStarted = FALSE;
            diceTypeProcessed = FALSE;  // Reset for new game
            lastPlayerCount = 0;        // Reset dice memory for new game
            roundContinueInProgress = FALSE;  // Reset protection flag
            lastSyncProcessTime = 0;  // Reset sync timing
            dbg("🎯 Game Manager reset - ready for new game!");
            return;
        }
        
        // Handle emergency state reset (for when game gets stuck)
        if (num == MSG_EMERGENCY_RESET && str == "EMERGENCY_RESET") {
            dbg("🚨 [Game Manager] Emergency reset triggered!");
            roundStarted = FALSE;
            perilPlayer = "";
            currentPickerIdx = 0;
            pickQueue = [];
            diceTypeProcessed = FALSE;
            roundContinueInProgress = FALSE;
            lastSyncProcessTime = 0;  // Reset sync timing
            dbg("🔒 [Game Manager] Emergency state reset complete");
            return;
        }
    }
}
