// Position Follower - Development Version
// This calculates the offset automatically and reports it
// Use this to find your perfect spacing, then hardcode the result

key MASTER_KEY;        
vector MY_OFFSET;      
integer SYNC_CHANNEL = -54321;
integer SETUP_DONE = FALSE;

default {
    state_entry() {
        llListen(SYNC_CHANNEL, "", "", "");
        llOwnerSay("Looking for Controller object...");
        
        // Find the master object (controller)
        llSensor("", "", ACTIVE, 96.0, PI);  // Scan for all objects
    }

    sensor(integer num_detected) {
        if (!SETUP_DONE) {
            integer i;
            for (i = 0; i < num_detected; i++) {
                string name = llDetectedName(i);
                // Look for object with "Controller" or "controller" in the name
                if (llSubStringIndex(name, "Controller") >= 0 || 
                    llSubStringIndex(name, "controller") >= 0 ||
                    llSubStringIndex(name, "CONTROLLER") >= 0) {
                    
                    MASTER_KEY = llDetectedKey(i);
                    
                    // Calculate my offset from master's current position
                    vector master_pos = llDetectedPos(i);
                    rotation master_rot = llDetectedRot(i);
                    vector my_pos = llGetPos();
                    
                    // Calculate offset in master's local coordinate system
                    MY_OFFSET = (my_pos - master_pos) / master_rot;
                    
                    // Get my initial rotation
                    rotation my_rot = llGetRot();
                    
                    SETUP_DONE = TRUE;
                    
                    // IMPORTANT: This is what you need to hardcode in the final version
                    llOwnerSay("=== OFFSET CALCULATED ===");
                    llOwnerSay("MY_OFFSET = " + (string)MY_OFFSET + ";");
                    llOwnerSay("Copy this line into your final script!");
                    llOwnerSay("========================");
                    llOwnerSay("=== ROTATION INFO ===");
                    llOwnerSay("Controller rotation: " + (string)master_rot);
                    llOwnerSay("My initial rotation: " + (string)my_rot);
                    llOwnerSay("=====================");
                    
                    return;
                }
            }
            
            if (!SETUP_DONE) {
                llOwnerSay("Controller object not found! Make sure it has 'controller' in the name.");
                llSetTimerEvent(5.0); // Try again in 5 seconds
            }
        }
    }

    timer() {
        llSetTimerEvent(0.0);
        llSensor("", "", ACTIVE, 96.0, PI);
    }

    no_sensor() {
        llOwnerSay("No objects detected nearby. Make sure Controller is within 96m.");
        llSetTimerEvent(5.0);
    }

    listen(integer channel, string name, key id, string message) {
        if (SETUP_DONE && id == MASTER_KEY && llSubStringIndex(message, "CONTROLLER_MOVED|") == 0) {
            list parts = llParseString2List(message, ["|"], []);
            vector master_pos = (vector)llList2String(parts, 1);
            rotation master_rot = (rotation)llList2String(parts, 2);
            
            vector new_pos = master_pos + (MY_OFFSET * master_rot);
            llSetPos(new_pos);
            llSetRot(master_rot);
            
            llOwnerSay("Following controller to: " + (string)new_pos);
        }
    }
}
