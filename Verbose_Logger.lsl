// === Verbose Logger - Dedicated Debug Output Handler ===
// This script handles all verbose logging to reduce memory usage in Main Controller
// and other core game scripts

// Verbose logging control
integer VERBOSE_LOGGING = FALSE;

// Message constants for verbose logging system
integer MSG_VERBOSE_LOG = 9020;           // Request to log a message
integer MSG_VERBOSE_TOGGLE = 9010;        // Toggle verbose logging on/off
integer MSG_VERBOSE_BROADCAST = 9011;     // Broadcast logging state to all modules

// Memory monitoring
integer MSG_MEMORY_REPORT_VERBOSE = 9025;

// Script identification for log prefixes
list SCRIPT_PREFIXES = [
    "Main", "Game", "Dialog", "Roll", "Bot", "Float", "Calc", 
    "Mem", "Msg", "Score", "Lead", "Dice", "Debug", "Num"
];

// Buffer for batching messages to reduce spam
list messageBuffer = [];
integer BUFFER_SIZE = 5;
float FLUSH_INTERVAL = 2.0;

// Flush all buffered messages to owner
flushMessageBuffer() {
    if (llGetListLength(messageBuffer) == 0) return;
    
    integer i;
    for (i = 0; i < llGetListLength(messageBuffer); i++) {
        llOwnerSay(llList2String(messageBuffer, i));
    }
    messageBuffer = [];
}

// Report memory status of this script
reportMemoryStatus() {
    if (VERBOSE_LOGGING) {
        integer free = llGetFreeMemory();
        integer used = llGetUsedMemory();
        llOwnerSay("🔍 [Verbose Logger] Memory - Free: " + (string)free + " Used: " + (string)used);
        llOwnerSay("🔍 [Verbose Logger] Buffer size: " + (string)llGetListLength(messageBuffer));
    }
}

default {
    state_entry() {
        llOwnerSay("🔍 Verbose Logger initialized - ready to handle debug output");
        llSetTimerEvent(FLUSH_INTERVAL);
    }
    
    on_rez(integer start_param) {
        llOwnerSay("🔍 Verbose Logger rezzed - debug system ready");
        VERBOSE_LOGGING = FALSE; // Default to off after rez
        messageBuffer = [];
        llSetTimerEvent(FLUSH_INTERVAL);
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle
        if (num == MSG_VERBOSE_TOGGLE && str == "TOGGLE_VERBOSE_LOGS") {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            
            string status = "OFF";
            if (VERBOSE_LOGGING) {
                status = "ON";
                llOwnerSay("🔍 [Verbose Logger] Debug logging: ENABLED");
            } else {
                llOwnerSay("🔍 [Verbose Logger] Debug logging: DISABLED");
                messageBuffer = []; // Clear buffer when disabled
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
        
        // Handle log message requests
        if (num == MSG_VERBOSE_LOG && VERBOSE_LOGGING) {
            // Format: "SCRIPT_ID|MESSAGE"
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                integer scriptId = llList2Integer(parts, 0);
                string message = llList2String(parts, 1);
                
                string prefix = "[Unknown]";
                if (scriptId >= 0 && scriptId < llGetListLength(SCRIPT_PREFIXES)) {
                    prefix = "[" + llList2String(SCRIPT_PREFIXES, scriptId) + "]";
                }
                
                string logMessage = prefix + " " + message;
                
                // Add to buffer for batched output
                messageBuffer += [logMessage];
                
                // If buffer is full, flush immediately
                if (llGetListLength(messageBuffer) >= BUFFER_SIZE) {
                    flushMessageBuffer();
                }
            }
            return;
        }
        
        // Handle memory report request
        if (num == MSG_MEMORY_REPORT_VERBOSE) {
            reportMemoryStatus();
            return;
        }
    }
    
    timer() {
        // Periodic buffer flush
        if (VERBOSE_LOGGING && llGetListLength(messageBuffer) > 0) {
            flushMessageBuffer();
        }
    }
}
