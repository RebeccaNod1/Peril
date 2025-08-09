// === Controller Message Handler Helper Script ===
// Handles non-critical message processing for the Main Controller
// Reduces Main Controller size and improves modularity

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
                    llOwnerSay("➕ [Message Handler] Added " + pick + " to " + name);
                }
            } else if (action == "REMOVE_PICK") {
                integer idx = llListFindList(pickList, [pick]);
                if (idx != -1) {
                    pickList = llDeleteSubList(pickList, idx, idx);
                    llOwnerSay("➖ [Message Handler] Removed " + pick + " from " + name);
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
    llOwnerSay("🎲 [Message Handler] Sending dice type: " + (string)diceType);
    llMessageLinked(LINK_SET, 102, (string)diceType, requester); // MSG_ROLL_RESULT
}

// Handle leave game requests
handleLeaveGameRequest(string requestData) {
    list parts = llParseString2List(requestData, ["|"], []);
    if (llList2String(parts, 0) == "LEAVE_GAME") {
        string leavingName = llList2String(parts, 1);
        key leavingKey = (key)llList2String(parts, 2);
        integer idx = llListFindList(players, [leavingKey]);
        
        if (idx != -1) {
            // Remove player's float using the tracked channel
            integer ch = FLOATER_BASE_CHANNEL + idx;
            llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
            
            // Update local lists
            players = llDeleteSubList(players, idx, idx);
            names = llDeleteSubList(names, idx, idx);
            lives = llDeleteSubList(lives, idx, idx);
            picksData = llDeleteSubList(picksData, idx, idx);
            
            // Remove from ready list if present
            integer readyIdx = llListFindList(readyPlayers, [leavingName]);
            if (readyIdx != -1) {
                readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
            }
            
            llOwnerSay("👋 [Message Handler] " + leavingName + " left the game");
            
            // Notify Main Controller
            llMessageLinked(LINK_SET, MSG_LEAVE_GAME_REQUEST, requestData, NULL_KEY);
            
            // Check if game should end (less than 2 players)
            if (llGetListLength(names) == 1) {
                string winner = llList2String(names, 0);
                llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
                // Notify Main Controller of victory
                llMessageLinked(LINK_SET, 998, "GAME_WON|" + winner, NULL_KEY);
            }
        }
    }
}

// Synchronize game state from Main Controller
syncGameState(string stateData) {
    list parts = llParseString2List(stateData, ["~"], []);
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
        
        names = llCSV2List(llList2String(parts, 3));
    }
}

default {
    state_entry() {
        llOwnerSay("📨 [Message Handler] Helper script ready!");
        initializeChannels();
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle player list requests
        if (num == 202 && str == "REQUEST_PLAYER_LIST") {
            handlePlayerListRequest(id);
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
        
        // Handle leave game requests
        if (num == 107) {
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
            llOwnerSay("📨 [Message Handler] Reset complete");
        }
    }
}
