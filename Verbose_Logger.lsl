// === Verbose Logger - Simple Debug Toggle Controller ===
// Provides system-wide verbose logging toggle functionality
// Scripts use their own VERBOSE_LOGGING flags, this just coordinates the toggle

// Verbose logging control
integer VERBOSE_LOGGING = FALSE;

// Loop protection - prevent rapid toggle spam
float lastToggleTime = 0.0;
float TOGGLE_COOLDOWN = 2.0; // Minimum 2 seconds between toggles

// Message constants for verbose logging system
integer MSG_VERBOSE_TOGGLE = 9010;        // Toggle verbose logging on/off
integer MSG_VERBOSE_BROADCAST = 9011;     // Broadcast logging state to all modules

// Report memory status of this script
reportMemoryStatus() {
    if (VERBOSE_LOGGING) {
        integer free = llGetFreeMemory();
        integer used = llGetUsedMemory();
        llOwnerSay("🔍 [Verbose Logger] Memory - Free: " + (string)free + " Used: " + (string)used);
    }
}

default {
    state_entry() {
        llOwnerSay("🔍 Verbose Logger initialized - ready to handle debug toggle");
    }
    
    on_rez(integer start_param) {
        llOwnerSay("🔍 Verbose Logger rezzed - debug system ready");
        VERBOSE_LOGGING = FALSE; // Default to off after rez
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle - FIXED to prevent loops
        if (num == MSG_VERBOSE_TOGGLE && str == "TOGGLE_VERBOSE_LOGS") {
            // Only respond if sender is NOT the Main Controller (prevent forwarding loop)
            if (sender == 1) {
                // This came from Main Controller forwarding - ignore to prevent loop
                return;
            }
            
            // Loop protection - prevent rapid toggle spam
            float currentTime = llGetTime();
            if (currentTime - lastToggleTime < TOGGLE_COOLDOWN) {
                return; // Silent ignore during cooldown
            }
            lastToggleTime = currentTime;
            
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            
            string status = "OFF";
            if (VERBOSE_LOGGING) {
                status = "ON";
                llOwnerSay("🔍 [Verbose Logger] Debug logging: ENABLED");
            } else {
                llOwnerSay("🔍 [Verbose Logger] Debug logging: DISABLED");
            }
            
            // Public announcement
            llSay(0, "🔍 Verbose logging system-wide: " + status);
            
            // Broadcast the new setting to all modules
            llMessageLinked(LINK_SET, MSG_VERBOSE_BROADCAST, "VERBOSE_LOGGING|" + (string)VERBOSE_LOGGING, id);
            return;
        }
        
        // Handle verbose logging broadcast from other scripts
        if (num == MSG_VERBOSE_BROADCAST) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "VERBOSE_LOGGING") {
                VERBOSE_LOGGING = llList2Integer(parts, 1);
                return;
            }
        }
        
    }
}
