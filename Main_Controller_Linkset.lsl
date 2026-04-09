#include "peril/Peril_Constants.lsl"

// === Main Controller - Peril Dice Game (Linkset Version) ===

// Helper function to get display name with fallback to username
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        // Fallback to legacy username if display name is unavailable
        displayName = llKey2Name(id);
    }
    return displayName;
}

// =============================================================================
// DEBUG & LOCAL CONSTANTS
// =============================================================================

// Unified Timer System - prevents conflicts between multiple timer needs
#define TIMER_IDLE 0
#define TIMER_STATUS 1
#define TIMER_VICTORY_DELAY 2  // Timer mode for victory glow display
#define TIMER_XP_CHECK 3       // Timer mode for Experience sentinel ping
integer currentTimerMode = 0;    // Track what the timer is currently doing
float timerInterval = 1.0;       // How often timer() is called for checks
integer victoryDelayTimer = 0;   // Track victory delay timing

// Debug control - set to TRUE for verbose pick debugging, FALSE for normal operation
#define DEBUG_PICKS FALSE

// Script ID for Main Controller (used by Verbose_Logger for prefixes)
#define SCRIPT_ID_MAIN 0

// Memory reporting function
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    dbg("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

// REMOVED: debugMsg() - too memory intensive for Main Controller

// REMOVED: Heavy message forwarding functions - too memory intensive

// Status message timing
#define STATUS_DISPLAY_TIME 8.0 // How long to show status messages on scoreboard
integer statusTimer = 0;         // Track when status messages were sent
string lastStatus = "";          // Track last status sent

// Game state variables
list players = [];
list names = [];
list lives = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list picksData = [];
list readyPlayers = [];
list floaterChannels = []; // Track actual floater channels for cleanup

// Victory state tracking
integer victoryInProgress = FALSE;

// Lockout system variables
integer isLocked = FALSE;
integer resetInProgress = FALSE;  // Lockout flag for reset synchronization
key gameOwner;

list pickQueue = [];
integer currentPickerIdx = 0;
integer roundStarted = FALSE;
integer gameStarting = FALSE;  // Track when game is in startup sequence

// Prevent duplicate registration by tracking pending registrations
list pendingRegistrations = [];  // Keys of players who have registration in progress
#define REGISTRATION_TIMEOUT 10  // Seconds to keep pending registration

// Display configuration
#define CONTROLLER_FACE 1  // Face to display start image on (front face)
#define TEXTURE_START "title_start"  // Start image texture
#define TEXTURE_GAME_ACTIVE "game_active"  // Optional: different texture during game

// Maximum number of players allowed (including test players)
#define MAX_PLAYERS 10

// Timeout system removed - using owner kick functionality instead

key currentPicker;

integer gameTimer = 0;           

// Dynamic channel system for floaters and dialogs (still needed for external communication)
#define CHANNEL_BASE -77000

integer calculateChannel(integer offset) {
    string ownerStr = (string)llGetOwner();
    // CRITICAL: Always use root prim (1) for channel calculation so scripts in child prims match
    string objectStr = (string)llGetLinkKey(1);
    string combinedStr = ownerStr + objectStr;
    
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2;
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Dynamic channels still needed for external communication (floaters, dialogs)
integer SYNC_CHANNEL;
integer NUMBERPICK_CHANNEL;
integer ROLLDIALOG_CHANNEL; 
integer MAIN_DIALOG_CHANNEL;
integer BOT_COMMAND_CHANNEL;
integer FLOATER_BASE_CHANNEL;

// Legacy channel variables for backward compatibility
integer syncChannel;
integer numberPickChannel;
integer rollDialogChannel;
integer DIALOG_CHANNEL;

// Listen handle management
integer dialogHandle = -1;
integer botHandle = -1;
integer rollHandle = -1;
key sentinelQueryID = NULL_KEY; // Track the Experience Sentinel ping
integer EX_READY = FALSE; // Track the Experience Sentinel ping

// Channel initialization function
initializeChannels() {
    SYNC_CHANNEL = calculateChannel(1);
    NUMBERPICK_CHANNEL = calculateChannel(2);     
    ROLLDIALOG_CHANNEL = calculateChannel(3);
    MAIN_DIALOG_CHANNEL = calculateChannel(4);
    BOT_COMMAND_CHANNEL = calculateChannel(5);
    FLOATER_BASE_CHANNEL = calculateChannel(9);
    
    // Set legacy variables for backward compatibility
    syncChannel = SYNC_CHANNEL;
    numberPickChannel = NUMBERPICK_CHANNEL;
    rollDialogChannel = ROLLDIALOG_CHANNEL;
    DIALOG_CHANNEL = MAIN_DIALOG_CHANNEL;
    
}

// Clean up listen handles
cleanupListeners() {
    if (dialogHandle != -1) {
        llListenRemove(dialogHandle);
        dialogHandle = -1;
    }
    if (botHandle != -1) {
        llListenRemove(botHandle);
        botHandle = -1;
    }
    if (rollHandle != -1) {
        llListenRemove(rollHandle);
        rollHandle = -1;
    }
}

// Re-initialize listen handles
initListeners() {
    dialogHandle = llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
    botHandle = llListen(BOT_COMMAND_CHANNEL, "", NULL_KEY, "");
    rollHandle = llListen(rollDialogChannel, "", NULL_KEY, "");
}

// Memory monitoring functions delegated to Controller_Memory.lsl helper script
checkMemoryUsage(string context) {
    llMessageLinked(LINK_SET, MSG_MEMORY_CHECK, context, NULL_KEY);
}

// REMOVED: emergencyMemoryCleanup() - delegated to Controller_Memory.lsl
// REMOVED: reportMemoryStats() - delegated to Controller_Memory.lsl

// Experience Sentinel - Functional probe to check if KVP is active
// NOTE FOR FUTURE AI/DEVS: KVP (World Rankings) ONLY requires the script to be 
// compiled with the Experience. Land-Scope whitelisting (llAgentInExperience) 
// is ONLY required for HUD auto-attachments and Animations.
// MOVED: checkExperience() - delegated to Player_RegistrationManager.lsl

// Send status message to scoreboard using link messages
sendStatusMessage(string status) {
    // LOCKOUT: If victory is in progress, only allow "Victory" or "Title" statuses
    // This prevents elimination messages from stomping on the victory display
    if (victoryInProgress) {
        if (status != "Victory" && status != "Title") {
            dbg("🏆 [Main Controller] 🚫 Status update BLOCKED during victory: " + status);
            return;
        }
    }

    statusTimer = llGetUnixTime();
    lastStatus = status;
    
    // Send texture update to scoreboard
    llMessageLinked(LINK_SCOREBOARD, MSG_GAME_STATUS, status, NULL_KEY);
    
    // NEW: Send dynamic text update to FURWARE status bridge
    llMessageLinked(LINK_SET, MSG_STATUS_TEXT, status, NULL_KEY);
    
    currentTimerMode = TIMER_STATUS;
    llSetTimerEvent(STATUS_DISPLAY_TIME + 1.0);
}

// UNIFIED SYSTEM: Single source of truth for global game state sync
syncGameState() {
    // Build sync message WITHOUT redundant player keys to save memory
    // Format: lives~picks~perilPlayer~names
    string picksStr = (string)llDumpList2String(picksData, "^");
    if (picksStr == "") picksStr = "EMPTY"; // Standardized token
    
    // DELIMITER FIX: Ensure each of the 4 parts is explicitly separated by ~
    string syncMsg = llList2CSV(lives) + "~" + 
                     picksStr + "~" + 
                     (string)llList2String([perilPlayer, "NONE"], (perilPlayer == "")) + "~" + 
                     llList2CSV(names);
                     
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, syncMsg, NULL_KEY);
    dbg("🌍 [Main Controller] 📡 Global State Sync broadcasted (Picks: " + picksStr + ")");
}


// Direct scoreboard update for most recently added player
updateHelpers() {
    // EMERGENCY memory check - much stricter threshold
    integer freeMem = llGetFreeMemory();
    if (victoryInProgress || freeMem < 4000) {
        // Emergency: Don't even create strings if memory is critically low
        return;
    }
    
    // MINIMAL: Only send update for the most recently added player
    // No CSV operations, no string building - just direct message
    integer nameCount = llGetListLength(names);
    if (nameCount > 0) {
        integer lastIdx = nameCount - 1;
        // Minimal string operations - direct message
        llMessageLinked(LINK_SCOREBOARD, MSG_PLAYER_UPDATE, 
                       llList2String(names, lastIdx) + "|" + 
                       (string)llList2Integer(lives, lastIdx) + "|" + 
                       (string)llList2Key(players, lastIdx), NULL_KEY);
    }
}

// Request helper-calculated values
requestPicksRequired(integer idx) {
    llMessageLinked(LINK_SET, MSG_GET_PICKS_REQUIRED, llList2String(names, idx), NULL_KEY);
}

requestPickerIndex(string name) {
    llMessageLinked(LINK_SET, MSG_GET_PICKER_INDEX, name, NULL_KEY);
}

string generateSerializedState() {
    // Simplified to avoid memory-intensive CSV operations
    return "MINIMAL_STATE~" + perilPlayer + "~" + (string)llGetListLength(names);
}

// Update floating text based on lock status
updateFloatingText() {
    if (isLocked) {
        llSetText("🔒 GAME LOCKED\nOwner access only", <1.0, 0.5, 0.0>, 1.0);
    } else {
        if (roundStarted || gameStarting) {
            integer actualPlayerCount = llGetListLength(names);
            llSetText("🎮 GAME IN PROGRESS\n" + (string)actualPlayerCount + " players", <1.0, 0.2, 0.2>, 1.0);
        } else {
            llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
        }
    }
}

resetGame() {
    resetInProgress = TRUE;  // Start lockout
    cleanupListeners();
    
    // Let Floater Manager handle cleanup intelligently
    llMessageLinked(LINK_SET, MSG_CLEANUP_ALL_FLOATERS, "RESET", NULL_KEY);
    // Reduced delay for snappy restart
    llSleep(0.1); 
    
    players = names = lives = picksData = globalPickedNumbers = readyPlayers = [];
    floaterChannels = [];
    pendingRegistrations = [];
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    roundStarted = FALSE;
    gameStarting = FALSE;
    victoryInProgress = FALSE;
    currentPicker = NULL_KEY;
    
    llMessageLinked(LINK_SET, MSG_RESET_ALL, "FULL_RESET", NULL_KEY);
    llSay(syncChannel, "RESET");
    
    // CHANGED: Use link messages instead of llRegionSay for display cleanup
    llMessageLinked(LINK_SCOREBOARD, MSG_CLEAR_GAME, "", NULL_KEY);
    // Clear winner glow from scoreboard (floaters will clear naturally on reset)
    llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_WINNER, "", NULL_KEY);  // Clear winner glow
    llMessageLinked(LINK_SET, MSG_CLEAR_DICE, "", NULL_KEY);
    
    // Give other scripts time to finish their reset before starting sync
    // INCREASED to 5.0s for high-speed Mono startup with Debug Logs OFF
    llSleep(5.0); 
    
    // NEW: Trigger Leaderboard to reload rankings from KVP on reset
    llMessageLinked(LINK_SET, MSG_RESET_LEADERBOARD, "START_SYNC", NULL_KEY);
    
    dbg("🎮 Game reset! All state cleared (including scoreboard).");
    
    statusTimer = 0;
    lastStatus = "";
    
    llSetTexture(TEXTURE_START, CONTROLLER_FACE);
    llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
    
    // NEW: Update status bar for idle state
    sendStatusMessage("PERIL DICE GAME\nTouch to Join!");
    
    // Quick buffer for Linkset to settle
    llSleep(0.2); 
    llSetTimerEvent(0);
    
    initListeners();
    resetInProgress = FALSE;  // End lockout
}

