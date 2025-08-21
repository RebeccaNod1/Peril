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

// Duplicate request prevention
string lastHumanPickMessage = "";
string lastBotPickMessage = "";
integer lastProcessTime = 0;

// Message constants
integer MSG_SHOW_DIALOG = 101;
integer MSG_SHOW_ROLL_DIALOG = 301;
integer MSG_GET_DICE_TYPE = 1001;
integer MSG_DICE_TYPE_RESULT = 1005;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SYNC_PICKQUEUE = 2001;
integer MSG_PLAYER_WON = 551;
integer MSG_UPDATE_FLOAT = 2010;

continueCurrentRound() {
    // ALWAYS start fresh for a new round - clear all picks and global picked numbers
    // After a roll, we need everyone to pick new numbers
    picksData = [];
    globalPickedNumbers = [];
    
    llOwnerSay("🔄 [Game Manager] continueCurrentRound: Cleared picks data, starting fresh");
    
    // Set round as started for the new round
    roundStarted = TRUE;
    diceTypeProcessed = FALSE; // Reset dice type processing for new round
    
    // Create new pick queue with peril player first
    pickQueue = [perilPlayer];
    integer i;
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
    globalPickedNumbers = [];
    
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
            // All picked, show roll dialog
            integer perilIdx = llListFindList(names, [perilPlayer]);
            if (perilIdx != -1) {
                key perilKey = llList2Key(players, perilIdx);
                llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
            }
        }
        return;
    }
    
    integer nameIdx = llListFindList(names, [firstName]);
    if (nameIdx == -1) {
        llOwnerSay("❌ Cannot show picker dialog: player " + firstName + " not found in names list");
        return;
    }
    
    currentPicker = llList2Key(players, nameIdx);
    
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
            
            string alreadyPicked = llList2CSV(globalPickedNumbers);
            string botCommand = "BOT_PICK:" + firstName + ":" + (string)picksNeeded + ":" + (string)diceType + ":" + alreadyPicked;
            llMessageLinked(LINK_SET, -9999, botCommand, NULL_KEY);
            llOwnerSay("🤖 " + firstName + " is automatically picking " + (string)picksNeeded + " numbers...");
        } else {
            // Bot already has picks, advance to next player immediately
            currentPickerIdx++;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                showNextPickerDialog();
            } else {
                // All picked, show roll dialog
                integer perilIdx = llListFindList(names, [perilPlayer]);
                if (perilIdx != -1) {
                    key perilKey = llList2Key(players, perilIdx);
                    llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                }
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
        
        string alreadyPicked = llList2CSV(globalPickedNumbers);
        string dialogPayload = firstName + "|" + (string)diceType + "|" + (string)picksNeeded + "|" + alreadyPicked;
        
        llOwnerSay("🎯 Showing pick dialog for " + firstName);
        llSleep(0.5);  // Brief delay to prevent spam
        
        llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, currentPicker);
    }
}

// requestDiceType() removed - Game Manager no longer requests dice type directly
// This prevents loops. Main Controller handles all dice type requests.

syncStateToMain() {
    // Send updated state back to main controller
    string perilForSync = "NONE";
    if (roundStarted) perilForSync = perilPlayer;
    
    string picksDataStr = "EMPTY";
    if (llGetListLength(picksData) > 0) {
        picksDataStr = llDumpList2String(picksData, "^");
    }
    
    // Keep sync message format standard for all modules (4 parts)
    string serialized = llList2CSV(lives) + "~" + picksDataStr + "~" + perilForSync + "~" + llList2CSV(names);
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, serialized, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_SYNC_PICKQUEUE, llList2CSV(pickQueue), NULL_KEY);
}

