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

// Game timing settings
float BOT_PICK_DELAY = 2.0;
float HUMAN_PICK_DELAY = 1.0;
float DIALOG_DELAY = 1.5;
float STATUS_DISPLAY_TIME = 8.0;

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
        string pick = llList2String(globalPickedNumbers, i);
        if (pick != "" && llListFindList(allPicks, [pick]) == -1) {
            allPicks += [pick];
        }
    }
    
    return allPicks;
}

// Memory reporting function
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    llOwnerSay("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

// Verbose logging control - toggled by owner
integer VERBOSE_LOGGING = FALSE;

// Message constants
integer MSG_SHOW_DIALOG = 101;
integer MSG_SHOW_ROLL_DIALOG = 301;
integer MSG_GET_DICE_TYPE = 1001;
integer MSG_DICE_TYPE_RESULT = 1005;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SYNC_PICKQUEUE = 2001;
integer MSG_PLAYER_WON = 551;
integer MSG_UPDATE_FLOAT = 2010;
integer MSG_DIALOG_FORWARD_REQUEST = 9060; // Request dialog forwarding from Player_RegistrationManager
integer MSG_CONTINUE_ROUND = 998; // Continue round after roll processing

continueCurrentRound() {
    // MEMORY OPTIMIZED: Skip complex validation - trust game state
    // Main Controller handles all game ending validation
    
    // Check for eliminated players (0 lives) - don't continue if any exist
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        integer playerIdx = llListFindList(names, [playerName]);
        if (playerIdx != -1 && playerIdx < llGetListLength(lives)) {
            integer playerLives = llList2Integer(lives, playerIdx);
            if (playerLives <= 0) {
                llOwnerSay("🛑 [Game Manager] continueCurrentRound: Found eliminated player " + playerName + " with " + (string)playerLives + " lives - aborting round start");
                return;
            }
        }
    }
    
    if (perilPlayer == "" || perilPlayer == "NONE") {
        llOwnerSay("🛑 [Game Manager] continueCurrentRound: Invalid peril player (" + perilPlayer + ") - aborting round start");
        return;
    }
    
    // Verify peril player exists and has lives
    integer perilIdx = llListFindList(names, [perilPlayer]);
    if (perilIdx == -1) {
        llOwnerSay("🛑 [Game Manager] continueCurrentRound: Peril player " + perilPlayer + " not found in names list - aborting round start");
        return;
    }
    if (perilIdx >= llGetListLength(lives)) {
        llOwnerSay("🛑 [Game Manager] continueCurrentRound: Peril player " + perilPlayer + " index out of bounds - aborting round start");
        return;
    }
    integer perilLives = llList2Integer(lives, perilIdx);
    if (perilLives <= 0) {
        llOwnerSay("🛑 [Game Manager] continueCurrentRound: Peril player " + perilPlayer + " has " + (string)perilLives + " lives - aborting round start");
        return;
    }
    
    // Start fresh for a new round - clear picks data
    // globalPickedNumbers will be cleared when first player picks
    picksData = [];
    
    llOwnerSay("🔄 [Game Manager] continueCurrentRound: All validation passed, starting fresh round with " + (string)llGetListLength(names) + " players");
    
    // Set round as started for the new round
    roundStarted = TRUE;
    diceTypeProcessed = FALSE; // Reset dice type processing for new round
    
    // Create new pick queue with peril player first
    pickQueue = [perilPlayer];
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        if (playerName != perilPlayer) {
            pickQueue += [playerName];
        }
    }
    currentPickerIdx = 0;
    
    llOwnerSay("🎯 [Game Manager] Pick queue created: " + llList2CSV(pickQueue) + ", requesting dice type");
    
    // Request dice type directly from Calculator for the new round
    llMessageLinked(LINK_SET, MSG_GET_DICE_TYPE, (string)llGetListLength(names), NULL_KEY);
    
    // Note: showNextPickerDialog() will be called when dice type result is received
}

