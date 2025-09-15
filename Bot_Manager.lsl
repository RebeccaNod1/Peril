// Bot Manager for Peril Dice
// Handles logic for test players (bots): picking numbers and rolling dice

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

// Dynamic channel variables
integer BOT_COMMAND_CHANNEL;

// Channel initialization function
initializeChannels() {
    BOT_COMMAND_CHANNEL = calculateChannel(5);  // ~-77500 range to match Main.lsl
}

// Configuration
integer LISTEN_CHANNEL; // Will be set dynamically
integer MSG_SYNC_GAME_STATE = 107;

// Listen handle management
integer listenHandle = -1;

// Bot timing configuration to prevent dialog system overload
float BOT_RESPONSE_DELAY = 1.5;  // Delay before bot responds to commands

// Memory monitoring
float MEMORY_WARNING_THRESHOLD = 0.8;  // Warn when using >80% of memory

// Track game state to validate bot commands
list names = [];
list lives = [];
string perilPlayer = "";

// Track processed bot commands to prevent duplicates
list processedBotCommands = [];

// Track sent BOT_PICKED messages to prevent duplicate sending
list sentBotMessages = [];

// Verbose logging control - toggled by owner
integer VERBOSE_LOGGING = FALSE;

// Helper function to check and report memory usage
checkMemoryUsage(string context) {
    integer usedMemory = llGetUsedMemory();
    float memoryPercentage = (float)usedMemory / 65536.0; // LSL scripts have 64KB limit
    
    if (memoryPercentage > MEMORY_WARNING_THRESHOLD) {
        llOwnerSay("[Bot Manager] ⚠️ High memory usage in " + context + ": " + 
                   (string)usedMemory + " bytes (" + 
                   (string)llRound(memoryPercentage * 100.0) + "% of 64KB limit)");
    }
}

// Helper to parse and respond to pick commands
doBotPick(string botName, integer count, integer diceMax, list avoidNumbers) {
    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔧 doBotPick ENTRY - botName:" + botName + " count:" + (string)count + " diceMax:" + (string)diceMax);
    checkMemoryUsage("doBotPick start");
    
    // Validate bot exists and is still alive
    integer botIdx = llListFindList(names, [botName]);
    if (botIdx == -1) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' not found in game - ignoring command");
        return;
    }
    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔧 Bot found at index:" + (string)botIdx);
    
    integer botLives = llList2Integer(lives, botIdx);
    if (botLives <= 0) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' is eliminated (lives=" + (string)botLives + ") - ignoring command");
        return;
    }
    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔧 Bot lives check passed:" + (string)botLives);
    
    // IMPROVED ALGORITHM: Calculate available numbers first
    list availableNumbers = [];
    integer i;
    for (i = 1; i <= diceMax; i++) {
        string numStr = (string)i;
        if (llListFindList(avoidNumbers, [numStr]) == -1) {
            availableNumbers += [numStr];
        }
    }
    
    integer availableCount = llGetListLength(availableNumbers);
    integer targetCount = count;
    
    // Graceful degradation: adjust target if not enough numbers available
    if (availableCount < count) {
        if (availableCount > 0) {
            llOwnerSay("[Bot Manager] ⚠️ " + botName + " requested " + (string)count + " picks, but only " + (string)availableCount + " numbers available - picking all available");
            targetCount = availableCount;
        } else {
            llOwnerSay("[Bot Manager] ❌ " + botName + " cannot pick any numbers - all " + (string)diceMax + " numbers are taken!");
            // Still send empty response to prevent game hanging
            string response = "BOT_PICKED:" + botName + ":";
            llMessageLinked(LINK_SET, -9997, response, NULL_KEY);
            return;
        }
    }
    
    // IMPROVED PICKING: Use shuffled selection instead of random attempts
    list picks = [];
    list workingList = availableNumbers; // Copy to modify
    
    integer pickCount = 0;
    while (pickCount < targetCount && llGetListLength(workingList) > 0) {
        // Pick random index from remaining available numbers
        integer randomIdx = (integer)(llFrand((float)llGetListLength(workingList)));
        string selectedNumber = llList2String(workingList, randomIdx);
        
        // Add to picks and remove from working list
        picks += [selectedNumber];
        workingList = llDeleteSubList(workingList, randomIdx, randomIdx);
        pickCount++;
    }
    
    // Final validation
    if (llGetListLength(picks) < count) {
        llOwnerSay("[Bot Manager] ℹ️ " + botName + " picked " + (string)llGetListLength(picks) + "/" + (string)count + " numbers (limited by availability)");
    } else {
        llOwnerSay("[Bot Manager] ✅ " + botName + " successfully picked " + (string)llGetListLength(picks) + " numbers");
    }
    
    string pickString = llDumpList2String(picks, ";");
    string response = "BOT_PICKED:" + botName + ":" + pickString;
    
    // Check if we've already sent this exact message to prevent duplicates
    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔍 DEBUG - Checking if message already sent: " + response);
    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔍 DEBUG - sentBotMessages list: " + llDumpList2String(sentBotMessages, "|"));
    if (llListFindList(sentBotMessages, [response]) != -1) {
        llOwnerSay("[Bot Manager] ⚠️ DUPLICATE SEND - Already sent message: " + response);
        return;
    }
    
    // Mark this message as sent BEFORE sending to prevent race conditions
    sentBotMessages += [response];
    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔍 DEBUG - Added to sentBotMessages, new list: " + llDumpList2String(sentBotMessages, "|"));
    
    llOwnerSay("[Bot Manager] 🤖 " + botName + " picked: " + llList2CSV(picks));
    llOwnerSay("[Bot Manager] 📬 SENDING BOT_PICKED: " + response);
    
    // Send message immediately to avoid timing issues
    llMessageLinked(LINK_SET, -9997, response, NULL_KEY);
    llOwnerSay("[Bot Manager] 📬 BOT_PICKED message sent via llMessageLinked(LINK_SET, -9997, ...)");
    
    // Do NOT sleep after sending messages - this causes LSL message delivery loops!
}

