// XyzzyText Debug Helper
// This script helps debug issues with XyzzyText display

// Constants for XyzzyText communication
integer DISPLAY_STRING = 204000;
integer DISPLAY_EXTENDED = 204001;
integer RESCAN_LINKSET = 204008;

// Communication channel from scoreboard
integer LEADERBOARD_CHANNEL = -12346;

default {
    state_entry() {
        // Listen for messages from scoreboard
        llListen(LEADERBOARD_CHANNEL, "", "", "");
        llOwnerSay("XyzzyText Debug Helper started");
        
        // Check linkset info
        integer numPrims = llGetNumberOfPrims();
        llOwnerSay("DEBUG: Linkset has " + (string)numPrims + " prims");
        
        // List all prim names to verify XyzzyText setup
        integer i;
        for (i = 1; i <= numPrims; i++) {
            string primName = llGetLinkName(i);
            llOwnerSay("DEBUG: Prim " + (string)i + " name: '" + primName + "'");
        }
        
        // Trigger a rescan of the linkset for XyzzyText
        llOwnerSay("DEBUG: Triggering XyzzyText rescan");
        llMessageLinked(LINK_SET, RESCAN_LINKSET, "", "");
        
        // Send test text to each bank
        llSleep(1.0); // Wait for rescan to complete
        llOwnerSay("DEBUG: Sending test text to banks");
        llMessageLinked(LINK_SET, DISPLAY_STRING, "TEST0", "0"); // Bank 0 (left)
        llMessageLinked(LINK_SET, DISPLAY_STRING, "TEST1", "1"); // Bank 1 (middle)
        llMessageLinked(LINK_SET, DISPLAY_STRING, "TEST2", "2"); // Bank 2 (right)
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == LEADERBOARD_CHANNEL) {
            llOwnerSay("DEBUG: Received message on channel " + (string)channel + ": " + message);
            
            if (llSubStringIndex(message, "LEFT_TEXT|") == 0) {
                string leftText = llGetSubString(message, 10, -1);
                llOwnerSay("DEBUG: Got LEFT text: " + leftText);
                llMessageLinked(LINK_SET, DISPLAY_STRING, leftText, "0");
            } 
            else if (llSubStringIndex(message, "MIDDLE_TEXT|") == 0) {
                string middleText = llGetSubString(message, 12, -1);
                llOwnerSay("DEBUG: Got MIDDLE text: " + middleText);
                llMessageLinked(LINK_SET, DISPLAY_STRING, middleText, "1");
            } 
            else if (llSubStringIndex(message, "RIGHT_TEXT|") == 0) {
                string rightText = llGetSubString(message, 11, -1);
                llOwnerSay("DEBUG: Got RIGHT text: " + rightText);
                llMessageLinked(LINK_SET, DISPLAY_STRING, rightText, "2");
            }
        }
    }
    
    touch_start(integer total_number) {
        // When touched, refresh debug info and test displays
        llOwnerSay("--- XyzzyText Debug Refresh ---");
        
        // Check linkset info
        integer numPrims = llGetNumberOfPrims();
        llOwnerSay("DEBUG: Linkset has " + (string)numPrims + " prims");
        
        // List all prim names
        integer i;
        for (i = 1; i <= numPrims; i++) {
            string primName = llGetLinkName(i);
            llOwnerSay("DEBUG: Prim " + (string)i + " name: '" + primName + "'");
        }
        
        // Trigger rescan and test displays
        llOwnerSay("DEBUG: Triggering XyzzyText rescan");
        llMessageLinked(LINK_SET, RESCAN_LINKSET, "", "");
        
        llSleep(1.0);
        llOwnerSay("DEBUG: Sending test text to banks");
        llMessageLinked(LINK_SET, DISPLAY_STRING, "TEST0", "0");
        llMessageLinked(LINK_SET, DISPLAY_STRING, "TEST1", "1");
        llMessageLinked(LINK_SET, DISPLAY_STRING, "TEST2", "2");
    }
}
