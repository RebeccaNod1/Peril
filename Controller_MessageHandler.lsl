#include "peril/Peril_Constants.lsl"

// === Controller Message Handler Helper Script ===
// Handles non-critical message processing for the Main Controller
// Reduces Main Controller size and improves modularity

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
#define MSG_SYNC_PICKQUEUE 2001

// Channel constants for scoreboard updates
integer SCOREBOARD_CHANNEL_1;
integer SCOREBOARD_CHANNEL_2;
integer FLOATER_BASE_CHANNEL;

// Dynamic channel calculation (matches Main Controller)
#define CHANNEL_BASE -77000

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
    llMessageLinked(LINK_SET, MSG_PLAYER_LIST_PICK_RESULT, namesCSV, requester);
}

// Handle pick data requests
handlePickDataRequest(string targetName, key requester) {
    integer j;
    for (j = 0; j < llGetListLength(picksData); j++) {
        string rawEntry = llList2String(picksData, j);
        list pickParts = llParseString2List(rawEntry, ["|"], []);
        if (llList2String(pickParts, 0) == targetName) {
            llMessageLinked(LINK_SET, MSG_PICK_LIST_RESULT, targetName + "|" + llList2String(pickParts, 1), requester);
            return;
        }
    }
    llMessageLinked(LINK_SET, MSG_PICK_LIST_RESULT, targetName + "|", requester);
}

// Handle life data requests
handleLifeDataRequest(string playerName, key requester) {
    integer lifeIdx = llListFindList(names, [playerName]);
    if (lifeIdx != -1) {
        string lifeVal = llList2String(lives, lifeIdx);
        llMessageLinked(LINK_SET, MSG_LIFE_LOOKUP_RESULT, playerName + "|" + lifeVal, requester);
    }
}

// Handle pick actions (ADD_PICK/REMOVE_PICK)
handlePickAction(string actionData) {
    list actionParts = llParseString2List(actionData, ["~"], []);
    string pickAction = llList2String(actionParts, 0);
    list args = llParseString2List(llList2String(actionParts, 1), ["|"], []);
    string name = llList2String(args, 0);
    string pick = llList2String(args, 1);
    
    integer k;
    for (k = 0; k < llGetListLength(picksData); k++) {
        string entry = llList2String(picksData, k);
        list pdParts = llParseString2List(entry, ["|"], []);
        if (llList2String(pdParts, 0) == name) {
            list pickList = [];
            string rawPicks = llList2String(pdParts, 1);
            if (rawPicks != "") {
                pickList = llParseString2List(rawPicks, [","], []);
            }
            
            if (pickAction == "ADD_PICK") {
                if (llListFindList(pickList, [pick]) == -1) {
                    pickList += [pick];
                }
            } else if (pickAction == "REMOVE_PICK") {
                integer removeIdx = llListFindList(pickList, [pick]);
                if (removeIdx != -1) {
                    pickList = llDeleteSubList(pickList, removeIdx, removeIdx);
                }
            }
            
            // Update local picks data
            picksData = llListReplaceList(picksData, [name + "|" + llList2CSV(pickList)], k, k);
            
            // Notify Main Controller of the change
            llMessageLinked(LINK_SET, MSG_PICK_ACTION, actionData, NULL_KEY);
            return;
        }
    }
}

// Handle dice type requests
handleDiceTypeRequest(key requester) {
    llMessageLinked(LINK_SET, MSG_DICE_TYPE_RESULT, (string)diceType, requester); 
}

