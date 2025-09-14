// === System Debugger - Game State Validation ===
// Validates game state consistency and reports issues

// Verbose logging control
integer VERBOSE_LOGGING = TRUE;  // Global flag for verbose debug logs
integer MSG_TOGGLE_VERBOSE_LOGS = 9998;  // Message to toggle verbose logging

integer MSG_SYNC_GAME_STATE = 107;

list validatePicksData(list picksData, list names) {
    list allPicksFlat = [];
    integer i;

    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        
        // Handle entries ending with "|" (empty picks) - LSL drops trailing empty elements
        if (llGetListLength(parts) == 1 && llGetSubString(entry, -1, -1) == "|") {
            parts += [""];  // Add the empty picks part back
        }

        if (llGetListLength(parts) == 2) {
            string name = llList2String(parts, 0);
            string picks = llList2String(parts, 1);
            list pickNums = llParseString2List(picks, [";"], []);

            // Check if name is in names list
            if (names != [] && llListFindList(names, [name]) == -1) {
                llOwnerSay("⚠️ picksData name not in names list: " + name);
            }

            // Check for duplicate picks in this player's list
            integer j;
            list uniqueCheck = [];
            for (j = 0; j < llGetListLength(pickNums); j++) {
                string pick = llList2String(pickNums, j);
                // Skip validation warnings for cosmetic issues
                if (~llListFindList(uniqueCheck, [pick])) {
                    llOwnerSay("🚨 Duplicate pick in " + name + "'s picks: " + pick);
                } else {
                    uniqueCheck += [pick];
                }
                allPicksFlat += [pick];
            }

            // Only show picks if player has actually picked something
            if (picks != "" && VERBOSE_LOGGING) {
                llOwnerSay("✅ " + name + "'s picks: " + llList2CSV(pickNums));
            }
        } else if (entry != "") {
            // Only warn about non-empty malformed entries
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
    state_entry() {
        llOwnerSay("🔍 System Debugger ready!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle
        if (num == MSG_TOGGLE_VERBOSE_LOGS) {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔊 [System Debugger] Verbose logging ENABLED");
            } else {
                llOwnerSay("🔊 [System Debugger] Verbose logging DISABLED");
            }
            return;
        }
        
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Debugger doesn't maintain state, but acknowledge reset
            llOwnerSay("🔍 System Debugger reset!");
            return;
        }
        
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) < 4) {
                if (VERBOSE_LOGGING) {
                    llOwnerSay("⚠️ Incomplete game state received.");
                }
                return;
            }

            list lives = llCSV2List(llList2String(parts, 0));
            // Use ^ delimiter for picksData to avoid comma conflicts
            string picksDataStr = llList2String(parts, 1);
            list picksData = [];
            if (picksDataStr != "" && picksDataStr != "EMPTY") {
                picksData = llParseString2List(picksDataStr, ["^"], []);
            }
            string perilPlayer = llList2String(parts, 2);
            list names = llCSV2List(llList2String(parts, 3));

            // Only show checking message if there's actual picks data to validate
            integer hasPicksData = FALSE;
            integer i;
            for (i = 0; i < llGetListLength(picksData); i++) {
                string entry = llList2String(picksData, i);
                list parts = llParseString2List(entry, ["|"], []);
                if (llGetListLength(parts) == 2 && llList2String(parts, 1) != "") {
                    hasPicksData = TRUE;
                    jump skipCheck;
                }
            }
            @skipCheck;
            
            // Only show checking message for actual issues, not routine validation
            validatePicksData(picksData, names);
        }
    }
}
