#include "Peril_Constants.lsl"

string leftText = "";

// Distribute text to the FURWARE "Leaderboard" boxes
distributeFullText(string text) {
    if (llGetSubString(text, 0, 7) == "COLUMNS|") {
        // Use llParseStringKeepNulls to ensure empty columns don't break logic
        list parts = llParseStringKeepNulls(llGetSubString(text, 8, -1), ["|"], []);
        if (llGetListLength(parts) >= 3) {
            // Distribute each column to its virtual box
            llMessageLinked(LINK_SET, 0, llList2String(parts, 0), (key)"fw_data:LB_Rank");
            llMessageLinked(LINK_SET, 0, llList2String(parts, 1), (key)"fw_data:LB_Name");
            llMessageLinked(LINK_SET, 0, llList2String(parts, 2), (key)"fw_data:LB_WL");
            
            // Route Navigation Arrows to dedicated button boxes
            if (llGetListLength(parts) >= 5) {
                llMessageLinked(LINK_SET, 0, llList2String(parts, 3), (key)"fw_data:LB_PREV_BTN");
                llMessageLinked(LINK_SET, 0, llList2String(parts, 4), (key)"fw_data:LB_NEXT_BTN");
            }
        }
    } else {
        // Fallback for legacy text or titles (sent to parent box)
        llMessageLinked(LINK_SET, 0, text, (key)"fw_data:Leaderboard");
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
        dbg("📋 [Leaderboard] Bridge Active. Awaiting Engine...");
        
        // Wait for engine to be ready
        llSleep(2.0);
        
        // Registering virtual columns + Navigation buttons
        // Coordinates: x, y, width, height (0-indexed)
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_Rank:Leaderboard:0,1,4,10:");
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_Name:Leaderboard:4,1,20,10:");
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_WL:Leaderboard:24,1,8,10:");
        
        // Navigation Row (Shifted down to Y=11)
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_PREV_BTN:Leaderboard:4,11,10,1:");
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_NEXT_BTN:Leaderboard:20,11,12,1:");
        
        dbg("📋 [Leaderboard] Box registration sent.");
        
        // Give the engine time to build boxes before first refresh
        llSleep(2.0); 
        // Set the Top Line Header on the main box
        llMessageLinked(LINK_SET, 0, "=== WORLD RANKING ===", (key)"fw_data:Leaderboard");
        
        // Trigger Leaderboard Manager to download from KVP Database
        llMessageLinked(LINK_SET, MSG_RESET_LEADERBOARD, "START_SYNC", NULL_KEY);
    }
    
    touch_start(integer _n) {
        // Use exact syntax from example: fw_touchquery:link:face
        integer _link = llDetectedLinkNumber(0);
        integer _face = llDetectedTouchFace(0);
        
        dbg("👆 [Leaderboard] Touch detected. Sending fw_touchquery:" + (string)_link + ":" + (string)_face);
        llMessageLinked(LINK_SET, 0, "LB_TOUCH", (key)("fw_touchquery:" + (string)_link + ":" + (string)_face));
    }
    
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_DISPLAY_LEADERBOARD) {
            if (llGetSubString(str, 0, 14) == "FORMATTED_TEXT|") {
                distributeFullText(llGetSubString(str, 15, -1));
            } else if (llGetSubString(str, 0, 9) == "LEFT_TEXT|") {
                leftText = llGetSubString(str, 10, -1);
                distributeFullText(leftText);
            } else {
                distributeFullText(str);
            }
        }
        else if (id == "fw_touchreply") {
            dbg("👆 [Leaderboard] Raw Reply: " + str);
            // Format: boxName:dx:dy:rootName:x:y:userData
            list _parts = llParseStringKeepNulls(str, [":"], []);
            string _box = llList2String(_parts, 0);
            string _uData = llList2String(_parts, 6);
            
            if (_uData == "LB_TOUCH") {
                dbg("👆 [Leaderboard] Click: " + _box);
                
                if (_box == "LB_PREV_BTN") {
                     llMessageLinked(LINK_SET, MSG_LB_PAGE_PREV, "", NULL_KEY);
                } else if (_box == "LB_NEXT_BTN") {
                     llMessageLinked(LINK_SET, MSG_LB_PAGE_NEXT, "", NULL_KEY);
                }
            }
        }
    }
}
