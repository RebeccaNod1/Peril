// === Main Peril Dice Controller (Refactored with Game Helpers Integration, with dynamic player join) ===

//
// This version of the main game controller includes support for players (including
// the owner) joining the game at runtime via a MSG_REGISTER_PLAYER message. When
// a new player registers, they are added to the internal lists (players, names,
// lives and picksData), a floating display is rezzed for them, and helpers are
// updated. This mirrors the behaviour used when adding a test player, but now
// applies to any avatar joining the game via the dialog handler.

integer syncChannel = -77777;
integer numberPickChannel = -77888;
integer rollDialogChannel = -77999;
integer DIALOG_CHANNEL = -88888;

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

// Forward game state to helpers when it changes
updateHelpers() {
    // Don't send peril player name if game hasn't started yet
    string perilForSync = "NONE";  // Use placeholder instead of empty string
    if (roundStarted) {
        perilForSync = perilPlayer;
    }
    llOwnerSay("🔍 updateHelpers() - lives: " + llList2CSV(lives) + ", roundStarted: " + (string)roundStarted);
    llOwnerSay("🔍 updateHelpers() - perilPlayer: '" + perilPlayer + "', perilForSync: '" + perilForSync + "'");
    // Encode picksData with a safe delimiter that won't conflict with player names or picks
    // Replace commas in picks with semicolons to avoid CSV conflicts
    list encodedPicksData = [];
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        // Replace commas with semicolons in the picks portion only
        list parts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(parts) >= 2) {
            string playerName = llList2String(parts, 0);
            string picks = llList2String(parts, 1);
            // Only process picks if they're not empty
            if (picks != "") {
                // Parse picks, trim whitespace, then join with semicolons
                list pickList = llParseString2List(picks, [","], []);
                list cleanPickList = [];
                integer j;
                for (j = 0; j < llGetListLength(pickList); j++) {
                    string pick = llStringTrim(llList2String(pickList, j), STRING_TRIM);
                    if (pick != "") {
                        cleanPickList += [pick];
                    }
                }
                picks = llDumpList2String(cleanPickList, ";");
            }
            encodedPicksData += [playerName + "|" + picks];
        } else if (llSubStringIndex(entry, "|") != -1) {
            // Handle entries with empty picks (e.g., "PlayerName|")
            encodedPicksData += [entry];
        } else {
            // Skip malformed entries without pipe separator
            llOwnerSay("⚠️ Skipping malformed picksData entry: " + entry);
        }
    }
    string picksDataStr = llDumpList2String(encodedPicksData, "^");
    // Ensure we always send valid format even with empty picks
    if (picksDataStr == "") {
        picksDataStr = "EMPTY";  // Use a clear placeholder for empty picks data
    }
    string serialized = llList2CSV(lives) + "~" + picksDataStr +
        "~" + perilForSync + "~" + llList2CSV(names);
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, serialized, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_SYNC_PICKQUEUE, llList2CSV(pickQueue), NULL_KEY);
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

