#include "Peril_Constants.lsl"

string leftText = "";
string firstName = "";
integer blinkState = 0;
integer canBlink = 0;


// Distribute text to the FURWARE "Leaderboard" boxes
distributeFullText(string text) {
    if (llGetSubString(text, 0, 7) == "COLUMNS|") {
        // Use llParseStringKeepNulls to ensure empty columns don't break logic
        list parts = llParseStringKeepNulls(llGetSubString(text, 8, -1), ["|"], []);
        if (llGetListLength(parts) >= 3) {
            // Distribute each column to its virtual box
            llMessageLinked(LINK_SET, 0, llList2String(parts, 0), (key)"fw_data:LB_Rank");
            
            // Distribute Name column (Split first line for blinking)
            string nameText = llList2String(parts, 1);
            integer firstLineEnd = llSubStringIndex(nameText, "\n");
            if (firstLineEnd != -1) {
                firstName = llGetSubString(nameText, 0, firstLineEnd - 1);
                string remainingNames = llGetSubString(nameText, firstLineEnd + 1, -1);
                llMessageLinked(LINK_SET, 0, firstName, (key)"fw_data:LB_Name_Top");
                llMessageLinked(LINK_SET, 0, remainingNames, (key)"fw_data:LB_Name");
            } else {
                firstName = nameText;
                llMessageLinked(LINK_SET, 0, firstName, (key)"fw_data:LB_Name_Top");
                llMessageLinked(LINK_SET, 0, "", (key)"fw_data:LB_Name");
            }

            // Check if we should blink (#1 spot on first page only)
            integer offset = (integer)llList2String(parts, 5);
            if (offset == 0) {
                canBlink = TRUE;
                llSetTimerEvent(0.5);
            } else {
                canBlink = FALSE;
                llSetTimerEvent(0.0);
                // Ensure name is visible on non-blinking pages
                llMessageLinked(LINK_SET, 0, firstName, (key)"fw_data:LB_Name_Top");
            }

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
        // border=lr added to create vertical separators between columns
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_Rank:Leaderboard:0,1,4,10:");
        
        // Split Name into Top (for blinking) and Body
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_Name_Top:Leaderboard:4,1,20,1:border=lr");
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_Name:Leaderboard:4,2,20,9:border=lr");
        
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_WL:Leaderboard:24,1,8,10:");
        
        // Navigation Row (Shifted down to Y=11)
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_PREV_BTN:Leaderboard:4,11,10,1:");
        llMessageLinked(LINK_SET, 0, "", (key)"fw_addbox:LB_NEXT_BTN:Leaderboard:20,11,12,1:");
        
        dbg("📋 [Leaderboard] Box registration sent.");
        
        // Give the engine time to build boxes before first refresh
        llSleep(2.0); 
        // Set the Top Line Header on the main box
        llMessageLinked(LINK_SET, 0, "=== WORLD RANKING ===", (key)"fw_data:Leaderboard");
        
        // Note: Leaderboard sync should be triggered by the Main Controller or Game Manager 
        // during game resets, rather than every time the bridge initializes.
        // llMessageLinked(LINK_SET, MSG_RESET_LEADERBOARD, "START_SYNC", NULL_KEY);
        
        // Start Blink Timer (0.5s intervals)
        llSetTimerEvent(0.5);
    }
    
    timer() {
        if (!canBlink) {
            llSetTimerEvent(0.0);
            return;
        }
        blinkState = !blinkState;
        if (blinkState) {
            llMessageLinked(LINK_SET, 0, firstName, (key)"fw_data:LB_Name_Top");
        } else {
            llMessageLinked(LINK_SET, 0, "", (key)"fw_data:LB_Name_Top");
        }
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
        else if (num == MSG_RESET_ALL) { llResetScript(); }
    }
}
