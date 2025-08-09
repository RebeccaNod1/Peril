// XyzzyText Bridge Script - Dice Display Bridge
// This script goes in the ROOT prim of the linked dice display XyzzyText object
// Works with official XyzzyText v2.1 (10-char) script
// Handles dice roll display across 1 bank (20 characters total)

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

// Dynamic channel variables
integer DICE_CHANNEL;

// Controller discovery function
startControllerDiscovery() {
    llOwnerSay("📡 [Dice] Starting controller discovery...");
    
    // Listen on discovery channel
    llListen(DISCOVERY_CHANNEL, "", "", "");
    
    // Broadcast discovery request
    llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|dice");
    
    // Reset discovery attempts
    DISCOVERY_ATTEMPTS = 0;
    
    // Set timer for retry if needed
    llSetTimerEvent(5.0);
}

// Channel initialization function (with controller discovery)
initializeChannels() {
    if (CONTROLLER_KEY != NULL_KEY) {
        // Use controller-based channels for consistency
        DICE_CHANNEL = calculateChannelWithController(8, CONTROLLER_KEY);   // ~-85000 range (matches SCOREBOARD_CHANNEL_3)
    } else {
        // Fallback to legacy channels during discovery
        DICE_CHANNEL = calculateChannel(8);   // ~-85000 range (matches SCOREBOARD_CHANNEL_3)
    }
    
    // Report channel to owner for debugging
    llOwnerSay("🔧 [Dice Bridge] Dynamic channel initialized:");
    llOwnerSay("  Dice Channel: " + (string)DICE_CHANNEL);
}

// Function to initialize after controller discovery
initializeAfterDiscovery() {
    if (CONTROLLER_KEY != NULL_KEY) {
        llOwnerSay("✅ [Dice] Controller found! Initializing channels and listeners...");
    } else {
        llOwnerSay("⚠️ [Dice] Initializing in legacy mode (no controller found)...");
    }
    
    // Initialize dynamic channels with controller key (or legacy channels if NULL)
    initializeChannels();
    
    // Clean up any existing listeners
    if (listenHandle != -1) {
        llListenRemove(listenHandle);
    }
    
    // Set up managed listener with dynamic channels
    listenHandle = llListen(DICE_CHANNEL, "", "", "");
    
    // Initialize variables
    currentLeftText = "";
    currentRightText = "";
    
    // Initialize XyzzyText bank with blank text (20 spaces)
    llMessageLinked(LINK_THIS, DISPLAY_STRING, "                    ", (key)((string)DICE_BANK));
    
    // Mark as initialized to prevent repeated initialization
    INITIALIZED = TRUE;
    
    llOwnerSay("✅ Dice Display Bridge ready - listening on channel " + (string)DICE_CHANNEL);
    llOwnerSay("Using dice bank: " + (string)DICE_BANK + " (20 characters across 2 prims)");
    llOwnerSay("Make sure prims are named: xyzzytext-0-0, xyzzytext-0-1");
}
integer DISPLAY_STRING = 204000;
integer DISPLAY_EXTENDED = 204001;

// Listen handle management
integer listenHandle = -1;

// Bank configuration for XyzzyText v2.1
// Single bank with 2 prims: xyzzytext-0-0 (chars 1-10), xyzzytext-0-1 (chars 11-20)
integer DICE_BANK = 0;   // Single bank for dice display (20 characters total)

// Storage for combining left and right parts
string currentLeftText = "";
string currentRightText = "";

// Function to combine and display the dice text
displayDiceText() {
    string fullText = currentLeftText + currentRightText;
    
    // Ensure exactly 20 characters
    while (llStringLength(fullText) < 20) {
        fullText += " ";
    }
    if (llStringLength(fullText) > 20) {
        fullText = llGetSubString(fullText, 0, 19);
    }
    
    // Send to XyzzyText bank
    llMessageLinked(LINK_THIS, DISPLAY_STRING, fullText, (key)((string)DICE_BANK));
    
    
    // Clear the stored parts for next message
    currentLeftText = "";
    currentRightText = "";
}

