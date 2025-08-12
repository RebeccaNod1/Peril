// XyzzyText Bridge Script - Dice Display Bridge (Linkset Version)
// This script goes in link 73 of the linkset
// Works with simple XyzzyText v1.0 script (like leaderboard)
// Handles dice roll display across 2 prims (20 characters total)

// =============================================================================
// LINKSET COMMUNICATION - NO DISCOVERY NEEDED
// =============================================================================

// Message constants for link communication
// Dice messages (from link 1 - controller)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;

integer DISPLAY_STRING = 204000;

// Dice prim links
integer DICE_PRIM_1 = 73;  // First dice prim (characters 0-9)
integer DICE_PRIM_2 = 74;  // Second dice prim (characters 10-19)

// Function to display dice text across both prims
displayDiceText(string text) {
    // Ensure exactly 20 characters
    while (llStringLength(text) < 20) {
        text += " ";
    }
    if (llStringLength(text) > 20) {
        text = llGetSubString(text, 0, 19);
    }
    
    // Split into 10-character chunks for each prim
    string leftText = llGetSubString(text, 0, 9);   // Characters 0-9
    string rightText = llGetSubString(text, 10, 19); // Characters 10-19
    
    // Send to individual XyzzyText prims
    llMessageLinked(DICE_PRIM_1, DISPLAY_STRING, leftText, "");
    llMessageLinked(DICE_PRIM_2, DISPLAY_STRING, rightText, "");
    
    llOwnerSay("🎲 Dice display updated: '" + text + "'");
}

default {
    state_entry() {
        llOwnerSay("🎲 Dice Display Bridge ready! (Linkset Version)");
        llOwnerSay("🎲 This is link " + (string)llGetLinkNumber() + " - should be link 73");
        llOwnerSay("🎲 Managing dice display links 73-74 (2 prims total)");
        llOwnerSay("✅ Linkset communication active - listening for messages from link 1!");
        
        // Initialize dice display with blank text (10 spaces each prim)
        displayDiceText("                    "); // 20 spaces
        
        llOwnerSay("Dice display initialized - using simple XyzzyText v1.0 (like leaderboard)");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Only listen to messages from the main controller (link 1)
        if (sender != 1) return;
        
        if (num == MSG_DICE_ROLL) {
            // Handle different message formats
            list parts = llParseString2List(str, ["|"], []);
            
            if (llGetListLength(parts) >= 3) {
                // Format: "player|result|dicetype" - single die roll
                string player = llList2String(parts, 0);
                string result = llList2String(parts, 1);
                string diceType = llList2String(parts, 2);
                
                // Create dice display: "Player1: rolled 4  "
                string displayText = player;
                if (llStringLength(displayText) > 8) {
                    displayText = llGetSubString(displayText, 0, 7);
                }
                displayText += ": rolled " + result;
                
                displayDiceText(displayText);
            }
            else {
                // Treat as direct display text
                displayDiceText(str);
            }
        }
        else if (num == MSG_CLEAR_DICE) {
            // Clear dice display (20 spaces)
            displayDiceText("                    ");
            llOwnerSay("🎲 Dice display cleared");
        }
    }
    
    touch_start(integer total_number) {
        // Owner can get debug info and test display by touching dice
        if (llDetectedKey(0) == llGetOwner()) {
            llOwnerSay("🎲 Dice Display Status:");
            llOwnerSay("  Link Number: " + (string)llGetLinkNumber());
            llOwnerSay("  Total prims in linkset: " + (string)llGetNumberOfPrims());
            llOwnerSay("  Managing links 73-74 (2 XyzzyText prims)");
            llOwnerSay("  Listening for messages from link 1 (controller)");
            llOwnerSay("  Using simple XyzzyText v1.0 (like leaderboard)");
            
            // Test display - 20 characters total
            displayDiceText("TEST: Player1 -> 6  ");
            llOwnerSay("🎲 Test display sent: 'TEST: Player1 -> 6  '");
            llOwnerSay("🎲 Touch again in 3 seconds to clear test");
            
            // Set timer to clear test display
            llSetTimerEvent(3.0);
        } else {
            // Non-owner touch - show friendly message  
            llSay(0, "🎲 Dice display shows the latest rolls! Watch for game actions!");
        }
    }
    
    timer() {
        // Clear test display
        llSetTimerEvent(0.0); // Stop timer
        displayDiceText("                    "); // 20 spaces
        llOwnerSay("🎲 Test display cleared");
    }
}
