// === Game Helper Functions Module ===

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

integer getDiceType(integer playerCount) {
    if (playerCount < 1) return 2;
    return (integer)(llPow(3.0, (float)(playerCount - 1)) * 2.0);
}

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

integer getPickerIndex(string name) {
    return llListFindList(pickQueue, [name]);
}

string serializeGameState() {
    return llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
}

showPickManager(string player, key id) {
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
            return;
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