default {
    state_entry() {
        llOwnerSay("🎮 [Dice] Starting and discovering controller...");
        
        // Start controller discovery first
        startControllerDiscovery();
    }
    
    timer() {
        // Handle controller discovery retries and test display clearing
        if (CONTROLLER_KEY == NULL_KEY) {
            DISCOVERY_ATTEMPTS++;
            
            if (DISCOVERY_ATTEMPTS <= MAX_DISCOVERY_ATTEMPTS) {
                llOwnerSay("⏱️ [Dice] Controller discovery retry " + (string)DISCOVERY_ATTEMPTS + "/" + (string)MAX_DISCOVERY_ATTEMPTS);
                
                // Broadcast discovery request again
                llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|dice");
                
                // Set timer for next retry (exponential backoff: 5s, 10s, 15s, etc.)
                llSetTimerEvent(5.0 * DISCOVERY_ATTEMPTS);
            } else {
                llOwnerSay("❌ [Dice] Controller discovery failed after " + (string)MAX_DISCOVERY_ATTEMPTS + " attempts");
                llOwnerSay("   Operating in legacy mode with owner-based channels");
                
                // Stop timer and initialize with legacy channels
                llSetTimerEvent(0.0);
                initializeAfterDiscovery(); // This will use legacy channels since CONTROLLER_KEY is NULL
            }
        } else {
            // Timer used for test display clearing
            llSetTimerEvent(0.0); // Stop timer
            // Clear test display (20 spaces)
            llMessageLinked(LINK_THIS, DISPLAY_STRING, "                    ", (key)((string)DICE_BANK));
            llOwnerSay("Test display cleared.");
        }
    }
    
    listen(integer channel, string senderName, key id, string message) {
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
                    
                    llOwnerSay("✅ [Dice] Controller discovered: " + (string)CONTROLLER_KEY + " (distance: " + (string)llRound(distance) + "m)");
                    
                    // Notify controller that we've connected
                    llRegionSay(DISCOVERY_CHANNEL, "CLIENT_CONNECTED|dice|" + (string)llGetKey());
                    
                    // Cancel discovery timer
                    llSetTimerEvent(0.0);
                    
                    // Initialize with controller key
                    initializeAfterDiscovery();
                    return;
                } else {
                    llOwnerSay("📍 [Dice] Controller too far (" + (string)llRound(distance) + "m > " + (string)llRound(MAX_CONTROLLER_DISTANCE) + "m), ignoring");
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
                    
                    llOwnerSay("✅ [Dice] Controller available: " + (string)CONTROLLER_KEY + " (distance: " + (string)llRound(distance) + "m)");
                    
                    // Notify controller that we've connected
                    llRegionSay(DISCOVERY_CHANNEL, "CLIENT_CONNECTED|dice|" + (string)llGetKey());
                    
                    // Cancel discovery timer
                    llSetTimerEvent(0.0);
                    
                    // Initialize with controller key
                    initializeAfterDiscovery();
                    return;
                } else {
                    llOwnerSay("📍 [Dice] Controller too far (" + (string)llRound(distance) + "m > " + (string)llRound(MAX_CONTROLLER_DISTANCE) + "m), ignoring");
                }
            }
        }
        
        if (channel == DICE_CHANNEL) {
            if (llSubStringIndex(message, "DICE_LEFT|") == 0) {
                // Store the left part (characters 0-9)
                currentLeftText = llGetSubString(message, 10, -1); // Remove "DICE_LEFT|" prefix
                
                // Pad to exactly 10 characters
                while (llStringLength(currentLeftText) < 10) {
                    currentLeftText += " ";
                }
                if (llStringLength(currentLeftText) > 10) {
                    currentLeftText = llGetSubString(currentLeftText, 0, 9);
                }
                
                
                // If we have both parts, display them
                if (currentRightText != "") {
                    displayDiceText();
                }
            }
            else if (llSubStringIndex(message, "DICE_RIGHT|") == 0) {
                // Store the right part (characters 10-19)
                currentRightText = llGetSubString(message, 11, -1); // Remove "DICE_RIGHT|" prefix
                
                // Pad to exactly 10 characters
                while (llStringLength(currentRightText) < 10) {
                    currentRightText += " ";
                }
                if (llStringLength(currentRightText) > 10) {
                    currentRightText = llGetSubString(currentRightText, 0, 9);
                }
                
                
                // If we have both parts, display them
                if (currentLeftText != "") {
                    displayDiceText();
                }
            }
        }
    }
    
    touch_start(integer total_number) {
        // Touch for debugging - show current state and test display
        if (llDetectedKey(0) == llGetOwner()) {
            llOwnerSay("Dice Display Bridge - listening on channel " + (string)DICE_CHANNEL);
            llOwnerSay("Total prims in linkset: " + (string)llGetNumberOfPrims());
            llOwnerSay("Using dice bank: " + (string)DICE_BANK);
            
            // Test display - 20 characters total
            llMessageLinked(LINK_THIS, DISPLAY_STRING, "TEST: Player1 -> 6 ", (key)((string)DICE_BANK));
            
            llOwnerSay("Test display sent. Touch again to clear.");
            
            // Use a different timer approach that works with discovery timer
            if (CONTROLLER_KEY != NULL_KEY) {
                llSetTimerEvent(3.0); // Clear test after 3 seconds only if not in discovery mode
            }
        }
    }
}
