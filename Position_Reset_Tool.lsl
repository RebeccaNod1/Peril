// Position Reset Tool for Peril Game Display Objects
// Drop this script in your CONTROLLER object and click it
// This will generate config values for your notecard

// =============================================================================
// DYNAMIC CHANNEL CONFIGURATION
// =============================================================================

// Base channel offset - should match Main.lsl
integer CHANNEL_BASE = -77000;

// Calculate channels dynamically to avoid hardcoded conflicts
integer calculateChannel(integer offset) {
    // Use BOTH owner's key AND object's key to make channels unique per game instance
    // This prevents interference when same owner has multiple game tables
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetKey();
    string combinedStr = ownerStr + objectStr;
    
    // Create a more unique hash using both keys
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2; // Creates 0-255 range
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

key controller_key;
vector controller_pos;
rotation controller_rot;

// Dynamic channels
integer SCOREBOARD_DATA_CHANNEL;
integer LEADERBOARD_DATA_CHANNEL; 
integer DICE_DATA_CHANNEL;

// Listen handle management
integer scoreboardHandle = -1;
integer leaderboardHandle = -1;
integer diceHandle = -1;

default {
    state_entry() {
        // Initialize dynamic channels
        SCOREBOARD_DATA_CHANNEL = calculateChannel(6);  // ~-83000 range
        LEADERBOARD_DATA_CHANNEL = calculateChannel(7); // ~-84000 range
        DICE_DATA_CHANNEL = calculateChannel(8);        // ~-85000 range
        
        controller_key = llGetKey();
        llOwnerSay("🔧 [Position Reset Tool] Dynamic channels initialized:");
        llOwnerSay("  Scoreboard: " + (string)SCOREBOARD_DATA_CHANNEL);
        llOwnerSay("  Leaderboard: " + (string)LEADERBOARD_DATA_CHANNEL);
        llOwnerSay("  Dice: " + (string)DICE_DATA_CHANNEL);
        llOwnerSay("Position Reset Tool ready - Click to scan for display objects");
        
        // Clean up any existing listeners
        if (scoreboardHandle != -1) llListenRemove(scoreboardHandle);
        if (leaderboardHandle != -1) llListenRemove(leaderboardHandle);
        if (diceHandle != -1) llListenRemove(diceHandle);
        
        // Set up managed listeners with dynamic channels
        scoreboardHandle = llListen(SCOREBOARD_DATA_CHANNEL, "", "", "");
        leaderboardHandle = llListen(LEADERBOARD_DATA_CHANNEL, "", "", "");
        diceHandle = llListen(DICE_DATA_CHANNEL, "", "", "");
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == llGetOwner()) {
            controller_pos = llGetPos();
            controller_rot = llGetRot();
            
            llOwnerSay("Scanning for display objects within 20 meters...");
            
            // Send scan messages on all data channels to find display objects
            llRegionSay(SCOREBOARD_DATA_CHANNEL, "POSITION_SCAN|" + (string)controller_key);
            llRegionSay(LEADERBOARD_DATA_CHANNEL, "POSITION_SCAN|" + (string)controller_key);
            llRegionSay(DICE_DATA_CHANNEL, "POSITION_SCAN|" + (string)controller_key);
            llSetTimerEvent(3.0); // Wait 3 seconds for responses
        }
    }
    
    listen(integer channel, string name, key id, string msg) {
        if ((channel == SCOREBOARD_DATA_CHANNEL || channel == LEADERBOARD_DATA_CHANNEL || channel == DICE_DATA_CHANNEL) && 
            llSubStringIndex(msg, "POSITION_RESPONSE|") == 0) {
            list parts = llParseString2List(msg, ["|"], []);
            string object_type = llList2String(parts, 1);
            vector object_pos = (vector)llList2String(parts, 2);
            rotation object_rot = (rotation)llList2String(parts, 3);
            
            // Calculate offset and relative rotation
            vector offset = (object_pos - controller_pos) / controller_rot;
            rotation rel_rot = object_rot / controller_rot;
            
            llOwnerSay("\n=== " + llToUpper(object_type) + " CONFIG ===");
            llOwnerSay(object_type + "_offset=" + (string)offset);
            llOwnerSay(object_type + "_rotation=" + (string)rel_rot);
        }
    }
    
    timer() {
        llSetTimerEvent(0.0);
        llOwnerSay("\nScan complete. Copy values to your 'config' notecard.");
    }
}