resetGame() {
    // Clean up all tracked floater channels
    integer i;
    for (i = 0; i < llGetListLength(floaterChannels); i++) {
        integer ch = llList2Integer(floaterChannels, i);
        llOwnerSay("🔍 Cleaning up floater channel " + (string)ch + " during reset");
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    
    // Also send cleanup for all possible floater channels in case of orphaned floaters
    // This handles any duplicate floaters that weren't properly tracked
    for (i = 0; i < MAX_PLAYERS; i++) {
        integer ch = -777000 + i;
        llOwnerSay("🧹 Sending cleanup for possible orphaned floater channel " + (string)ch);
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    players = names = lives = picksData = globalPickedNumbers = readyPlayers = [];
    floaterChannels = []; // Clear the tracked channels
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    roundStarted = FALSE; // Reset round flag
    llSay(syncChannel, "RESET");
    llOwnerSay(" Game reset!");
    llSleep(0.2);
    llSetTimerEvent(0);
    updateHelpers();
}

continueCurrentRound() {
    // Continue the current round after elimination with existing picks intact
    // This is different from startNextRound() which resets picks for a new round
    llOwnerSay("🔄 Continuing current round with new peril player: " + perilPlayer);
    
    // Remove eliminated player's pick data but keep others
    integer i;
    list newPicksData = [];
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(parts) >= 1) {
            string entryPlayerName = llList2String(parts, 0);
            // Only keep picks from players still in the game
            if (llListFindList(names, [entryPlayerName]) != -1) {
                newPicksData += [entry];
            }
        }
    }
    picksData = newPicksData;
    
    // Update global picked numbers to match remaining players' picks
    globalPickedNumbers = [];
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(parts) >= 2) {
            string picks = llList2String(parts, 1);
            if (picks != "") {
                // Handle semicolon encoding for picks
                string decodedPicks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                list playerPicks = llParseString2List(decodedPicks, [","], []);
                globalPickedNumbers += playerPicks;
            }
        }
    }
    
    // Check if all remaining players have picked
    integer allPicked = TRUE;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        // Check if this player has picks
        integer hasPicksEntry = FALSE;
        integer j;
        for (j = 0; j < llGetListLength(picksData); j++) {
            string entry = llList2String(picksData, j);
            list parts = llParseString2List(entry, ["|"], []);
            if (llGetListLength(parts) >= 1 && llList2String(parts, 0) == playerName) {
                string picks = "";
                if (llGetListLength(parts) >= 2) {
                    picks = llList2String(parts, 1);
                }
                if (picks != "") {
                    hasPicksEntry = TRUE;
                }
            }
        }
        if (!hasPicksEntry) {
            allPicked = FALSE;
        }
    }
    
    if (allPicked) {
        // All players have picked, prompt peril player to roll
        llOwnerSay("✅ All remaining players have picks, prompting " + perilPlayer + " to roll");
        integer perilIdx = llListFindList(names, [perilPlayer]);
        if (perilIdx != -1) {
            key perilKey = llList2Key(players, perilIdx);
            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
        }
    } else {
        // Some players still need to pick, continue with pick phase
        llOwnerSay("⏳ Some players still need to pick, continuing pick phase");
        updateHelpers();
        // Check if peril player needs to pick
        showNextPickerDialog();
    }
}

startNextRound() {
    // Do not start a round if there are fewer than 2 players. This guard prevents
    // accidental starts when only one player is present (e.g. after a reset or
    // before any other participants join).
    if (llGetListLength(names) < 2) {
        llOwnerSay("⚠️ Need at least 2 players to start the game.");
        return;
    }
    // If somehow called with exactly one player, treat them as the winner and reset.
    if (llGetListLength(names) == 1) {
        llSay(0, " " + llList2String(names, 0) + " is the last player standing and wins the game!");
        resetGame();
        return;
    }
    // Reset round flag for new round
    roundStarted = FALSE;
    
    llOwnerSay("🔍 DEBUG: startNextRound() called with perilPlayer = '" + perilPlayer + "'");
    
    // Select random initial peril player if none is set (only for very first round)
    if (perilPlayer == "" || perilPlayer == "NONE") {
        integer randomIdx = (integer)llFrand(llGetListLength(names));
        perilPlayer = llList2String(names, randomIdx);
        llSay(0, "🎯 " + perilPlayer + " has been randomly selected and is now in peril!");
        llOwnerSay("🔍 DEBUG: Selected random peril player: " + perilPlayer);
    } else {
        llOwnerSay("🔍 DEBUG: Continuing with existing peril player: " + perilPlayer);
    }
    picksData = [];
    globalPickedNumbers = [];
    // Create pick queue with peril player first, then all others
    pickQueue = [perilPlayer];
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        if (playerName != perilPlayer) {
            pickQueue += [playerName];
        }
    }
    currentPickerIdx = 0;
    // Don't pre-populate picksData with empty entries - let them be added as picks are made
    // This prevents encoding corruption with empty "|" entries
    updateHelpers();
    // requestDiceType(); // Removed to avoid recursion loop
}