default {
    state_entry() {
        llOwnerSay("🎯 Game Manager ready!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        
        // Receive game state updates from main controller
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            
            // EARLY VALIDATION: Extract peril player from any sync message and validate it
            // This prevents loops from incomplete sync messages with invalid peril players
            if (llGetListLength(parts) >= 3) {
                string receivedPerilPlayer = llList2String(parts, 2);
                list newNames = [];
                if (llGetListLength(parts) >= 4) {
                    newNames = llCSV2List(llList2String(parts, 3));
                }
                
                // PROTECTION: Don't accept peril player updates for players that don't exist OR have 0 lives
                if (receivedPerilPlayer != "NONE" && receivedPerilPlayer != "" && receivedPerilPlayer != perilPlayer) {
                    // If we have the names list, validate against it
                    if (llGetListLength(newNames) > 0) {
                        integer receivedPlayerExists = llListFindList(newNames, [receivedPerilPlayer]) != -1;
                        if (!receivedPlayerExists) {
                            llOwnerSay("⚠️ [Game Manager] EARLY REJECTION: Invalid peril player update " + receivedPerilPlayer + " (player no longer exists) - IGNORING entire message");
                            return; // Reject the entire sync message
                        }
                        
                        // ADDITIONAL CHECK: If we have lives data, reject players with 0 lives
                        if (llGetListLength(parts) >= 1) {
                            list newLivesCheck = llCSV2List(llList2String(parts, 0));
                            integer receivedPlayerIdx = llListFindList(newNames, [receivedPerilPlayer]);
                            if (receivedPlayerIdx != -1 && receivedPlayerIdx < llGetListLength(newLivesCheck)) {
                                integer receivedPlayerLives = llList2Integer(newLivesCheck, receivedPlayerIdx);
                                if (receivedPlayerLives <= 0) {
                                    llOwnerSay("⚠️ [Game Manager] EARLY REJECTION: Invalid peril player update " + receivedPerilPlayer + " (player has 0 lives) - IGNORING entire message");
                                    return; // Reject the entire sync message
                                }
                            }
                        }
                    }
                }
            }
            
            if (llGetListLength(parts) < 4) {
                llOwnerSay("⚠️ [Game Manager] Incomplete sync message received, parts: " + (string)llGetListLength(parts) + " - IGNORING");
                return;
            } else {
                list newLives = llCSV2List(llList2String(parts, 0));
                
                string picksDataStr = llList2String(parts, 1);
                list newPicksData = [];
                if (picksDataStr == "" || picksDataStr == "EMPTY") {
                    newPicksData = [];
                } else {
                    newPicksData = llParseString2List(picksDataStr, ["^"], []);
                }
                
                // Accept peril player updates from Roll module (Plot Twist, elimination, etc.)
                list newNames = llCSV2List(llList2String(parts, 3));
                string receivedPerilPlayer = llList2String(parts, 2);
                
                // SAVE original peril player BEFORE any updates for Plot Twist detection
                string originalPerilPlayer = perilPlayer;
                
                // Update peril player if Roll module sent a change
                // PROTECTION: Don't accept peril player updates for players that don't exist in the current game
                if (receivedPerilPlayer != "NONE" && receivedPerilPlayer != "" && receivedPerilPlayer != perilPlayer) {
                    integer receivedPlayerExists = llListFindList(newNames, [receivedPerilPlayer]) != -1;
                    if (receivedPlayerExists) {
                        llOwnerSay("🎯 [Game Manager] Peril player updated from Roll module: " + perilPlayer + " -> " + receivedPerilPlayer);
                        perilPlayer = receivedPerilPlayer;
                    } else {
                        llOwnerSay("⚠️ [Game Manager] REJECTING peril player update from Roll module: " + receivedPerilPlayer + " (player no longer exists)");
                        // Keep current peril player instead of accepting the invalid update
                    }
                }
                
                // Handle elimination case - if current peril player was eliminated, find a new one
                if (perilPlayer != "" && perilPlayer != "NONE") {
                    integer perilStillExists = llListFindList(newNames, [perilPlayer]) != -1;
                    if (!perilStillExists && llListFindList(names, [perilPlayer]) != -1) {
                        // Peril player was eliminated! Game Manager needs to assign new peril player
                        llOwnerSay("🚨 [Game Manager] Detected elimination of peril player: " + perilPlayer);
                        
                        // Find first remaining alive player to be new peril player
                        string newPerilPlayer = "";
                        integer k;
                        for (k = 0; k < llGetListLength(newNames) && newPerilPlayer == ""; k++) {
                            string candidateName = llList2String(newNames, k);
                            integer candidateIdx = llListFindList(newNames, [candidateName]);
                            if (candidateIdx != -1 && candidateIdx < llGetListLength(newLives)) {
                                integer candidateLives = llList2Integer(newLives, candidateIdx);
                                if (candidateLives > 0) {
                                    newPerilPlayer = candidateName;
                                }
                            }
                        }
                        
                        if (newPerilPlayer != "") {
                            llOwnerSay("🎯 [Game Manager] Assigning new peril player after elimination: " + newPerilPlayer);
                            perilPlayer = newPerilPlayer;
                        } else {
                            llOwnerSay("⚠️ [Game Manager] No valid peril player candidates found!");
                            perilPlayer = "NONE";
                        }
                    }
                }
                
                names = newNames;
                
                // New: also receive players list if available (for dialog targeting)
                if (llGetListLength(parts) >= 5) {
                    players = llCSV2List(llList2String(parts, 4));
                }
                
                // Always update state normally - check for round completion regardless of lives changes
                lives = newLives;
                picksData = newPicksData;
                
                // Check if all picks are empty (round is complete) - this works for ALL roll outcomes
                integer allPicksEmpty = TRUE;
                integer i;
                for (i = 0; i < llGetListLength(newPicksData) && allPicksEmpty; i++) {
                    string entry = llList2String(newPicksData, i);
                    list parts = llParseString2List(entry, ["|"], []);
                    if (llGetListLength(parts) >= 2 && llList2String(parts, 1) != "") {
                        allPicksEmpty = FALSE;
                    }
                }
                
                // Check for win condition FIRST to prevent infinite loops
                if (roundStarted && llGetListLength(newNames) <= 1) {
                    if (llGetListLength(newNames) == 1) {
                        string winner = llList2String(newNames, 0);
                        llOwnerSay("🏆 [Game Manager] Victory detected: " + winner + " wins!");
                        // Reset round state to prevent loops
                        roundStarted = FALSE;
                        perilPlayer = "";
                        // Let Main Controller handle the victory celebration and reset
                        return;
                    } else {
                        llOwnerSay("💀 [Game Manager] No survivors remain!");
                        // Reset round state to prevent loops
                        roundStarted = FALSE;
                        perilPlayer = "";
                        return;
                    }
                }
                
                // STOP processing if game is over or peril player is invalid
                if (!roundStarted || perilPlayer == "" || perilPlayer == "NONE" || llGetListLength(newNames) <= 1) {
                    // Game is ending or already ended, don't continue rounds
                    return;
                }
                
                // Only show debug and continue if game is actually active
                llOwnerSay("🔍 [Game Manager] DEBUG - allPicksEmpty: " + (string)allPicksEmpty + ", perilPlayer: " + perilPlayer + ", roundStarted: " + (string)roundStarted);
                
                // If picks are empty, round started, and we have a valid peril player, continue to next round
                // This works for ALL outcomes: Direct Hit, No Shield, AND Plot Twist
                // PROTECTION: Prevent rapid consecutive calls to continueCurrentRound
                // ADDITIONAL PROTECTION: Verify peril player still exists in the game
                // CRITICAL FIX: Prevent double processing during Plot Twist scenarios
                integer perilPlayerExists = (perilPlayer != "" && perilPlayer != "NONE" && llListFindList(newNames, [perilPlayer]) != -1);
                if (allPicksEmpty && roundStarted && perilPlayerExists && llGetListLength(newNames) > 1 && !roundContinueInProgress) {
                    // ADDITIONAL CHECK: Don't start new rounds if we just received a peril player update
                    // This prevents double round starts during Plot Twist scenarios
                    if (receivedPerilPlayer != "NONE" && receivedPerilPlayer != "" && receivedPerilPlayer != originalPerilPlayer) {
                        llOwnerSay("🎯 [Game Manager] Plot Twist detected - peril player changed from " + originalPerilPlayer + " to " + perilPlayer + ", deferring round continuation");
                        // Don't start new round immediately after Plot Twist - wait for next sync
                        return;
                    }
                    
                    llOwnerSay("🎯 [Game Manager] Round complete - starting next round with peril player: " + perilPlayer);
                    roundContinueInProgress = TRUE;  // Set flag to prevent rapid calls
                    llSleep(2.0); // Brief pause for dramatic effect
                    continueCurrentRound(); // Use continueCurrentRound instead of startNextRound
                    roundContinueInProgress = FALSE;  // Clear flag after completion
                } else if (allPicksEmpty && roundStarted && !perilPlayerExists && llGetListLength(newNames) > 1) {
                    llOwnerSay("⚠️ [Game Manager] Peril player " + perilPlayer + " no longer exists, but game continues with " + (string)llGetListLength(newNames) + " players");
                    // Don't continue the round - let the elimination logic handle victory condition
                }
            }
            return;
        }
        
        // Receive pick queue updates
        if (num == MSG_SYNC_PICKQUEUE) {
            list newPickQueue = llCSV2List(str);
            llOwnerSay("🔍 [Game Manager] Received pickQueue sync from sender " + (string)sender + ": '" + str + "' (" + (string)llGetListLength(newPickQueue) + " items)");
            
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
        
        // Handle start round requests
        if (num == 997) {
            if (str == "START_NEXT_ROUND") {
                startNextRound();
            }
            else if (llSubStringIndex(str, "CONTINUE_ROUND|") == 0) {
                string newPeril = llGetSubString(str, 15, -1);
                perilPlayer = newPeril;
                llOwnerSay("🎯 Game Manager received CONTINUE_ROUND for " + newPeril);
                // Reset round state for new round
                roundStarted = FALSE;
                currentPickerIdx = 0;
                continueCurrentRound();
            }
            return;
        }
        
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
                
                // Validate picks against global picked numbers
                list newPicks = llParseString2List(picksStr, [","], []);
                list validPicks = [];
                list duplicatePicks = [];
                integer i;
                
                for (i = 0; i < llGetListLength(newPicks); i++) {
                    string pick = llStringTrim(llList2String(newPicks, i), STRING_TRIM);
                    if (pick != "") {
                        if (llListFindList(globalPickedNumbers, [pick]) == -1) {
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
                        
                        string dialogPayload = playerName + "|" + (string)diceType + "|" + (string)picksNeeded + "|" + llList2CSV(globalPickedNumbers);
                        llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, llList2Key(players, idx));
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
                    // Don't sync to Main here - it creates loops
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
                        llSleep(0.2); // Brief delay to ensure sync propagates
                        
                        integer perilIdx = llListFindList(names, [perilPlayer]);
                        if (perilIdx != -1) {
                            key perilKey = llList2Key(players, perilIdx);
                            llOwnerSay("🎯 [Game Manager] Sending MSG_SHOW_ROLL_DIALOG to key: " + (string)perilKey);
                            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                        } else {
                            llOwnerSay("⚠️ [Game Manager] ERROR: Could not find peril player " + perilPlayer + " in names list!");
                        }
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
                        llSleep(0.2); // Brief delay to ensure sync propagates
                        
                        // Force close any active number picker dialogs
                        llOwnerSay("🚫 [Game Manager] Sending CLOSE_ALL_DIALOGS command");
                        llMessageLinked(LINK_SET, -9999, "CLOSE_ALL_DIALOGS", NULL_KEY);
                        
                        integer perilIdx = llListFindList(names, [perilPlayer]);
                        if (perilIdx != -1) {
                            key perilKey = llList2Key(players, perilIdx);
                            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                        }
                    }
                            return; // Ignore duplicate - bot already has real picks
                        }
                        existingPicksIdx = m;
                        // Don't break - continue to make sure there are no other entries with picks
                    }
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
                    
                    // Update global picked numbers - bot picks use semicolon delimiters
                    list newPicks = llParseString2List(picksStr, [";"], []);
                    integer j;
                    for (j = 0; j < llGetListLength(newPicks); j++) {
                        string pick = llList2String(newPicks, j);
                        if (llListFindList(globalPickedNumbers, [pick]) == -1) {
                            globalPickedNumbers += [pick];
                        }
                    }
                    
                    llSay(0, "🎯 " + playerName + " (bot) stakes their digital life on numbers: " + picksStr + " 🎲");
                    // Don't sync to Main here - it creates loops
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
                        
                        integer perilIdx = llListFindList(names, [perilPlayer]);
                        if (perilIdx != -1) {
                            key perilKey = llList2Key(players, perilIdx);
                            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                        }
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
            llOwnerSay("🎯 Game Manager reset!");
            return;
        }
    }
}
