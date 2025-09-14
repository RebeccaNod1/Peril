// === Controller Message Handler Helper Script ===
// Handles non-critical message processing for the Main Controller
// Reduces Main Controller size and improves modularity

// Verbose logging control
integer VERBOSE_LOGGING = TRUE;  // Global flag for verbose debug logs
integer MSG_TOGGLE_VERBOSE_LOGS = 9998;  // Message to toggle verbose logging

// Message constants for communication with main controller
integer MSG_REQUEST_PLAYER_DATA = 8001;
integer MSG_REQUEST_PICK_DATA = 8002;
integer MSG_REQUEST_LIFE_DATA = 8003;
integer MSG_PICK_ACTION = 8004;
integer MSG_DICE_TYPE_REQUEST = 8005;
integer MSG_LEAVE_GAME_REQUEST = 8006;

// Game state data synchronized from Main Controller
list players = [];
list names = [];
list lives = [];
list picksData = [];
list readyPlayers = [];
integer diceType = 6;
string perilPlayer = "";  // Track who the peril player is to determine if game is active
integer roundStarted = FALSE;  // Track if the game round has started

// Message constants from Main Controller (synchronized)
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SYNC_PICKQUEUE = 2001;

// Channel constants for scoreboard updates
integer SCOREBOARD_CHANNEL_1;
integer SCOREBOARD_CHANNEL_2;
integer FLOATER_BASE_CHANNEL;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_UPDATE_FLOAT = 103;

// Dynamic channel calculation (matches Main Controller)
integer CHANNEL_BASE = -77000;

integer calculateChannel(integer offset) {
    // Use BOTH owner's key AND object's key to make channels unique per game instance
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

initializeChannels() {
    SCOREBOARD_CHANNEL_1 = calculateChannel(6);   // ~-77600 range
    SCOREBOARD_CHANNEL_2 = calculateChannel(7);   // ~-77700 range  
    FLOATER_BASE_CHANNEL = calculateChannel(9);   // ~-77900 range
}

// Handle player list requests
handlePlayerListRequest(key requester) {
    string namesCSV = llList2CSV(names);
    llMessageLinked(LINK_SET, 203, namesCSV, requester);
}

// Handle pick data requests
handlePickDataRequest(string targetName, key requester) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string rawEntry = llList2String(picksData, i);
        list parts = llParseString2List(rawEntry, ["|"], []);
        if (llList2String(parts, 0) == targetName) {
            llMessageLinked(LINK_SET, 205, targetName + "|" + llList2String(parts, 1), requester);
            return;
        }
    }
    llMessageLinked(LINK_SET, 205, targetName + "|", requester);
}

// Handle life data requests
handleLifeDataRequest(string playerName, key requester) {
    integer idx = llListFindList(names, [playerName]);
    if (idx != -1) {
        string lifeVal = llList2String(lives, idx);
        llMessageLinked(LINK_SET, 208, playerName + "|" + lifeVal, requester);
    }
}

// Handle pick actions (ADD_PICK/REMOVE_PICK)
handlePickAction(string actionData) {
    list parts = llParseString2List(actionData, ["~"], []);
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
                    if (VERBOSE_LOGGING) {
                        llOwnerSay("➕ [Message Handler] Added " + pick + " to " + name);
                    }
                }
            } else if (action == "REMOVE_PICK") {
                integer idx = llListFindList(pickList, [pick]);
                if (idx != -1) {
                    pickList = llDeleteSubList(pickList, idx, idx);
                    if (VERBOSE_LOGGING) {
                        llOwnerSay("➖ [Message Handler] Removed " + pick + " from " + name);
                    }
                }
            }
            
            // Update local picks data
            picksData = llListReplaceList(picksData, [name + "|" + llList2CSV(pickList)], i, i);
            
            // Notify Main Controller of the change
            llMessageLinked(LINK_SET, 204, actionData, NULL_KEY);
            return;
        }
    }
}

