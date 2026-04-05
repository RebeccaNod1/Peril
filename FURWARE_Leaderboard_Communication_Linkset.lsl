#include "Peril_Constants.lsl"

string leftText = "";

// Distribute text to the FURWARE "Leaderboard" box
distributeFullText(string text) {
    // Send directly to FURWARE. It handles multiple prims and newlines automatically.
    llMessageLinked(LINK_SET, 0, text, (key)(FW_DATA + ":Leaderboard"));
}

default {
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        llResetScript(); 
    }

    state_entry() {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("📋 [Leaderboard] Leaderboard Communication Script ready! (FURWARE Version)");
        dbg("📋 [Leaderboard] Managing 'Leaderboard' FURWARE box");
        dbg("📋 [Leaderboard] ✅ Discovery complete! Scoreboard: " + (string)LINK_SCOREBOARD);
        
        // Start with blank display
        distributeFullText("");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Only listen to messages from the scoreboard
        if (sender != LINK_SCOREBOARD) {
            return;
        }
        
        if (num == MSG_RESET_LEADERBOARD) {
            // FURWARE handles the entire leaderboard as a single text block
            if (llGetSubString(str, 0, 14) == "FORMATTED_TEXT|") {
                distributeFullText(llGetSubString(str, 15, -1));
            }
            // For individual bank updates
            else if (llGetSubString(str, 0, 9) == "LEFT_TEXT|") {
                leftText = llGetSubString(str, 10, -1);
                distributeFullText(leftText);
            }
        }
        else if (llSubStringIndex(str, "LEADERBOARD") == 0) {
            dbg("📋 [Leaderboard] ⚠️ Received legacy LEADERBOARD format - ignoring");
        }
    }
    
}