showNextPickerDialog() {
    if (diceType <= 0) {
        llOwnerSay("❌ Cannot show picker dialog: diceType not set (" + (string)diceType + ")");
        return;
    }
    
    string firstName = llList2String(pickQueue, currentPickerIdx);
    currentPicker = llList2Key(players, llListFindList(names, [firstName]));
    
    // Check if this is a bot (TestBot names)
    if (llSubStringIndex(firstName, "TestBot") == 0) {
        // Get number of picks needed based on peril player's lives
        integer perilIdx = llListFindList(names, [perilPlayer]);
        integer perilLives = 3; // default
        if (perilIdx != -1) {
            perilLives = llList2Integer(lives, perilIdx);
        }
        llOwnerSay("🔍 DEBUG BOT: Peril player '" + perilPlayer + "' lives=" + (string)perilLives + " (idx=" + (string)perilIdx + ")");
        // Pick count = 4 - peril player's lives (3 lives=1 pick, 2 lives=2 picks, 1 life=3 picks)
        integer picksNeeded = 4 - perilLives;
        
        // Send command to Bot Manager to auto-pick numbers (include already picked numbers)
        string alreadyPicked = llList2CSV(globalPickedNumbers);
        string botCommand = "BOT_PICK:" + firstName + ":" + (string)picksNeeded + ":" + (string)diceType + ":" + alreadyPicked;
        llOwnerSay("📡 Sending to Bot Manager: " + botCommand);
        llMessageLinked(LINK_SET, -9999, botCommand, NULL_KEY);
        llOwnerSay("🤖 " + firstName + " is automatically picking " + (string)picksNeeded + " numbers...");
    } else {
        // Show dialog for human players - calculate picks needed
        integer perilIdx = llListFindList(names, [perilPlayer]);
        integer perilLives = 3; // default
        if (perilIdx != -1) {
            perilLives = llList2Integer(lives, perilIdx);
        }
        llOwnerSay("🔍 DEBUG: Peril player '" + perilPlayer + "' lives=" + (string)perilLives + " (idx=" + (string)perilIdx + ")");
        llOwnerSay("🔍 DEBUG: All lives: " + llList2CSV(lives));
        integer picksNeeded = 4 - perilLives;
        llOwnerSay("🔍 DEBUG: Picks needed calculation: 4 - " + (string)perilLives + " = " + (string)picksNeeded);
        
        // Include already picked numbers so player can't pick duplicates
        string alreadyPicked = llList2CSV(globalPickedNumbers);
        string dialogPayload = firstName + "|" + (string)diceType + "|" + (string)picksNeeded + "|" + alreadyPicked;
        llOwnerSay("🎯 Sending dialog to " + firstName + " with diceType=" + (string)diceType + ", picksNeeded=" + (string)picksNeeded);
        llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, currentPicker);
        timeoutTimer = llGetUnixTime();
        lastWarning = 0;
        llSetTimerEvent(60.0);
    }
}

integer roundStarted = FALSE;