default {
    state_entry() {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("🎮 Main Controller ready! (Discovery Mode)");
        
        // Initialize lockout system
        gameOwner = llGetOwner();
        isLocked = FALSE; // Default to unlocked
        
        // Initialize channels for external communication
        initializeChannels();
        
        // Reset the game on startup to ensure clean state
        resetGame();
        
        // MOVED: checkExperience() - already called by Registration Management
        
        dbg("✅ Main Controller initialization complete!");
    }
    
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        REPORT_MEMORY();
        dbg("🔄 Main Controller reset via rez...");
        
        // Re-initialize lockout system
        gameOwner = llGetOwner();
        isLocked = FALSE;
        
        // Re-initialize channels for external communication
        initializeChannels();
        
        // Reset the game to ensure clean state when rezzed
        resetGame();
        
        // MOVED: checkExperience()
        
        dbg("✅ Main Controller reset complete after rez!");
    }

    touch_start(integer total_number) {
        integer clickedLink = llDetectedLinkNumber(0);
        string clickedName = llGetLinkName(clickedLink);
        key toucher = llDetectedKey(0);

        // DELIVER: Forward touch event to Dialog Handler to save bytecode in Main
        llMessageLinked(LINK_SET, MSG_TOUCH_EVENT, (string)clickedLink + "|" + clickedName, toucher);
    }

    link_message(integer sender, integer num, string str, key id) {
        // Handle MSG_UPDATE_LIFE - Reported by Roll Module when someone takes a hit
        if (num == MSG_UPDATE_LIFE) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string hitPlayer = llList2String(parts, 0);
                integer newLifeCount = (integer)llList2String(parts, 1);
                
                integer pidx = llListFindList(names, [hitPlayer]);
                if (pidx != -1) {
                    lives = llListReplaceList(lives, [newLifeCount], pidx, pidx);
                    dbg("🛡️ [Main Controller] 💗 Damage Report Confirmed: " + hitPlayer + " -> " + (string)newLifeCount + " hearts.");
                    syncGameState();
                    
                    // AUTHORITATIVE: Signal Game Manager to continue to the next round after the damage report
                    llSleep(DELAY_SYNC_PROPAGATION);
                    llMessageLinked(LINK_SET, MSG_CONTINUE_ROUND, perilPlayer, NULL_KEY);
                }
            }
            return;
        }
        
        // Handle messages from the game logic and bridges
        
        // Handle registration updates from Player_RegistrationManager
        if (num == MSG_UPDATE_MAIN_LISTS) { // MSG_UPDATE_MAIN_LISTS
            // ULTRA-OPTIMIZED: Player_RegistrationManager now handles all heavy processing
            // Main Controller just adds the player to its master lists
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 2) {
                integer ch = llList2Integer(parts, 0);
                string newName = llList2String(parts, 1);
                
                // CHECK FOR DUPLICATES: Only check players list (names list may be populated by sync messages)
                integer existingPlayerIdx = llListFindList(players, [id]);
                
                if (existingPlayerIdx != -1) {
                    dbg("⚠️ [Main Controller] DUPLICATE PLAYER KEY DETECTED - Player: " + newName + " (" + (string)id + ") already exists!");
                    dbg("⚠️ [Main Controller] Players list length: " + (string)llGetListLength(players) + ", Names list length: " + (string)llGetListLength(names));
                    return; // Skip adding duplicate
                }
                
                // Add new player directly to master lists (minimal operations)
                players += [id];
                names += [newName];
                lives += [3];
                floaterChannels += [ch];
                
                // NEW: Update status bar with registration count
                sendStatusMessage("JOIN THE PERIL!\n" + (string)llGetListLength(names) + "/" + (string)MAX_PLAYERS + " Players registered...");
                
                // Clean up pending registrations
                integer pendingIdx = llListFindList(pendingRegistrations, [id]);
                if (pendingIdx != -1) {
                    pendingRegistrations = llDeleteSubList(pendingRegistrations, pendingIdx, pendingIdx);
                }
                
                // That's it! Player_RegistrationManager already sent sync and scoreboard updates
                dbg("✅ Player added to master lists: " + newName + " (" + (string)llGetFreeMemory() + " bytes free)");
                dbg("🔍 [DEBUG] Updated lists - Players: " + (string)llGetListLength(players) + ", Names: " + (string)llGetListLength(names));
            }
            return;
        }
        
        // Handle elimination requests
        // MOVED: MSG_ELIMINATE_PLAYER logic - delegated to Game_Manager.lsl
        // Process ONLY the final list cleanup here after Game Manager finishes visuals
        if (num == MSG_PROCESS_ELIMINATION) {
            string eliminatedPlayer = str;
            integer idx = llListFindList(names, [eliminatedPlayer]);
            if (idx != -1) {
                // Remove from indexed lists
                players = llDeleteSubList(players, idx, idx);
                names = llDeleteSubList(names, idx, idx);
                lives = llDeleteSubList(lives, idx, idx);
                floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                
                // Remove from picksData
                integer pickIdx = -1;
                integer p;
                for (p = 0; p < llGetListLength(picksData); p++) {
                    string entry = llList2String(picksData, p);
                    if (llSubStringIndex(entry, eliminatedPlayer + "|") == 0) {
                        pickIdx = p;
                        jump found_pick_entry;
                    }
                }
                @found_pick_entry;
                if (pickIdx != -1) {
                    picksData = llDeleteSubList(picksData, pickIdx, pickIdx);
                }
                
                syncGameState();
                dbg("🎯 [Main Controller] Deep Cleanup Complete: " + eliminatedPlayer + " purged from state.");
            }
            return;
        }
        
        // Handle emergency reset for stuck games
        if (num == MSG_EMERGENCY_RESET && str == "EMERGENCY_RESET") {
            dbg("🚨 [Main Controller] Emergency reset triggered - sending emergency reset to all scripts");
            // Signal all scripts to emergency reset
            llMessageLinked(LINK_SET, MSG_EMERGENCY_RESET, "EMERGENCY_RESET", NULL_KEY);
            llSleep(DELAY_SYNC_PROPAGATION);
            // Then do full reset
            resetGame();
            return;
        }
        
        // Handle game won
        if (num == 998) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "GAME_WON") {
                string winner = llList2String(parts, 1);
                // Send dice roll winner message using LINK_SET
                llMessageLinked(LINK_SET, MSG_DICE_ROLL, winner + "|WON", NULL_KEY);
                llSleep(DELAY_GAME_RESET);
                resetGame();
            }
            return;
        }
        
        // Forward sync updates to Game Manager for processing
        if (num == MSG_SYNC_GAME_STATE) {
            // Skip forwarding during victory sequence
            if (victoryInProgress) {
                return;
            }
            // DON'T forward sync messages - this creates loops!
            // Game Manager should receive the original message directly
            // Main Controller just ignores sync messages now
            return;
        }
        
        // Handle peril player updates from other modules
        if (num == MSG_UPDATE_PERIL_PLAYER) {
            perilPlayer = str;
            dbg("🎯 [Main Controller] Peril Player Updated: " + perilPlayer);
            syncGameState();
            
            // AUTHORITATIVE: Signal Game Manager to continue to the next round after Plot Twist
            llSleep(DELAY_SYNC_PROPAGATION);
            llMessageLinked(LINK_SET, MSG_CONTINUE_ROUND, perilPlayer, NULL_KEY);
            return;
        }
        
        // Receive lightweight updates from Game Manager
        if (num == 9070) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 3 && llList2String(parts, 0) == "PERIL_UPDATE") {
                perilPlayer = llList2String(parts, 1);
                integer playerCount = (integer)llList2String(parts, 2);
                
                // Update floating text if needed
                if (roundStarted || gameStarting) {
                    llSetText("🎮 GAME IN PROGRESS\n" + (string)playerCount + " players", <1.0, 0.2, 0.2>, 1.0);
                }
            }
            return;
        }
        
        // Legacy 997 message handler removed - now using direct communication to Game Manager
        
        // Handle ready state toggle
        if (num == MSG_TOGGLE_READY) {
            string playerName = str;
            integer idx = llListFindList(names, [playerName]);
            if (idx != -1) {
                if (llSubStringIndex(playerName, "Bot") == 0) {
                    dbg("🤖 Bots are always ready and cannot change state");
                    return;
                }
                
                integer readyIdx = llListFindList(readyPlayers, [playerName]);
                if (readyIdx == -1) {
                    readyPlayers += [playerName];
                    llSay(0, "⚔️ " + playerName + " steels themselves for the deadly challenge ahead! ⚔️");
                } else {
                    readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    llSay(0, "🏃 " + playerName + " loses their nerve and backs away from the challenge! 🏃");
                }
            }
            return;
        }
        
        // Handle ready state queries
        if (num == MSG_QUERY_READY_STATE) {
            list qParts = llParseString2List(str, ["|"], []);
            string qPlayerName;
            integer qRequestID = 0;
            
            if (llGetListLength(qParts) >= 2) {
                qPlayerName = llList2String(qParts, 0);
                qRequestID = (integer)llList2String(qParts, 1);
            } else {
                qPlayerName = str;
            }
            
            integer isReady = llListFindList(readyPlayers, [qPlayerName]) != -1;
            integer isBot = llSubStringIndex(qPlayerName, "Bot") == 0;
            string resultStr = qPlayerName + "|" + (string)isReady + "|" + (string)isBot + "|" + (string)qRequestID;
            llMessageLinked(LINK_SET, MSG_READY_STATE_RESULT, resultStr, id);
            return;
        }
        
        // Handle owner status queries
        if (num == MSG_QUERY_OWNER_STATUS) {
            list osParts = llParseString2List(str, ["|"], []);
            string osName;
            integer osRequestID = 0;
            
            if (llGetListLength(osParts) >= 2) {
                osName = llList2String(osParts, 0);
                osRequestID = (integer)llList2String(osParts, 1);
            } else {
                osName = str;
            }
            
            // Check if owner is registered
            integer ownerIdx = llListFindList(players, [id]);
            integer isRegistered = (ownerIdx != -1);
            integer isPending = (llListFindList(pendingRegistrations, [id]) != -1);
            integer isStarter = FALSE;
            
            if (isRegistered) {
                // Calculate starter status if registered
                isStarter = TRUE;
                integer k;
                for (k = 0; k < ownerIdx && isStarter; k++) {
                    string existingName = llList2String(names, k);
                    if (llSubStringIndex(existingName, "Bot") != 0) {
                        isStarter = FALSE;
                    }
                }
                if (ownerIdx == 0) {
                    isStarter = TRUE;
                }
            }
            
            string result = osName + "|" + (string)isRegistered + "|" + (string)isPending + "|" + (string)isStarter + "|" + (string)osRequestID;
            llMessageLinked(LINK_SET, MSG_OWNER_STATUS_RESULT, result, id);
            return;
        }
        
        // MSG_CLEANUP_ALL_FLOATERS is handled by Floater Manager only
        
        // Handle leave game requests processed by Controller_MessageHandler
        if (num == MSG_LEAVE_GAME_REQUEST) { // MSG_LEAVE_GAME_REQUEST
            // This message comes FROM the Controller_MessageHandler after it has processed the removal
            // We need to update the main controller's lists to match
            list parts = llParseString2List(str, ["|"], []);
            string action = llList2String(parts, 0);
            if (action == "LEAVE_GAME" || action == "KICK_PLAYER") {
                string leavingName = llList2String(parts, 1);
                    // Find and remove the player from main controller lists
                    integer idx = llListFindList(names, [leavingName]);
                    if (idx != -1) {
                        // CRITICAL: Inform all scripts (Registration Manager) to scrub this player
                        llMessageLinked(LINK_SET, MSG_REMOVE_PLAYER, leavingName, NULL_KEY);
                    
                    // Only announce if it's not the end of the game
                    if (llGetListLength(names) > 1) {
                        sendStatusMessage("PLAYER FALLEN!\n" + leavingName + " has been eliminated!");
                    }
                    
                    // Clean up the leaving player's floater using their current channel
                    integer ch = FLOATER_BASE_CHANNEL + idx;
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    
                    // CRITICAL: If the leaving player was the peril player, update before updateHelpers()
                    if (perilPlayer == leavingName) {
                        // Find first remaining alive player to be new peril player  
                        string newPerilPlayer = "";
                        integer k;
                        for (k = 0; k < llGetListLength(names) && newPerilPlayer == ""; k++) {
                            string candidateName = llList2String(names, k);
                            if (candidateName != leavingName) { // Skip the player being removed
                                integer candidateIdx = llListFindList(names, [candidateName]);
                                if (candidateIdx != -1 && candidateIdx < llGetListLength(lives)) {
                                    integer candidateLives = llList2Integer(lives, candidateIdx);
                                    if (candidateLives > 0) {
                                        newPerilPlayer = candidateName;
                                    }
                                }
                            }
                        }
                        
                        if (newPerilPlayer != "") {
                            dbg("🎯 [Main Controller] Peril player left - assigning new peril player: " + newPerilPlayer);
                            perilPlayer = newPerilPlayer;
                            // Send peril player update to scoreboard for glow effect
                            llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_PERIL_PLAYER, newPerilPlayer, NULL_KEY);  // MSG_UPDATE_PERIL_PLAYER
                        } else {
                            dbg("⚠️ [Main Controller] No valid peril player candidates found after player left!");
                            perilPlayer = "NONE";
                            // Clear peril player glow on scoreboard
                            llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_PERIL_PLAYER, "", NULL_KEY);
                        }
                    }
                    
                    // Update main controller's lists to match the message handler
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    // Remove any picks data entry for this player
                    integer j;
                    for (j = 0; j < llGetListLength(picksData); j++) {
                        list pickParts = llParseString2List(llList2String(picksData, j), ["|"], []);
                        if (llList2String(pickParts, 0) == leavingName) {
                            picksData = llDeleteSubList(picksData, j, j);
                            j = llGetListLength(picksData); // Exit loop LSL-style
                        }
                    }
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    
                    // Remove from ready list if present
                    integer readyIdx = llListFindList(readyPlayers, [leavingName]);
                    if (readyIdx != -1) {
                        readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    }
                    
                    // Check if we should reset the game (no players left)
                    if (llGetListLength(names) == 0) {
                        dbg("🔄 [Main Controller] All players left - resetting game");
                        // Force clear any remaining game state before reset
                        roundStarted = FALSE;
                        gameStarting = FALSE;
                        perilPlayer = "";
                        currentPicker = NULL_KEY;
                        resetGame();
                        return;
                    }
                    
                    // Skip updateHelpers to prevent memory crashes during player removal
                    // Scoreboard was already updated with MSG_REMOVE_PLAYER above
                    dbg("✅ [Main Controller] Synchronized removal of " + leavingName);
                }
            }
            return;
        }
        
        // Handle lock/unlock messages from Dialog Handler
        if (num == MSG_LOCK_GAME) { // Lock game message
            if (id == gameOwner && str == "LOCK_GAME") {
                isLocked = TRUE;
                updateFloatingText();
                dbg("🔒 [Main Controller] Game has been LOCKED - Floating text updated");
            }
            return;
        }
        
        if (num == MSG_UNLOCK_GAME) { // Unlock game message
            if (id == gameOwner && str == "UNLOCK_GAME") {
                isLocked = FALSE;
                updateFloatingText();
                dbg("🔓 [Main Controller] Game has been UNLOCKED - Floating text updated");
            }
            return;
        }
        
        
        
        // Handle memory monitor messages
        if (num == MSG_EMERGENCY_CLEANUP) {
            // Removed emergencyMemoryCleanup call to save memory
            dbg("Emergency cleanup disabled to prevent crashes");
            return;
        }
        
        // Handle reset requests from other scripts (like Game_Manager)
        if (num == MSG_EMERGENCY_RESET && str == "REQUEST_GAME_RESET") {
            dbg("🔄 [Main Controller] Reset requested by " + (string)sender + ", executing...");
            resetGame();
            return;
        }
        
    }

    listen(integer channel, string name, key id, string msg) {
        if (channel == rollDialogChannel) {
            if (msg == "Start Next Round" || msg == "BEGIN KILLING GAME") {
                if (roundStarted) {
                    dbg("⚠️ Round already in progress, ignoring duplicate round start from roll dialog");
                    return;
                }
                
                llSay(0, "⚡ THE KILLING GAME CONTINUES! " + perilPlayer + " begins the next deadly round!");
                llMessageLinked(LINK_SET, 998, perilPlayer, NULL_KEY);
                return;
            }
        }
        
        if (channel == DIALOG_CHANNEL) {
            // Handle owner choice dialog responses during gameplay
            if (id == llGetOwner() && roundStarted) {
                if (msg == "🔄 Recover Pick Dialog") {
                    string ownerName = getPlayerName(id);
                    llSay(0, "🔄 " + ownerName + " - Restoring your number picking dialog...");
                    llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, ownerName, id);
                    return;
                }
                else if (msg == "🔄 Recover Roll Dialog") {
                    llSay(0, "🔄 " + getPlayerName(id) + " - Restoring your roll dialog...");
                    llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, id);
                    return;
                }
                else if (msg == "🔧 Admin Menu") {
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", id);
                    return;
                }
            }
            
            // Handle owner choice menu - "Join Game" is handled by Player_DialogHandler
            if (id == llGetOwner()) {
                if (msg == "Owner Menu") {
                    // Owner wants admin functions without joining - use admin targetType
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "admin|0", id);
                    return;
                }
            }
            
            // Owner-specific commands (when they've accessed admin menu)
            if (id == llGetOwner()) {
                if (msg == "Reset Game") {
                    resetGame();
                    return;
                }
                if (msg == "Reset Leaderboard") {
                    llDialog(id, "⚠️ WARNING: This will PERMANENTLY WIPE the World Ranking database (all 10 shards). Are you sure?", ["YES, WIPE LB", "NO, CANCEL"], DIALOG_CHANNEL);
                    return;
                }
                if (msg == "YES, WIPE LB") {
                    if (id != (key)GLOBAL_ADMIN) {
                        llRegionSayTo(id, 0, "🚫 Access Denied: Only the Global Admin can perform this action.");
                        return;
                    }
                    llMessageLinked(LINK_SET, MSG_RESET_LEADERBOARD, "WIPE", id); // Use LINK_SET
                    dbg("🏆 GLOBAL LEADERBOARD WIPE confirmed and executed.");
                    return;
                }
                if (msg == "Reset All") {
                    llDialog(id, "⚠️ WARNING: This will factory reset the game AND permanently wipe the leaderboard. Are you sure?", ["YES, RESET ALL", "NO, CANCEL"], DIALOG_CHANNEL);
                    return;
                }
                if (msg == "YES, RESET ALL") {
                    if (id != (key)GLOBAL_ADMIN) {
                        llRegionSayTo(id, 0, "🚫 Access Denied: Only the Global Admin can perform this action.");
                        return;
                    }
                    resetGame();
                    llMessageLinked(LINK_SET, MSG_RESET_LEADERBOARD, "WIPE", id); // Use LINK_SET
                    dbg("🔄 FULL RESET confirmed and executed.");
                    return;
                }
                if (msg == "Memory Stats") {
                    // Removed reportMemoryStats call to save memory
                    dbg("Memory stats reporting disabled to prevent crashes");
                    return;
                }
                if (msg == "Add Test Player") {
                    if (llGetListLength(players) >= MAX_PLAYERS) {
                        dbg("⚠️ Cannot add test player; the game is full (max " + (string)MAX_PLAYERS + ").");
                        return;
                    }
                    
                    // Create shorter bot names to avoid dialog button length issues
                    // Count existing bots to determine next bot number
                    integer existingBots = 0;
                    integer i;
                    for (i = 0; i < llGetListLength(names); i++) {
                        string playerName = llList2String(names, i);
                        if (llSubStringIndex(playerName, "Bot") == 0) {
                            existingBots++;
                        }
                    }
                    integer botNum = existingBots + 1;
                    string testName = "Bot" + (string)botNum;
                    key fake = llGenerateKey();
                    llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER_REQUEST, testName + "|" + (string)fake, NULL_KEY);
                    
                    // Don't show menu immediately - let the player touch the board again
                    // This avoids timing issues where the menu is shown before registration completes
                    dbg("✅ " + testName + " registration sent - touch the board again to refresh menu");
                    return;
                }
                if (msg == "Force Floaters") {
                    dbg("🔧 Forcing floater creation for all " + (string)llGetListLength(names) + " players...");
                    integer i;
                    for (i = 0; i < llGetListLength(names); i++) {
                        string playerName = llList2String(names, i);
                        key playerKey = llList2Key(players, i);
                        llMessageLinked(LINK_SET, MSG_REZ_FLOAT, playerName, playerKey);
                        llSleep(DELAY_GENERIC_TICK);
                    }
                    dbg("✅ Floater creation requests sent for all players!");
                    
                    // After forcing floaters, show appropriate menu based on owner registration status
                    integer ownerIdx = llGetListLength(players); // Simplified check
                    if (ownerIdx != -1) {
                        // Owner is registered - show registered owner menu
                        integer ownerIsStarter = TRUE;
                        integer n;
                        for (n = 0; n < ownerIdx && ownerIsStarter; n++) {
                            string existingName = llList2String(names, n);
                            if (llSubStringIndex(existingName, "Bot") != 0) {
                                ownerIsStarter = FALSE;
                            }
                        }
                        llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)ownerIsStarter, llGetOwner());
                    } else {
                        // Owner is not registered - show unregistered owner menu
                        if (llGetListLength(players) >= 2) {
                            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "unregistered_owner_starter|1", llGetOwner());
                        } else {
                            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "unregistered_owner|0", llGetOwner());
                        }
                    }
                    return;
                }
            }
            
            // Allow starter to start the game
            if (msg == "Start Game") {
                integer playerCount = llGetListLength(players);
                integer nameCount = llGetListLength(names);
                if (playerCount < 2) {
                    dbg("⚠️ Need at least 2 players to start the game.");
                    return;
                }
                
                string starterName = "";
                if (id == llGetOwner()) {
                    starterName = getPlayerName(llGetOwner());
                } else if (llGetListLength(players) > 0) {
                    key firstPlayer = llList2Key(players, 0);
                    if (id == firstPlayer) {
                        starterName = getPlayerName(firstPlayer);
                    }
                }
                
                if (starterName == "") {
                    dbg("⚠️ Only the game starter can start the game.");
                    return;
                }
                
                list notReadyPlayers = [];
                integer i;
                for (i = 0; i < llGetListLength(names); i++) {
                    string playerName = llList2String(names, i);
                    if (playerName != starterName && llSubStringIndex(playerName, "Bot") != 0) {
                        if (llListFindList(readyPlayers, [playerName]) == -1) {
                            notReadyPlayers += [playerName];
                        }
                    }
                }
                
                if (llGetListLength(notReadyPlayers) > 0) {
                    dbg("⚠️ Cannot start game. These players are not ready: " + llList2CSV(notReadyPlayers));
                    return;
                }
                
                gameStarting = TRUE;
                
                // MEMORY OPTIMIZED: Clear stale lists as soon as game enters active phase
                readyPlayers = [];
                pendingRegistrations = [];
                
                llSay(0, "⚡ ALL PARTICIPANTS READY! THE DEADLY PERIL DICE GAME BEGINS! ⚡");
                
                integer currentLiveCount = llGetListLength(names);
                llSetText("🎮 GAME IN PROGRESS\n" + (string)currentLiveCount + " players", <1.0, 0.2, 0.2>, 1.0);
                
                // FIXED: Use proper announcement instead of internal texture name "Title"
                sendStatusMessage("GAME STARTING!\nAll players are ready!");
                
                // Dramatic pause to let the start announcement be read before round prep begins
                llSleep(DELAY_LONG_SYNC);
                
                // For game start, use empty peril player - Game Manager will select one
                llMessageLinked(LINK_SET, 998, "", NULL_KEY);
            }
            
            if (llListFindList(names, [msg]) != -1) {
                llMessageLinked(LINK_SET, 206, msg, id);
            }
        }
    }
    
    timer() {
        if (currentTimerMode == TIMER_STATUS) {
            if (statusTimer > 0 && (llGetUnixTime() - statusTimer) >= STATUS_DISPLAY_TIME) {
                statusTimer = 0;
                lastStatus = "";
                // CHANGED: Use link message instead of llRegionSay
                llMessageLinked(LINK_SCOREBOARD, MSG_GAME_STATUS, "Title", NULL_KEY);
                dbg("📢 Status cleared - reverted to Title");
                currentTimerMode = TIMER_IDLE;
                llSetTimerEvent(0);
            }
        }
        else if (currentTimerMode == TIMER_XP_CHECK) {
            // Timer fired - it means llReadKeyValue FAILED to respond (Land block or non-associated script)
            // checkExperience() and experience_permissions_denied() already handle the public warnings.
            dbg("⚠️ [Peril Dice] Experience Sentinel: KVP Probe timed out. Land/Script block confirmed.");
            llSetTimerEvent(0);
            currentTimerMode = TIMER_IDLE;
        }
        else if (currentTimerMode == TIMER_VICTORY_DELAY) {
            if (victoryDelayTimer > 0) {
                integer elapsed = llGetUnixTime() - victoryDelayTimer;
                if (elapsed >= (integer)(STATUS_DISPLAY_TIME * 3.0)) {  // 24 seconds
                    dbg("🏆 [Main Controller] Victory display time complete - executing game reset");
                    victoryDelayTimer = 0;
                    currentTimerMode = TIMER_IDLE;
                    llSetTimerEvent(0);
                    resetGame();  // Now reset after the delay
                }
            }
        }
    }
    
    dataserver(key query_id, string data) {
        if (query_id == sentinelQueryID) {
            // WE GOT A RESPONSE! 
            integer c = llSubStringIndex(data, ",");
            string st = data;
            if (c != -1) st = llGetSubString(data, 0, c - 1);
            
            sentinelQueryID = NULL_KEY;
            llSetTimerEvent(0);
            if (st == "1" || st == "3") { // Status 1 (Found) or 3 (Not Found) both prove Experience access
                 dbg("✅ [Peril Dice] Experience Sentinel: KVP Heartbeat Confirmed.");
                 EX_READY = TRUE;
            } else {
                 EX_READY = FALSE;
                 dbg("⚠️ [Peril Dice] Sentinel handshake returned status: " + st);
            }
        }
    }
    
    experience_permissions_denied(key agent_id, integer reason) {
        // This event fires if an Experience function fails (like our Sentinel Ping)
        // reason 17 = XP_ERROR_NOT_PERMITTED_LAND
        // reason 1 = XP_ERROR_NOT_EXPERIENCE
        if (reason == 17 || reason == 1) { 
            sentinelQueryID = NULL_KEY;
            llSetTimerEvent(0);
            currentTimerMode = TIMER_IDLE;
            // Removed redundant messaging - checkExperience() handles the OwnerSay
            dbg("⚠️ [Peril Dice] Experience Denial (Reason " + (string)reason + ") detected land block.");
        } else {
            dbg("⚠️ [Peril Dice] Experience Denial (Code " + (string)reason + ") for agent " + (string)agent_id);
        }
    }
}
