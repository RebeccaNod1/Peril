////////////////////////////////////////////
// Leaderboard Communication Script - Clean Version
// Based on actual link verification results
////////////////////////////////////////////

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
float MAX_CONTROLLER_DISTANCE = 75.0; // Maximum distance to accept controller (meters)
integer INITIALIZED = FALSE; // Flag to prevent multiple initializations

// Calculate channels dynamically using controller key for consistency
integer calculateChannelWithController(integer offset, key controllerKey) {
    // Use owner's key AND CONTROLLER's key to ensure all objects use same channels
    string ownerStr = (string)llGetOwner();
    string controllerStr = (string)controllerKey;
    string combinedStr = ownerStr + controllerStr;
    
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

// Dynamic channel variables
integer LEADERBOARD_CHANNEL;

// Controller discovery function
startControllerDiscovery() {
    llOwnerSay("📡 [Leaderboard] Starting controller discovery...");
    
    // Listen on discovery channel
    llListen(DISCOVERY_CHANNEL, "", "", "");
    
    // Broadcast discovery request
    llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|leaderboard");
    
    // Reset discovery attempts
    DISCOVERY_ATTEMPTS = 0;
    
    // Set timer for retry if needed
    llSetTimerEvent(5.0);
}

// Channel initialization function (with controller discovery)
initializeChannels() {
    if (CONTROLLER_KEY != NULL_KEY) {
        // Use controller-based channels for consistency
        LEADERBOARD_CHANNEL = calculateChannelWithController(7, CONTROLLER_KEY);   // ~-84000 range (matches SCOREBOARD_CHANNEL_2)
    } else {
        // Fallback to legacy channels during discovery
        LEADERBOARD_CHANNEL = calculateChannel(7);   // ~-84000 range (matches SCOREBOARD_CHANNEL_2)
    }
    
    // Report channel to owner for debugging
    llOwnerSay("🔧 [Leaderboard Bridge] Dynamic channel initialized:");
    llOwnerSay("  Leaderboard Channel: " + (string)LEADERBOARD_CHANNEL);
}

// Function to initialize after controller discovery
initializeAfterDiscovery() {
    if (CONTROLLER_KEY != NULL_KEY) {
        llOwnerSay("✅ [Leaderboard] Controller found! Initializing channels and listeners...");
    } else {
        llOwnerSay("⚠️ [Leaderboard] Initializing in legacy mode (no controller found)...");
    }
    
    // Initialize dynamic channels with controller key (or legacy channels if NULL)
    initializeChannels();
    
    // Clean up any existing listeners
    if (listenHandle != -1) {
        llListenRemove(listenHandle);
    }
    
    // Set up managed listener with dynamic channels
    listenHandle = llListen(LEADERBOARD_CHANNEL, "", "", "");
    
    // Mark as initialized to prevent repeated initialization
    INITIALIZED = TRUE;
    
    llOwnerSay("✅ Leaderboard Communication Script ready");
}
integer DISPLAY_STRING = 204000;

// Listen handle management
integer listenHandle = -1;

// Bank assignments based on actual link testing:
list leftmostLinks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];           // Links 1-12 = Leftmost bank
list middleLeftLinks = [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]; // Links 13-24 = Middle-left bank  
list middleRightLinks = [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]; // Links 25-36 = Middle-right bank
list rightmostLinks = [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48];   // Links 37-48 = Rightmost bank

string leftText = "";
string middleLeftText = "";
string middleRightText = "";
string rightText = "";

distributeToBank(string text, list linkNumbers) {
    list lines = llParseString2List(text, ["\n"], []);
    integer i;
    for (i = 0; i < llGetListLength(lines) && i < llGetListLength(linkNumbers); i++) {
        string line = llList2String(lines, i);
        // Ensure exactly 10 characters
        if (llStringLength(line) > 10) {
            line = llGetSubString(line, 0, 9);
        } else if (llStringLength(line) < 10) {
            line = line + llGetSubString("          ", 0, 9 - llStringLength(line));
        }
        integer linkNum = llList2Integer(linkNumbers, i);
        llMessageLinked(linkNum, DISPLAY_STRING, line, "");
    }
}

