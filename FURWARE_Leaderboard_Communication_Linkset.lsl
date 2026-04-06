#include "Peril_Constants.lsl"

string leftText = "";

// Distribute text to the FURWARE "Leaderboard" boxes
distributeFullText(string text) {
    if (llGetSubString(text, 0, 7) == "COLUMNS|") {
        // Use llParseStringKeepNulls to ensure empty columns don't break the registration logic
        list parts = llParseStringKeepNulls(llGetSubString(text, 8, -1), ["|"], []);
        if (llGetListLength(parts) >= 3) {
            // Distribute each column to its virtual box
            llMessageLinked(LINK_SET, 0, llList2String(parts, 0), (key)(FW_DATA + ":LB_Rank"));
            llMessageLinked(LINK_SET, 0, llList2String(parts, 1), (key)(FW_DATA + ":LB_Name"));
            llMessageLinked(LINK_SET, 0, llList2String(parts, 2), (key)(FW_DATA + ":LB_WL"));
        }
    } else {
        // Fallback for legacy text or titles (sent to parent box)
        llMessageLinked(LINK_SET, 0, text, (key)(FW_DATA + ":Leaderboard"));
    }
}

default {
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        llResetScript(); 
    }

    state_entry() {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("📋 [Leaderboard] Leaderboard Communication Script ready! (Virtual Multi-Column)");
        
        // Wait for engine to be ready, then register virtual columns
        llSleep(DELAY_LEADERBOARD_SYNC);
        
        // Registering virtual columns inside the physical "Leaderboard" mesh
        // Format: fw_addbox:NewName:ParentName:x,y,w,h
        llMessageLinked(LINK_SET, 0, "", (key)("fw_addbox:LB_Rank:Leaderboard:0,1,4,11"));
        llMessageLinked(LINK_SET, 0, "", (key)("fw_addbox:LB_Name:Leaderboard:4,1,20,11"));
        llMessageLinked(LINK_SET, 0, "", (key)("fw_addbox:LB_WL:Leaderboard:24,1,8,11"));
        
        dbg("📋 [Leaderboard] Virtual column registration requests sent.");
        
        // --- STARTUP HANDSHAKE ---
        // Wait a moment for the engine to process ADD_BOX, then ask Scoreboard for a fresh update
        llSleep(DELAY_LEADERBOARD_READY);
        llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "REFRESH_STARTUP", NULL_KEY);
        
        // Start with blank display
        distributeFullText("");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle messages from the game logic
        if (num == MSG_DISPLAY_LEADERBOARD) {
            if (llGetSubString(str, 0, 14) == "FORMATTED_TEXT|") {
                distributeFullText(llGetSubString(str, 15, -1));
            } else if (llGetSubString(str, 0, 9) == "LEFT_TEXT|") {
                // For individual bank updates
                leftText = llGetSubString(str, 10, -1);
                distributeFullText(leftText);
            } else {
                // Pass directly for COLUMNS| or multi-column data
                distributeFullText(str);
            }
        }
        else if (llSubStringIndex(str, "LEADERBOARD") == 0) {
            dbg("📋 [Leaderboard] ⚠️ Received legacy LEADERBOARD format - ignoring");
        }
    }
    
}
