////////////////////////////////////////////
// Leaderboard Communication Script - Linkset Version
// Based on actual link verification results
////////////////////////////////////////////

// =============================================================================
// LINKSET COMMUNICATION - NO DISCOVERY NEEDED
// =============================================================================

// Verbose logging control
integer VERBOSE_LOGGING = TRUE;  // Global flag for verbose debug logs
integer MSG_TOGGLE_VERBOSE_LOGS = 9998;  // Message to toggle verbose logging

// Message constants for link communication
// Leaderboard messages (from link 12 - scoreboard)
integer MSG_GAME_WON = 3010;
integer MSG_GAME_LOST = 3011;
integer MSG_RESET_LEADERBOARD = 3012;

integer DISPLAY_STRING = 204000;

// Bank assignments based on actual link testing - UPDATED FOR LINKSET:
// Original links were 1-48, now they are 35-82 (offset by +34)
list leftmostLinks = [35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46];     // Links 35-46 = Leftmost bank (was 1-12)
list middleLeftLinks = [47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58];   // Links 47-58 = Middle-left bank (was 13-24)  
list middleRightLinks = [59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70];  // Links 59-70 = Middle-right bank (was 25-36)
list rightmostLinks = [71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82];    // Links 71-82 = Rightmost bank (was 37-48)

string leftText = "";
string middleLeftText = "";
string middleRightText = "";
string rightText = "";

// Distribute text across all 4 banks properly - each line can be 40 chars total
distributeFullText(string text) {
    list lines = llParseString2List(text, ["\n"], []);
    list allLinks = leftmostLinks + middleLeftLinks + middleRightLinks + rightmostLinks;
    
    integer lineIndex = 0;
    integer maxLines = 12; // Each bank has 12 prims
    
    // Process each line
    while (lineIndex < maxLines) {
        string currentLine;
        
        if (lineIndex < llGetListLength(lines)) {
            currentLine = llList2String(lines, lineIndex);
        } else {
            currentLine = ""; // Empty line
        }
        
        // Pad line to 40 characters (4 banks × 10 chars each)
        while (llStringLength(currentLine) < 40) {
            currentLine += " ";
        }
        // Truncate if too long
        if (llStringLength(currentLine) > 40) {
            currentLine = llGetSubString(currentLine, 0, 39);
        }
        
        // Distribute this line across the 4 banks (10 chars each)
        integer bank;
        for (bank = 0; bank < 4; bank++) {
            string bankText = llGetSubString(currentLine, bank * 10, (bank * 10) + 9);
            integer linkNum;
            
            if (bank == 0) linkNum = llList2Integer(leftmostLinks, lineIndex);
            else if (bank == 1) linkNum = llList2Integer(middleLeftLinks, lineIndex);
            else if (bank == 2) linkNum = llList2Integer(middleRightLinks, lineIndex);
            else linkNum = llList2Integer(rightmostLinks, lineIndex);
            
            llMessageLinked(linkNum, DISPLAY_STRING, bankText, "");
        }
        
        lineIndex++;
    }
}

