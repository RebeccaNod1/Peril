// === Dialog Handler Module ===
integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_SYNC_GAME_STATE = 107;

integer numberPickChannel = -77888;
integer diceType = 6;
integer maxPerPage = 12;
integer page = 0;

integer getPicksRequired(integer lifeCount) {
    if (lifeCount == 3) return 1;
    if (lifeCount == 2) return 2;
    return 3;
}

list globalPickedNumbers = [];
list names = [];
list lives = [];
list players = [];
list picksData = [];
string perilPlayer = "";
list pickQueue = [];
integer currentPickerIdx = 0;

list getPicksFor(string nameInput) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        if (llSubStringIndex(entry, nameInput + "|") == 0) {
            list parts = llParseString2List(entry, ["|"], []);
            return llParseString2List(llList2String(parts, 1), [","], []);
        }
    }
    return [];
}

showPickDialog(key id, string name) {
    list picks = getPicksFor(name);
    integer picksRequired = getPicksRequired(llList2Integer(lives, llListFindList(names, [name])));

    list options = [];
    integer start = page * maxPerPage + 1;
    integer endNum;
    if ((start + maxPerPage - 1) <= diceType) {
        endNum = start + maxPerPage - 1;
    } else {
        endNum = diceType;
    }

    integer i;
    for (i = start; i <= endNum; i++) {
        string s = (string)i;
        if (llListFindList(globalPickedNumbers, [s]) == -1) options += [s];
    }

    list buttons = [];
    if (page > 0) buttons += ["« Prev"];
    buttons += options;
    if ((page + 1) * maxPerPage < diceType) buttons += ["Next »"];

    llDialog(id, "Pick " + (string)picksRequired + " unique number(s):", buttons, numberPickChannel);
}

default {
    state_entry() {
        llListen(numberPickChannel, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SHOW_DIALOG) {
            page = 0;
            showPickDialog(id, str);
        }
    }

    listen(integer channel, string name, key id, string msg) {
    if (channel == numberPickChannel) {
        string currentName = llList2String(pickQueue, currentPickerIdx);
        integer playerIdx = llListFindList(names, [currentName]);
        if (playerIdx == -1) return;
        key playerKey = llList2Key(players, playerIdx);
        if (id != playerKey) return;

        if (msg == "Next »") {
            page++;
            showPickDialog(id, currentName);
        } else if (msg == "« Prev") {
            if (page > 0) page--;
            showPickDialog(id, currentName);
        } else {
            integer idx = llListFindList(names, [currentName]);
            integer perilIdx = llListFindList(names, [perilPlayer]);
            integer limit = getPicksRequired(llList2Integer(lives, perilIdx));
            list picks = getPicksFor(currentName);

            if (llListFindList(picks, [msg]) != -1 || llGetListLength(picks) >= limit) return;

            picks += [msg];
            picksData = llListReplaceList(picksData, [currentName + "|" + llDumpList2String(picks, ",")], idx, idx);
            globalPickedNumbers += [msg];

            string sync = llList2CSV(lives) + "~" + llDumpList2String(picksData, "~") + "~" + perilPlayer + "~" + llList2CSV(names);
            llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, sync, NULL_KEY);
            llSleep(0.2);

            if (llGetListLength(picks) >= limit) {
                currentPickerIdx++;
            }
            page = 0;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                showPickDialog(llList2Key(players, llListFindList(names, [llList2String(pickQueue, currentPickerIdx)])), llList2String(pickQueue, currentPickerIdx));
            }
        }
    }
}

}