// Handle leave game and kick player requests
handleLeaveGameRequest(string requestData) {
    list leaveParts = llParseString2List(requestData, ["|"], []);
    string leaveAction = llList2String(leaveParts, 0);
    if (leaveAction == "LEAVE_GAME" || leaveAction == "KICK_PLAYER") {
        string leavingName = llList2String(leaveParts, 1);
        key requestKey = (key)llList2String(leaveParts, 2); // This is the requester's key, not the player's key
        integer leaveIdx = llListFindList(names, [leavingName]); // Find by name instead of key
        
        if (leaveIdx != -1) {
            // Update local lists FIRST to prevent race conditions
            players = llDeleteSubList(players, leaveIdx, leaveIdx);
            names = llDeleteSubList(names, leaveIdx, leaveIdx);
            lives = llDeleteSubList(lives, leaveIdx, leaveIdx);
            picksData = llDeleteSubList(picksData, leaveIdx, leaveIdx);
            
            // Remove from ready list if present
            integer readyIdx = llListFindList(readyPlayers, [leavingName]);
            if (readyIdx != -1) {
                readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
            }
            
            // Different messages for voluntary leave vs kick
            if (leaveAction == "LEAVE_GAME") {
                llSay(0, "👋 " + leavingName + " has left the deadly game! 👋");
            } else if (leaveAction == "KICK_PLAYER") {
                llSay(0, "👢 " + leavingName + " has been kicked from the deadly game by the owner! 👢");
            }
            
            // Notify Main Controller of the removal
            llMessageLinked(LINK_SET, MSG_LEAVE_GAME_REQUEST, requestData, NULL_KEY);
            
            // Check if game should end (0 players = reset, 1 player = victory)
            if (llGetListLength(names) == 0) {
                // Main Controller will handle the reset
            } else if (llGetListLength(names) == 1 && roundStarted && perilPlayer != "" && perilPlayer != "NONE") {
                // Only declare victory if the game has actually started (round active and peril player assigned)
                string winner = llList2String(names, 0);
                llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
                // Notify Main Controller of victory
                llMessageLinked(LINK_SET, MSG_CONTINUE_GAME, "GAME_WON|" + winner, NULL_KEY);
            } else if (llGetListLength(names) == 1) {
                // Game not started yet, just inform but don't declare victory
                string remainingPlayer = llList2String(names, 0);
            }
        }
    }
}

