integer MSG_SYNC_GAME_STATE = 107;

list validatePicksData(list picksData, list names) {
    list allPicksFlat = [];
    integer i;

    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);

        if (llGetListLength(parts) == 2) {
            string name = llList2String(parts, 0);
            string picks = llList2String(parts, 1);
            list pickNums = llParseString2List(picks, [","], []);

            // Check if name is in names list
            if (names != [] && llListFindList(names, [name]) == -1) {
                llOwnerSay("⚠️ picksData name not in names list: " + name);
            }

            // Check for duplicate picks in this player's list
            integer j;
            list uniqueCheck = [];
            for (j = 0; j < llGetListLength(pickNums); j++) {
                string pick = llList2String(pickNums, j);
                if ((string)((float)pick) != pick) {
                    llOwnerSay("⚠️ Invalid number in picks for " + name + ": '" + pick + "'");
                }
                if (~llListFindList(uniqueCheck, [pick])) {
                    llOwnerSay("🚨 Duplicate pick in " + name + "'s picks: " + pick);
                } else {
                    uniqueCheck += [pick];
                }
                allPicksFlat += [pick];
            }

            llOwnerSay("✅ " + name + "'s picks: " + llList2CSV(pickNums));
        } else {
            llOwnerSay("⚠️ Malformed entry in picksData: " + entry);
        }
    }

    // Check for duplicate picks across all players
    list seen = [];
    integer k;
    for (k = 0; k < llGetListLength(allPicksFlat); k++) {
        string val = llList2String(allPicksFlat, k);
        if (~llListFindList(seen, [val])) {
            llOwnerSay("❌ Duplicate pick across players: " + val);
        } else {
            seen += [val];
        }
    }

    return picksData;
}



default {
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) < 4) {
                llOwnerSay("⚠️ Incomplete game state received.");
                return;
            }

            list lives = llCSV2List(llList2String(parts, 0));
            list picksData = llCSV2List(llList2String(parts, 1));
            string perilPlayer = llList2String(parts, 2);
            list names = llCSV2List(llList2String(parts, 3));

            llOwnerSay("🔍 Checking picksData...");
            validatePicksData(picksData, names);
        }
    }
}
integer MSG_SYNC_GAME_STATE = 107;

list validatePicksData(list picksData, list names) {
    list allPicksFlat = [];
    integer i;

    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);

        if (llGetListLength(parts) == 2) {
            string name = llList2String(parts, 0);
            string picks = llList2String(parts, 1);
            list pickNums = llParseString2List(picks, [","], []);

            // Check if name is in names list
            if (names != [] && llListFindList(names, [name]) == -1) {
                llOwnerSay("⚠️ picksData name not in names list: " + name);
            }

            // Check for duplicate picks in this player's list
            integer j;
            list uniqueCheck = [];
            for (j = 0; j < llGetListLength(pickNums); j++) {
                string pick = llList2String(pickNums, j);
                if ((string)((float)pick) != pick) {
                    llOwnerSay("⚠️ Invalid number in picks for " + name + ": '" + pick + "'");
                }
                if (~llListFindList(uniqueCheck, [pick])) {
                    llOwnerSay("🚨 Duplicate pick in " + name + "'s picks: " + pick);
                } else {
                    uniqueCheck += [pick];
                }
                allPicksFlat += [pick];
            }

            llOwnerSay("✅ " + name + "'s picks: " + llList2CSV(pickNums));
        } else {
            llOwnerSay("⚠️ Malformed entry in picksData: " + entry);
        }
    }

    // Check for duplicate picks across all players
    list seen = [];
    integer k;
    for (k = 0; k < llGetListLength(allPicksFlat); k++) {
        string val = llList2String(allPicksFlat, k);
        if (~llListFindList(seen, [val])) {
            llOwnerSay("❌ Duplicate pick across players: " + val);
        } else {
            seen += [val];
        }
    }

    return picksData;
}



default {
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) < 4) {
                llOwnerSay("⚠️ Incomplete game state received.");
                return;
            }

            list lives = llCSV2List(llList2String(parts, 0));
            list picksData = llCSV2List(llList2String(parts, 1));
            string perilPlayer = llList2String(parts, 2);
            list names = llCSV2List(llList2String(parts, 3));

            llOwnerSay("🔍 Checking picksData...");
            validatePicksData(picksData, names);
        }
    }
}