default {
    state_entry() {
        llOwnerSay("🎮 [Leaderboard] Starting and discovering controller...");
        
        // Start controller discovery first
        startControllerDiscovery();
    }
    
    timer() {
        // Handle controller discovery retries
        if (CONTROLLER_KEY == NULL_KEY) {
            DISCOVERY_ATTEMPTS++;
            
            if (DISCOVERY_ATTEMPTS <= MAX_DISCOVERY_ATTEMPTS) {
                llOwnerSay("⏱️ [Leaderboard] Controller discovery retry " + (string)DISCOVERY_ATTEMPTS + "/" + (string)MAX_DISCOVERY_ATTEMPTS);
                
                // Broadcast discovery request again
                llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|leaderboard");
                
                // Set timer for next retry (exponential backoff: 5s, 10s, 15s, etc.)
                llSetTimerEvent(5.0 * DISCOVERY_ATTEMPTS);
            } else {
                llOwnerSay("❌ [Leaderboard] Controller discovery failed after " + (string)MAX_DISCOVERY_ATTEMPTS + " attempts");
                llOwnerSay("   Operating in legacy mode with owner-based channels");
                
                // Stop timer and initialize with legacy channels
                llSetTimerEvent(0.0);
                initializeAfterDiscovery(); // This will use legacy channels since CONTROLLER_KEY is NULL
            }
        } else {
            // Controller found, stop timer
            llSetTimerEvent(0.0);
        }
    }
    
    listen(integer channel, string name, key id, string message) {
        // Handle controller discovery responses
        if (channel == DISCOVERY_CHANNEL) {
            if (llSubStringIndex(message, "CONTROLLER_FOUND|") == 0) {
                list parts = llParseString2List(message, ["|"], []);
                key controllerKey = (key)llList2String(parts, 1);
                
                // Check proximity - only accept nearby controllers
                vector myPos = llGetPos();
                vector controllerPos = llList2Vector(llGetObjectDetails(controllerKey, [OBJECT_POS]), 0);
                float distance = llVecDist(myPos, controllerPos);
                
                if (distance <= MAX_CONTROLLER_DISTANCE) {
                    CONTROLLER_KEY = controllerKey;
                    
                    llOwnerSay("✅ [Leaderboard] Controller discovered: " + (string)CONTROLLER_KEY + " (distance: " + (string)llRound(distance) + "m)");
                    
                    // Notify controller that we've connected
                    llRegionSay(DISCOVERY_CHANNEL, "CLIENT_CONNECTED|leaderboard|" + (string)llGetKey());
                    
                    // Cancel discovery timer
                    llSetTimerEvent(0.0);
                    
                    // Initialize with controller key
                    initializeAfterDiscovery();
                    return;
                } else {
                    llOwnerSay("📍 [Leaderboard] Controller too far (" + (string)llRound(distance) + "m > " + (string)llRound(MAX_CONTROLLER_DISTANCE) + "m), ignoring");
                }
            }
            else if (llSubStringIndex(message, "CONTROLLER_AVAILABLE|") == 0) {
                // Handle broadcast availability messages - but only if not already initialized
                if (INITIALIZED) {
                    // Already initialized, ignore repeated availability messages
                    return;
                }
                
                list parts = llParseString2List(message, ["|"], []);
                key controllerKey = (key)llList2String(parts, 1);
                
                // Check proximity - only accept nearby controllers
                vector myPos = llGetPos();
                vector controllerPos = llList2Vector(llGetObjectDetails(controllerKey, [OBJECT_POS]), 0);
                float distance = llVecDist(myPos, controllerPos);
                
                if (distance <= MAX_CONTROLLER_DISTANCE) {
                    CONTROLLER_KEY = controllerKey;
                    
                    llOwnerSay("✅ [Leaderboard] Controller available: " + (string)CONTROLLER_KEY + " (distance: " + (string)llRound(distance) + "m)");
                    
                    // Notify controller that we've connected
                    llRegionSay(DISCOVERY_CHANNEL, "CLIENT_CONNECTED|leaderboard|" + (string)llGetKey());
                    
                    // Cancel discovery timer
                    llSetTimerEvent(0.0);
                    
                    // Initialize with controller key
                    initializeAfterDiscovery();
                    return;
                } else {
                    llOwnerSay("📍 [Leaderboard] Controller too far (" + (string)llRound(distance) + "m > " + (string)llRound(MAX_CONTROLLER_DISTANCE) + "m), ignoring");
                }
            }
        }
        
        if (channel == LEADERBOARD_CHANNEL) {
            if (llGetSubString(message, 0, 9) == "LEFT_TEXT|") {
                leftText = llGetSubString(message, 10, -1);
                distributeToBank(leftText, leftmostLinks);
                
            } else if (llGetSubString(message, 0, 16) == "MIDDLE_LEFT_TEXT|") {
                middleLeftText = llGetSubString(message, 17, -1);
                distributeToBank(middleLeftText, middleLeftLinks);
                
            } else if (llGetSubString(message, 0, 17) == "MIDDLE_RIGHT_TEXT|") {
                middleRightText = llGetSubString(message, 18, -1);
                distributeToBank(middleRightText, middleRightLinks);
                
            } else if (llGetSubString(message, 0, 10) == "RIGHT_TEXT|") {
                rightText = llGetSubString(message, 11, -1);
                distributeToBank(rightText, rightmostLinks);
            }
        }
    }
}