startNextRound() {
    // Prevent multiple calls to start round
    if (roundStarted) {
        llOwnerSay("⚠️ Round already started, ignoring duplicate start request");
        return;
    }
    
    if (llGetListLength(names) < 2) {
        llOwnerSay("⚠️ Need at least 2 players to start the game.");
        return;
    }
    
    if (llGetListLength(names) == 1) {
        string winner = llList2String(names, 0);
        llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
        
        // Send winner glow update to scoreboard
        llMessageLinked(12, 3006, winner, NULL_KEY);  // MSG_UPDATE_WINNER
        
        llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
        llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
                // Don't use hardcoded channel here - let Main Controller handle scoreboard updates
                // Main Controller will send the proper GAME_WON message to scoreboard
        // Let main controller handle reset
        return;
    }
    
    llOwnerSay("🎯 Game Manager starting new round...");
    
    // Set roundStarted immediately to prevent duplicate calls
    roundStarted = TRUE;
    diceTypeProcessed = FALSE;  // Reset for new round
    
    // Select random peril player if none is set
    if (perilPlayer == "" || perilPlayer == "NONE") {
        integer randomIdx = (integer)llFrand(llGetListLength(names));
        perilPlayer = llList2String(names, randomIdx);
        llSay(0, "🎯 " + perilPlayer + " has been randomly selected and is now in peril!");
        
        // Send peril player update to scoreboard for glow effect
        llMessageLinked(12, 3005, perilPlayer, NULL_KEY);  // MSG_UPDATE_PERIL_PLAYER
        
        // Sync state to floater manager first, then update floaters to show new peril player immediately
        llOwnerSay("🔄 [Game Manager] Syncing state and updating floaters for new peril player: " + perilPlayer);
        syncStateToMain(); // Sync the peril player to all modules first
        llSleep(0.1); // Brief delay to ensure sync propagates
        integer j;
        for (j = 0; j < llGetListLength(names); j++) {
            string playerName = llList2String(names, j);
            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, playerName, NULL_KEY);
        }
    }
    
    picksData = [];
    // globalPickedNumbers will be cleared when first player picks
    
    // Create pick queue with peril player first
    llOwnerSay("🎯 Debug - Creating pickQueue. names: " + llList2CSV(names) + ", perilPlayer: " + perilPlayer);
    pickQueue = [perilPlayer];
    integer k;
    for (k = 0; k < llGetListLength(names); k++) {
        string playerName = llList2String(names, k);
        if (playerName != perilPlayer) {
            pickQueue += [playerName];
        }
    }
    currentPickerIdx = 0;
    llOwnerSay("🎯 Debug - Created pickQueue: " + llList2CSV(pickQueue) + ", currentPickerIdx: " + (string)currentPickerIdx);
    
    // Request dice type for this round
    llMessageLinked(LINK_SET, MSG_GET_DICE_TYPE, (string)llGetListLength(names), NULL_KEY);
    llOwnerSay("🎯 Game Manager round setup complete, requesting dice type...");
}

