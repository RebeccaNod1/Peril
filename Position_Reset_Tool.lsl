// Position Reset Tool for Peril Game Display Objects
// Drop this script in your CONTROLLER object and click it
// This will generate config values for your notecard

key controller_key;
vector controller_pos;
rotation controller_rot;

default {
    state_entry() {
        controller_key = llGetKey();
        llOwnerSay("Position Reset Tool ready - Click to scan for display objects");
        llListen(-12345, "", "", ""); // Scoreboard responses
        llListen(-12346, "", "", ""); // Leaderboard responses
        llListen(-12347, "", "", ""); // Dice responses
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == llGetOwner()) {
            controller_pos = llGetPos();
            controller_rot = llGetRot();
            
            llOwnerSay("Scanning for display objects within 20 meters...");
            
            // Send scan messages on all data channels to find display objects
            llRegionSay(-12345, "POSITION_SCAN|" + (string)controller_key); // Scoreboard
            llRegionSay(-12346, "POSITION_SCAN|" + (string)controller_key); // Leaderboard  
            llRegionSay(-12347, "POSITION_SCAN|" + (string)controller_key); // Dice
            llSetTimerEvent(3.0); // Wait 3 seconds for responses
        }
    }
    
    listen(integer channel, string name, key id, string msg) {
        if ((channel == -12345 || channel == -12346 || channel == -12347) && 
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