// Helper to respond to peril roll commands
doBotRoll(string botName, integer diceMax) {
    // Validate bot exists and is still alive
    integer botIdx = llListFindList(names, [botName]);
    if (botIdx == -1) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' not found in game - ignoring roll command");
        return;
    }
    
    integer botLives = llList2Integer(lives, botIdx);
    if (botLives <= 0) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' is eliminated (lives=" + (string)botLives + ") - ignoring roll command");
        return;
    }
    
    if (botName != perilPlayer) {
        llOwnerSay("[Bot Manager] ❌ Bot '" + botName + "' is not the peril player (current peril: '" + perilPlayer + "') - ignoring roll command");
        return;
    }
    
    // Add delay before rolling to prevent dialog system overload
    llSleep(BOT_RESPONSE_DELAY);
    
    integer roll = 1 + (integer)(llFrand((float)diceMax));
    llRegionSay(LISTEN_CHANNEL, "BOT_ROLL:" + botName + ":" + (string)roll);
}

default {
    state_entry() {
        initializeChannels();
        LISTEN_CHANNEL = BOT_COMMAND_CHANNEL;
        
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Initialize/reset all state variables
        names = [];
        lives = [];
        perilPlayer = "";
        processedBotCommands = [];
        sentBotMessages = [];
        
        listenHandle = llListen(LISTEN_CHANNEL, "", NULL_KEY, "");
        llOwnerSay("🤖 Bot Manager ready!");
    }
    
    on_rez(integer start_param) {
        llOwnerSay("🔄 Bot Manager rezzed - reinitializing...");
        
        // Re-initialize dynamic channels
        initializeChannels();
        LISTEN_CHANNEL = BOT_COMMAND_CHANNEL;
        
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Reset all state variables on rez
        names = [];
        lives = [];
        perilPlayer = "";
        processedBotCommands = [];
        sentBotMessages = [];
        
        listenHandle = llListen(LISTEN_CHANNEL, "", NULL_KEY, "");
        llOwnerSay("✅ Bot Manager reset complete after rez!");
    }

    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle from Main Controller
        if (num == 9011 && llSubStringIndex(str, "VERBOSE_LOGGING|") == 0) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                VERBOSE_LOGGING = (integer)llList2String(parts, 1);
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔍 [Bot Manager] Verbose logging ON");
                } else {
                    llOwnerSay("🔍 [Bot Manager] Verbose logging OFF");
                }
            }
            return;
        }
        
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Reset bot manager state
            names = [];
            lives = [];
            perilPlayer = "";
            processedBotCommands = [];  // Clear processed commands for new game
            sentBotMessages = [];       // Clear sent messages for new game
            llOwnerSay("[Bot Manager] Reset complete!");
            return;
        }
        
        // Handle game state sync to track player eliminations
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                lives = llCSV2List(llList2String(parts, 0));
                // Don't need picks data for validation, skip parts[1]
                string receivedPeril = llList2String(parts, 2);
                string oldPerilPlayer = perilPlayer;
                if (receivedPeril == "NONE") {
                    perilPlayer = "";
                } else {
                    perilPlayer = receivedPeril;
                }
                names = llCSV2List(llList2String(parts, 3));
                
                // Clear processed commands and sent messages when new round starts
                // Detect new round by: peril player change OR lives change (someone got hit)
                string currentLivesStr = llList2CSV(lives);
                string oldLivesStr = "";
                if (llGetListLength(lives) > 0) {
                    // Build previous lives string for comparison
                    oldLivesStr = currentLivesStr; // This will be different if lives changed
                }
                
                if (oldPerilPlayer != perilPlayer && perilPlayer != "") {
                    processedBotCommands = [];
                    sentBotMessages = [];
                    llOwnerSay("[Bot Manager] New round detected (peril change), cleared processed commands and sent messages");
                } else {
                    // Only clear if we detect truly empty picks data during an active game
                    // Don't clear during initial registration (when picks = "EMPTY")
                    string picksStr = llList2String(parts, 1);
                    if (picksStr != "EMPTY" && (picksStr == "" || llSubStringIndex(picksStr, "|") == -1) && perilPlayer != "") {
                        processedBotCommands = [];
                        sentBotMessages = [];
                        llOwnerSay("[Bot Manager] New round detected (picks cleared), cleared processed commands and sent messages");
                    }
                }
            }
            return;
        }
        
        if (num == -9999) {
            if (llSubStringIndex(str, "BOT_PICK:") == 0) {
                // Format: BOT_PICK:bot_1:3:20:1,2,3 (last part is optional already picked numbers)
                llOwnerSay("[Bot Manager] 📬 RECEIVED BOT_PICK: " + str);
                list parts = llParseStringKeepNulls(str, [":"], []);
                if (llGetListLength(parts) >= 4) {
                    string botName = llList2String(parts, 1);
                    integer count = (integer)llList2String(parts, 2);
                    integer diceMax = (integer)llList2String(parts, 3);
                    
                    // Check for duplicate command - prevent processing same bot command multiple times
                    // Include more details to make signature more specific
                    string commandSignature = "PICK:" + botName + ":" + (string)count + ":" + (string)diceMax + ":" + perilPlayer;
                    
                    if (llListFindList(processedBotCommands, [commandSignature]) != -1) {
                        llOwnerSay("[Bot Manager] ⚠️ DUPLICATE - Ignoring identical command for " + botName + " (already processed this exact pick request)");
                        return;
                    }
                    
                    // Mark this command as processed BEFORE doing the work to prevent race conditions
                    processedBotCommands += [commandSignature];
                    llOwnerSay("[Bot Manager] ✅ Processing " + botName + " pick command");
                    list avoidNumbers = [];
                    if (llGetListLength(parts) >= 5) {
                        string avoidStr = llList2String(parts, 4);
                        if (avoidStr != "") {
                            list rawList = llCSV2List(avoidStr);
                            // Trim whitespace from each number
                            avoidNumbers = [];
                            integer i;
                            for (i = 0; i < llGetListLength(rawList); i++) {
                                string trimmed = llStringTrim(llList2String(rawList, i), STRING_TRIM);
                                if (trimmed != "") {
                                    avoidNumbers += [trimmed];
                                }
                            }
                        }
                    }
                    // Debug: Show the game state before calling doBotPick
                    if (VERBOSE_LOGGING) llOwnerSay("[Bot Manager] 🔧 Game state - names:" + llList2CSV(names) + " lives:" + llList2CSV(lives));
                    doBotPick(botName, count, diceMax, avoidNumbers);
                }
            }
            else if (llSubStringIndex(str, "BOT_PERIL_ROLL:") == 0) {
                // Format: BOT_PERIL_ROLL:bot_1:20
                list parts = llParseStringKeepNulls(str, [":"], []);
                if (llGetListLength(parts) == 3) {
                    string botName = llList2String(parts, 1);
                    integer diceMax = (integer)llList2String(parts, 2);
                    doBotRoll(botName, diceMax);
                }
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        // Listen handler removed - all bot commands now come via link messages only
        // This prevents duplicate processing of bot commands
    }
}