showNextPickerDialog() {
    // MEMORY OPTIMIZED: Skip complex validation - trust that game is active
    // Main Controller handles all game ending logic
    
    // Clear globalPickedNumbers if this is the first picker of a new round
    if (currentPickerIdx == 0 && llGetListLength(picksData) == 0) {
        globalPickedNumbers = [];
        llOwnerSay("🔄 [Game Manager] Cleared globalPickedNumbers at start of new round");
    }
    
    if (diceType <= 0) {
        llOwnerSay("❌ Cannot show picker dialog: diceType not set (" + (string)diceType + ")");
        return;
    }
    
    if (currentPickerIdx >= llGetListLength(pickQueue)) {
        llOwnerSay("❌ Cannot show picker dialog: currentPickerIdx (" + (string)currentPickerIdx + ") >= pickQueue length (" + (string)llGetListLength(pickQueue) + ")");
        return;
    }
    
    string firstName = llList2String(pickQueue, currentPickerIdx);
    if (firstName == "") {
        llOwnerSay("❌ Cannot show picker dialog: empty player name at index " + (string)currentPickerIdx);
        return;
    }
    
    // CRITICAL: Verify this player is still alive and in the game
    integer playerIdx = llListFindList(names, [firstName]);
    if (playerIdx == -1) {
        llOwnerSay("❌ Cannot show picker dialog: player " + firstName + " not found in current game");
        return;
    }
    
    if (playerIdx >= llGetListLength(lives)) {
        llOwnerSay("❌ Cannot show picker dialog: player " + firstName + " index out of bounds for lives list");
        return;
    }
    
    integer playerLives = llList2Integer(lives, playerIdx);
    if (playerLives <= 0) {
        llOwnerSay("❌ Cannot show picker dialog: player " + firstName + " has been eliminated (" + (string)playerLives + " lives)");
        return;
    }
    
    // CHECK: Don't show dialog if this player already has picks to prevent loops
    integer alreadyHasPicks = FALSE;
    integer i;
    for (i = 0; i < llGetListLength(picksData) && !alreadyHasPicks; i++) {
        if (llSubStringIndex(llList2String(picksData, i), firstName + "|") == 0) {
            string existingPicks = llGetSubString(llList2String(picksData, i), llStringLength(firstName) + 1, -1);
            if (existingPicks != "") {
                alreadyHasPicks = TRUE;
                llOwnerSay("🎯 Game Manager: " + firstName + " already has picks (" + existingPicks + "), advancing to next player");
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
            string rollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
            llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, rollRequest, NULL_KEY);
        }
        return;
    }
    
    integer nameIdx = llListFindList(names, [firstName]);
    if (nameIdx == -1) {
        llOwnerSay("❌ Cannot show picker dialog: player " + firstName + " not found in names list");
        return;
    }
    
        // SIMPLE FIX: Send dialog request to Main Controller with player name
        // Main Controller has the player keys and can forward to NumberPicker with correct key
        
        llSleep(DIALOG_DELAY);
        
        if (llSubStringIndex(firstName, "Bot") == 0) {
        // Bot picking - but first double-check this bot doesn't already have picks
        integer botAlreadyHasPicks = FALSE;
        integer j;
        for (j = 0; j < llGetListLength(picksData) && !botAlreadyHasPicks; j++) {
            if (llSubStringIndex(llList2String(picksData, j), firstName + "|") == 0) {
                string existingBotPicks = llGetSubString(llList2String(picksData, j), llStringLength(firstName) + 1, -1);
                if (existingBotPicks != "") {
                    botAlreadyHasPicks = TRUE;
                    llOwnerSay("⚠️ [Game Manager] Bot " + firstName + " already has picks, skipping bot command: " + existingBotPicks);
                }
            }
        }
        
        if (!botAlreadyHasPicks) {
            integer perilIdx = llListFindList(names, [perilPlayer]);
            integer perilLives = 3;
            if (perilIdx != -1) {
                perilLives = llList2Integer(lives, perilIdx);
            }
            integer picksNeeded = 4 - perilLives;
            
            // Send proper avoid list to bots so they don't pick human numbers
            list completeAvoidList = buildCompleteAvoidanceList();
            string avoidListStr = llList2CSV(completeAvoidList);
            string botCommand = "BOT_PICK:" + firstName + ":" + (string)picksNeeded + ":" + (string)diceType + ":" + avoidListStr;
            llOwnerSay("🎯 [Game Manager] Sending bot command with complete avoid list (" + (string)llGetListLength(completeAvoidList) + " numbers): " + avoidListStr);
            llMessageLinked(LINK_SET, -9999, botCommand, NULL_KEY);
            llOwnerSay("🤖 " + firstName + " is automatically picking " + (string)picksNeeded + " numbers...");
        } else {
            // Bot already has picks, advance to next player immediately
            currentPickerIdx++;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                showNextPickerDialog();
            } else {
                // All picked, show roll dialog through Player_RegistrationManager
                string rollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
                llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, rollRequest, NULL_KEY);
            }
        }
    } else {
        // Human picking
        integer perilIdx = llListFindList(names, [perilPlayer]);
        integer perilLives = 3;
        if (perilIdx != -1) {
            perilLives = llList2Integer(lives, perilIdx);
        }
        integer picksNeeded = 4 - perilLives;
        
        // Send dialog payload with complete avoid list for humans too
        list completeAvoidList = buildCompleteAvoidanceList();
        string avoidListStr = llList2CSV(completeAvoidList);
        string dialogPayload = firstName + "|" + (string)diceType + "|" + (string)picksNeeded + "|" + avoidListStr;
        
        llOwnerSay("🎯 Showing pick dialog for " + firstName);
        llSleep(0.5);  // Brief delay to prevent spam
        
        // Send dialog request through Player_RegistrationManager (it has the correct player keys)
        string dialogRequest = "SHOW_DIALOG|" + firstName + "|" + dialogPayload;
        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, dialogRequest, NULL_KEY);
    }
}

