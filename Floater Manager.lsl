// === FloatManager (Consolidated) ===
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

        if (llSubStringIndex(entry, "|") == -1) {
            llOwnerSay("⚠️ Malformed picks entry (missing pipe): " + entry);
        } else {
            list parts = llParseString2List(entry, ["|"], []);
            if (llGetListLength(parts) < 2) {
                llOwnerSay("⚠️ Malformed picks entry (too few parts): " + entry);
            }
            else if (llList2String(parts, 0) == nameInput) {
                string pickString = llList2String(parts, 1);
                if (pickString == "") {
                    llOwnerSay("⚠️ Malformed or empty picks entry: " + entry);
                } else {
                    list all = llParseString2List(pickString, [","], []);
                    list filtered = [];
                    integer j;
                    for (j = 0; j < llGetListLength(all); j++) {
                        string val = llStringTrim(llList2String(all, j), STRING_TRIM);
                        if (val != "" && (string)((integer)val) == val) {
                            filtered += [val];
                        } else {
                            llOwnerSay("⚠️ Invalid number in picks for " + nameInput + ": '" + val + "'");
                        }
                    }
                    return filtered;
                }
            }
        }
    }
    return [];
}

string getNameFromKey(key id) {
    integer i = llListFindList(players, [id]);
    if (i != -1) return llList2String(names, i);
    return (string)id;
}

default {
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_REGISTER_PLAYER) {
            list info = llParseString2List(str, ["|"], []);
            string name = llList2String(info, 0);
            key avKey = llList2Key(info, 1);
            names += [name];
            players += [avKey];
            llOwnerSay("📝 Registered: " + name);
        }
        else if (num == MSG_REZ_FLOAT) {
            string name = str;
            integer idx = llListFindList(names, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(players, idx);
            vector pos = llList2Vector(llGetObjectDetails(avKey, [OBJECT_POS]), 0) + <1,0,1>;
            integer ch = -777000 + idx;
            llOwnerSay("📦 Rezzing float for " + name + " at " + (string)pos);
            llSetObjectDesc(name);
            llRezObject("StatFloat", pos, ZERO_VECTOR, ZERO_ROTATION, ch);
        }
        else if (num == MSG_UPDATE_FLOAT) {
            string name = str;
            integer idx = llListFindList(names, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(players, idx);
            integer ch = -777000 + idx;
            integer lifeCount = llList2Integer(lives, idx);

            llOwnerSay("🔍 Checking picksData: " + name);
            list picks = getPicksFor(name);

            llOwnerSay("🛠️ Updating float for " + name);
            llOwnerSay("🔎 Found picks: " + llList2CSV(picks));

            string perilName;
            if (perilPlayer == "") {
                perilName = "🧍 Status: Waiting for game to start...";
            } else {
                perilName = "🧍 Peril: " + getNameFromKey(perilPlayer);
            }

            string picksDisplay = llList2CSV(picks);
            string txt = "🎲 Peril Dice\n👤 " + name + "\n❤️ Lives: " + (string)lifeCount + "\n" + perilName + "\n🔢 Picks: " + picksDisplay;
            llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
            llOwnerSay("📤 Sent FLOAT message on channel " + (string)ch + ": " + txt);
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
        else if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            lives = llCSV2List(llList2String(parts, 0));
            list rawPicks = llCSV2List(llList2String(parts, 1));
            picksData = [];
            integer i;
            for (i = 0; i < llGetListLength(rawPicks); i++) {
                string entry = llList2String(rawPicks, i);
                if (llSubStringIndex(entry, "|") != -1) {
                    picksData += [entry];
                } else {
                    llOwnerSay("⚠️ Ignored malformed picksData during sync: " + entry);
                }
            }
            perilPlayer = llList2String(parts, 2);
        }
    }
}
