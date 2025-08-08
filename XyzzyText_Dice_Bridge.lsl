// XyzzyText Bridge Script - Dice Display Bridge
// This script goes in the ROOT prim of the linked dice display XyzzyText object
// Works with official XyzzyText v2.1 (10-char) script
// Handles dice roll display across 1 bank (20 characters total)

integer DICE_CHANNEL = -12347; // Channel for dice roll display
integer DISPLAY_STRING = 204000;
integer DISPLAY_EXTENDED = 204001;

// Bank configuration for XyzzyText v2.1
// Single bank with 2 prims: xyzzytext-0-0 (chars 1-10), xyzzytext-0-1 (chars 11-20)
integer DICE_BANK = 0;   // Single bank for dice display (20 characters total)

// Storage for combining left and right parts
string currentLeftText = "";
string currentRightText = "";

// Function to combine and display the dice text
displayDiceText() {
    string fullText = currentLeftText + currentRightText;
    
    // Ensure exactly 20 characters
    while (llStringLength(fullText) < 20) {
        fullText += " ";
    }
    if (llStringLength(fullText) > 20) {
        fullText = llGetSubString(fullText, 0, 19);
    }
    
    // Send to XyzzyText bank
    llMessageLinked(LINK_THIS, DISPLAY_STRING, fullText, (key)((string)DICE_BANK));
    
    
    // Clear the stored parts for next message
    currentLeftText = "";
    currentRightText = "";
}

default {
    state_entry() {
        // Listen for dice display messages
        llListen(DICE_CHANNEL, "", "", "");
        
        // Initialize variables
        currentLeftText = "";
        currentRightText = "";
        
        // Initialize XyzzyText bank with blank text (20 spaces)
        llMessageLinked(LINK_THIS, DISPLAY_STRING, "                    ", (key)((string)DICE_BANK));
        
        llOwnerSay("Dice Display Bridge ready - listening on channel " + (string)DICE_CHANNEL);
        llOwnerSay("Using dice bank: " + (string)DICE_BANK + " (20 characters across 2 prims)");
        llOwnerSay("Make sure prims are named: xyzzytext-0-0, xyzzytext-0-1");
    }
    
    listen(integer channel, string senderName, key id, string message) {
        if (channel == DICE_CHANNEL) {
            if (llSubStringIndex(message, "DICE_LEFT|") == 0) {
                // Store the left part (characters 0-9)
                currentLeftText = llGetSubString(message, 10, -1); // Remove "DICE_LEFT|" prefix
                
                // Pad to exactly 10 characters
                while (llStringLength(currentLeftText) < 10) {
                    currentLeftText += " ";
                }
                if (llStringLength(currentLeftText) > 10) {
                    currentLeftText = llGetSubString(currentLeftText, 0, 9);
                }
                
                
                // If we have both parts, display them
                if (currentRightText != "") {
                    displayDiceText();
                }
            }
            else if (llSubStringIndex(message, "DICE_RIGHT|") == 0) {
                // Store the right part (characters 10-19)
                currentRightText = llGetSubString(message, 11, -1); // Remove "DICE_RIGHT|" prefix
                
                // Pad to exactly 10 characters
                while (llStringLength(currentRightText) < 10) {
                    currentRightText += " ";
                }
                if (llStringLength(currentRightText) > 10) {
                    currentRightText = llGetSubString(currentRightText, 0, 9);
                }
                
                
                // If we have both parts, display them
                if (currentLeftText != "") {
                    displayDiceText();
                }
            }
        }
    }
    
    touch_start(integer total_number) {
        // Touch for debugging - show current state and test display
        if (llDetectedKey(0) == llGetOwner()) {
            llOwnerSay("Dice Display Bridge - listening on channel " + (string)DICE_CHANNEL);
            llOwnerSay("Total prims in linkset: " + (string)llGetNumberOfPrims());
            llOwnerSay("Using dice bank: " + (string)DICE_BANK);
            
            // Test display - 20 characters total
            llMessageLinked(LINK_THIS, DISPLAY_STRING, "TEST: Player1 -> 6 ", (key)((string)DICE_BANK));
            
            llOwnerSay("Test display sent. Touch again to clear.");
            llSetTimerEvent(3.0); // Clear test after 3 seconds
        }
    }
    
    timer() {
        llSetTimerEvent(0.0); // Stop timer
        // Clear test display (20 spaces)
        llMessageLinked(LINK_THIS, DISPLAY_STRING, "                    ", (key)((string)DICE_BANK));
        llOwnerSay("Test display cleared.");
    }
}