// requestDiceType() removed - Game Manager no longer requests dice type directly
// This prevents loops. Main Controller handles all dice type requests.

syncStateToMain() {
    // MEMORY OPTIMIZED: Skip ALL sync operations to prevent corrupting Main Controller's data
    // Main Controller is the master - Game Manager should not send sync messages
    return;
}

default {
    state_entry() {
        reportMemoryUsage("Game Manager");
        llOwnerSay("🎯 Game Manager initializing...");
        
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
        
        llOwnerSay("🎯 Game Manager ready!");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("Game Manager");
        llOwnerSay("🔄 Game Manager rezzed - reinitializing...");
        
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
        
        llOwnerSay("✅ Game Manager reset complete after rez!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        
        // Handle incoming sync updates from Roll Confetti Module and other sources
        if (num == MSG_SYNC_GAME_STATE) {
            // Only skip sync messages if we're explicitly ignoring them
            // Allow player registration syncs even when game is not active
            
            list parts = llParseString2List(str, ["~"], []);
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
                    if (encodedPicksDataStr != "") {
                        list encodedEntries = llParseString2List(encodedPicksDataStr, ["^"], []);
                        integer i;
                        for (i = 0; i < llGetListLength(encodedEntries); i++) {
                            string entry = llList2String(encodedEntries, i);
                            list entryParts = llParseString2List(entry, ["|"], []);
                            if (llGetListLength(entryParts) >= 2) {
                                string playerName = llList2String(entryParts, 0);
                                string picks = llList2String(entryParts, 1);
                                picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                                newPicksData += [playerName + "|" + picks];
                            } else {
                                newPicksData += [entry];
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
                    if (perilChanged && perilPlayer != "" && perilPlayer != "NONE") {
                        string lightUpdate = "PERIL_UPDATE|" + perilPlayer + "|" + (string)llGetListLength(names);
                        llMessageLinked(LINK_SET, 9070, lightUpdate, NULL_KEY);
                    }
                    
                    integer allPicksEmpty = TRUE;
                    integer i;
                    for (i = 0; i < llGetListLength(newPicksData) && allPicksEmpty; i++) {
                        string entry = llList2String(newPicksData, i);
                        list parts = llParseString2List(entry, ["|"], []);
                        if (llGetListLength(parts) >= 2 && llList2String(parts, 1) != "") {
                            allPicksEmpty = FALSE;
                        }
                    }
                    
                    if (livesChanged && newPerilPlayer != "" && newPerilPlayer != "NONE" && roundStarted && allPicksEmpty) {
                        llOwnerSay("🎯 Post-roll state update detected - continuing round");
                        continueCurrentRound();
                    }
                }
            }
            return;
        }
        
        // Receive legacy game state updates from main controller (simplified version)
        if (num == 9071) {
            llOwnerSay("🔧 [Game Manager] Received sync: " + str);
            list parts = llParseString2List(str, ["~"], []);
            llOwnerSay("🔧 [Game Manager] Parsed into " + (string)llGetListLength(parts) + " parts");
            
            // MEMORY OPTIMIZED: Skip heavy validation that causes sync rejections
            // Trust that Main Controller sends valid data
            
            // Handle special RESET sync message
            if (llGetListLength(parts) >= 5 && llList2String(parts, 0) == "RESET") {
                llOwnerSay("🔄 [Game Manager] Received reset sync - ignoring during reset");
                return;
            }
            
            if (llGetListLength(parts) < 4) {
                llOwnerSay("⚠️ [Game Manager] Incomplete sync message received, parts: " + (string)llGetListLength(parts) + " - IGNORING");
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
                        string livesStr = llList2String(parts, 0);
                        if (llSubStringIndex(livesStr, ",") != -1) {
                            lives = llCSV2List(livesStr);
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
                    
                    llOwnerSay("🎯 [Game Manager] Updated: " + (string)llGetListLength(names) + " players (minimal parsing)");
                }
                
                // Update peril player
                string receivedPerilPlayer = llList2String(parts, 2);
                if (receivedPerilPlayer != "NONE" && receivedPerilPlayer != "") {
                    perilPlayer = receivedPerilPlayer;
                    llOwnerSay("🎯 [Game Manager] Peril player updated to: " + perilPlayer);
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
            llOwnerSay("🔍 [Game Manager] Received pickQueue sync from sender " + senderStr + ": '" + str + "' (" + queueLenStr + " items)");
            
            // STRONGEST PROTECTION: Never accept empty pickQueues during any active round
            if (roundStarted && llGetListLength(pickQueue) > 0 && (str == "" || llGetListLength(newPickQueue) == 0)) {
                llOwnerSay("🔍 [Game Manager] REJECTING empty/invalid pickQueue sync during active round - keeping: " + llList2CSV(pickQueue));
                return;
            }
            
            // Additional protection: Don't accept pickQueue syncs if we just created a valid one
            if (llGetListLength(pickQueue) > 0 && (str == "" || llGetListLength(newPickQueue) == 0)) {
                llOwnerSay("🔍 [Game Manager] REJECTING empty pickQueue sync - keeping valid queue: " + llList2CSV(pickQueue));
                return;
            }
            
            // Only accept valid non-empty pickQueues
            if (llGetListLength(newPickQueue) > 0) {
                pickQueue = newPickQueue;
                llOwnerSay("🔍 [Game Manager] pickQueue updated to: " + llList2CSV(pickQueue));
            } else {
                llOwnerSay("🔍 [Game Manager] Ignoring invalid pickQueue sync - keeping current: " + llList2CSV(pickQueue));
            }
            return;
        }
        
        // Handle dice type result from Calculator
        if (num == MSG_DICE_TYPE_RESULT) {
            // Prevent duplicate processing of dice type results
            if (diceTypeProcessed) {
                llOwnerSay("🎲 Ignoring duplicate dice type result: " + str);
                return;
            }
            
            diceType = (integer)str;
            diceTypeProcessed = TRUE;
            llOwnerSay("🎲 Game Manager received dice type: d" + str + " from Calculator");
            llSleep(0.3);  // Brief delay
            
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
                    llOwnerSay("🎯 Starting picks for " + currentPlayerName);
                    llSleep(0.5);
                    showNextPickerDialog();
                }
            }
            return;
        }
        
        // Legacy 997 message handler removed - now using direct MSG_CONTINUE_ROUND (998) communication
        
        // Handle human picks
        if (num == -9998 && llSubStringIndex(str, "HUMAN_PICKED:") == 0) {
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                llOwnerSay("👤 HUMAN: " + playerName + " picking " + picksStr + " (global has: " + llList2CSV(globalPickedNumbers) + ")");
                
                // Check if this player already has picks to prevent duplicate processing
                integer alreadyHasPicks = FALSE;
                integer existingPicksIdx = -1;
                integer m;
                for (m = 0; m < llGetListLength(picksData) && !alreadyHasPicks; m++) {
                    if (llSubStringIndex(llList2String(picksData, m), playerName + "|") == 0) {
                        string existingPicks = llGetSubString(llList2String(picksData, m), llStringLength(playerName) + 1, -1);
                        if (existingPicks != "") {
                            llOwnerSay("⚠️ [Game Manager] " + playerName + " already has picks: " + existingPicks + ", ignoring duplicate HUMAN_PICKED");
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
                
                llOwnerSay("🔍 [Game Manager] Validating " + playerName + "'s picks against complete avoid list (" + (string)llGetListLength(completeAvoidList) + " numbers): " + llList2CSV(completeAvoidList));
                
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
                    llOwnerSay("❌ DUPLICATE PICKS REJECTED: " + playerName + " tried to pick: " + llList2CSV(duplicatePicks));
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
                        llOwnerSay("⚠️ [Game Manager] Re-showing pick dialog for " + playerName + " with updated picks");
                        
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
                        string dialogRequest = "SHOW_DIALOG|" + playerName + "|" + dialogPayload;
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
                    llOwnerSay("🟢 " + playerName + " picks saved: " + picksStr);
                    
                    llSay(0, "🎯 " + playerName + " stakes their life on numbers: " + picksStr + " 🎲");
                    
                    // IMMEDIATE FLOATER UPDATE: Update this player's floater right after their pick is saved
                    // First sync the picks data so Floater Manager has the latest picks, then update the floater
                    llOwnerSay("🔄 [Game Manager] Syncing picks and updating floater immediately for " + playerName + " with new picks");
                    
                    // Send just the updated picks data to Floater Manager (lightweight sync)
                    string picksDataStr = llDumpList2String(picksData, "^");
                    string lightSync = llList2CSV(lives) + "~" + picksDataStr + "~" + perilPlayer + "~" + llList2CSV(names);
                    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, lightSync, NULL_KEY);
                    
                    // Brief delay to ensure sync reaches Floater Manager before update request
                    llSleep(0.1);
                    
                    // Now update the floater
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, playerName, llList2Key(players, idx));
                    
                    // Don't do full sync to Main here - it creates loops, but targeted floater update is safe
                    llSleep(HUMAN_PICK_DELAY);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        llOwnerSay("🔍 [Game Manager] More players in queue, showing next dialog");
                        showNextPickerDialog();
                    } else {
                        // All picked, show roll dialog
                        llOwnerSay("🎯 [Game Manager] All players have picked! Showing roll dialog to " + perilPlayer);
                        
                        // CRITICAL: Sync the updated picks data to all modules before roll phase
                        llOwnerSay("🔄 [Game Manager] Syncing final picks data before roll phase...");
                        syncStateToMain();
                        llSleep(1.0); // Longer delay to ensure sync propagates to all modules
                        
                        // Send roll dialog through Player_RegistrationManager
                        llOwnerSay("🎯 [Game Manager] Sending roll dialog request for: " + perilPlayer);
                        string rollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
                        llMessageLinked(LINK_SET, MSG_DIALOG_FORWARD_REQUEST, rollRequest, NULL_KEY);
                    }
                }
            }
            return;
        }
        
// Handle bot picks
        if (num == -9997 && llSubStringIndex(str, "BOT_PICKED:") == 0) {
            llOwnerSay("🔍 [Game Manager] BOT_PICKED message received: " + str);
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                llOwnerSay("🤖 BOT: " + playerName + " picking " + picksStr + " (global had: " + llList2CSV(globalPickedNumbers) + ")");
                
                // Check if this bot has already made picks this round to prevent duplicates
                integer existingPicksIdx = -1;
                integer m;
                for (m = 0; m < llGetListLength(picksData); m++) {
                    if (llSubStringIndex(llList2String(picksData, m), playerName + "|") == 0) {
                        string existingPicks = llGetSubString(llList2String(picksData, m), llStringLength(playerName) + 1, -1);
                        if (existingPicks != "") {
                            llOwnerSay("⚠️ [Game Manager] Ignoring duplicate BOT_PICKED for " + playerName + " (already has picks: " + existingPicks + ")");
                            
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
                        llOwnerSay("🎯 [Game Manager] All players have picks! Moving to roll phase...");
                        
                        // CRITICAL: Sync the updated picks data to all modules before roll phase
                        llOwnerSay("🔄 [Game Manager] Syncing final picks data before roll phase...");
                        syncStateToMain();
                        llSleep(1.0); // Longer delay to ensure sync propagates to all modules
                        
                        // Force close any active number picker dialogs
                        llOwnerSay("🚫 [Game Manager] Sending CLOSE_ALL_DIALOGS command");
                        llMessageLinked(LINK_SET, -9999, "CLOSE_ALL_DIALOGS", NULL_KEY);
                        
                        // Send roll dialog through Player_RegistrationManager
                        string rollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
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
                    llOwnerSay("❌ [Game Manager] Bot " + playerName + " tried to pick duplicate number: " + picksStr + " - REJECTING");
                    llOwnerSay("🙄 [Game Manager] Sending new pick command to Bot Manager for " + playerName);
                    
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
                    llOwnerSay("🎯 [Game Manager] Sending retry bot command with complete avoid list (" + (string)llGetListLength(completeAvoidList) + " numbers): " + avoidListStr);
                    llMessageLinked(LINK_SET, -9999, botCommand, NULL_KEY);
                    return; // Don't save this pick
                }
                
                // Update picks data
                integer idx = llListFindList(names, [playerName]);
                llOwnerSay("🔧 [Game Manager] Looking for bot " + playerName + " in names list: " + llList2CSV(names) + " (idx: " + (string)idx + ")");
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
                    llOwnerSay("🔄 [Game Manager] Syncing picks and updating floater immediately for " + playerName + " (bot) with new picks");
                    
                    // Send just the updated picks data to Floater Manager (lightweight sync)
                    string picksDataStr = llDumpList2String(picksData, "^");
                    string lightSync = llList2CSV(lives) + "~" + picksDataStr + "~" + perilPlayer + "~" + llList2CSV(names);
                    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, lightSync, NULL_KEY);
                    
                    // Brief delay to ensure sync reaches Floater Manager before update request
                    llSleep(0.1);
                    
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
                    
                    llOwnerSay("🔍 [Game Manager] Bot pick complete - players with picks: " + (string)playersWithPicks + "/" + (string)llGetListLength(names));
                    
                    // If all players have picks, advance to roll phase
                    if (playersWithPicks >= llGetListLength(names)) {
                        llOwnerSay("🎯 [Game Manager] All players have picks! Moving to roll phase...");
                        
                        // CRITICAL: Sync the updated picks data to all modules before roll phase
                        llOwnerSay("🔄 [Game Manager] Syncing final picks data before roll phase...");
                        syncStateToMain();
                        llSleep(0.2); // Brief delay to ensure sync propagates
                        
                        // Force close any active number picker dialogs
                        llOwnerSay("🚫 [Game Manager] Sending CLOSE_ALL_DIALOGS command");
                        llMessageLinked(LINK_SET, -9999, "CLOSE_ALL_DIALOGS", NULL_KEY);
                        
                        // Send roll dialog through Player_RegistrationManager
                        string rollRequest = "SHOW_ROLL_DIALOG|" + perilPlayer + "|" + perilPlayer;
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
            llOwnerSay("🎯 [Game Manager] Received continue round request with peril player: '" + str + "'");
            
            // Update peril player from the continue message if provided
            if (str != "" && str != "NONE") {
                perilPlayer = str;
                llOwnerSay("🎯 [Game Manager] Updated peril player to: " + perilPlayer);
                
                // Reset round state and continue with existing peril player
                roundStarted = FALSE;
                currentPickerIdx = 0;
                diceTypeProcessed = FALSE;
                roundContinueInProgress = FALSE;
                
                // Continue current round with assigned peril player
                continueCurrentRound();
            } else {
                // Empty peril player means this is initial game start - use startNextRound()
                llOwnerSay("🎯 [Game Manager] Empty peril player - starting initial game round");
                
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
        
        // Handle verbose logging toggle from Main Controller
        if (num == 9011 && llSubStringIndex(str, "VERBOSE_LOGGING|") == 0) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                VERBOSE_LOGGING = (integer)llList2String(parts, 1);
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔍 [Game Manager] Verbose logging ON");
                } else {
                    llOwnerSay("🔍 [Game Manager] Verbose logging OFF");
                }
            }
            return;
        }
        
        // Handle reset
        if (num == -99999 && str == "FULL_RESET") {
            players = names = lives = picksData = globalPickedNumbers = pickQueue = [];
            perilPlayer = "";
            currentPickerIdx = 0;
            diceType = 6;
            currentPicker = NULL_KEY;
            roundStarted = FALSE;
            diceTypeProcessed = FALSE;  // Reset for new game
            roundContinueInProgress = FALSE;  // Reset protection flag
            lastSyncProcessTime = 0;  // Reset sync timing
            llOwnerSay("🎯 Game Manager reset - ready for new game!");
            return;
        }
        
        // Handle emergency state reset (for when game gets stuck)
        if (num == -99998 && str == "EMERGENCY_RESET") {
            llOwnerSay("🚨 [Game Manager] Emergency reset triggered!");
            roundStarted = FALSE;
            perilPlayer = "";
            currentPickerIdx = 0;
            pickQueue = [];
            diceTypeProcessed = FALSE;
            roundContinueInProgress = FALSE;
            lastSyncProcessTime = 0;  // Reset sync timing
            llOwnerSay("🔒 [Game Manager] Emergency state reset complete");
            return;
        }
    }
}
