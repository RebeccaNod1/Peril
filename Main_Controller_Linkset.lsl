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

//
// LINKSET VERSION - Uses llMessageLinked() instead of llRegionSay()
// All discovery and channel management code removed
//

// =============================================================================
// LINKSET COMMUNICATION CONSTANTS
// =============================================================================

// Target link numbers (UPDATED after overlay prim insertion)
integer SCOREBOARD_LINK = 12;     // Scoreboard manager cube
integer LEADERBOARD_LINK = 35;    // Leaderboard manager (first XyzzyText prim)
integer DICE_LINK = 83;           // Dice display manager (first dice prim)

// Message constants for link communication
// Scoreboard messages (to link 12)
integer MSG_GAME_STATUS = 3001;
integer MSG_PLAYER_UPDATE = 3002;
integer MSG_CLEAR_GAME = 3003;
integer MSG_REMOVE_PLAYER = 3004;
integer MSG_UPDATE_PERIL_PLAYER = 3005;
integer MSG_UPDATE_WINNER = 3006;

// Leaderboard messages (to link 35)  
integer MSG_GAME_WON = 3010;
integer MSG_GAME_LOST = 3011;
integer MSG_RESET_LEADERBOARD = 3012;

// Dice messages (to link 83)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;

// Legacy message constants (keep for internal controller communication)
integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_REGISTER_PLAYER_REQUEST = 9050;  // New dedicated message to Player_RegistrationManager
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SHOW_MENU = 201;
integer MSG_TOGGLE_READY = 202;
integer MSG_QUERY_READY_STATE = 210;
integer MSG_READY_STATE_RESULT = 211;
integer MSG_CLEANUP_ALL_FLOATERS = 212;
integer MSG_QUERY_OWNER_STATUS = 213;
integer MSG_OWNER_STATUS_RESULT = 214;
integer MSG_SHOW_ROLL_DIALOG = 301;
integer MSG_GET_CURRENT_DIALOG = 302;
integer MSG_PLAYER_WON = 551;
integer MSG_GET_PICKS_REQUIRED = 1002;
integer MSG_GET_PICKER_INDEX = 1003;

// Memory monitoring handled by Controller_Memory.lsl helper script
integer MSG_MEMORY_CHECK = 6001;
integer MSG_MEMORY_STATS = 6002;
integer MSG_MEMORY_CLEANUP = 6003;
integer MSG_MEMORY_REPORT = 6004;
integer MSG_EMERGENCY_CLEANUP = 6005;
integer MSG_MEMORY_STATS_REQUEST = 6006;

// Unified Timer System - prevents conflicts between multiple timer needs
integer TIMER_IDLE = 0;
integer TIMER_STATUS = 1;
integer TIMER_VICTORY_DELAY = 2;  // Timer mode for victory glow display
integer currentTimerMode = 0;    // Track what the timer is currently doing
float timerInterval = 1.0;       // How often timer() is called for checks
integer victoryDelayTimer = 0;   // Track victory delay timing

// Debug control - set to TRUE for verbose pick debugging, FALSE for normal operation
integer DEBUG_PICKS = FALSE;

// Verbose logging moved to dedicated Verbose_Logger.lsl script to save memory
// Message constants for verbose logging
integer MSG_VERBOSE_LOG = 9020;
integer MSG_VERBOSE_TOGGLE = 9010;

// Script ID for Main Controller (used by Verbose_Logger for prefixes)
integer SCRIPT_ID_MAIN = 0;

// Message handling constants (delegate to Controller_MessageHandler)
integer MSG_OWNER_MESSAGE = 9030;
integer MSG_PUBLIC_MESSAGE = 9031;
integer MSG_REGION_MESSAGE = 9032;
integer MSG_DIALOG_REQUEST = 9033;

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
float STATUS_DISPLAY_TIME = 8.0; // How long to show status messages on scoreboard
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
integer REGISTRATION_TIMEOUT = 10;  // Seconds to keep pending registration

// Display configuration
integer CONTROLLER_FACE = 1;  // Face to display start image on (front face)
string TEXTURE_START = "title_start";  // Start image texture
string TEXTURE_GAME_ACTIVE = "game_active";  // Optional: different texture during game

// Maximum number of players allowed (including test players)
integer MAX_PLAYERS = 10;

// Timeout system removed - using owner kick functionality instead

key currentPicker;

// Game timing settings
float BOT_PICK_DELAY = 2.0;      
float HUMAN_PICK_DELAY = 1.0;    
float DIALOG_DELAY = 1.5;        
integer gameTimer = 0;           

