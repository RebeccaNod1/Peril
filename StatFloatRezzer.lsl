// === Float Rezzer Module ===

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_SYNC_GAME_STATE = 107;

list players = [];
list names = [];
list lives = [];
list picksData = [];
string perilPlayer = "";

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

default {
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_REGISTER_PLAYER) {
            list info = llParseString2List(str, ["|"], []);
            names += [llList2String(info, 0)];
            players += [llList2Key(info, 1)];
            llOwnerSay("📝 Registered player for float rezzer: " + llList2String(info, 0));
        }
        else if (num == MSG_REZ_FLOAT) {
            string name = str;
            integer idx = llListFindList(names, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(players, idx);
            vector pos = llList2Vector(llGetObjectDetails(avKey, [OBJECT_POS]), 0) + <1,0,1>;
            integer ch = -777000 + idx;
            llOwnerSay("📦 Rezzing StatFloat for " + name + " at " + (string)pos);
            llSetObjectDesc(name); // Set the description to the name before rez
            llRezObject("StatFloat", pos, ZERO_VECTOR, ZERO_ROTATION, ch);
        }
        else if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            lives = llCSV2List(llList2String(parts, 0));
            picksData = llCSV2List(llList2String(parts, 1));
            perilPlayer = llList2String(parts, 2);
        }
        else if (num == MSG_UPDATE_FLOAT) {
            string name = str;
            integer idx = llListFindList(names, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(players, idx);
            integer ch = -777000 + idx;
            integer lifeCount = llList2Integer(lives, idx);
            list picks = getPicksFor(name);
            string txt = "🎲 Peril Dice\n👤 " + name + "\n❤️ Lives: " + (string)lifeCount + "\n🧍 Peril: " + perilPlayer + "\n🔢 Picks: " + llList2CSV(picks);
            llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
        }
        else if (num == MSG_CLEANUP_FLOAT) {
            integer ch = (integer)str;
            integer idx = ch - (-777000);
            if (idx >= 0 && idx < llGetListLength(players)) {
                llRegionSay(ch, "CLEANUP");
                players = llDeleteSubList(players, idx, idx);
                names = llDeleteSubList(names, idx, idx);
                lives = llDeleteSubList(lives, idx, idx);
                picksData = llDeleteSubList(picksData, idx, idx);
            }
        }
    }
}