// Handle dice type requests
handleDiceTypeRequest(key requester) {
    if (VERBOSE_LOGGING) {
        llOwnerSay("🎲 [Message Handler] Sending dice type: " + (string)diceType);
    }
    llMessageLinked(LINK_SET, 102, (string)diceType, requester); // MSG_ROLL_RESULT
}

// Handle leave game and kick player requests
handleLeaveGameRequest(string requestData) {
    list parts = llParseString2List(requestData, ["|"], []);
    string action = llList2String(parts, 0);
    if (action == "LEAVE_GAME" || action == "KICK_PLAYER") {
        string leavingName = llList2String(parts, 1);
        key requestKey = (key)llList2String(parts, 2); // This is the requester's key, not the player's key
        integer idx = llListFindList(names, [leavingName]); // Find by name instead of key
        
        if (idx != -1) {
            // Update local lists FIRST to prevent race conditions
            players = llDeleteSubList(players, idx, idx);
            names = llDeleteSubList(names, idx, idx);
            lives = llDeleteSubList(lives, idx, idx);
            picksData = llDeleteSubList(picksData, idx, idx);
            
            // THEN send floater cleanup using the previously calculated channel
            // Note: We DON'T send MSG_CLEANUP_FLOAT here anymore to avoid double-cleanup
            // The Main Controller will handle floater cleanup after list synchronization
            if (VERBOSE_LOGGING) {
                llOwnerSay("📝 [Message Handler] Updated local lists for " + leavingName + ", deferring floater cleanup to Main Controller");
            }
            
            // Remove from ready list if present
            integer readyIdx = llListFindList(readyPlayers, [leavingName]);
            if (readyIdx != -1) {
                readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
            }
            
            // Different messages for voluntary leave vs kick
            if (action == "LEAVE_GAME") {
                llOwnerSay("👋 [Message Handler] " + leavingName + " left the game");
                llSay(0, "👋 " + leavingName + " has left the deadly game! 👋");
            } else if (action == "KICK_PLAYER") {
                llOwnerSay("👢 [Message Handler] " + leavingName + " was kicked from the game");
                llSay(0, "👢 " + leavingName + " has been kicked from the deadly game by the owner! 👢");
            }
            
            // Notify Main Controller of the removal
            llMessageLinked(LINK_SET, MSG_LEAVE_GAME_REQUEST, requestData, NULL_KEY);
            
            // Check if game should end (0 players = reset, 1 player = victory)
            if (llGetListLength(names) == 0) {
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔄 [Message Handler] All players left - game will reset");
                }
                // Main Controller will handle the reset
            } else if (llGetListLength(names) == 1 && roundStarted && perilPlayer != "" && perilPlayer != "NONE") {
                // Only declare victory if the game has actually started (round active and peril player assigned)
                string winner = llList2String(names, 0);
                llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
                // Notify Main Controller of victory
                llMessageLinked(LINK_SET, 998, "GAME_WON|" + winner, NULL_KEY);
            } else if (llGetListLength(names) == 1) {
                // Game not started yet, just inform but don't declare victory
                string remainingPlayer = llList2String(names, 0);
                if (VERBOSE_LOGGING) {
                    llOwnerSay("📝 [Message Handler] Only " + remainingPlayer + " remains, but game hasn't started yet");
                }
            }
        }
    }
}