// Dynamic channel system for floaters and dialogs (still needed for external communication)
integer CHANNEL_BASE = -77000;

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

// Send status message to scoreboard using link messages
sendStatusMessage(string status) {
    statusTimer = llGetUnixTime();
    lastStatus = status;
    
    // CHANGED: Use link message instead of llRegionSay
    llMessageLinked(SCOREBOARD_LINK, MSG_GAME_STATUS, status, NULL_KEY);
    
    // Removed ownerMsg call to save memory
    
    currentTimerMode = TIMER_STATUS;
    llSetTimerEvent(STATUS_DISPLAY_TIME + 1.0);
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
        llMessageLinked(SCOREBOARD_LINK, MSG_PLAYER_UPDATE, 
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
    // Only request cleanup if we actually have game data that might have floaters
    if (llGetListLength(names) > 0 || llGetListLength(floaterChannels) > 0) {
        llMessageLinked(LINK_SET, MSG_CLEANUP_ALL_FLOATERS, "RESET", NULL_KEY);
        llSleep(1.0);
    }
    
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
    
    llMessageLinked(LINK_SET, -99999, "FULL_RESET", NULL_KEY);
    llSay(syncChannel, "RESET");
    
    // CHANGED: Use link messages instead of llRegionSay for display cleanup
    llMessageLinked(SCOREBOARD_LINK, MSG_CLEAR_GAME, "", NULL_KEY);
    // Clear winner glow from scoreboard (floaters will clear naturally on reset)
    llMessageLinked(SCOREBOARD_LINK, MSG_UPDATE_WINNER, "", NULL_KEY);  // Clear winner glow
    llMessageLinked(DICE_LINK, MSG_CLEAR_DICE, "", NULL_KEY);
    
    llOwnerSay("🎮 Game reset! All state cleared (including scoreboard).");
    
    statusTimer = 0;
    lastStatus = "";
    
    llSetTexture(TEXTURE_START, CONTROLLER_FACE);
    llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
    
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
        reportMemoryUsage("Main Controller");
        llOwnerSay("🎮 Main Controller ready! (Linkset Version)");
        
        // Initialize lockout system
        gameOwner = llGetOwner();
        isLocked = FALSE; // Default to unlocked
        
        // Initialize channels for external communication
        initializeChannels();
        
        // Reset the game on startup to ensure clean state
        resetGame();
        
        llOwnerSay("✅ Main Controller initialization complete!");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("Main Controller");
        llOwnerSay("🔄 Main Controller rezzed - resetting game state...");
        
        // Re-initialize lockout system
        gameOwner = llGetOwner();
        isLocked = FALSE;
        
        // Re-initialize channels for external communication
        initializeChannels();
        
        // Reset the game to ensure clean state when rezzed
        resetGame();
        
        llOwnerSay("✅ Main Controller reset complete after rez!");
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        
        // Enhanced disconnect/reconnect handling - check if this player should be picking
        if (idx != -1 && toucher != llGetOwner() && roundStarted) {
            string playerName = llList2String(names, idx);
            
            // ENHANCED: Check if this player is supposed to be the current picker based on game state
            // This handles cases where currentPicker got corrupted due to disconnect
            integer shouldBePicking = FALSE;
            if (currentPickerIdx < llGetListLength(pickQueue)) {
                string expectedPickerName = llList2String(pickQueue, currentPickerIdx);
                // Removed debugMsg call to save memory
                if (playerName == expectedPickerName) {
                    shouldBePicking = TRUE;
                    // Fix corrupted currentPicker state
                    if (currentPicker != toucher) {
                    // Removed ownerMsg call to save memory
                        currentPicker = toucher;
                    }
                }
            } else {
                // Removed debugMsg call to save memory
            }
            
            // FALLBACK: If game is stuck and no one is set as current picker, but we're in pick phase,
            // let any registered player attempt to resume (with owner confirmation)
            if (!shouldBePicking && currentPicker == NULL_KEY && currentPickerIdx < llGetListLength(pickQueue)) {
                if (toucher == llGetOwner()) {
                    // Removed ownerMsg calls to save memory
                    // Game stuck error and recovery logging removed
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
            llOwnerSay("🔍 [DEBUG] Owner touched - idx: " + (string)idx + ", players list: " + llList2CSV(players));
            if (idx == -1) {
                // Owner is not in game - show join/admin choice
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    llOwnerSay("⏳ Registration already in progress for " + getPlayerName(toucher));
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
                    llOwnerSay("⏳ Registration already in progress for " + playerName);
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
            } else {
                llOwnerSay("⚠️ Could not get name for toucher: " + (string)toucher);
            }
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        // Dialog forwarding now handled by Player_RegistrationManager
        
        // Handle player registration from other scripts (NOT delegated, this is for other internal communication)
        if (num == MSG_REGISTER_PLAYER) {
            // This is for other scripts that might still use the old MSG_REGISTER_PLAYER message
            // Convert it to the new message for the Player_RegistrationManager
            llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER_REQUEST, str, id);
            return;
        }
        
        // Handle registration updates from Player_RegistrationManager
        if (num == 9040) { // MSG_UPDATE_MAIN_LISTS
            // ULTRA-OPTIMIZED: Player_RegistrationManager now handles all heavy processing
            // Main Controller just adds the player to its master lists
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 2) {
                integer ch = llList2Integer(parts, 0);
                string newName = llList2String(parts, 1);
                
                // CHECK FOR DUPLICATES: Only check players list (names list may be populated by sync messages)
                integer existingPlayerIdx = llListFindList(players, [id]);
                
                if (existingPlayerIdx != -1) {
                    llOwnerSay("⚠️ [Main Controller] DUPLICATE PLAYER KEY DETECTED - Player: " + newName + " (" + (string)id + ") already exists!");
                    llOwnerSay("⚠️ [Main Controller] Players list length: " + (string)llGetListLength(players) + ", Names list length: " + (string)llGetListLength(names));
                    return; // Skip adding duplicate
                }
                
                // Add new player directly to master lists (minimal operations)
                players += [id];
                names += [newName];
                lives += [3];
                floaterChannels += [ch];
                
                // Clean up pending registrations
                integer pendingIdx = llListFindList(pendingRegistrations, [id]);
                if (pendingIdx != -1) {
                    pendingRegistrations = llDeleteSubList(pendingRegistrations, pendingIdx, pendingIdx);
                }
                
                // That's it! Player_RegistrationManager already sent sync and scoreboard updates
                llOwnerSay("✅ Player added to master lists: " + newName + " (" + (string)llGetFreeMemory() + " bytes free)");
                llOwnerSay("🔍 [DEBUG] Updated lists - Players: " + (string)llGetListLength(players) + ", Names: " + (string)llGetListLength(names));
            }
            return;
        }
        
        // Handle elimination requests
        if (num == 999) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "ELIMINATE_PLAYER") {
                string eliminatedPlayer = llList2String(parts, 1);
                integer idx = llListFindList(names, [eliminatedPlayer]);
                if (idx != -1) {
                    // FIRST: Set the player's lives to 0 and show 0 hearts
                    lives = llListReplaceList(lives, [0], idx, idx);
                    
                    // Send ONLY a direct scoreboard update to show 0 hearts
                    llMessageLinked(SCOREBOARD_LINK, MSG_PLAYER_UPDATE, 
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
                            llMessageLinked(SCOREBOARD_LINK, MSG_UPDATE_WINNER, potentialWinner, NULL_KEY);
                            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, potentialWinner, NULL_KEY);  // Update winner's floater
                            llOwnerSay("🏆 [Main Controller] Pre-victory winner glow sent for: " + potentialWinner);
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
                            llMessageLinked(SCOREBOARD_LINK, MSG_UPDATE_PERIL_PLAYER, newPerilPlayer, NULL_KEY);
                        } else {
                            perilPlayer = "NONE";
                            // Clear peril player glow on scoreboard
                            llMessageLinked(SCOREBOARD_LINK, MSG_UPDATE_PERIL_PLAYER, "", NULL_KEY);
                        }
                    }
                    
                    // CRITICAL: Send sync message with 0 lives so floater shows elimination state
                    // Build sync message BEFORE any list modifications to prevent corruption
                    string livesStr = llList2CSV(lives);
                    string picksStr = llDumpList2String(picksData, "^");
                    if (picksStr == "") picksStr = "EMPTY";  // Prevent empty string
                    string perilStr = perilPlayer;
                    if (perilStr == "") perilStr = "NONE";   // Prevent empty string
                    string namesStr = llList2CSV(names);
                    string playersStr = llList2CSV(players);
                    
                    string eliminationSync = livesStr + "~" + picksStr + "~" + perilStr + "~" + namesStr + "~" + playersStr;
                    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, eliminationSync, NULL_KEY);
                    
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
                    
                    
                    // Peril player assignment already handled before sync message was sent
                    
                    // CHANGED: Send to scoreboard, which will handle leaderboard updates
                    llMessageLinked(SCOREBOARD_LINK, MSG_GAME_LOST, eliminatedPlayer, NULL_KEY);
                    
                    // Status message now sent directly by Roll Module
                    
                    // Check for victory condition BEFORE calling updateHelpers()
                    if (llGetListLength(names) <= 1) {
                        if (llGetListLength(names) == 1) {
                            string winner = llList2String(names, 0);
                            
                            // ENHANCED: Give eliminated player's floater time to show eliminated status
                            // before declaring victory and cleaning up
                            llOwnerSay("⏳ [Main Controller] Final elimination detected - allowing display time before victory");
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
                            
                            llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
                            llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
                            
                            // IMPORTANT: Send winner update to scoreboard and trigger floater update
                            llMessageLinked(SCOREBOARD_LINK, MSG_UPDATE_WINNER, winner, NULL_KEY);
                            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, winner, NULL_KEY);  // Update winner's floater
                            
                            // CHANGED: Send to scoreboard, which will handle leaderboard updates
                            llMessageLinked(SCOREBOARD_LINK, MSG_GAME_WON, winner, NULL_KEY);
                            
                            // Use timer instead of llSleep to avoid immediate reset
                            llOwnerSay("🏆 [Main Controller] Winner glow applied - starting victory delay timer");
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
                        // Sync the updated game state to all modules (5-part format)
                        string picksDataStr = "EMPTY";  // Empty picks for new round
                        string gameSync = llList2CSV(lives) + "~" + picksDataStr + "~" + perilPlayer + "~" + llList2CSV(names) + "~" + llList2CSV(players);
                        llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
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
        if (num == -99998 && str == "EMERGENCY_RESET") {
            llOwnerSay("🚨 [Main Controller] Emergency reset triggered - sending emergency reset to all scripts");
            // Signal all scripts to emergency reset
            llMessageLinked(LINK_SET, -99998, "EMERGENCY_RESET", NULL_KEY);
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
                // CHANGED: Use link message instead of llRegionSay
                llMessageLinked(DICE_LINK, MSG_DICE_ROLL, winner + "|WON", NULL_KEY);
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
                    llOwnerSay("🤖 Bots are always ready and cannot change state");
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
        if (num == 8006) { // MSG_LEAVE_GAME_REQUEST
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
                    llMessageLinked(SCOREBOARD_LINK, MSG_REMOVE_PLAYER, leavingName, NULL_KEY);
                    
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
                            llOwnerSay("🎯 [Main Controller] Peril player left - assigning new peril player: " + newPerilPlayer);
                            perilPlayer = newPerilPlayer;
                            // Send peril player update to scoreboard for glow effect
                            llMessageLinked(SCOREBOARD_LINK, 3005, newPerilPlayer, NULL_KEY);  // MSG_UPDATE_PERIL_PLAYER
                        } else {
                            llOwnerSay("⚠️ [Main Controller] No valid peril player candidates found after player left!");
                            perilPlayer = "NONE";
                            // Clear peril player glow on scoreboard
                            llMessageLinked(SCOREBOARD_LINK, MSG_UPDATE_PERIL_PLAYER, "", NULL_KEY);
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
                        llOwnerSay("🔄 [Main Controller] All players left - resetting game");
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
                    llOwnerSay("✅ [Main Controller] Synchronized removal of " + leavingName);
                }
            }
            return;
        }
        
        // Handle lock/unlock messages from Dialog Handler
        if (num == 9001) { // Lock game message
            if (id == gameOwner && str == "LOCK_GAME") {
                isLocked = TRUE;
                updateFloatingText();
                llOwnerSay("🔒 [Main Controller] Game has been LOCKED - Floating text updated");
            }
            return;
        }
        
        if (num == 9002) { // Unlock game message
            if (id == gameOwner && str == "UNLOCK_GAME") {
                isLocked = FALSE;
                updateFloatingText();
                llOwnerSay("🔓 [Main Controller] Game has been UNLOCKED - Floating text updated");
            }
            return;
        }
        
        
        // Handle verbose logging toggle - redirect to dedicated Verbose_Logger script
        if (num == MSG_VERBOSE_TOGGLE && str == "TOGGLE_VERBOSE_LOGS") {
            // Forward to dedicated verbose logger script, but exclude ourselves from LINK_SET
            // Send to each script individually to avoid the forwarding loop
            integer i;
            integer linkCount = llGetNumberOfPrims();
            for (i = 2; i <= linkCount; i++) { // Start from 2 to skip ourselves (link 1)
                llMessageLinked(i, MSG_VERBOSE_TOGGLE, "TOGGLE_VERBOSE_LOGS", id);
            }
            return;
        }
        
        // Handle memory monitor messages
        if (num == MSG_EMERGENCY_CLEANUP) {
            // Removed emergencyMemoryCleanup call to save memory
            llOwnerSay("Emergency cleanup disabled to prevent crashes");
            return;
        }
        
        // Handle reset requests from other scripts (like Game_Manager)
        if (num == -99998 && str == "REQUEST_GAME_RESET") {
            llOwnerSay("🔄 [Main Controller] Reset requested by " + (string)sender + ", executing...");
            resetGame();
            return;
        }
        
    }

    listen(integer channel, string name, key id, string msg) {
        if (channel == rollDialogChannel) {
            if (msg == "Start Next Round" || msg == "BEGIN KILLING GAME") {
                if (roundStarted) {
                    llOwnerSay("⚠️ Round already in progress, ignoring duplicate round start from roll dialog");
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
                    llMessageLinked(SCOREBOARD_LINK, MSG_RESET_LEADERBOARD, "", NULL_KEY);
                    llOwnerSay("🏆 Leaderboard scores reset - game wins cleared!");
                    return;
                }
                if (msg == "Reset All") {
                    resetGame();
                    llMessageLinked(SCOREBOARD_LINK, MSG_RESET_LEADERBOARD, "", NULL_KEY);
                    llOwnerSay("🔄 Complete reset - game and leaderboard cleared!");
                    return;
                }
                if (msg == "Memory Stats") {
                    // Removed reportMemoryStats call to save memory
                    llOwnerSay("Memory stats reporting disabled to prevent crashes");
                    return;
                }
                if (msg == "Add Test Player") {
                    if (llGetListLength(players) >= MAX_PLAYERS) {
                        llOwnerSay("⚠️ Cannot add test player; the game is full (max " + (string)MAX_PLAYERS + ").");
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
                    llOwnerSay("✅ " + testName + " registration sent - touch the board again to refresh menu");
                    return;
                }
                if (msg == "Force Floaters") {
                    llOwnerSay("🔧 Forcing floater creation for all " + (string)llGetListLength(names) + " players...");
                    integer i;
                    for (i = 0; i < llGetListLength(names); i++) {
                        string playerName = llList2String(names, i);
                        key playerKey = llList2Key(players, i);
                        llMessageLinked(LINK_SET, MSG_REZ_FLOAT, playerName, playerKey);
                        llSleep(0.3);
                    }
                    llOwnerSay("✅ Floater creation requests sent for all players!");
                    
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
                    llOwnerSay("⚠️ Need at least 2 players to start the game.");
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
                    llOwnerSay("⚠️ Only the game starter can start the game.");
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
                    llOwnerSay("⚠️ Cannot start game. These players are not ready: " + llList2CSV(notReadyPlayers));
                    return;
                }
                
                gameStarting = TRUE;
                llSay(0, "⚡ ALL PARTICIPANTS READY! THE DEADLY PERIL DICE GAME BEGINS! ⚡");
                
                integer actualPlayerCount = llGetListLength(names);
                llSetText("🎮 GAME IN PROGRESS\n" + (string)actualPlayerCount + " players", <1.0, 0.2, 0.2>, 1.0);
                
                sendStatusMessage("Title");
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
                llMessageLinked(SCOREBOARD_LINK, MSG_GAME_STATUS, "Title", NULL_KEY);
                llOwnerSay("📢 Status cleared - reverted to Title");
                currentTimerMode = TIMER_IDLE;
                llSetTimerEvent(0);
            }
        }
        else if (currentTimerMode == TIMER_VICTORY_DELAY) {
            if (victoryDelayTimer > 0) {
                integer elapsed = llGetUnixTime() - victoryDelayTimer;
                if (elapsed >= (integer)(STATUS_DISPLAY_TIME * 3.0)) {  // 24 seconds
                    llOwnerSay("🏆 [Main Controller] Victory display time complete - executing game reset");
                    victoryDelayTimer = 0;
                    currentTimerMode = TIMER_IDLE;
                    llSetTimerEvent(0);
                    resetGame();  // Now reset after the delay
                }
            }
        }
    }
}
