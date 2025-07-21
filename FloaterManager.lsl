// === Floater Manager Module ===
integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;

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
        if (num == MSG_UPDATE_FLOAT) {
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
            llRegionSay(ch, "CLEANUP");
        }
    }
}
