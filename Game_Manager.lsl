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

continueCurrentRound() {
    // ALWAYS start fresh for a new round - clear all picks and global picked numbers
    // After a roll, we need everyone to pick new numbers
    picksData = [];
    globalPickedNumbers = [];
    
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
    
    // Request dice type for the new round
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
    }
    
    picksData = [];
    globalPickedNumbers = [];
    
    // Create pick queue with peril player first
    llOwnerSay("🎯 Debug - Creating pickQueue. names: " + llList2CSV(names) + ", perilPlayer: " + perilPlayer);
    pickQueue = [perilPlayer];
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
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
    
    if (llSubStringIndex(firstName, "TestBot") == 0) {
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
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                
                string picksDataStr = llList2String(parts, 1);
                list newPicksData = [];
                if (picksDataStr == "" || picksDataStr == "EMPTY") {
                    newPicksData = [];
                } else {
                    newPicksData = llParseString2List(picksDataStr, ["^"], []);
                }
                
                // Don't sync peril player from Main Controller - Game Manager is authoritative
                // string receivedPeril = llList2String(parts, 2);
                // Game Manager manages its own peril player state
                names = llCSV2List(llList2String(parts, 3));
                
                // New: also receive players list if available (for dialog targeting)
                if (llGetListLength(parts) >= 5) {
                    players = llCSV2List(llList2String(parts, 4));
                }
                
                // AUTOMATIC ROUND CONTINUATION: Detect post-roll state
                // Check if lives have changed (indicating a roll occurred) and all picks are now empty
                string oldLivesStr = llList2CSV(lives);
                string newLivesStr = llList2CSV(newLives);
                integer livesChanged = (oldLivesStr != newLivesStr);
                
                // Check if all picks are empty (indicating post-roll state)
                integer allPicksEmpty = TRUE;
                integer i;
                for (i = 0; i < llGetListLength(newPicksData) && allPicksEmpty; i++) {
                    string entry = llList2String(newPicksData, i);
                    list entryParts = llParseString2List(entry, ["|"], []);
                    if (llGetListLength(entryParts) >= 2 && llList2String(entryParts, 1) != "") {
                        allPicksEmpty = FALSE;
                    }
                }
                
                // If lives changed and all picks are empty, this is post-roll - start new round
                if (livesChanged && allPicksEmpty && roundStarted && perilPlayer != "" && perilPlayer != "NONE") {
                    llOwnerSay("🎯 [Game Manager] Post-roll detected - automatically continuing to next round");
                    
                    // Update our state first
                    lives = newLives;
                    picksData = newPicksData;
                    
                    // Reset for new round and continue
                    roundStarted = FALSE;
                    currentPickerIdx = 0;
                    continueCurrentRound();
                } else {
                    // Normal state update
                    lives = newLives;
                    picksData = newPicksData;
                }
            }
            return;
        }
        
        // Receive pick queue updates
        if (num == MSG_SYNC_PICKQUEUE) {
            pickQueue = llCSV2List(str);
            return;
        }
        
        // Handle dice type result from Main Controller
        if (num == MSG_DICE_TYPE_RESULT) {
            // Prevent duplicate processing of dice type results
            if (diceTypeProcessed) {
                llOwnerSay("🎲 Ignoring duplicate dice type result: " + str);
                return;
            }
            
            diceType = (integer)str;
            diceTypeProcessed = TRUE;
            llOwnerSay("🎲 Dice type set to: " + str);
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
            llOwnerSay("🎯 Game Manager reset!");
            return;
        }
    }
}
