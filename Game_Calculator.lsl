#include "peril/Peril_Constants.lsl"

// === Game Calculator Module (Max 10 players) ===
// Calculates dice types, pick requirements, and other game mechanics
// This version chooses a dice size based on the number of players,
// ensuring at least three numbers are available per player.


list lives;
list picksData;
string perilPlayer;
list names;
list pickQueue;

// List of supported dice sizes; ensure the last entry can accommodate 10 players × 3 picks = 30
#define STANDARD_DICE [6, 12, 20, 30]

// Determine which die to use based on player count.
// Each player should have at least 3 numbers available to choose from.
integer getDiceType(integer playerCount) {
    integer minimumSides = playerCount * 3;
    integer i;
    for (i = 0; i < llGetListLength(STANDARD_DICE); i++) {
        integer sides = llList2Integer(STANDARD_DICE, i);
        if (sides >= minimumSides) {
            return sides;
        }
    }
    // If no predefined die has enough sides, return the largest supported die (d30)
    return llList2Integer(STANDARD_DICE, llGetListLength(STANDARD_DICE) - 1);
}

// Determine how many picks a player should make based on the peril player's lives
integer getPicksRequiredFromName(string name) {
    integer nameIdx = llListFindList(names, [name]);
    if (nameIdx == -1) {
        integer j;
        for (j = 0; j < llGetListLength(names); j++) {
            string checkName = llList2String(names, j);
            if (llSubStringIndex(checkName, name) != -1) {
                nameIdx = j;
                j = llGetListLength(names);
            }
        }
    }
    if (nameIdx == -1) return 0;
    integer lifeCount = (integer)llList2String(lives, nameIdx);
    // Pick count = 4 - peril player's lives (3 lives=1 pick, 2 lives=2 picks, 1 life=3 picks)
    return 4 - lifeCount;
}

// Find the index of a player in the pickQueue by name
integer getPickerIndex(string name) {
    return llListFindList(pickQueue, [name]);
}

// Serialize the current game state for syncing with other scripts
string serializeGameState() {
    return llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
}

// Show a pick management dialog for the owner.
// LSL does not support a void return type, so this returns an integer which is ignored.
integer showPickManager(string player, key id) {
    string searchName = player;
    if (llSubStringIndex(searchName, "~") != -1) {
        list parts = llParseString2List(searchName, ["~"], []);
        searchName = llList2String(parts, 1);
    }

    integer searchIdx = llListFindList(names, [searchName]);
    if (searchIdx == -1) {
        integer k;
        for (k = 0; k < llGetListLength(names); k++) {
            string matchName = llList2String(names, k);
            if (llSubStringIndex(matchName, searchName) != -1) {
                searchIdx = k;
                k = llGetListLength(names);
            }
        }
        if (searchIdx == -1) {
            return 0;
        }
    }

    integer maxPicks = getPicksRequiredFromName(llList2String(names, searchIdx));

    string currentData = llList2String(picksData, searchIdx);
    list dataParts = llParseString2List(currentData, ["|"], []);
    list currentPicks = [];
    if (llGetListLength(dataParts) > 1) {
        currentPicks = llParseString2List(llList2String(dataParts, 1), [","], []);
    }

    list buttons = [];
    integer buttonIdx;
    for (buttonIdx = 1; buttonIdx <= 6; buttonIdx++) {
        string numStr = (string)buttonIdx;
        if (llListFindList(currentPicks, [numStr]) != -1) {
            buttons += ["❌ " + numStr];
        } else if (llGetListLength(currentPicks) < maxPicks) {
            buttons += ["➕ " + numStr];
        }
    }

    return 0;
}

default {
    state_entry() {
        REPORT_MEMORY();
        
        // Initialize/reset all state variables
        lives = [];
        picksData = [];
        perilPlayer = "";
        names = [];
        pickQueue = [];
        dbg("🧮 [Calculator] Game Calculator ready!");
    }
    
    on_rez(integer start_param) {
        REPORT_MEMORY();
        
        // Reset all state variables on rez
        lives = [];
        picksData = [];
        perilPlayer = "";
        names = [];
        pickQueue = [];
    }
    
    link_message(integer sender, integer num, string str, key id) {
        
        // Handle full reset from main controller
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            // Reset helper state
            lives = [];
            picksData = [];
            perilPlayer = "";
            names = [];
            pickQueue = [];
            dbg("🧮 [Calculator] Calculator Module reset!");
            return;
        }
        
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            
            // Handle special RESET sync message
            if (llGetListLength(parts) >= 5 && llList2String(parts, 0) == "RESET") {
                dbg("🧮 [Calculator] 🔄 Received reset sync - ignoring during reset");
                return;
            }
            
            if (llGetListLength(parts) < 4) {
                dbg("🧮 [Calculator] ⚠️ Incomplete sync message received, parts: " + (string)llGetListLength(parts));
                dbg("🧮 [Calculator] ⚠️ Incomplete game state received.");
                return;
            }
            lives = llCSV2List(llList2String(parts, 0));
            // Use ^ delimiter for picksData to avoid comma conflicts
            string picksDataStr = llList2String(parts, 1);
            if (picksDataStr == "" || picksDataStr == "EMPTY") {
                picksData = [];
            } else {
                picksData = llParseString2List(picksDataStr, ["^"], []);
            }
            string receivedPeril = llList2String(parts, 2);
            if (receivedPeril == "NONE") {
                perilPlayer = "";
            } else {
                perilPlayer = receivedPeril;
            }
            names = llCSV2List(llList2String(parts, 3));
            
        }
        else if (num == MSG_SYNC_PICKQUEUE) {
            pickQueue = llCSV2List(str);
        }
        else if (num == MSG_GET_DICE_TYPE) {
            integer playerCount = (integer)str;
            dbg("🧮 [Calculator] 📈 Calculating dice type for " + (string)playerCount + " players");
            integer result = getDiceType(playerCount);
            // Send result only to the requester (sender), not broadcast to everyone
            llMessageLinked(sender, MSG_DICE_TYPE_RESULT, (string)result, NULL_KEY);
        }
        else if (num == MSG_GET_PICKS_REQUIRED) {
            integer result = getPicksRequiredFromName(str);
            llMessageLinked(LINK_THIS, MSG_GET_PICKS_REQUIRED, (string)result, NULL_KEY);
        }
        else if (num == MSG_GET_PICKER_INDEX) {
            integer result = getPickerIndex(str);
            llMessageLinked(LINK_THIS, MSG_GET_PICKER_INDEX, (string)result, NULL_KEY);
        }
        else if (num == MSG_SERIALIZE_GAME_STATE) {
            llMessageLinked(LINK_THIS, MSG_SERIALIZE_GAME_STATE, serializeGameState(), NULL_KEY);
        }
        else if (num == MSG_OWNER_PICK_MANAGER) {
            dbg("🧮 [Calculator] 📨 MSG 206 received for: " + str + " from: " + (string)id);
            showPickManager(str, id);
        }
    }
}
