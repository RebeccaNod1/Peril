#include "Peril_Constants.lsl"

// =============================================================================
// FURWARE STATUS BRIDGE - Dynamic Game Info Display
// =============================================================================

// Function to update the Furware "Status" box
updateStatusDisplay(string text) {
    // Send to FURWARE Text engine
    // We use <!c=darkyellow> to set the color to dark yellow
    string formattedText = "<!c=darkyellow>" + text;
    
    // Send directly to the Status box
    llMessageLinked(LINK_SET, 0, formattedText, (key)(FW_DATA + ":Status"));
}

default {
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        llResetScript(); 
    }
    
    state_entry() {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("📊 [Status Bridge] Status Display Bridge ready!");
        
        // Wait a tiny bit for Furware to be ready, then set initial text
        llSleep(1.0);
        updateStatusDisplay("PERIL DICE GAME\nWaiting for players...");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Listen for status text updates
        if (num == MSG_STATUS_TEXT) {
            updateStatusDisplay(str);
            dbg("📊 [Status Bridge] Update: " + str);
        }
        // Handle full resets
        else if (num == MSG_RESET_ALL || num == MSG_CLEAR_GAME) {
            updateStatusDisplay("PERIL DICE GAME\nWaiting for players...");
        }
    }
}
