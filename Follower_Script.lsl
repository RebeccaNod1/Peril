// Peril Game Display Follower Script - Config Version
// This script reads position settings from a "config" notecard
// Change DISPLAY_TYPE below to match your display object

string DISPLAY_TYPE = "scoreboard"; // Change to: "scoreboard", "leaderboard", or "dice"

// =============================================================================
// CONTROLLER DISCOVERY SYSTEM
// =============================================================================

// Fixed discovery channel for finding controller
integer DISCOVERY_CHANNEL = -77000;

// Base channel offset - should match Main.lsl
integer CHANNEL_BASE = -77000;

// Controller discovery state
key CONTROLLER_KEY = NULL_KEY;
integer DISCOVERY_ATTEMPTS = 0;
integer MAX_DISCOVERY_ATTEMPTS = 10;
integer AUTO_CONFIG_ATTEMPTS = 0;
integer MAX_AUTO_CONFIG_ATTEMPTS = 5;
integer INITIALIZED = FALSE; // Flag to prevent multiple initializations

// Calculate channels dynamically using controller key for consistency
integer calculateChannelWithController(integer offset, key controllerKey) {
    // Use owner's key AND CONTROLLER's object key to ensure all objects use same channels
    // This should match the calculateChannel method in Controller_Discovery.lsl
    string ownerStr = (string)llGetOwner();
    string controllerObjStr = (string)controllerKey; // This is the controller object key
    string combinedStr = ownerStr + controllerObjStr;
    
    // Create a more unique hash using both keys
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2; // Creates 0-255 range
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Legacy function for backward compatibility (uses own key)
integer calculateChannel(integer offset) {
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetKey();
    string combinedStr = ownerStr + objectStr;
    
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2;
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Channel mapping for different display types (with controller discovery)
integer getDataChannelForType(string displayType) {
    if (CONTROLLER_KEY != NULL_KEY) {
        // Use controller-based channels for consistency
        if (displayType == "scoreboard") return calculateChannelWithController(6, CONTROLLER_KEY);  // SCOREBOARD_CHANNEL_1
        else if (displayType == "leaderboard") return calculateChannelWithController(7, CONTROLLER_KEY); // SCOREBOARD_CHANNEL_2 
        else if (displayType == "dice") return calculateChannelWithController(8, CONTROLLER_KEY); // SCOREBOARD_CHANNEL_3
        else return calculateChannelWithController(1, CONTROLLER_KEY); // Default to sync channel
    } else {
        // Fallback to legacy calculation during discovery
        if (displayType == "scoreboard") return calculateChannel(6);  // SCOREBOARD_CHANNEL_1
        else if (displayType == "leaderboard") return calculateChannel(7); // SCOREBOARD_CHANNEL_2 
        else if (displayType == "dice") return calculateChannel(8); // SCOREBOARD_CHANNEL_3
        else return calculateChannel(1); // Default to sync channel
    }
}

// Controller discovery function
startControllerDiscovery() {
    llOwnerSay("📡 [" + DISPLAY_TYPE + "] Starting controller discovery...");
    
    // Listen on discovery channel
    llListen(DISCOVERY_CHANNEL, "", "", "");
    
    // Broadcast discovery request
    llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|" + DISPLAY_TYPE);
    
    // Reset discovery attempts
    DISCOVERY_ATTEMPTS = 0;
    
    // Set timer for retry if needed
    llSetTimerEvent(5.0);
}

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

// Function to initialize channels and config after controller discovery
initializeAfterDiscovery() {
    if (CONTROLLER_KEY != NULL_KEY) {
        llOwnerSay("🆗 [" + DISPLAY_TYPE + "] Controller found! Initializing channels...");
    } else {
        llOwnerSay("⚠️ [" + DISPLAY_TYPE + "] Initializing in legacy mode (no controller found)...");
    }
    
    // Update channels with controller key (or legacy channels if NULL)
    if (CONTROLLER_KEY != NULL_KEY) {
        MY_CHANNEL = calculateChannelWithController(1, CONTROLLER_KEY); // Position sync channel
        MY_DATA_CHANNEL = getDataChannelForType(DISPLAY_TYPE);
    } else {
        // Use legacy channels when no controller found
        MY_CHANNEL = calculateChannel(1); // Position sync channel
        MY_DATA_CHANNEL = getDataChannelForType(DISPLAY_TYPE); // This will use legacy calculation
    }
    
    llOwnerSay("🔧 [" + DISPLAY_TYPE + "] Dynamic channels initialized:");
    llOwnerSay("  Position sync: " + (string)MY_CHANNEL);
    llOwnerSay("  Data channel: " + (string)MY_DATA_CHANNEL);
    
    // Start reading config notecard or use auto-detection
    if (llGetInventoryType("config") == INVENTORY_NOTECARD) {
        llOwnerSay("📜 Reading config notecard...");
        config_query = llGetNotecardLine("config", 0);
        config_line = 0;
    } else if (CONTROLLER_KEY != NULL_KEY) {
        // Only try auto-detection if we have a controller
        llOwnerSay("⚠️ No 'config' notecard found - using auto-detection mode!");
        llOwnerSay("📍 Looking for controller to auto-configure position...");
        
        // Set up listeners for auto-detection with correct channels
        llListen(MY_CHANNEL, "", "", ""); // Position sync channel
        llListen(MY_DATA_CHANNEL, "", "", ""); // Data/scan channel
        
        // Request auto-configuration from controller
        llRegionSay(MY_DATA_CHANNEL, "AUTO_CONFIG_REQUEST|" + DISPLAY_TYPE + "|" + 
                   (string)llGetPos() + "|" + (string)llGetRot());
        
        // Reset auto-config retry counter
        AUTO_CONFIG_ATTEMPTS = 0;
        
        // Set a timer to retry if no response
        llSetTimerEvent(5.0);
    } else {
        // No controller and no config - just set up basic listeners in legacy mode
        llOwnerSay("⚠️ [" + DISPLAY_TYPE + "] No controller or config found - legacy mode with default positioning");
        
        // Set up listeners for legacy mode
        llListen(MY_CHANNEL, "", "", ""); // Position sync channel
        llListen(MY_DATA_CHANNEL, "", "", ""); // Data/scan channel
        
        // Set default positioning values
        MY_OFFSET = <0.0, 0.0, 0.0>;
        MY_ROTATION = <0.0, 0.0, 0.0, 1.0>;
        
        llOwnerSay("🔄 [" + DISPLAY_TYPE + "] Ready in legacy mode - listening for position updates");
    }
    
    // Mark as initialized to prevent repeated initialization
    INITIALIZED = TRUE;
}

default {
    state_entry() {
        llOwnerSay("🎮 Starting " + DISPLAY_TYPE + " follower - discovering controller...");
        
        // Start controller discovery first
        startControllerDiscovery();
    }
    
    dataserver(key query_id, string data) {
        if (query_id == config_query) {
            if (data == EOF) {
                // Finished reading config
                llOwnerSay("🔧 [" + DISPLAY_TYPE + " Follower] Dynamic channels initialized:");
                llOwnerSay("  Position sync: " + (string)MY_CHANNEL);
                llOwnerSay("  Data channel: " + (string)MY_DATA_CHANNEL);
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
                            if (value == "DYNAMIC") {
                                MY_CHANNEL = calculateChannel(1); // Position sync channel
                            } else {
                                MY_CHANNEL = (integer)value; // Legacy hardcoded channel
                            }
                        } else if (config_key == DISPLAY_TYPE + "_data_channel") {
                            if (llSubStringIndex(value, "DYNAMIC") == 0) {
                                MY_DATA_CHANNEL = getDataChannelForType(DISPLAY_TYPE);
                            } else {
                                MY_DATA_CHANNEL = (integer)value; // Legacy hardcoded channel
                            }
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
        // Handle controller discovery responses
        if (channel == DISCOVERY_CHANNEL) {
            if (llSubStringIndex(msg, "CONTROLLER_FOUND|") == 0) {
                list parts = llParseString2List(msg, ["|"], []);
                CONTROLLER_KEY = (key)llList2String(parts, 1);
                
                llOwnerSay("✅ [" + DISPLAY_TYPE + "] Controller discovered: " + (string)CONTROLLER_KEY);
                
                // Cancel discovery timer
                llSetTimerEvent(0.0);
                
                // Initialize with controller key
                initializeAfterDiscovery();
                return;
            }
            else if (llSubStringIndex(msg, "CONTROLLER_AVAILABLE|") == 0) {
                // Handle broadcast availability messages - but only if not already initialized
                if (INITIALIZED) {
                    // Already initialized, ignore repeated availability messages
                    return;
                }
                
                list parts = llParseString2List(msg, ["|"], []);
                CONTROLLER_KEY = (key)llList2String(parts, 1);
                
                llOwnerSay("✅ [" + DISPLAY_TYPE + "] Controller available: " + (string)CONTROLLER_KEY);
                
                // Cancel discovery timer
                llSetTimerEvent(0.0);
                
                // Initialize with controller key
                initializeAfterDiscovery();
                return;
            }
        }
        
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
            else if (llSubStringIndex(msg, "POSITION_UPDATE|") == 0) {
                // Handle automatic position updates from integrated reset tool
                list parts = llParseString2List(msg, ["|"], []);
                if (llGetListLength(parts) >= 4) {
                    string updateType = llList2String(parts, 1);
                    if (updateType == DISPLAY_TYPE) {
                        vector newOffset = (vector)llList2String(parts, 2);
                        rotation newRotation = (rotation)llList2String(parts, 3);
                        
                        // Update our stored offset and rotation
                        MY_OFFSET = newOffset;
                        MY_ROTATION = newRotation;
                        
                        llOwnerSay("✨ " + DISPLAY_TYPE + " position updated automatically!");
                        llOwnerSay("New offset: " + (string)MY_OFFSET);
                        llOwnerSay("New rotation: " + (string)MY_ROTATION);
                        
                        // If we have a master position, update our position immediately
                        if (master_key != NULL_KEY) {
                            vector new_pos = last_master_pos + (MY_OFFSET * last_master_rot);
                            rotation new_rot = MY_ROTATION * last_master_rot;
                            llSetPos(new_pos);
                            llSetRot(new_rot);
                            llOwnerSay("🎥 Moved to new position!");
                        }
                        
                        // Cancel retry timer if we got a successful update
                        llSetTimerEvent(0.0);
                    }
                }
            }
            else if (llSubStringIndex(msg, "AUTO_CONFIG_RESPONSE|") == 0) {
                // Handle automatic configuration response from controller
                list parts = llParseString2List(msg, ["|"], []);
                if (llGetListLength(parts) >= 4) {
                    string responseType = llList2String(parts, 1);
                    if (responseType == DISPLAY_TYPE) {
                        vector autoOffset = (vector)llList2String(parts, 2);
                        rotation autoRotation = (rotation)llList2String(parts, 3);
                        
                        // Set our position values from auto-detection
                        MY_OFFSET = autoOffset;
                        MY_ROTATION = autoRotation;
                        
                        llOwnerSay("🎆 " + DISPLAY_TYPE + " auto-configured successfully!");
                        llOwnerSay("Auto-detected offset: " + (string)MY_OFFSET);
                        llOwnerSay("Auto-detected rotation: " + (string)MY_ROTATION);
                        llOwnerSay("🟢 Ready and listening for controller movement...");
                        
                        // Cancel retry timer
                        llSetTimerEvent(0.0);
                        
                        // Announce readiness
                        llRegionSay(MY_CHANNEL, "FOLLOWER_READY|" + DISPLAY_TYPE);
                    }
                }
            }
        }
    }
    
    timer() {
        if (CONTROLLER_KEY == NULL_KEY) {
            // Still in controller discovery phase
            DISCOVERY_ATTEMPTS++;
            
            if (DISCOVERY_ATTEMPTS <= MAX_DISCOVERY_ATTEMPTS) {
                llOwnerSay("🔄 [" + DISPLAY_TYPE + "] Retrying controller discovery (attempt " + 
                          (string)DISCOVERY_ATTEMPTS + "/" + (string)MAX_DISCOVERY_ATTEMPTS + ")...");
                
                // Retry controller discovery
                llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|" + DISPLAY_TYPE);
                
                // Set timer for next retry (exponential backoff)
                float retryDelay = 5.0 * DISCOVERY_ATTEMPTS; // 5s, 10s, 15s, etc.
                llSetTimerEvent(retryDelay);
            } else {
                llOwnerSay("❌ [" + DISPLAY_TYPE + "] Controller discovery failed after " + 
                          (string)MAX_DISCOVERY_ATTEMPTS + " attempts");
                llOwnerSay("   Operating in legacy mode with owner-based channels");
                
                // Stop timer and initialize with legacy channels
                llSetTimerEvent(0.0);
                initializeAfterDiscovery(); // This will use legacy channels since CONTROLLER_KEY is NULL
            }
        } else {
            // Controller found, retry auto-configuration request with limit
            AUTO_CONFIG_ATTEMPTS++;
            
            if (AUTO_CONFIG_ATTEMPTS <= MAX_AUTO_CONFIG_ATTEMPTS) {
                llOwnerSay("🔄 [" + DISPLAY_TYPE + "] No auto-config response - retrying (" + 
                          (string)AUTO_CONFIG_ATTEMPTS + "/" + (string)MAX_AUTO_CONFIG_ATTEMPTS + ")...");
                
                if (MY_DATA_CHANNEL != 0) {
                    llRegionSay(MY_DATA_CHANNEL, "AUTO_CONFIG_REQUEST|" + DISPLAY_TYPE + "|" + 
                               (string)llGetPos() + "|" + (string)llGetRot());
                } else {
                    llOwnerSay("⚠️ [" + DISPLAY_TYPE + "] Data channel not initialized yet!");
                }
                
                // Set timer for next retry (10 seconds)
                llSetTimerEvent(10.0);
            } else {
                llOwnerSay("❌ [" + DISPLAY_TYPE + "] Auto-config failed after " + (string)MAX_AUTO_CONFIG_ATTEMPTS + " attempts");
                llOwnerSay("🔄 [" + DISPLAY_TYPE + "] Using default position - ready for manual configuration");
                
                // Stop timer and set default positioning
                llSetTimerEvent(0.0);
                
                // Set default positioning values
                MY_OFFSET = <0.0, 0.0, 0.0>;
                MY_ROTATION = <0.0, 0.0, 0.0, 1.0>;
                
                // Announce readiness with default positioning
                llRegionSay(MY_CHANNEL, "FOLLOWER_READY|" + DISPLAY_TYPE);
                llOwnerSay("🛫 [" + DISPLAY_TYPE + "] Ready and listening for controller movement (default position)");
            }
        }
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
}
