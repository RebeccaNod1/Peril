#include "Peril_Constants.lsl"

// === Controller Memory Monitor ===
// Handles memory monitoring and reporting for the Main Controller
// Communicates with other scripts via link messages

// Memory monitoring system
#define MEMORY_WARNING_THRESHOLD 0.8   // Warn at 80% usage
#define MEMORY_CRITICAL_THRESHOLD 0.9  // Critical at 90% usage
integer lastMemoryCheck = 0;             // Track last memory check time
#define MEMORY_CHECK_INTERVAL 60      // Check every 60 seconds

// Track main controller stats for comprehensive reporting
list mainControllerStats = [];

checkMemoryUsage(string context) {
    integer currentTime = llGetUnixTime();
    integer usedMemory = llGetUsedMemory();
    float memoryPercentage = (float)usedMemory / 65536.0; // 64KB = 65536 bytes
    
    if (memoryPercentage > MEMORY_CRITICAL_THRESHOLD) {
        dbg("📊 [Memory Monitor] 🎆 CRITICAL MEMORY: " + context + " - " + 
                   (string)usedMemory + " bytes (" + 
                   (string)llRound(memoryPercentage * 100.0) + "% of 64KB limit)");
        // Trigger emergency cleanup in main controller
        llMessageLinked(LINK_SET, MSG_EMERGENCY_CLEANUP, context, NULL_KEY);
    } else if (memoryPercentage > MEMORY_WARNING_THRESHOLD) {
        // Only warn once per interval to avoid spam
        if ((currentTime - lastMemoryCheck) >= MEMORY_CHECK_INTERVAL) {
            dbg("📊 [Memory Monitor] ⚠️ High memory in " + context + ": " + 
                       (string)usedMemory + " bytes (" + 
                       (string)llRound(memoryPercentage * 100.0) + "% of 64KB limit)");
            lastMemoryCheck = currentTime;
        }
    }
    
    // Send status to main controller
    string status = context + "|" + (string)usedMemory + "|" + (string)llRound(memoryPercentage * 100.0);
    llMessageLinked(LINK_SET, MSG_MEMORY_REPORT, status, NULL_KEY);
}

// Emergency memory cleanup function
emergencyMemoryCleanup() {
    dbg("📊 [Memory Monitor] 🎆 Emergency memory cleanup initiated!");
    
    // Clean up temporary variables and optimize lists
    mainControllerStats = [];
    
    // Force garbage collection by clearing and rebuilding critical lists
    list tempStats = mainControllerStats;
    mainControllerStats = [];
    mainControllerStats = tempStats;
    
    dbg("📊 [Memory Monitor] 🎆 Emergency cleanup complete - memory: " + 
               (string)llGetUsedMemory() + " bytes");
}

reportMemoryStats() {
    integer statsUsedMemory = llGetUsedMemory();
    float statsMemoryPercentage = (float)statsUsedMemory / 65536.0;
    
    dbg("📊 [Memory Monitor] Memory Monitor Stats:");
    dbg("📊 [Memory Monitor]   Helper Memory Used: " + (string)statsUsedMemory + " bytes (" + 
               (string)llRound(statsMemoryPercentage * 100.0) + "% of 64KB)");
    string memoryStatus;
    if (statsMemoryPercentage > MEMORY_CRITICAL_THRESHOLD) {
        memoryStatus = "CRITICAL";
    } else if (statsMemoryPercentage > MEMORY_WARNING_THRESHOLD) {
        memoryStatus = "WARNING";
    } else {
        memoryStatus = "NORMAL";
    }
    dbg("📊 [Memory Monitor]   Memory Status: " + memoryStatus);
    
    // Request main controller stats
    llMessageLinked(LINK_SET, MSG_MEMORY_STATS_REQUEST, "REQUEST_MAIN_STATS", NULL_KEY);
}

// Process main controller stats response
processMainControllerStats(string statsData) {
    list parts = llParseString2List(statsData, ["|"], []);
    if (llGetListLength(parts) >= 8) {
        integer mainMemory = (integer)llList2String(parts, 0);
        integer players = (integer)llList2String(parts, 1);
        integer names = (integer)llList2String(parts, 2);
        integer lives = (integer)llList2String(parts, 3);
        integer picksData = (integer)llList2String(parts, 4);
        integer readyPlayers = (integer)llList2String(parts, 5);
        integer pickQueue = (integer)llList2String(parts, 6);
        integer globalPicked = (integer)llList2String(parts, 7);
        integer floaterChannels = 0;
        if (llGetListLength(parts) >= 9) {
            floaterChannels = (integer)llList2String(parts, 8);
        }
        
        float mainMemoryPercentage = (float)mainMemory / 65536.0;
        
        dbg("📊 [Memory Monitor] Main Controller Stats:");
        dbg("📊 [Memory Monitor]   Main Memory Used: " + (string)mainMemory + " bytes (" + 
                   (string)llRound(mainMemoryPercentage * 100.0) + "% of 64KB)");
        dbg("📊 [Memory Monitor]   Players: " + (string)players);
        dbg("📊 [Memory Monitor]   Names: " + (string)names);
        dbg("📊 [Memory Monitor]   Lives: " + (string)lives);
        dbg("📊 [Memory Monitor]   Picks Data: " + (string)picksData);
        dbg("📊 [Memory Monitor]   Ready Players: " + (string)readyPlayers);
        dbg("📊 [Memory Monitor]   Pick Queue: " + (string)pickQueue);
        dbg("📊 [Memory Monitor]   Global Picked: " + (string)globalPicked);
        if (floaterChannels > 0) {
            dbg("📊 [Memory Monitor]   Floater Channels: " + (string)floaterChannels);
        }
    }
}

default {
    state_entry() {
        dbg("📊 [Memory Monitor] Memory Monitor ready!");
        
        // Start periodic memory monitoring
        llSetTimerEvent(MEMORY_CHECK_INTERVAL);
    }
    
    timer() {
        // Periodic memory check
        checkMemoryUsage("periodic_check");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_MEMORY_CHECK) {

            // Manual memory check request
            checkMemoryUsage(str);
        }
        else if (num == MSG_MEMORY_STATS) {
            if (str == "REQUEST_MAIN_STATS") {
                // This is a response with main controller stats
                processMainControllerStats(str);
            } else {
                // Report memory statistics
                reportMemoryStats();
            }
        }
        else if (num == MSG_MEMORY_STATS_REQUEST) {
            // Main controller is providing stats data
            processMainControllerStats(str);
        }
        else if (num == MSG_EMERGENCY_CLEANUP) {
            // Perform emergency cleanup on this helper script
            emergencyMemoryCleanup();
        }
        else if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            // Handle full game reset
            lastMemoryCheck = 0;
            mainControllerStats = [];
            dbg("📊 [Memory Monitor] 🔄 Reset complete");
        }
    }
}
