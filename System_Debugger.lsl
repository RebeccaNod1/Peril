#include "Peril_Constants.lsl"

// === System Debugger - Game State Validation ===
// Validates game state consistency and reports issues

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
                dbg("🔍 [System Debugger] ⚠️ picksData name not in names list: " + name);
            }

            // Check for duplicate picks in this player's list
            integer j;
            list uniqueCheck = [];
            for (j = 0; j < llGetListLength(pickNums); j++) {
                string pick = llList2String(pickNums, j);
                // Skip validation warnings for cosmetic issues
                if (~llListFindList(uniqueCheck, [pick])) {
                    dbg("🔍 [System Debugger] 🚨 Duplicate pick in " + name + "'s picks: " + pick);
                } else {
                    uniqueCheck += [pick];
                }
                allPicksFlat += [pick];
            }

            // Only show picks if player has actually picked something
            if (picks != "") {
                dbg("🔍 [System Debugger] ✅ " + name + "'s picks: " + llList2CSV(pickNums));
            }
        } else if (entry != "") {
            // Only warn about non-empty malformed entries
            dbg("🔍 [System Debugger] ⚠️ Malformed entry in picksData: " + entry);
        }
    }

    // Check for duplicate picks across all players
    list seen = [];
    integer k;
    for (k = 0; k < llGetListLength(allPicksFlat); k++) {
        string val = llList2String(allPicksFlat, k);
        if (~llListFindList(seen, [val])) {
            dbg("🔍 [System Debugger] ❌ Duplicate pick across players: " + val);
        } else {
            seen += [val];
        }
    }

    return picksData;
}



default {
    state_entry() {
        REPORT_MEMORY();
        dbg("🔍 [System Debugger] 🔍 System Debugger ready!");
    }
    
    on_rez(integer start_param) {
        REPORT_MEMORY();
    }
    
    link_message(integer sender, integer num, string str, key id) {

        // Handle legacy verbose logging toggle (OBSELETE)
        
        // Handle full reset from main controller
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            // Debugger doesn't maintain state, but acknowledge reset
            dbg("🔍 [System Debugger] 🔍 System Debugger reset!");
            return;
        }
        
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) < 4) {
                dbg("🔍 [System Debugger] ✅ Validation completed - no critical issues found.");
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