default {
    state_entry() {
        llOwnerSay("🎮 Main Controller ready!");
        llOwnerSay("🎮 Main Controller key: " + (string)llGetKey());
        llOwnerSay("🎮 Main Controller position: " + (string)llGetPos());
        llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
        llListen(-9999, "", NULL_KEY, ""); // Listen for bot responses
        llListen(rollDialogChannel, "", NULL_KEY, ""); // Listen for roll dialog responses
    }

    touch_start(integer total_number) {
        llOwnerSay("Touched by: " + (string)llDetectedKey(0));
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        if (toucher == llGetOwner()) {
            // Determine if this will be the first registered player (starter) before registration
            integer isStarter = FALSE;
            if (idx == -1) {
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
                string ownerName = llKey2Name(toucher);
                // Send a registration request; Main.lsl will handle adding them and rezzing a float
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, ownerName + "|" + (string)toucher, NULL_KEY);
            } else {
                // Already registered; check if owner is the first human player
                string ownerName = llList2String(names, idx);
                isStarter = TRUE;  // Default to TRUE for owner
                llOwnerSay("🔍 Owner check: idx=" + (string)idx + ", ownerName=" + ownerName);
                integer k;
                for (k = 0; k < idx && isStarter; k++) {
                    string existingName = llList2String(names, k);
                    llOwnerSay("🔍 Checking name[" + (string)k + "] = " + existingName + " (isBot=" + (string)(llSubStringIndex(existingName, "TestBot") == 0) + ")");
                    // If there's a human player before the owner, owner is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                        llOwnerSay("❌ Found human player before owner, not starter");
                    }
                }
                llOwnerSay("🔍 Final isStarter = " + (string)isStarter);
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
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        // Player list and pick list handling remain unchanged
        if (num == 202 && str == "REQUEST_PLAYER_LIST") {
            string namesCSV = llList2CSV(names);
            llMessageLinked(LINK_SET, 203, namesCSV, id);
            return;
        }
        if (num == 206) {
            string targetName = str;
            integer i;
            for (i = 0; i < llGetListLength(picksData); i++) {
                string rawEntry = llList2String(picksData, i);
                list parts = llParseString2List(rawEntry, ["|"], []);
                if (llList2String(parts, 0) == targetName) {
                    llMessageLinked(LINK_SET, 205, targetName + "|" + llList2String(parts, 1), id);
                    return;
                }
            }
            llMessageLinked(LINK_SET, 205, targetName + "|", id);
            return;
        }
        if (num == 208) {
            string playerName = str;
            integer idx = llListFindList(names, [playerName]);
            if (idx != -1) {
                string lifeVal = llList2String(lives, idx);
                llMessageLinked(LINK_SET, 208, playerName + "|" + lifeVal, id);
            }
            return;
        }
        // Handle dice type result from helper
        if (num == MSG_DICE_TYPE_RESULT) {
            if (!roundStarted) {
                roundStarted = TRUE;
                diceType = (integer)str;
                llOwnerSay(" Dice type set to: " + str);
                // Update helpers now that game has started - this will sync peril player
                updateHelpers();
                showNextPickerDialog();
            } else {
                // Game already started, but dice type changed (e.g., after elimination)
                diceType = (integer)str;
                llOwnerSay(" Dice type set to: " + str);
                updateHelpers();
                showNextPickerDialog();
            }
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
        // Handle pick actions
        if (num == 204) {
            list parts = llParseString2List(str, ["~"], []);
            string action = llList2String(parts, 0);
            list args = llParseString2List(llList2String(parts, 1), ["|"], []);
            string name = llList2String(args, 0);
            string pick = llList2String(args, 1);
            integer i;
            for (i = 0; i < llGetListLength(picksData); i++) {
                string entry = llList2String(picksData, i);
                list pdParts = llParseString2List(entry, ["|"], []);
                if (llList2String(pdParts, 0) == name) {
                    list pickList = [];
                    string rawPicks = llList2String(pdParts, 1);
                    if (rawPicks != "") {
                        pickList = llParseString2List(rawPicks, [","], []);
                    }
                    if (action == "ADD_PICK") {
                        if (llListFindList(pickList, [pick]) == -1) {
                            pickList += [pick];
                            llOwnerSay("➕ Added " + pick + " to " + name);
                        }
                    } else if (action == "REMOVE_PICK") {
                        integer idx = llListFindList(pickList, [pick]);
                        if (idx != -1) {
                            pickList = llDeleteSubList(pickList, idx, idx);
                            llOwnerSay("➖ Removed " + pick + " from " + name);
                        }
                    }
                    picksData = llListReplaceList(picksData, [name + "|" + llList2CSV(pickList)], i, i);
                    updateHelpers();
                    return;
                }
            }
            return;
        }
        // New: handle dynamic registration of players (owner or players) via MSG_REGISTER_PLAYER
        if (num == MSG_REGISTER_PLAYER) {
            // str is in the format "Name|<key>"
            list parts = llParseString2List(str, ["|"], []);
            string newName = llList2String(parts, 0);
            key newKey = (key)llList2String(parts, 1);
            
            // Prevent joining game in progress (except owner accessing menu)
            if (roundStarted && newKey != llGetOwner()) {
                llOwnerSay("⚠️ " + newName + " cannot join - game in progress");
                llRegionSayTo(newKey, 0, "⚠️ Cannot join game in progress. Wait for current game to finish.");
                return;
            }
            
            // Do not register if already present
            integer existingIdx = llListFindList(players, [newKey]);
            llOwnerSay("🐛 DEBUG: Registration request for " + newName + " (key: " + (string)newKey + "), existingIdx: " + (string)existingIdx);
            llOwnerSay("🐛 DEBUG: Current players: " + llList2CSV(players));
            llOwnerSay("🐛 DEBUG: Current lives: " + llList2CSV(lives));
            if (existingIdx == -1) {
                // Add to local lists
                players += [newKey];
                names += [newName];
                lives += [3];
                llOwnerSay("🐛 DEBUG: Added player " + newName + " with 3 lives. Lives now: " + llList2CSV(lives));
                picksData += [newName + "|"];
                // Track the floater channel for this player
                integer newPlayerIdx = llGetListLength(names) - 1;
                integer ch = -777000 + newPlayerIdx;
                floaterChannels += [ch];
                llOwnerSay("🔍 Added floater channel " + (string)ch + " for " + newName);
                // Auto-mark bots as ready, leave humans as not ready
                if (llSubStringIndex(newName, "TestBot") == 0) {
                    readyPlayers += [newName];
                    llOwnerSay("🤖 Auto-marked bot " + newName + " as ready");
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
                    llOwnerSay("🔍 Cleaning up floater channel " + (string)ch + " for " + eliminatedPlayer);
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // Remove from all lists
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    
                    llOwnerSay("🗑️ Eliminated " + eliminatedPlayer + ". Remaining players: " + (string)llGetListLength(names));
                    
                    // Update all scripts with the new player lists after elimination
                    updateHelpers();
                    
                    // Check if game should end (1 or fewer players remaining)
                    if (llGetListLength(names) <= 1) {
                        if (llGetListLength(names) == 1) {
                            llSay(0, "🏆 " + llList2String(names, 0) + " wins the game!");
                            // Trigger victory confetti
                            llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
                        } else {
                            llSay(0, "🏆 Game over - no players remaining!");
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
                        llOwnerSay("🔍 DEBUG: Ignoring sync attempt to change peril player from '" + perilPlayer + "' to 'NONE'");
                        return; // Don't process this sync update
                    } else {
                        llOwnerSay("🔍 DEBUG: Allowing peril player clear because current peril '" + perilPlayer + "' is no longer in game");
                    }
                }
                
                integer perilChanged = (perilPlayer != newPerilPlayerCheck);
                integer livesChanged = (newLivesStr != currentLivesStr);
                
                if (livesChanged || perilChanged) {
                    llOwnerSay("🔍 DEBUG: Sync update needed - livesChanged=" + (string)livesChanged + ", perilChanged=" + (string)perilChanged);
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
                    
                    // Debug peril player changes
                    if (perilPlayer != newPerilPlayer) {
                        llOwnerSay("🔍 DEBUG: Main Controller peril change: '" + perilPlayer + "' -> '" + newPerilPlayer + "'");
                    }
                    
                    // Update our game state with the new data
                    lives = newLives;
                    picksData = newPicksData;
                    perilPlayer = newPerilPlayer;
                    names = newNames;
                    
                    
                    // Don't call updateHelpers() here to avoid loop - other modules already have the data
                }
            }
            return;
        }
        // Handle start next round request
        if (num == 997) {
            if (str == "START_NEXT_ROUND") {
                startNextRound();
                requestDiceType();
            }
            else if (llSubStringIndex(str, "START_NEXT_ROUND_DIALOG|") == 0) {
                string playerName = llGetSubString(str, 24, -1); // Remove "START_NEXT_ROUND_DIALOG|" prefix
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    key playerKey = llList2Key(players, idx);
                    llOwnerSay("🎯 Showing next round dialog to " + playerName);
                    // Check if it's a bot
                    if (llSubStringIndex(playerName, "TestBot") == 0) {
                        // Auto-start for bots with delay to allow sync to complete
                        llOwnerSay("🤖 " + playerName + " (bot) auto-starting next round...");
                        llSleep(0.5); // Give sync time to complete
                        startNextRound();
                        requestDiceType();
                    } else {
                        // Show dialog for humans
                        llDialog(playerKey, "🎯 You're in peril! Ready for the next round?", ["Start Next Round"], -77999);
                    }
                }
            }
            return;
        }
        // Handle dice type request from roll module
        if (num == 996) {
            if (str == "GET_DICE_TYPE") {
                llOwnerSay("🎲 Main Controller sending dice type: " + (string)diceType);
                llMessageLinked(LINK_SET, MSG_ROLL_RESULT, (string)diceType, NULL_KEY);
            }
            return;
        }
        // Handle leave game requests
        if (num == 107) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "LEAVE_GAME") {
                string leavingName = llList2String(parts, 1);
                key leavingKey = (key)llList2String(parts, 2);
                integer idx = llListFindList(players, [leavingKey]);
                if (idx != -1) {
                    // Remove player's float using the tracked channel
                    integer ch = llList2Integer(floaterChannels, idx);
                    llOwnerSay("🔍 Cleaning up floater channel " + (string)ch + " for " + leavingName);
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // Remove from all lists including ready state
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    // Remove from ready list if present
                    integer readyIdx = llListFindList(readyPlayers, [leavingName]);
                    if (readyIdx != -1) {
                        readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    }
                    // Update helpers
                    updateHelpers();
                    llOwnerSay("👋 " + leavingName + " left the game");
                    // Check if game should end (less than 2 players)
                    if (llGetListLength(names) == 1) {
                        llSay(0, " " + llList2String(names, 0) + " is the last player standing and wins the game!");
                        // Trigger victory confetti
                        llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
                        resetGame();
                    } else if (llGetListLength(names) == 0) {
                        resetGame();
                    }
                }
            }
            return;
        }
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
                    llOwnerSay("✅ " + playerName + " is now ready");
                } else {
                    // Player is ready, make them not ready
                    readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    llOwnerSay("❌ " + playerName + " is no longer ready");
                }
                llOwnerSay("🔍 Ready players: " + llList2CSV(readyPlayers));
            }
            return;
        }
        // Handle ready state queries
        if (num == MSG_QUERY_READY_STATE) {
            string playerName = str;
            integer isReady = llListFindList(readyPlayers, [playerName]) != -1;
            integer isBot = llSubStringIndex(playerName, "TestBot") == 0;
            string result = playerName + "|" + (string)isReady + "|" + (string)isBot;
            llMessageLinked(LINK_SET, MSG_READY_STATE_RESULT, result, id);
            return;
        }
        // Handle aggressive floater cleanup
        if (num == MSG_CLEANUP_ALL_FLOATERS) {
            llOwnerSay("🧹 Performing aggressive floater cleanup for all possible channels...");
            integer i;
            for (i = 0; i < MAX_PLAYERS; i++) {
                integer ch = -777000 + i;
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                // Also try some potential duplicate channels
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 100), NULL_KEY);
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 1000), NULL_KEY);
            }
            // Reset our tracked channels list
            floaterChannels = [];
            llOwnerSay("🧹 Aggressive cleanup completed!");
            return;
        }
        // Handle HUMAN_PICKED messages from dialog handler
        if (num == -9998 && llSubStringIndex(str, "HUMAN_PICKED:") == 0) {
            llOwnerSay("📨 Main Controller received: " + str);
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                // Update the player's picks in picksData
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    // Find existing picks entry or add new one
                    integer picksIdx = -1;
                    integer k;
                    for (k = 0; k < llGetListLength(picksData); k++) {
                        string entry = llList2String(picksData, k);
                        if (llSubStringIndex(entry, playerName + "|") == 0) {
                            picksIdx = k;
                        }
                    }
                    string newEntry = playerName + "|" + picksStr;
                    if (picksIdx == -1) {
                        picksData += [newEntry];
                    } else {
                        picksData = llListReplaceList(picksData, [newEntry], picksIdx, picksIdx);
                    }
                    // Update global picked numbers list
                    list newPicks = llParseString2List(picksStr, [","], []);
                    integer i;
                    for (i = 0; i < llGetListLength(newPicks); i++) {
                        string pick = llList2String(newPicks, i);
                        if (llListFindList(globalPickedNumbers, [pick]) == -1) {
                            globalPickedNumbers += [pick];
                        }
                    }
                    updateHelpers();
                    llOwnerSay("👤 " + playerName + " picked: " + picksStr);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        showNextPickerDialog();
                    } else {
                        llOwnerSay("✅ All players have picked their numbers!");
                        // Show roll dialog to peril player
                        llOwnerSay("🔍 DEBUG: About to show roll dialog - perilPlayer: '" + perilPlayer + "'");
                        if (perilPlayer == "" || perilPlayer == "NONE") {
                            llOwnerSay("❌ ERROR: Cannot show roll dialog - perilPlayer is invalid: '" + perilPlayer + "'");
                            return;
                        }
                        key perilKey = llList2Key(players, llListFindList(names, [perilPlayer]));
                        llOwnerSay("🔍 DEBUG: Sending roll dialog to '" + perilPlayer + "' (key: " + (string)perilKey + ")");
                        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                    }
                }
            }
            return;
        }
        // Handle BOT_PICKED messages from Bot Manager
        if (num == -9997 && llSubStringIndex(str, "BOT_PICKED:") == 0) {
            llOwnerSay("📨 Main Controller received: " + str);
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                // Update the player's picks in picksData
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    // Find existing picks entry or add new one
                    integer picksIdx = -1;
                    integer k;
                    for (k = 0; k < llGetListLength(picksData); k++) {
                        string entry = llList2String(picksData, k);
                        if (llSubStringIndex(entry, playerName + "|") == 0) {
                            picksIdx = k;
                        }
                    }
                    string newEntry = playerName + "|" + picksStr;
                    if (picksIdx == -1) {
                        picksData += [newEntry];
                    } else {
                        picksData = llListReplaceList(picksData, [newEntry], picksIdx, picksIdx);
                    }
                    // Update global picked numbers list
                    list newPicks = llParseString2List(picksStr, [","], []);
                    integer j;
                    for (j = 0; j < llGetListLength(newPicks); j++) {
                        string pick = llList2String(newPicks, j);
                        if (llListFindList(globalPickedNumbers, [pick]) == -1) {
                            globalPickedNumbers += [pick];
                        }
                    }
                    updateHelpers();
                    llOwnerSay("🤖 " + playerName + " picked: " + picksStr);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        showNextPickerDialog();
                    } else {
                        llOwnerSay("✅ All players have picked their numbers!");
                        // Show roll dialog to peril player
                        llOwnerSay("🔍 DEBUG: About to show roll dialog - perilPlayer: '" + perilPlayer + "'");
                        if (perilPlayer == "" || perilPlayer == "NONE") {
                            llOwnerSay("❌ ERROR: Cannot show roll dialog - perilPlayer is invalid: '" + perilPlayer + "'");
                            return;
                        }
                        key perilKey = llList2Key(players, llListFindList(names, [perilPlayer]));
                        llOwnerSay("🔍 DEBUG: Sending roll dialog to '" + perilPlayer + "' (key: " + (string)perilKey + ")");
                        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                    }
                }
            }
            return;
        }
    }


    listen(integer channel, string name, key id, string msg) {
        // Handle bot and human responses
        if (channel == -9999 && (llSubStringIndex(msg, "BOT_PICKED:") == 0 || llSubStringIndex(msg, "HUMAN_PICKED:") == 0)) {
            list parts = llParseString2List(msg, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                // Update the player's picks in picksData
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    picksData = llListReplaceList(picksData, [playerName + "|" + picksStr], idx, idx);
                    updateHelpers();
                    string icon = "🤖";
                    if (llSubStringIndex(msg, "HUMAN_PICKED:") == 0) icon = "👤";
                    llOwnerSay(icon + " " + playerName + " picked: " + picksStr);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        showNextPickerDialog();
                    } else {
                        llOwnerSay("✅ All players have picked their numbers!");
                        // Show roll dialog to peril player
                        key perilKey = llList2Key(players, llListFindList(names, [perilPlayer]));
                        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                    }
                }
            }
            return;
        }
        
        if (channel == rollDialogChannel) {
            if (msg == "Start Next Round") {
                llOwnerSay("🔍 DEBUG: Start Next Round clicked by " + llKey2Name(id) + ", but perilPlayer=" + perilPlayer);
                llSay(0, "🎯 " + perilPlayer + " is starting the next round!");
                startNextRound();
                requestDiceType();
                return;
            }
        }
        
        if (channel == DIALOG_CHANNEL) {
            // Owner-specific commands: only owner messages in the dialog should be processed here.
            if (id == llGetOwner()) {
                if (msg == "Reset Game") {
                    resetGame();
                    return;
                }
                // Note: do not handle "Start Game" here; allow the generic start logic below to apply,
                // so that minimum player checks are enforced and non-owner starters can initiate the game.
                if (msg == "Dump Players") {
                    llOwnerSay(" Players: " + llList2CSV(names));
                    return;
                }
                if (msg == "Manage Picks") {
                    llOwnerSay(" Fetching list of players for pick management...");
                    llMessageLinked(LINK_SET, 202, "REQUEST_PLAYER_LIST", llGetOwner());
                    return;
                }
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
                    starterName = llKey2Name(llGetOwner());
                } else if (llGetListLength(players) > 0) {
                    key firstPlayer = llList2Key(players, 0);
                    if (id == firstPlayer) {
                        starterName = llKey2Name(firstPlayer);
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
                llOwnerSay("✅ All players ready! Starting game...");
                startNextRound();
                requestDiceType();
            }
            // If the message text matches a player name, request their pick list
            if (llListFindList(names, [msg]) != -1) {
                llMessageLinked(LINK_SET, 206, msg, id);
            }
        }
    }
}