// Peril Game Display Follower Script - Config Version
// This script reads position settings from a "config" notecard
// Change DISPLAY_TYPE below to match your display object

string DISPLAY_TYPE = "scoreboard"; // Change to: "scoreboard", "leaderboard", or "dice"

// These will be loaded from config notecard
vector MY_OFFSET;
rotation MY_ROTATION; 
integer MY_CHANNEL;
integer MY_DATA_CHANNEL;

// Controller tracking
key master_key;
vector last_master_pos;
rotation last_master_rot;

// Config reading
integer config_line = 0;
key config_query;

default {
    state_entry() {
        llOwnerSay("Starting " + DISPLAY_TYPE + " follower - reading config...");
        
        // Start reading config notecard
        if (llGetInventoryType("config") == INVENTORY_NOTECARD) {
            config_query = llGetNotecardLine("config", 0);
            config_line = 0;
        } else {
            llOwnerSay("ERROR: No 'config' notecard found!");
            llOwnerSay("Please add a config notecard to this object.");
            return;
        }
    }
    
    dataserver(key query_id, string data) {
        if (query_id == config_query) {
            if (data == EOF) {
                // Finished reading config
                llOwnerSay(DISPLAY_TYPE + " config loaded. Listening for controller...");
                llListen(MY_CHANNEL, "", "", ""); // Position sync channel
                llListen(MY_DATA_CHANNEL, "", "", ""); // Data/scan channel
                llRegionSay(MY_CHANNEL, "FOLLOWER_READY|" + DISPLAY_TYPE);
            } else if (data != "") {
                // Parse config line
                data = llStringTrim(data, STRING_TRIM);
                if (llGetSubString(data, 0, 0) != "#") { // Skip comments
                    integer eq_pos = llSubStringIndex(data, "=");
                    if (eq_pos != -1) {
                        string config_key = llStringTrim(llGetSubString(data, 0, eq_pos - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(data, eq_pos + 1, -1), STRING_TRIM);
                        
                        
                        // Load values for this display type
                        if (config_key == DISPLAY_TYPE + "_offset") {
                            MY_OFFSET = (vector)value;
                        } else if (config_key == DISPLAY_TYPE + "_rotation") {
                            MY_ROTATION = (rotation)value;
                        } else if (config_key == DISPLAY_TYPE + "_channel") {
                            MY_CHANNEL = (integer)value;
                        } else if (config_key == DISPLAY_TYPE + "_data_channel") {
                            MY_DATA_CHANNEL = (integer)value;
                        }
                    }
                }
                
                // Read next line
                config_line++;
                config_query = llGetNotecardLine("config", config_line);
            } else {
                // Read next line even if this one is empty
                config_line++;
                config_query = llGetNotecardLine("config", config_line);
            }
        }
    }
    
    listen(integer channel, string name, key id, string msg) {
        if (channel == MY_CHANNEL) {
            if (llSubStringIndex(msg, "CONTROLLER_MOVE|") == 0) {
                list parts = llParseString2List(msg, ["|"], []);
                master_key = (key)llList2String(parts, 1);
                vector master_pos = (vector)llList2String(parts, 2);
                rotation master_rot = (rotation)llList2String(parts, 3);
                
                // Calculate new position
                vector new_pos = master_pos + (MY_OFFSET * master_rot);
                rotation new_rot = MY_ROTATION * master_rot;
                
                llSetPos(new_pos);
                llSetRot(new_rot);
                
                last_master_pos = master_pos;
                last_master_rot = master_rot;
            }
        } else if (channel == MY_DATA_CHANNEL) {
            if (llSubStringIndex(msg, "POSITION_SCAN|") == 0) {
                // Respond to position scan for reset tool
                llRegionSay(MY_DATA_CHANNEL, "POSITION_RESPONSE|" + DISPLAY_TYPE + "|" + 
                           (string)llGetPos() + "|" + (string)llGetRot());
            }
        }
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
}