// Legacy function for single bank distribution
distributeToBank(string text, list linkNumbers) {
    list lines;
    
    // If text is empty, create a list of empty strings to clear all prims
    if (text == "") {
        integer numPrims = llGetListLength(linkNumbers);
        integer i;
        for (i = 0; i < numPrims; i++) {
            lines += ["          "]; // 10 spaces to clear each line
        }
    } else {
        lines = llParseString2List(text, ["\n"], []);
    }
    
    // Send text to each prim in the bank
    integer i;
    for (i = 0; i < llGetListLength(linkNumbers); i++) {
        string line;
        
        if (i < llGetListLength(lines)) {
            line = llList2String(lines, i);
        } else {
            line = "          "; // 10 spaces for empty lines
        }
        
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
        if (VERBOSE_LOGGING) {
            llOwnerSay("📋 Leaderboard Communication Script ready! (Linkset Version)");
            llOwnerSay("📋 This is link " + (string)llGetLinkNumber() + " - should be link 35");
            llOwnerSay("📋 Managing XyzzyText links 35-82 (48 prims total)");
            llOwnerSay("✅ Linkset communication active - listening for messages from link 12!");
        }
        
        // Start with blank display - real data will come from scoreboard script
        distributeFullText("");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle
        if (num == MSG_TOGGLE_VERBOSE_LOGS) {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔊 [Leaderboard] Verbose logging ENABLED");
            } else {
                llOwnerSay("🔊 [Leaderboard] Verbose logging DISABLED");
            }
            return;
        }
        
        // Only listen to messages from the scoreboard (link 12)
        if (sender != 12) {
            return;
        }
        
        if (num == MSG_RESET_LEADERBOARD) {
            // Handle the different text section messages
            if (llGetSubString(str, 0, 9) == "LEFT_TEXT|") {
                leftText = llGetSubString(str, 10, -1);
                distributeToBank(leftText, leftmostLinks);
                
            } else if (llGetSubString(str, 0, 16) == "MIDDLE_LEFT_TEXT|") {
                middleLeftText = llGetSubString(str, 17, -1);
                distributeToBank(middleLeftText, middleLeftLinks);
                
            } else if (llGetSubString(str, 0, 17) == "MIDDLE_RIGHT_TEXT|") {
                middleRightText = llGetSubString(str, 18, -1);
                distributeToBank(middleRightText, middleRightLinks);
                
            } else if (llGetSubString(str, 0, 10) == "RIGHT_TEXT|") {
                rightText = llGetSubString(str, 11, -1);
                distributeToBank(rightText, rightmostLinks);
            }
            else if (llGetSubString(str, 0, 14) == "FORMATTED_TEXT|") {
                // This is pre-formatted text from the scoreboard - just display it
                string formattedText = llGetSubString(str, 15, -1);
                leftText = formattedText;
                distributeFullText(leftText);
            }
            else if (llSubStringIndex(str, "LEADERBOARD") == 0) {
                // Legacy leaderboard format - not used with linkset version
                // Scoreboard now sends pre-formatted text via FORMATTED_TEXT
                if (VERBOSE_LOGGING) {
                    llOwnerSay("⚠️ [Leaderboard] Received legacy LEADERBOARD format - ignoring");
                }
            }
        }
    }
    
    touch_start(integer total_number) {
        // Owner can get debug info by touching leaderboard
        if (llDetectedKey(0) == llGetOwner()) {
            llOwnerSay("📋 Leaderboard Status:");
            llOwnerSay("  Link Number: " + (string)llGetLinkNumber());
            llOwnerSay("  Total prims in linkset: " + (string)llGetNumberOfPrims());
            llOwnerSay("  Managing links 35-82 (48 XyzzyText prims)");
            llOwnerSay("  Listening for messages from link 12 (scoreboard)");
            llOwnerSay("  Current text sections:");
            string leftStatus;
            if (leftText != "") {
                leftStatus = "SET (" + (string)llStringLength(leftText) + " chars)";
            } else {
                leftStatus = "EMPTY";
            }
            llOwnerSay("    Left: " + leftStatus);
            
            string middleLeftStatus;
            if (middleLeftText != "") {
                middleLeftStatus = "SET";
            } else {
                middleLeftStatus = "EMPTY";
            }
            llOwnerSay("    Middle-Left: " + middleLeftStatus);
            
            string middleRightStatus;
            if (middleRightText != "") {
                middleRightStatus = "SET";
            } else {
                middleRightStatus = "EMPTY";
            }
            llOwnerSay("    Middle-Right: " + middleRightStatus);
            
            string rightStatus;
            if (rightText != "") {
                rightStatus = "SET";
            } else {
                rightStatus = "EMPTY";
            }
            llOwnerSay("    Right: " + rightStatus);
        } else {
            // Non-owner touch - show friendly message
            llSay(0, "🏆 Leaderboard shows the top players! Keep playing to climb the ranks!");
        }
    }
}
