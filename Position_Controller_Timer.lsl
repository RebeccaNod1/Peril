// Position Controller - Master Object
// Add this to your controller object
// When it moves, all follower objects will maintain relative positions

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

integer SYNC_CHANNEL;
vector lastPos;
rotation lastRot;

default {
    state_entry() {
        // Initialize dynamic channels
        SYNC_CHANNEL = calculateChannel(1); // ~-78000 range
        
        llOwnerSay("🔧 [Position Controller] Dynamic channel initialized: " + (string)SYNC_CHANNEL);
        llOwnerSay("Position Controller active - other objects will follow when this moves");
        lastPos = llGetPos();
        lastRot = llGetRot();
        llSetTimerEvent(0.5); // Check position every 0.5 seconds
    }

    moving_start() {
        // Optional: notify when starting to move
        llOwnerSay("Moving game system...");
    }

    moving_end() {
        // When movement stops, broadcast new position
        vector pos = llGetPos();
        rotation rot = llGetRot();
        llRegionSay(SYNC_CHANNEL, "CONTROLLER_MOVE|" + (string)llGetKey() + "|" + (string)pos + "|" + (string)rot);
        llOwnerSay("Game system repositioned");
    }

    timer() {
        vector currentPos = llGetPos();
        rotation currentRot = llGetRot();
        
        // Check if position or rotation has changed significantly
        if (llVecDist(currentPos, lastPos) > 0.01 || 
            llAngleBetween(currentRot, lastRot) > 0.01) {
            
            lastPos = currentPos;
            lastRot = currentRot;
            llRegionSay(SYNC_CHANNEL, "CONTROLLER_MOVE|" + (string)llGetKey() + "|" + (string)currentPos + "|" + (string)currentRot);
        }
    }

    on_rez(integer start_param) {
        llResetScript();
    }
}
