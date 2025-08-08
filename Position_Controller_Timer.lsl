// Position Controller - Master Object
// Add this to your controller object
// When it moves, all follower objects will maintain relative positions

integer SYNC_CHANNEL = -54321;
vector lastPos;
rotation lastRot;

default {
    state_entry() {
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
