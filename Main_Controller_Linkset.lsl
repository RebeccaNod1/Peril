#include "Peril_Constants.lsl"

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
    
    llOwnerSay("🧠 [" + scriptName + "] Memory: " + 
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

// Game timing settings
#define BOT_PICK_DELAY 2.0      
#define HUMAN_PICK_DELAY 1.0    
#define DIALOG_DELAY 1.5        
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

// Experience Sentinel - Functional probe to check if Experience is allowed on land
checkExperience() {
    dbg("🔍 [Peril Dice] Experience Sentinel: Starting key-based diagnostic...");
    llOwnerSay("🛡️ [Peril Dice] Experience Sentinel: Verifying Land-Scope permissions for 'Final Girlz I.N.C.'...");
    
    // THE "KEY" CHECK: Uses the Experience UUID directly to verify land readiness.
    // This is the definitive check to see if the Experience is allowed on this parcel.
    if (!llAgentInExperience(EXPERIENCE_ID)) {
        llOwnerSay("⚠️ [Peril Dice] SYSTEM WARNING: Experience Features are BLOCKED on this land.");
        llOwnerSay("🛡️ [Peril Dice] TO FIX: Open 'About Land' -> 'Experiences' -> 'Add' and search for 'Final Girlz I.N.C.'");
        return; 
    }

    // Functional Handshake (KVP Read) to confirm secondary connectivity
    currentTimerMode = TIMER_XP_CHECK;
    llSetTimerEvent(3.0); 
    sentinelQueryID = llReadKeyValue("_SENTINEL_PING_");
}

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
    string syncMsg = llList2CSV(lives) + "~" + 
                     (string)llDumpList2String(picksData, "^") + "~" + 
                     (string)llList2String([perilPlayer, "NONE"], (perilPlayer == "")) + "~" + 
                     llList2CSV(names);
                     
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, syncMsg, NULL_KEY);
    dbg("🌍 [Main Controller] 📡 Global State Sync broadcasted.");
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
    cleanupListeners();
    
    // Let Floater Manager handle cleanup intelligently
    // Always request cleanup on a reset to ensure no orphans are left behind
    llMessageLinked(LINK_SET, MSG_CLEANUP_ALL_FLOATERS, "RESET", NULL_KEY);
    llSleep(0.5);
    
    llSleep(0.5);
    
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
    
    dbg("🎮 Game reset! All state cleared (including scoreboard).");
    
    statusTimer = 0;
    lastStatus = "";
    
    llSetTexture(TEXTURE_START, CONTROLLER_FACE);
    llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
    
    // NEW: Update status bar for idle state
    sendStatusMessage("PERIL DICE GAME\nTouch to Join!");
    
    llSleep(0.5);
    llSetTimerEvent(0);
    
    initListeners();
    
    // SAFETY: Only call updateHelpers if we have actual game data to prevent startup issues
    if (llGetListLength(names) > 0) {
        updateHelpers();
    }
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
        
        // Experience Sentinel check - Moved after reset to protect timer
        checkExperience();
        
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
        
        // Experience Sentinel check - Moved after reset to protect timer
        checkExperience();
        
        dbg("✅ Main Controller reset complete after rez!");
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        
        // Enhanced disconnect/reconnect handling - check if this player should be picking
        if (idx != -1 && toucher != llGetOwner() && roundStarted) {
            string playerName = llList2String(names, idx);
            
            // ENHANCED: Check if this player is supposed to be the current picker based on game state
            integer shouldBePicking = FALSE;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                string expectedPickerName = llList2String(pickQueue, currentPickerIdx);
                if (playerName == expectedPickerName) {
                    shouldBePicking = TRUE;
                    // Fix corrupted currentPicker state
                    if (currentPicker != toucher) {
                        currentPicker = toucher;
                    }
                }
            }
            
            // FALLBACK: If game is stuck and no one is set as current picker, but we're in pick phase,
            // let any registered player attempt to resume (with owner confirmation)
            if (!shouldBePicking && currentPicker == NULL_KEY && currentPickerIdx < llGetListLength(pickQueue)) {
                if (toucher == llGetOwner()) {
                    currentPicker = toucher;
                    shouldBePicking = TRUE;
                }
            }
            
            // Check for dialog recovery (original logic OR enhanced detection)
            if (currentPicker == toucher || shouldBePicking) {
                llSay(0, "🔄 " + playerName + " - Welcome back! Restoring your number picking dialog...");
                llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, playerName, toucher);
                return;
            }
            else if (playerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
                llSay(0, "🔄 " + playerName + " - Welcome back! Restoring your roll dialog...");
                llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, toucher);
                return;
            }
        }

        // Special handling for owner during gameplay
        if (toucher == llGetOwner() && roundStarted) {
            string ownerName = getPlayerName(toucher);
            list options = [];
            string menuText = "Game in progress. What would you like to do?";
            
            integer hasActiveDialog = FALSE;
            if (currentPicker == toucher) {
                options += ["🔄 Recover Pick Dialog"];
                hasActiveDialog = TRUE;
            }
            if (ownerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
                options += ["🔄 Recover Roll Dialog"];
                hasActiveDialog = TRUE;
            }
            
            options += ["🔧 Admin Menu"];
            
            if (!hasActiveDialog) {
                llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", toucher);
                return;
            }
            
            llDialog(toucher, menuText, options, DIALOG_CHANNEL);
            return;
        }
        
        if (toucher == llGetOwner()) {
            dbg("🔍 [DEBUG] Owner touched - idx: " + (string)idx + ", players list: " + llList2CSV(players));
            if (idx == -1) {
                // Owner is not in game - show join/admin choice
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    dbg("⏳ Registration already in progress for " + getPlayerName(toucher));
                    return;
                }
                
                // Owner is not in game - determine menu type based on player count
                if (llGetListLength(players) >= 2) {
                    // Enough players for game - show starter menu
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "unregistered_owner_starter|1", toucher);
                } else {
                    // Not enough players - show basic menu
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "unregistered_owner|0", toucher);
                }
            } else {
                // Owner is already in game - show player menu with appropriate starter status
                integer isStarter = TRUE;
                integer k;
                for (k = 0; k < idx && isStarter; k++) {
                    string existingName = llList2String(names, k);
                    if (llSubStringIndex(existingName, "Bot") != 0) {
                        isStarter = FALSE;
                    }
                }
                if (idx == 0) {
                    isStarter = TRUE;
                }
                llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, toucher);
            }
        } else if (idx != -1) {
            // Non-owner player who is already registered
            integer isStarter = TRUE;
            integer m;
            for (m = 0; m < idx && isStarter; m++) {
                string existingName = llList2String(names, m);
                if (llSubStringIndex(existingName, "Bot") != 0) {
                    isStarter = FALSE;
                }
            }
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
        } else {
            string playerName = getPlayerName(toucher);
            if (playerName != "") {
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    dbg("⏳ Registration already in progress for " + playerName);
                    return;
                }
                
                pendingRegistrations += [toucher];
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER_REQUEST, playerName + "|" + (string)toucher, NULL_KEY);
                
                integer isStarter = TRUE;
                integer n;
                for (n = 0; n < llGetListLength(names) && isStarter; n++) {
                    string existingName = llList2String(names, n);
                    if (llSubStringIndex(existingName, "Bot") != 0) {
                        isStarter = FALSE;
                    }
                }
                llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
            }
        }
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
                    // Broadcast the OFFICIAL ledger to the entire Linkset
                    syncGameState();
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
        if (num == MSG_ELIMINATE_PLAYER) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "ELIMINATE_PLAYER") {
                string eliminatedPlayer = llList2String(parts, 1);
                integer idx = llListFindList(names, [eliminatedPlayer]);
                if (idx != -1) {
                    // NEW: Only announce elimination if it's not the end of the game (winner)
                    if (llGetListLength(names) > 1) {
                        sendStatusMessage("PLAYER STRUCK!\n" + eliminatedPlayer + " has been eliminated!");
                    }
                    
                    // FIRST: Set the player's lives to 0 and show 0 hearts
                    lives = llListReplaceList(lives, [0], idx, idx);
                    
                    // Send ONLY a direct scoreboard update to show 0 hearts
                    llMessageLinked(LINK_SCOREBOARD, MSG_PLAYER_UPDATE, 
                                   eliminatedPlayer + "|0|" + (string)llList2Key(players, idx), NULL_KEY);
                    
                    // CRITICAL: Check for victory condition BEFORE assigning new peril player
                    integer willCauseVictory = (llGetListLength(names) <= 2); // After removing one player
                    string potentialWinner = "";
                    
                    if (willCauseVictory) {
                        // Find the winner (the remaining non-eliminated player)
                        integer w;
                        for (w = 0; w < llGetListLength(names); w++) {
                            string candidateName = llList2String(names, w);
                            if (candidateName != eliminatedPlayer) {
                                potentialWinner = candidateName;
                                jump found_winner;
                            }
                        }
                        @found_winner;
                        
                        if (potentialWinner != "") {
                            // SEND WINNER GLOW to scoreboard and trigger floater update
                            llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_WINNER, potentialWinner, NULL_KEY);
                            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, potentialWinner, NULL_KEY);  // Update winner's floater
                            dbg("🏆 [Main Controller] Pre-victory winner glow sent for: " + potentialWinner);
                        }
                    }
                    
                    // Only assign new peril player if NOT causing victory
                    if (!willCauseVictory && (perilPlayer == eliminatedPlayer || perilPlayer == "")) {
                        // Find first remaining alive player to be new peril player (before removing eliminated player)
                        string newPerilPlayer = "";
                        integer k;
                        for (k = 0; k < llGetListLength(names) && newPerilPlayer == ""; k++) {
                            string candidateName = llList2String(names, k);
                            if (candidateName != eliminatedPlayer) { // Skip the player being eliminated
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
                            perilPlayer = newPerilPlayer;
                            // Send peril player update to scoreboard for glow effect
                            llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_PERIL_PLAYER, newPerilPlayer, NULL_KEY);
                        } else {
                            perilPlayer = "NONE";
                            // Clear peril player glow on scoreboard
                            llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_PERIL_PLAYER, "", NULL_KEY);
                        }
                    }
                    
                    // UNIFIED SYNC: Replaces inline sync calls to prevent language rift
                    syncGameState();
                    
                    // Direct floater update to ensure eliminated status is displayed
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, eliminatedPlayer, llList2Key(players, idx));
                    llSleep(2.0); // Give floater time to show eliminated status with red display
                    
                    if (willCauseVictory) {
                        // If this elimination will cause victory, give extra time for 0 hearts display
                        llSleep(1.5); // Additional time for victory scenarios
                    }
                    
                    // CHANGED: Don't cleanup floaters during elimination - let them show eliminated status
                    // The floater will show red glow + "ELIMINATED!" and stay visible until game end
                    // integer ch = llList2Integer(floaterChannels, idx);
                    // llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // llSleep(0.3); // Give floater time to cleanup
                    
                    // CRITICAL: Remove eliminated player's picks data by searching for their entry
                    // NOT by index, since picksData format is "PlayerName|picks" strings
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
                    
                    // Now remove from indexed lists (players, names, lives, floaterChannels)
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    
                    // NEW: FINAL SYNC - Tell everyone the list has actually SHRUNK now
                    // This prevents "Zombie Respawns" and "Ghost Heals"
                    syncGameState();
                    
                    // Peril player assignment already handled before sync message was sent
                    
                    // CHANGED: Send to scoreboard, which will handle leaderboard updates
                    llMessageLinked(LINK_SCOREBOARD, MSG_GAME_LOST, eliminatedPlayer, NULL_KEY);
                    
                    // Status message now sent directly by Roll Module
                    
                    // Check for victory condition BEFORE calling updateHelpers()
                    if (llGetListLength(names) <= 1) {
                        if (llGetListLength(names) == 1) {
                            string winner = llList2String(names, 0);
                            
                            // ENHANCED: Give eliminated player's floater time to show eliminated status
                            // before declaring victory and cleaning up
                            dbg("⏳ [Main Controller] Final elimination detected - allowing display time before victory");
                            llSleep(2.0); // Give final eliminated player time to show red eliminated status
                            
                            // CRITICAL: Set victory flag immediately to prevent sync processing
                            victoryInProgress = TRUE;
                            
                            // CRITICAL: Clear all game state immediately before any sync messages
                            // This prevents broadcasting stale winner data to other scripts
                            players = [];
                            names = [];
                            lives = [];
                            picksData = [];
                            perilPlayer = "";
                            pickQueue = [];
                            currentPickerIdx = 0;
                            roundStarted = FALSE;
                            gameStarting = FALSE;
                            currentPicker = NULL_KEY;
                            
                            llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
                            
                            // NEW: Send victory status to board and display winner name!
                            sendStatusMessage("Victory"); 
                            llMessageLinked(LINK_SET, MSG_STATUS_TEXT, "=== ULTIMATE VICTORY ===\n<!c=white>" + winner + " wins!", NULL_KEY);
                            
                            llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
                            llMessageLinked(LINK_SET, MSG_EFFECT_CONFETTI, "VICTORY_CONFETTI", NULL_KEY);
                            
                            // IMPORTANT: Send winner update to scoreboard and trigger floater update
                            llMessageLinked(LINK_SCOREBOARD, MSG_UPDATE_WINNER, winner, NULL_KEY);
                            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, winner, NULL_KEY);  // Update winner's floater
                            
                            // CHANGED: Send to scoreboard, which will handle leaderboard updates
                            llMessageLinked(LINK_SCOREBOARD, MSG_GAME_WON, winner, NULL_KEY);
                            
                            // Use timer instead of llSleep to avoid immediate reset
                            dbg("🏆 [Main Controller] Winner glow applied - starting victory delay timer");
                            victoryDelayTimer = llGetUnixTime();
                            currentTimerMode = TIMER_VICTORY_DELAY;
                            llSetTimerEvent(1.0);  // Check every second
                            return;  // Exit here - timer will handle reset
                        } else {
                            // CRITICAL: Set victory flag and clear state for no survivors scenario too
                            victoryInProgress = TRUE;
                            players = [];
                            names = [];
                            lives = [];
                            picksData = [];
                            perilPlayer = "";
                            pickQueue = [];
                            currentPickerIdx = 0;
                            roundStarted = FALSE;
                            gameStarting = FALSE;
                            currentPicker = NULL_KEY;
                            
                            llSay(0, "💀 DESPAIR WINS! No Ultimate Survivors remain!");
                            
                            // Use timer for no survivors scenario too
                            victoryDelayTimer = llGetUnixTime();
                            currentTimerMode = TIMER_VICTORY_DELAY;
                            llSetTimerEvent(1.0);
                            return;
                        }
                    }
                    
                    // CRITICAL: After elimination, sync state and continue game with new peril player
                    if (perilPlayer != "" && perilPlayer != "NONE") {
                        // Sync the updated game state to all modules (4-part format)
                        // Optimized to avoid large temporary string variables
                        llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, 
                            llList2CSV(lives) + "~EMPTY~" + perilPlayer + "~" + llList2CSV(names), NULL_KEY);
                        llSleep(0.5); // Give sync time to propagate
                        
                        // Continue the game with the new peril player - delegate to Game Manager
                        llMessageLinked(LINK_SET, 998, perilPlayer, NULL_KEY);
                    }
                    
                    // MINIMAL: Only send direct scoreboard update for remaining players
                    // Skip heavy updateHelpers() calls to prevent memory crashes
                }
            }
            return;
        }
        
        // Handle emergency reset for stuck games
        if (num == MSG_EMERGENCY_RESET && str == "EMERGENCY_RESET") {
            dbg("🚨 [Main Controller] Emergency reset triggered - sending emergency reset to all scripts");
            // Signal all scripts to emergency reset
            llMessageLinked(LINK_SET, MSG_EMERGENCY_RESET, "EMERGENCY_RESET", NULL_KEY);
            llSleep(0.5);
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
                llSleep(2.0);
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
            list queryParts = llParseString2List(str, ["|"], []);
            string playerName;
            integer requestID = 0;
            
            if (llGetListLength(queryParts) >= 2) {
                playerName = llList2String(queryParts, 0);
                requestID = (integer)llList2String(queryParts, 1);
            } else {
                playerName = str;
            }
            
            integer isReady = llListFindList(readyPlayers, [playerName]) != -1;
            integer isBot = llSubStringIndex(playerName, "Bot") == 0;
            string result = playerName + "|" + (string)isReady + "|" + (string)isBot + "|" + (string)requestID;
            llMessageLinked(LINK_SET, MSG_READY_STATE_RESULT, result, id);
            return;
        }
        
        // Handle owner status queries
        if (num == MSG_QUERY_OWNER_STATUS) {
            list queryParts = llParseString2List(str, ["|"], []);
            string ownerName;
            integer requestID = 0;
            
            if (id == gameOwner) {
                // Owner touched board - allow menu access AND trigger sentinel re-check
                checkExperience();
            }
            
            if (llGetListLength(queryParts) >= 2) {
                ownerName = llList2String(queryParts, 0);
                requestID = (integer)llList2String(queryParts, 1);
            } else {
                ownerName = str;
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
            
            string result = ownerName + "|" + (string)isRegistered + "|" + (string)isPending + "|" + (string)isStarter + "|" + (string)requestID;
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
                    // CHANGED: Remove player from scoreboard BEFORE updating lists
                    llMessageLinked(LINK_SCOREBOARD, MSG_REMOVE_PLAYER, leavingName, NULL_KEY);
                    
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
                    // CHANGED: Send to scoreboard, which will handle leaderboard reset
                    llMessageLinked(LINK_SCOREBOARD, MSG_RESET_LEADERBOARD, "", NULL_KEY);
                    dbg("🏆 Leaderboard scores reset - game wins cleared!");
                    return;
                }
                if (msg == "Reset All") {
                    resetGame();
                    llMessageLinked(LINK_SCOREBOARD, MSG_RESET_LEADERBOARD, "", NULL_KEY);
                    dbg("🔄 Complete reset - game and leaderboard cleared!");
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
                        llSleep(0.3);
                    }
                    dbg("✅ Floater creation requests sent for all players!");
                    
                    // After forcing floaters, show appropriate menu based on owner registration status
                    integer ownerIdx = llListFindList(players, [llGetOwner()]);
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
                
                integer actualPlayerCount = llGetListLength(names);
                llSetText("🎮 GAME IN PROGRESS\n" + (string)actualPlayerCount + " players", <1.0, 0.2, 0.2>, 1.0);
                
                // FIXED: Use proper announcement instead of internal texture name "Title"
                sendStatusMessage("GAME STARTING!\nAll players are ready!");
                
                // Dramatic pause to let the start announcement be read before round prep begins
                llSleep(4.0);
                
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
            // If the timer hits in XP_CHECK mode, it means llReadKeyValue FAILED to respond
            // THE "KEY" CHECK: Using the Experience Key directly to verify land permissions.
            // This is the definitive check to see if the Experience is allowed on this parcel.
            if (!llAgentInExperience(EXPERIENCE_ID)) {
                llOwnerSay("⚠️ [Peril Dice] SYSTEM WARNING: Experience features are BLOCKED on this land.");
                llOwnerSay("🛡️ [Peril Dice] TO FIX: Open 'About Land' -> 'Experiences' -> 'Add' and search for 'Final Girlz I.N.C.'");
                return; 
            }
            llSetTimerEvent(0);
            currentTimerMode = TIMER_IDLE;
            
            llOwnerSay("⚠️ [Peril Dice] SYSTEM WARNING: The 'Final Girlz I.N.C.' Experience is NOT active on this parcel!");
            llOwnerSay("🛡️ [Peril Dice] Auto-HUD attachment will FAIL. To fix: Open 'About Land' -> 'Experiences' -> 'Add' and search for 'Final Girlz I.N.C.'");
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
            // If the land is not configured, data will often be an error string like "Error: XP_ERROR_NOT_EXPERIENCE"
            if (llGetSubString(data, 0, 4) != "Error") {
                sentinelQueryID = NULL_KEY;
                llSetTimerEvent(0);
                currentTimerMode = TIMER_IDLE;
                dbg("✅ [Peril Dice] Experience Sentinel: KVP Handshake Successful. Land is ready!");
            } else {
                dbg("⚠️ [Peril Dice] Sentinel handshake returned error: " + data);
            }
        }
    }
    
    experience_permissions_denied(key agent_id, integer reason) {
        // This event fires if an Experience function fails (like our Sentinel Ping)
        // Reason 17 = XP_ERROR_NOT_PERMITTED_LAND
        if (reason == 17 || reason == 1) { // 1 = XP_ERROR_NOT_EXPERIENCE
            sentinelQueryID = NULL_KEY;
            llSetTimerEvent(0);
            currentTimerMode = TIMER_IDLE;
            
            llOwnerSay("⚠️ [Peril Dice] SYSTEM WARNING: Experience Features are BLOCKED on this land.");
            llOwnerSay("🛡️ [Peril Dice] TO FIX: Open 'About Land' -> 'Experiences' -> 'Add' -> 'Final Girlz I.N.C.'");
        } else {
            dbg("⚠️ [Peril Dice] Experience Denial (Code " + (string)reason + ") for agent " + (string)agent_id);
        }
    }
}
