// Leaderboard Bridge - Receives text from Game Scoreboard Manager and sends to XyzzyText
// This script goes in the root prim of your leaderboard object (alongside XyzzyText master)

// Communication channels
integer LEADERBOARD_CHANNEL = -12346; // Listen for messages from scoreboard

// XyzzyText Communication Constants
integer DISPLAY_STRING = 204000;
integer DISPLAY_EXTENDED = 204001;

default {
    state_entry() {
        llListen(LEADERBOARD_CHANNEL, "", "", "");
        llOwnerSay("Leaderboard Bridge ready - listening on channel " + (string)LEADERBOARD_CHANNEL);
        
        // Send initial blank display to all banks
        llMessageLinked(LINK_SET, DISPLAY_STRING, "     ", "0"); // Bank 0 (left)
        llMessageLinked(LINK_SET, DISPLAY_STRING, "     ", "1"); // Bank 1 (middle)  
        llMessageLinked(LINK_SET, DISPLAY_STRING, "     ", "2"); // Bank 2 (right)
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == LEADERBOARD_CHANNEL) {
            llOwnerSay("DEBUG: Received leaderboard message: " + message);
            
            if (llSubStringIndex(message, "LEFT_TEXT|") == 0) {
                // Extract left column text and send to bank 0
                string leftText = llGetSubString(message, 10, -1); // Remove "LEFT_TEXT|" prefix
                llOwnerSay("DEBUG: Sending to LEFT bank (0): " + leftText);
                llMessageLinked(LINK_SET, DISPLAY_STRING, leftText, "0");
                
            } else if (llSubStringIndex(message, "MIDDLE_TEXT|") == 0) {
                // Extract middle column text and send to bank 1
                string middleText = llGetSubString(message, 12, -1); // Remove "MIDDLE_TEXT|" prefix
                llOwnerSay("DEBUG: Sending to MIDDLE bank (1): " + middleText);
                llMessageLinked(LINK_SET, DISPLAY_STRING, middleText, "1");
                
            } else if (llSubStringIndex(message, "RIGHT_TEXT|") == 0) {
                // Extract right column text and send to bank 2
                string rightText = llGetSubString(message, 11, -1); // Remove "RIGHT_TEXT|" prefix
                llOwnerSay("DEBUG: Sending to RIGHT bank (2): " + rightText);
                llMessageLinked(LINK_SET, DISPLAY_STRING, rightText, "2");
                
            } else if (message == "CLEAR_LEADERBOARD") {
                // Clear all displays
                llOwnerSay("DEBUG: Clearing all leaderboard displays");
                llMessageLinked(LINK_SET, DISPLAY_STRING, "     ", "0");
                llMessageLinked(LINK_SET, DISPLAY_STRING, "     ", "1");
                llMessageLinked(LINK_SET, DISPLAY_STRING, "     ", "2");
                
            } else {
                llOwnerSay("DEBUG: Unrecognized leaderboard message: " + message);
            }
        }
    }
}