// Synchronize game state from Main Controller
syncGameState(string stateData) {
    list parts = llParseString2List(stateData, ["~"], []);
    
    // Handle special RESET sync message
    if (llGetListLength(parts) >= 5 && llList2String(parts, 0) == "RESET") {
        if (VERBOSE_LOGGING) {
            llOwnerSay("🔄 [Message Handler] Received reset sync - clearing all state");
        }
        // Clear all state during reset
        players = [];
        names = [];
        lives = [];
        picksData = [];
        readyPlayers = [];
        perilPlayer = "";
        roundStarted = FALSE;
        return;
    }
    
    if (llGetListLength(parts) >= 4) {
        lives = llCSV2List(llList2String(parts, 0));
        
        // Decode picks data
        string encodedPicksDataStr = llList2String(parts, 1);
        picksData = [];
        if (encodedPicksDataStr != "" && encodedPicksDataStr != "EMPTY") {
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
                    picksData += [playerName + "|" + picks];
                } else {
                    picksData += [entry];
                }
            }
        }
        
        // Track peril player and round state for victory detection
        string receivedPeril = llList2String(parts, 2);
        if (receivedPeril == "NONE" || receivedPeril == "") {
            perilPlayer = "";
            roundStarted = FALSE;
        } else {
            perilPlayer = receivedPeril;
            roundStarted = TRUE;  // Game is active if there's a peril player
        }
        
        names = llCSV2List(llList2String(parts, 3));
        
        // SAFETY: Validate peril player exists in current names list AFTER updating names
        if (perilPlayer != "" && perilPlayer != "NONE") {
            integer perilIdx = llListFindList(names, [perilPlayer]);
            if (perilIdx == -1) {
                // Only warn if we actually have players - during reset this is expected
                if (llGetListLength(names) > 0 && VERBOSE_LOGGING) {
                    llOwnerSay("⚠️ [Message Handler] WARNING: Peril player '" + perilPlayer + "' not found in names list - clearing peril status");
                }
                perilPlayer = "";
                roundStarted = FALSE;
            }
        }
    }
}

default {
    state_entry() {
        llOwnerSay("📨 [Message Handler] Helper script ready!");
        initializeChannels();
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle
        if (num == MSG_TOGGLE_VERBOSE_LOGS) {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔊 [Message Handler] Verbose logging ENABLED");
            } else {
                llOwnerSay("🔊 [Message Handler] Verbose logging DISABLED");
            }
            return;
        }
        
        // Handle player list requests (for pick management only)
        if (num == 202 && str == "REQUEST_PLAYER_LIST") {
            handlePlayerListRequest(id);
            return;
        }
        
        // Handle kick player list requests (separate message ID to avoid conflicts)
        if (num == 8009 && str == "REQUEST_PLAYER_LIST_KICK") {
            // Send back kick-specific message ID to avoid conflict with pick management
            string namesCSV = llList2CSV(names);
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔍 [Message Handler] Received request: '" + str + "'");
                llOwnerSay("🔍 [Message Handler] Names list: " + llDumpList2String(names, ", "));
                llOwnerSay("🔍 [Message Handler] Sending kick player list: '" + namesCSV + "'");
            }
            llMessageLinked(LINK_SET, 8009, namesCSV, id);
            return;
        }
        
        // Handle pick data requests  
        if (num == 206) {
            handlePickDataRequest(str, id);
            return;
        }
        
        // Handle life data requests
        if (num == 208) {
            handleLifeDataRequest(str, id);
            return;
        }
        
        // Handle pick actions
        if (num == 204) {
            handlePickAction(str);
            return;
        }
        
        // Handle dice type requests
        if (num == 996) {
            if (str == "GET_DICE_TYPE") {
                handleDiceTypeRequest(id);
            }
            return;
        }
        
        // Handle leave game requests (use proper message ID, not 107 which is for sync)
        if (num == 8007) { // Different from MSG_SYNC_GAME_STATE = 107
            handleLeaveGameRequest(str);
            return;
        }
        
        // Sync game state from Main Controller
        if (num == MSG_SYNC_GAME_STATE) {
            syncGameState(str);
            return;
        }
        
        // Sync player list for reference
        if (num == MSG_SYNC_PICKQUEUE) {
            // Update players list reference (if needed for future functionality)
            return;
        }
        
        // Handle full reset
        if (num == -99999 && str == "FULL_RESET") {
            players = [];
            names = [];
            lives = [];
            picksData = [];
            readyPlayers = [];
            diceType = 6;
            perilPlayer = "";
            roundStarted = FALSE;
            llOwnerSay("📨 [Message Handler] Reset complete");
        }
    }
}
