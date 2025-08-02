// === Game Helper Functions Module (Max 10 players) ===
// This version chooses a dice size based on the number of players,
// ensuring at least three numbers are available per player.

integer MSG_GET_DICE_TYPE = 1001;
integer MSG_DICE_TYPE_RESULT = 1005;
integer MSG_GET_PICKS_REQUIRED = 1002;
integer MSG_GET_PICKER_INDEX = 1003;
integer MSG_SERIALIZE_GAME_STATE = 1004;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SYNC_PICKQUEUE = 2001;

list lives;
list picksData;
string perilPlayer;
list names;
list pickQueue;

// List of supported dice sizes; ensure the last entry can accommodate 10 players × 3 picks = 30
list STANDARD_DICE = [6, 12, 20, 30];

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
    integer idx = llListFindList(names, [name]);
    if (idx == -1) {
        integer i;
        for (i = 0; i < llGetListLength(names); i++) {
            string testName = llList2String(names, i);
            if (llSubStringIndex(testName, name) != -1) {
                idx = i;
                i = llGetListLength(names);
            }
        }
    }
    if (idx == -1) return 0;
    integer lifeCount = (integer)llList2String(lives, idx);
    if (lifeCount >= 3) return 1;
    if (lifeCount == 2) return 2;
    return 3;
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

    integer idx = llListFindList(names, [searchName]);
    if (idx == -1) {
        integer i;
        for (i = 0; i < llGetListLength(names); i++) {
            string testName = llList2String(names, i);
            if (llSubStringIndex(testName, searchName) != -1) {
                idx = i;
                llOwnerSay("✅ Matched pick list for: " + testName);
                i = llGetListLength(names);
            }
        }
        if (idx == -1) {
            llOwnerSay("⚠️ Could not find player: " + player);
            return 0;
        }
    }

    integer maxPicks = getPicksRequiredFromName(llList2String(names, idx));

    string currentData = llList2String(picksData, idx);
    list parts = llParseString2List(currentData, ["|"], []);
    list currentPicks = [];
    if (llGetListLength(parts) > 1) {
        currentPicks = llParseString2List(llList2String(parts, 1), [","], []);
    }

    list buttons = [];
    integer i;
    for (i = 1; i <= 6; i++) {
        string numStr = (string)i;
        if (llListFindList(currentPicks, [numStr]) != -1) {
            buttons += ["❌ " + numStr];
        } else if (llGetListLength(currentPicks) < maxPicks) {
            buttons += ["➕ " + numStr];
        }
    }

    llOwnerSay("🛠 Showing pick dialog to: " + (string)id);
    llDialog(id, "🛠 Managing picks for: " + searchName + "\nCurrent: " + llList2CSV(currentPicks), buttons, -88888);

    // Return dummy value since LSL does not have a void return type
    return 0;
}

default {
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            lives = llCSV2List(llList2String(parts, 0));
            picksData = llCSV2List(llList2String(parts, 1));
            perilPlayer = llList2String(parts, 2);
            names = llCSV2List(llList2String(parts, 3));
        }
        else if (num == MSG_SYNC_PICKQUEUE) {
            pickQueue = llCSV2List(str);
        }
        else if (num == MSG_GET_DICE_TYPE) {
            integer playerCount = (integer)str;
            llOwnerSay("📊 playerCount received: " + (string)playerCount);
            integer result = getDiceType(playerCount);
            llMessageLinked(LINK_THIS, MSG_DICE_TYPE_RESULT, (string)result, NULL_KEY);
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
        else if (num == 206) {
            llOwnerSay("📨 MSG 206 received for: " + str + " from: " + (string)id);
            showPickManager(str, id);
        }
    }
}
