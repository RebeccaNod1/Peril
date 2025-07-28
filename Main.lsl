// === Main Peril Dice Controller (Refactored with Game Helpers Integration) ===

// --- Variables ---

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
integer MSG_SHOW_ROLL_DIALOG = 301;

integer MSG_GET_DICE_TYPE = 1001;
integer MSG_GET_PICKS_REQUIRED = 1002;
integer MSG_GET_PICKER_INDEX = 1003;
integer MSG_DICE_TYPE_RESULT = 1005;
integer MSG_SERIALIZE_GAME_STATE = 1004;
integer MSG_SYNC_PICKQUEUE = 2001;

integer TIMEOUT_SECONDS = 600;
integer timeoutTimer;

integer warning2min = 120;
integer warning5min = 300;
integer warning9min = 540;
integer lastWarning = 0;

key currentPicker;

// Forward game state to helpers when it changes
updateHelpers() {
    string serialized = llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
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
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        integer ch = -777000 + i;
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    players = names = lives = picksData = globalPickedNumbers = [];
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    llSay(syncChannel, "RESET");
    llOwnerSay("🔄 Game reset!");
    llSleep(0.2);
    llSetTimerEvent(0);
    updateHelpers();
}

startNextRound() {
    if (llGetListLength(names) == 1) {
        llSay(0, "🏆 " + llList2String(names, 0) + " is the last player standing and wins the game!");
        resetGame();
        return;
    }

    picksData = [];
    globalPickedNumbers = [];
    pickQueue = names;
    currentPickerIdx = 0;

    integer j;
    for (j = 0; j < llGetListLength(names); j++) {
        picksData += [llList2String(names, j) + "|"];
    }

    updateHelpers();
    // requestDiceType(); // Removed to avoid recursion loop
}

showNextPickerDialog() {
    string firstName = llList2String(pickQueue, currentPickerIdx);
    currentPicker = llList2Key(players, llListFindList(names, [firstName]));
    string dialogPayload = firstName + "|" + (string)diceType;
    llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, currentPicker);
    timeoutTimer = llGetUnixTime();
    lastWarning = 0;
    llSetTimerEvent(60.0);
}

integer roundStarted = FALSE;

default {
    state_entry() {
        llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
    }

    touch_start(integer total_number) {
        llOwnerSay("Touched by: " + (string)llDetectedKey(0));
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        if (toucher == llGetOwner()) {
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", toucher);
        } else if (idx != -1) {
            integer isStarter = (idx == 0);
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
        }
    }

    link_message(integer sender, integer num, string str, key id) {
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
        if (num == MSG_DICE_TYPE_RESULT) {
            if (!roundStarted) {
                roundStarted = TRUE;
                diceType = (integer)str;
                llOwnerSay("🎲 Dice type set to: " + str);
                showNextPickerDialog();
            }
        }
        else if (num == MSG_GET_PICKS_REQUIRED) {
            integer picksRequired = (integer)str;
            llOwnerSay("📌 Picks required: " + str);
        } else if (num == MSG_GET_PICKER_INDEX) {
            integer pickIndex = (integer)str;
            llOwnerSay("🔍 Picker index: " + str);
        } else if (num == MSG_SERIALIZE_GAME_STATE) {
            string serialized = str;
            llOwnerSay("🧾 Serialized game state: " + serialized);
        } else if (num == 204) {
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
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (channel == DIALOG_CHANNEL) {
            if (id == llGetOwner()) {
                if (msg == "Reset Game") {
                    resetGame();
                } else if (msg == "Start Game") {
                    startNextRound();
                    requestDiceType();
                } else if (msg == "Dump Players") {
                    llOwnerSay("📋 Players: " + llList2CSV(names));
                } else if (msg == "Manage Picks") {
                    llOwnerSay("📋 Fetching list of players for pick management...");
                    llMessageLinked(LINK_SET, 202, "REQUEST_PLAYER_LIST", llGetOwner());
                } else if (msg == "Add Test Player") {
                    string name = "TestBot" + (string)llGetUnixTime();
                    key fake = llGenerateKey();
                    players += [fake];
                    names += [name];
                    lives += [3];
                    picksData += [name + "|"];
                    llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, name + "|" + (string)fake, NULL_KEY);
                    llMessageLinked(LINK_SET, MSG_REZ_FLOAT, name, fake);
                    llSleep(0.2);
                    updateHelpers();
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", llGetOwner());
                }
            }
            if (llListFindList(names, [msg]) != -1) {
                llMessageLinked(LINK_SET, 206, msg, id);
            }
        }
    }
}