// Synchronize game state from Main Controller
syncGameState(string stateData) {
    list syncParts = llParseString2List(stateData, ["~"], []);
    
    // Handle special RESET sync message
    if (llGetListLength(syncParts) >= 5 && llList2String(syncParts, 0) == "RESET") {
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
    
    if (llGetListLength(syncParts) >= 4) {
        lives = llCSV2List(llList2String(syncParts, 0));
        
        // Decode picks data
        string encodedPicksDataStr = llList2String(syncParts, 1);
        picksData = [];
        if (encodedPicksDataStr != "" && encodedPicksDataStr != "EMPTY") {
            list encodedEntries = llParseString2List(encodedPicksDataStr, ["^"], []);
            integer m;
            for (m = 0; m < llGetListLength(encodedEntries); m++) {
                string syncEntry = llList2String(encodedEntries, m);
                list entryParts = llParseString2List(syncEntry, ["|"], []);
                if (llGetListLength(entryParts) >= 2) {
                    string syncPlayerName = llList2String(entryParts, 0);
                    string picks = llList2String(entryParts, 1);
                    // Convert semicolons back to commas
                    picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                    picksData += [syncPlayerName + "|" + picks];
                } else {
                    picksData += [syncEntry];
                }
            }
        }
        
        // Track peril player and round state for victory detection
        string receivedPeril = llList2String(syncParts, 2);
        if (receivedPeril == "NONE" || receivedPeril == "") {
            perilPlayer = "";
            roundStarted = FALSE;
        } else {
            perilPlayer = receivedPeril;
            roundStarted = TRUE;  // Game is active if there's a peril player
        }
        
        names = llCSV2List(llList2String(syncParts, 3));
        
        // SAFETY: Validate peril player exists in current names list AFTER updating names
        if (perilPlayer != "" && perilPlayer != "NONE") {
            integer perilIdx = llListFindList(names, [perilPlayer]);
            if (perilIdx == -1) {
                perilPlayer = "";
                roundStarted = FALSE;
            }
        }
    }
}

// Memory-efficient message handling functions

// Handle owner messages
handleOwnerMessage(string messageData) {
    // Format: "simple_message" or "type|param1|param2"
    list ownerParts = llParseString2List(messageData, ["|"], []);
    if (llGetListLength(ownerParts) == 1) {
        // Simple message
    } else {
        // Formatted message
        string ownerMsgType = llList2String(ownerParts, 0);
        if (ownerMsgType == "JOIN") {
            string ownerPlayerName = llList2String(ownerParts, 1);
            llSay(0, "🔔 Added player: " + ownerPlayerName);
        } else if (ownerMsgType == "LEAVE") {
            string leavePlayerName = llList2String(ownerParts, 1);
        } else if (ownerMsgType == "ERROR") {
            string error = llList2String(ownerParts, 1);
        } else if (ownerMsgType == "SUCCESS") {
            string msg = llList2String(ownerParts, 1);
        } else if (ownerMsgType == "DEBUG") {
            string component = llList2String(ownerParts, 1);
            string msg = llList2String(ownerParts, 2);
        }
    }
}

// Handle public messages
handlePublicMessage(string messageData) {
    list publicParts = llParseString2List(messageData, ["|"], []);
    if (llGetListLength(publicParts) == 1) {
        llSay(0, messageData);
    } else {
        string publicMsgType = llList2String(publicParts, 0);
        if (publicMsgType == "GAME") {
            string stateVal = llList2String(publicParts, 1);
            llSay(0, "🎮 " + stateVal);
        }
    }
}

// Handle region messages to specific players
handleRegionMessage(string messageData) {
    // Format: "player_key|message" or "player_key|type|param1|param2"
    list regionParts = llParseString2List(messageData, ["|"], []);
    if (llGetListLength(regionParts) >= 2) {
        key regionPlayerKey = llList2Key(regionParts, 0);
        string message = llList2String(regionParts, 1);
        
        if (llGetListLength(regionParts) == 2) {
            // Simple message - use llSay since we can't use llRegionSayTo on channel 0
            llSay(0, "[To " + llKey2Name(regionPlayerKey) + "] " + message);
        } else {
            // Formatted message
            string regionMsgType = llList2String(regionParts, 1);
            if (regionMsgType == "WELCOME") {
                string msg = llList2String(regionParts, 2);
                llSay(0, "[To " + llKey2Name(regionPlayerKey) + "] 🔄 " + msg);
            }
        }
    }
}

// Handle dialog requests
handleDialogRequest(string dialogData) {
    // Format: "player_key|dialog_text|option1,option2,option3|channel"
    list dialogParts = llParseString2List(dialogData, ["|"], []);
    if (llGetListLength(dialogParts) >= 4) {
        key dialogPlayerKey = llList2Key(dialogParts, 0);
        string dialogText = llList2String(dialogParts, 1);
        string optionsStr = llList2String(dialogParts, 2);
        integer channel = llList2Integer(dialogParts, 3);
        
        list options = llParseString2List(optionsStr, [","], []);
        llDialog(dialogPlayerKey, dialogText, options, channel);
    }
}

default {
    state_entry() {
        REPORT_MEMORY();
        
        initializeChannels();
    }
    
    on_rez(integer start_param) {
        REPORT_MEMORY();
        initializeChannels();
        // Reset local state if needed (synced from Main)
        players = [];
        names = [];
        lives = [];
        picksData = [];
        readyPlayers = [];
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle player list requests (for pick management only)
        if (num == MSG_REQUEST_PLAYER_LIST_PICK && str == "REQUEST_PLAYER_LIST") {

            handlePlayerListRequest(id);
            return;
        }
        
        // Handle kick player list requests (separate message ID to avoid conflicts)
        if (num == MSG_REQUEST_PLAYER_LIST_KICK && str == "REQUEST_PLAYER_LIST_KICK") {
            // Send back kick-specific message ID to avoid conflict with pick management
            string namesCSV = llList2CSV(names);
            dbg("🧠 [Controller Message Handler] 🔍 Received request: '" + str + "'");
            dbg("🧠 [Controller Message Handler] 🔍 Names list: " + llDumpList2String(names, ", "));
            dbg("🧠 [Controller Message Handler] 🔍 Sending kick player list: '" + namesCSV + "'");
            llMessageLinked(LINK_SET, MSG_REQUEST_PLAYER_LIST_KICK, namesCSV, id);
            return;
        }
        
        // Handle pick data requests  
        if (num == MSG_OWNER_PICK_MANAGER) {
            handlePickDataRequest(str, id);
            return;
        }
        
        // Handle life data requests
        if (num == MSG_LIFE_LOOKUP_REQUEST) {
            handleLifeDataRequest(str, id);
            return;
        }
        
        // Handle pick actions
        if (num == MSG_PICK_ACTION) {
            handlePickAction(str);
            return;
        }
        
        // Handle dice type requests
        if (num == MSG_GET_DICE_TYPE) {
            if (str == "GET_DICE_TYPE") {
                handleDiceTypeRequest(id);
            }
            return;
        }
        
        // Handle leave game requests (use proper message ID, not 107 which is for sync)
        if (num == MSG_LEAVE_GAME) { // Different from MSG_SYNC_GAME_STATE = 107
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
        
        // Handle memory-heavy message operations
        if (num == MSG_OWNER_MESSAGE) {
            handleOwnerMessage(str);
            return;
        }
        
        if (num == MSG_PUBLIC_MESSAGE) {
            handlePublicMessage(str);
            return;
        }
        
        if (num == MSG_REGION_MESSAGE) {
            handleRegionMessage(str);
            return;
        }
        
        if (num == MSG_DIALOG_REQUEST) {
            handleDialogRequest(str);
            return;
        }
        
        // Handle full reset
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            players = [];
            names = [];
            lives = [];
            picksData = [];
            readyPlayers = [];
            diceType = 6;
            perilPlayer = "";
            roundStarted = FALSE;
            dbg("🧠 [Controller Message Handler] Reset complete");
        }
    }
}
