////////////////////////////////////////////
// Leaderboard Communication Script - Clean Version
// Based on actual link verification results
////////////////////////////////////////////

integer LEADERBOARD_CHANNEL = -12346;
integer DISPLAY_STRING = 204000;

// Bank assignments based on actual link testing:
list leftmostLinks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];           // Links 1-12 = Leftmost bank
list middleLeftLinks = [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]; // Links 13-24 = Middle-left bank  
list middleRightLinks = [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]; // Links 25-36 = Middle-right bank
list rightmostLinks = [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48];   // Links 37-48 = Rightmost bank

string leftText = "";
string middleLeftText = "";
string middleRightText = "";
string rightText = "";

distributeToBank(string text, list linkNumbers) {
    list lines = llParseString2List(text, ["\n"], []);
    integer i;
    for (i = 0; i < llGetListLength(lines) && i < llGetListLength(linkNumbers); i++) {
        string line = llList2String(lines, i);
        // Ensure exactly 10 characters
        if (llStringLength(line) > 10) {
            line = llGetSubString(line, 0, 9);
        } else if (llStringLength(line) < 10) {
            line = line + llGetSubString("          ", 0, 9 - llStringLength(line));
        }
        integer linkNum = llList2Integer(linkNumbers, i);
        llMessageLinked(linkNum, DISPLAY_STRING, line, "");
    }
}

default {
    state_entry() {
        llOwnerSay("Leaderboard Communication Script ready");
        llListen(LEADERBOARD_CHANNEL, "", "", "");
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == LEADERBOARD_CHANNEL) {
            if (llGetSubString(message, 0, 9) == "LEFT_TEXT|") {
                leftText = llGetSubString(message, 10, -1);
                distributeToBank(leftText, leftmostLinks);
                
            } else if (llGetSubString(message, 0, 16) == "MIDDLE_LEFT_TEXT|") {
                middleLeftText = llGetSubString(message, 17, -1);
                distributeToBank(middleLeftText, middleLeftLinks);
                
            } else if (llGetSubString(message, 0, 17) == "MIDDLE_RIGHT_TEXT|") {
                middleRightText = llGetSubString(message, 18, -1);
                distributeToBank(middleRightText, middleRightLinks);
                
            } else if (llGetSubString(message, 0, 10) == "RIGHT_TEXT|") {
                rightText = llGetSubString(message, 11, -1);
                distributeToBank(rightText, rightmostLinks);
            }
        }
    }
}
