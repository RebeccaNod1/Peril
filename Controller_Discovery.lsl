// === Controller Discovery Helper ===
// Handles all controller discovery functionality for the Main Controller
// Also handles automatic position configuration for newly rezzed displays
// Communicates with other scripts via link messages

// =============================================================================
// DYNAMIC CHANNEL & DISCOVERY SYSTEM
// =============================================================================

// Fixed discovery channel for client objects to find controller
integer DISCOVERY_CHANNEL = -77000;

// Base channel offset - should match other controller scripts
integer CHANNEL_BASE = -77000;

// Calculate channels dynamically to avoid hardcoded conflicts
integer calculateChannel(integer offset) {
    // Use BOTH owner's key AND object's key to make channels unique per game instance
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

// Dynamic channel variables for auto-config communication
integer SCOREBOARD_DATA_CHANNEL;
integer LEADERBOARD_DATA_CHANNEL; 
integer DICE_DATA_CHANNEL;

// Client connection tracking
list connectedClients = [];      // List of client object keys that have connected
list expectedClientTypes = ["scoreboard", "leaderboard", "dice"]; // Expected client types
integer discoveryBroadcastActive = TRUE;
float DISCOVERY_BROADCAST_INTERVAL = 30.0;  // Broadcast availability every 30 seconds

// Message constants for inter-script communication
integer MSG_DISCOVERY_START = 5001;
integer MSG_DISCOVERY_STOP = 5002;
integer MSG_CLIENT_CONNECTED = 5003;
integer MSG_DISCOVERY_STATUS = 5004;

// Channel initialization function
initializeChannels() {
    SCOREBOARD_DATA_CHANNEL = calculateChannel(6);  // ~-83000 range
    LEADERBOARD_DATA_CHANNEL = calculateChannel(7); // ~-84000 range
    DICE_DATA_CHANNEL = calculateChannel(8);        // ~-85000 range
    
    // Report channels for debugging
    llOwnerSay("🔧 [Discovery] Auto-config channels initialized:");
    llOwnerSay("  Scoreboard: " + (string)SCOREBOARD_DATA_CHANNEL);
    llOwnerSay("  Leaderboard: " + (string)LEADERBOARD_DATA_CHANNEL);
    llOwnerSay("  Dice: " + (string)DICE_DATA_CHANNEL);
}

default {
    state_entry() {
        llOwnerSay("📡 [Discovery] Controller Discovery Helper ready!");
        
        // Initialize auto-config channels
        initializeChannels();
        
        // Listen on discovery channel for external objects seeking controller
        llListen(DISCOVERY_CHANNEL, "", "", "");
        
        // Listen on data channels for auto-config requests
        llListen(SCOREBOARD_DATA_CHANNEL, "", "", "");
        llListen(LEADERBOARD_DATA_CHANNEL, "", "", "");
        llListen(DICE_DATA_CHANNEL, "", "", "");
        
        // Start broadcasting controller availability
        discoveryBroadcastActive = TRUE;
        llOwnerSay("📺 [Discovery] Broadcasting controller availability...");
        llRegionSay(DISCOVERY_CHANNEL, "CONTROLLER_AVAILABLE|" + (string)llGetKey()); // Use controller object key
        
        // Set timer to periodically announce availability
        llSetTimerEvent(DISCOVERY_BROADCAST_INTERVAL);
        
        // Notify main controller that discovery is active
        llMessageLinked(LINK_SET, MSG_DISCOVERY_STATUS, "ACTIVE|" + (string)llGetListLength(connectedClients), NULL_KEY);
    }
    
    listen(integer channel, string name, key id, string msg) {
        if (channel == DISCOVERY_CHANNEL) {
            if (llSubStringIndex(msg, "FIND_CONTROLLER|") == 0) {
                list parts = llParseString2List(msg, ["|"], []);
                string objectType = llList2String(parts, 1);
                string controllerKey = (string)llGetKey(); // Use actual controller object key
                
                llOwnerSay("📡 [Discovery] Request from " + objectType + " (" + (string)id + ")");
                llRegionSayTo(id, DISCOVERY_CHANNEL, "CONTROLLER_FOUND|" + controllerKey);
                
                llOwnerSay("📡 [Discovery] Sent controller key to " + objectType + ": " + controllerKey);
            }
            else if (llSubStringIndex(msg, "CLIENT_CONNECTED|") == 0) {
                // Handle client connection notifications
                list parts = llParseString2List(msg, ["|"], []);
                if (llGetListLength(parts) >= 3) {
                    string clientType = llList2String(parts, 1);
                    key clientKey = (key)llList2String(parts, 2);
                    
                    // Track connected client
                    if (llListFindList(connectedClients, [clientKey]) == -1) {
                        connectedClients += [clientKey];
                        llOwnerSay("✅ [Discovery] " + clientType + " connected (" + (string)clientKey + ")");
                        llOwnerSay("🔗 [Discovery] Connected clients: " + (string)llGetListLength(connectedClients));
                        
                        // Notify main controller of connection
                        llMessageLinked(LINK_SET, MSG_CLIENT_CONNECTED, clientType + "|" + (string)clientKey, NULL_KEY);
                        
                        // Check if we should stop broadcasting
                        if (llGetListLength(connectedClients) >= llGetListLength(expectedClientTypes)) {
                            llOwnerSay("🎯 [Discovery] All expected clients connected - stopping broadcasts");
                            discoveryBroadcastActive = FALSE;
                            llSetTimerEvent(0.0);
                            
                            // Notify main controller that discovery is complete
                            llMessageLinked(LINK_SET, MSG_DISCOVERY_STATUS, "COMPLETE|" + (string)llGetListLength(connectedClients), NULL_KEY);
                        } else {
                            // Update status
                            llMessageLinked(LINK_SET, MSG_DISCOVERY_STATUS, "ACTIVE|" + (string)llGetListLength(connectedClients), NULL_KEY);
                        }
                    }
                }
            }
        }
        // Handle automatic configuration requests from newly rezzed displays
        else if ((channel == SCOREBOARD_DATA_CHANNEL || channel == LEADERBOARD_DATA_CHANNEL || channel == DICE_DATA_CHANNEL) &&
                 llSubStringIndex(msg, "AUTO_CONFIG_REQUEST|") == 0) {
            
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 4) {
                string requestType = llList2String(parts, 1);
                vector displayPos = (vector)llList2String(parts, 2);
                rotation displayRot = (rotation)llList2String(parts, 3);
                
                // Calculate offset and rotation relative to controller
                vector controller_current_pos = llGetPos();
                rotation controller_current_rot = llGetRot();
                
                vector calculatedOffset = (displayPos - controller_current_pos) / controller_current_rot;
                rotation calculatedRotation = displayRot / controller_current_rot;
                
                // Send auto-config response back to the display on the correct channel
                integer responseChannel;
                if (requestType == "scoreboard") responseChannel = SCOREBOARD_DATA_CHANNEL;
                else if (requestType == "leaderboard") responseChannel = LEADERBOARD_DATA_CHANNEL;
                else if (requestType == "dice") responseChannel = DICE_DATA_CHANNEL;
                else return; // Unknown display type
                
                string responseMsg = "AUTO_CONFIG_RESPONSE|" + requestType + "|" + 
                                   (string)calculatedOffset + "|" + (string)calculatedRotation;
                llRegionSay(responseChannel, responseMsg);
                
                llOwnerSay("🎆 [Discovery] Auto-configured " + requestType + " display at rez!");
                llOwnerSay("   Position: " + (string)displayPos);
                llOwnerSay("   Calculated offset: " + (string)calculatedOffset);
                llOwnerSay("   Calculated rotation: " + (string)calculatedRotation);
            }
        }
    }
    
    timer() {
        if (discoveryBroadcastActive) {
            // Broadcast controller availability
            llRegionSay(DISCOVERY_CHANNEL, "CONTROLLER_AVAILABLE|" + (string)llGetKey());
            llSetTimerEvent(DISCOVERY_BROADCAST_INTERVAL);
        } else {
            llSetTimerEvent(0.0);
        }
    }
    
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_DISCOVERY_START) {
            // Restart discovery broadcasts
            discoveryBroadcastActive = TRUE;
            llOwnerSay("📺 [Discovery] Restarting broadcasts");
            llRegionSay(DISCOVERY_CHANNEL, "CONTROLLER_AVAILABLE|" + (string)llGetKey());
            llSetTimerEvent(DISCOVERY_BROADCAST_INTERVAL);
        }
        else if (num == MSG_DISCOVERY_STOP) {
            // Stop discovery broadcasts
            discoveryBroadcastActive = FALSE;
            llSetTimerEvent(0.0);
            llOwnerSay("⏹️ [Discovery] Broadcasts stopped");
        }
        else if (num == -99999 && str == "FULL_RESET") {
            // Handle full game reset
            connectedClients = [];
            discoveryBroadcastActive = TRUE;
            llOwnerSay("🔄 [Discovery] Reset - restarting broadcasts");
            llRegionSay(DISCOVERY_CHANNEL, "CONTROLLER_AVAILABLE|" + (string)llGetKey());
            llSetTimerEvent(DISCOVERY_BROADCAST_INTERVAL);
            llMessageLinked(LINK_SET, MSG_DISCOVERY_STATUS, "ACTIVE|0", NULL_KEY);
        }
    }
}
