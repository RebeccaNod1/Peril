#include "Peril_Constants.lsl"

// =============================================================================
// LINKSET COMMUNICATION - NO DISCOVERY NEEDED
// =============================================================================

// Function to display dice text across the "Dice" box
displayDiceText(string text) {
    // Send to FURWARE Text engine
    llMessageLinked(LINK_SET, 0, text, (key)(FW_DATA + ":Dice"));
    
    dbg("🎲 [Dice Bridge] Dice display updated: '" + text + "'");
}

default {
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        llResetScript(); 
    }
    state_entry() {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("🎲 [Dice Bridge] Dice Display Bridge ready! (FURWARE Version)");
        dbg("🎲 [Dice Bridge] ✅ Discovery complete! Controller: " + (string)LINK_CONTROLLER);
        
        // Initialize dice display with blank text
        displayDiceText(""); 
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Only listen to messages from the main controller or scoreboard
        if (sender != LINK_CONTROLLER && sender != LINK_SCOREBOARD) return;
        
        if (num == MSG_DICE_ROLL) {
            // Handle different message formats
            list parts = llParseString2List(str, ["|"], []);
            
            if (llGetListLength(parts) >= 3) {
                // Format: "player|result|dicetype" - single die roll
                string player = llList2String(parts, 0);
                string result = llList2String(parts, 1);
                string diceType = llList2String(parts, 2);
                
                // Create dice display: "Player: rolled 4"
                // FURWARE handles alignment and wrapping, so we don't need strict padding
                string displayText = player + ": rolled " + result;
                displayDiceText(displayText);
            }
            else {
                // Treat as direct display text
                displayDiceText(str);
            }
        }
        else if (num == MSG_DICE_CLEAR) {
            displayDiceText("");
            dbg("🎲 [Dice Bridge] Dice display cleared");
        }
    }
    
    
    timer() {
        llSetTimerEvent(0.0);
        displayDiceText(""); 
        dbg("🎲 [Dice Bridge] Test display cleared");
    }
}

