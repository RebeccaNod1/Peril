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

// Target link numbers (confirmed from actual linkset scan)
integer SCOREBOARD_LINK = 2;      // Scoreboard manager (tiny controller box)
integer LEADERBOARD_LINK = 25;    // Leaderboard manager (first XyzzyText prim)
integer DICE_LINK = 73;           // Dice display manager (first dice prim)

// Message constants for link communication
// Scoreboard messages (to link 2)
integer MSG_GAME_STATUS = 3001;
integer MSG_PLAYER_UPDATE = 3002;
integer MSG_CLEAR_GAME = 3003;
integer MSG_REMOVE_PLAYER = 3004;

// Leaderboard messages (to link 25)  
integer MSG_GAME_WON = 3010;
integer MSG_GAME_LOST = 3011;
integer MSG_RESET_LEADERBOARD = 3012;

// Dice messages (to link 73)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;

// Legacy message constants (keep for internal controller communication)
integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
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
integer TIMER_TIMEOUT = 2;
integer TIMER_DISCOVERY = 3;
integer currentTimerMode = 0;    // Track what the timer is currently doing
float timerInterval = 1.0;       // How often timer() is called for checks

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

integer TIMEOUT_SECONDS = 120;  // 2 minute timeout
integer timeoutTimer;
integer warning30sec = 30;   
integer warning1min = 60;    
integer warning90sec = 90;   
integer lastWarning = 0;

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

emergencyMemoryCleanup() {
    llOwnerSay("🎆 [Main Controller] Emergency memory cleanup initiated!");
    
    globalPickedNumbers = llListSort(globalPickedNumbers, 1, TRUE); 
    
    list tempPlayers = players;
    list tempNames = names;
    list tempLives = lives;
    
    players = [];
    names = [];
    lives = [];
    
    players = tempPlayers;
    names = tempNames;
    lives = tempLives;
    
    llOwnerSay("🎆 [Main Controller] Emergency cleanup complete - memory: " + 
               (string)llGetUsedMemory() + " bytes");
}

reportMemoryStats() {
    string statsData = (string)llGetUsedMemory() + "|" + 
                       (string)llGetListLength(players) + "|" + 
                       (string)llGetListLength(names) + "|" + 
                       (string)llGetListLength(lives) + "|" + 
                       (string)llGetListLength(picksData) + "|" + 
                       (string)llGetListLength(readyPlayers) + "|" + 
                       (string)llGetListLength(pickQueue) + "|" + 
                       (string)llGetListLength(globalPickedNumbers) + "|" + 
                       (string)llGetListLength(floaterChannels);
    
    llMessageLinked(LINK_SET, MSG_MEMORY_STATS_REQUEST, statsData, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_MEMORY_STATS, "REQUEST_REPORT", NULL_KEY);
}

// Send status message to scoreboard using link messages
sendStatusMessage(string status) {
    statusTimer = llGetUnixTime();
    lastStatus = status;
    
    // CHANGED: Use link message instead of llRegionSay
    llMessageLinked(SCOREBOARD_LINK, MSG_GAME_STATUS, status, NULL_KEY);
    
    llOwnerSay("📢 Status: " + status + " (showing for " + (string)STATUS_DISPLAY_TIME + "s)");
    
    currentTimerMode = TIMER_STATUS;
    llSetTimerEvent(STATUS_DISPLAY_TIME + 1.0);
}

// Forward game state to helpers when it changes
updateHelpers() {
    checkMemoryUsage("updateHelpers_start");
    
    string perilForSync = "NONE";
    if (perilPlayer != "" && perilPlayer != "NONE") {
        perilForSync = perilPlayer;
    }
    
    string picksDataStr = "EMPTY";
    integer dataCount = llGetListLength(picksData);
    if (dataCount > 0) {
        picksDataStr = llDumpList2String(picksData, "^");
        checkMemoryUsage("updateHelpers_after_picks_processing");
    }
    
    // Send core game state to internal scripts (include players list for floater management)
    string syncMessage = llList2CSV(lives) + "~" + picksDataStr + "~" + perilForSync + "~" + llList2CSV(names) + "~" + llList2CSV(players);
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, syncMessage, NULL_KEY);
    
    // Send scoreboard updates using link messages
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        string updateData = llList2String(names, i) + "|" + 
                           (string)llList2Integer(lives, i) + "|" + 
                           (string)llList2Key(players, i);
        
        // CHANGED: Use link message instead of llRegionSay
        llMessageLinked(SCOREBOARD_LINK, MSG_PLAYER_UPDATE, updateData, NULL_KEY);
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
    return llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
}

// Update floating text based on lock status
updateFloatingText() {
    if (isLocked) {
        llSetText("🔒 GAME LOCKED\nOwner access only", <1.0, 0.5, 0.0>, 1.0);
    } else {
        if (roundStarted || gameStarting) {
            llSetText("🎮 GAME IN PROGRESS\nRound " + (string)(llGetListLength(names)) + " players", <1.0, 0.2, 0.2>, 1.0);
        } else {
            llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
        }
    }
}

resetGame() {
    cleanupListeners();
    
    // Only clean up channels that actually have active floaters
    integer i;
    for (i = 0; i < llGetListLength(floaterChannels); i++) {
        integer ch = llList2Integer(floaterChannels, i);
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    
    // Also send a few cleanup messages to common channel ranges in case of orphaned floaters
    for (i = 0; i < llGetListLength(names); i++) {
        integer ch = FLOATER_BASE_CHANNEL + i;
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    
    llSleep(2.0);
    
    players = names = lives = picksData = globalPickedNumbers = readyPlayers = [];
    floaterChannels = [];
    pendingRegistrations = [];
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    roundStarted = FALSE;
    gameStarting = FALSE;
    currentPicker = NULL_KEY;
    timeoutTimer = 0;
    lastWarning = 0;
    
    llMessageLinked(LINK_SET, -99999, "FULL_RESET", NULL_KEY);
    llSay(syncChannel, "RESET");
    
    // CHANGED: Use link messages instead of llRegionSay for display cleanup
    llMessageLinked(SCOREBOARD_LINK, MSG_CLEAR_GAME, "", NULL_KEY);
    llMessageLinked(DICE_LINK, MSG_CLEAR_DICE, "", NULL_KEY);
    
    llOwnerSay("🎮 Game reset! All state cleared (including scoreboard).");
    
    statusTimer = 0;
    lastStatus = "";
    
    llSetTexture(TEXTURE_START, CONTROLLER_FACE);
    llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
    
    llSleep(0.5);
    llSetTimerEvent(0);
    
    initListeners();
    updateHelpers();
}

default {
    state_entry() {
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
        
        // Check if player has a current dialog they can recover
        if (idx != -1 && toucher != llGetOwner() && roundStarted) {
            string playerName = llList2String(names, idx);
            if (currentPicker == toucher) {
                llRegionSayTo(toucher, 0, "🔄 Restoring your number picking dialog...");
                llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, playerName, toucher);
                return;
            }
            else if (playerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
                llRegionSayTo(toucher, 0, "🔄 Restoring your roll dialog...");
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
            if (idx == -1) {
                // Owner is not in game - show join/admin choice
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    llOwnerSay("⏳ Registration already in progress for " + getPlayerName(toucher));
                    return;
                }
                
                // Show owner choice menu: join game or access admin functions
                list options = ["Join Game", "Owner Menu"];
                string menuText = "👑 Owner Options:\n\n🎮 Join Game - Register as a player\n🔧 Owner Menu - Admin functions without joining";
                llDialog(toucher, menuText, options, DIALOG_CHANNEL);
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
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, playerName + "|" + (string)toucher, NULL_KEY);
                
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
        // Handle player registration
        if (num == MSG_REGISTER_PLAYER) {
            checkMemoryUsage("player_registration_start");
            
            list parts = llParseString2List(str, ["|"], []);
            string newName = llList2String(parts, 0);
            key newKey = (key)llList2String(parts, 1);
            
            if ((roundStarted || gameStarting) && newKey != llGetOwner()) {
                llOwnerSay("🚫 " + newName + " cannot join - the killing game has begun!");
                llRegionSayTo(newKey, 0, "🚫 The killing game has already begun! Wait for the current game to end.");
                return;
            }
            
            integer existingIdx = llListFindList(players, [newKey]);
            if (existingIdx == -1) {
                players += [newKey];
                names += [newName];
                lives += [3];
                checkMemoryUsage("player_registration_after_list_additions");
                
                integer newPlayerIdx = llGetListLength(names) - 1;
                integer ch = FLOATER_BASE_CHANNEL + newPlayerIdx;
                floaterChannels += [ch];
                
                if (llSubStringIndex(newName, "Bot") == 0) {
                    readyPlayers += [newName];
                    llSay(0, "🤖 " + newName + " boots up with deadly precision - ready to play! 🤖");
                } else {
                    integer humanCount = 0;
                    integer i;
                    for (i = 0; i < llGetListLength(names); i++) {
                        string playerName = llList2String(names, i);
                        if (llSubStringIndex(playerName, "Bot") != 0) {
                            humanCount++;
                        }
                    }
                    if (humanCount == 1) {
                        // First human player becomes the starter - owner or not
                        llSay(0, "👑 " + newName + " steps forward as the game starter! Touch to set your ready status.");
                    } else {
                        // Subsequent players need to set ready status
                        llSay(0, "🎮 " + newName + " has joined the deadly game! Touch to set your ready status.");
                    }
                }
                
                // If this is the owner joining, show them the appropriate player menu
                if (newKey == llGetOwner()) {
                    integer isStarter = TRUE;
                    integer j;
                    for (j = 0; j < llGetListLength(names) - 1 && isStarter; j++) {
                        string existingName = llList2String(names, j);
                        if (llSubStringIndex(existingName, "Bot") != 0) {
                            isStarter = FALSE;
                        }
                    }
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, newKey);
                }
                updateHelpers();
                llOwnerSay("🔔 Added player: " + newName);
            }
            
            integer pendingIdx = llListFindList(pendingRegistrations, [newKey]);
            if (pendingIdx != -1) {
                pendingRegistrations = llDeleteSubList(pendingRegistrations, pendingIdx, pendingIdx);
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
                    // FIRST: Set the player's lives to 0 and update scoreboard/floaters before removal
                    lives = llListReplaceList(lives, [0], idx, idx);
                    
                    // Update scoreboard and floaters to show 0 hearts
                    updateHelpers();
                    llSleep(1.5); // Give extra time for the 0 hearts display to be visible
                    
                    // Check if this will cause victory BEFORE removing player
                    integer willCauseVictory = (llGetListLength(names) <= 2); // After removing one player
                    
                    if (willCauseVictory) {
                        // If this elimination will cause victory, give extra time for 0 hearts display
                        llSleep(1.5); // Additional time for victory scenarios
                    }
                    
                    // THEN: Clean up and remove the player
                    integer ch = llList2Integer(floaterChannels, idx);
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    
                    
                    // CHANGED: Send to scoreboard, which will handle leaderboard updates
                    llMessageLinked(SCOREBOARD_LINK, MSG_GAME_LOST, eliminatedPlayer, NULL_KEY);
                    
                    sendStatusMessage("Elimination");
                    updateHelpers();
                    
                    // CRITICAL: Update perilPlayer if the eliminated player was the peril player
                    // This prevents sending stale sync messages in updateHelpers()
                    if (perilPlayer == eliminatedPlayer) {
                        // Find first remaining alive player to be new peril player
                        string newPerilPlayer = "";
                        integer k;
                        for (k = 0; k < llGetListLength(names) && newPerilPlayer == ""; k++) {
                            string candidateName = llList2String(names, k);
                            integer candidateIdx = llListFindList(names, [candidateName]);
                            if (candidateIdx != -1 && candidateIdx < llGetListLength(lives)) {
                                integer candidateLives = llList2Integer(lives, candidateIdx);
                                if (candidateLives > 0) {
                                    newPerilPlayer = candidateName;
                                }
                            }
                        }
                        
                        if (newPerilPlayer != "") {
                            llOwnerSay("🎯 [Main Controller] Peril player eliminated - assigning new peril player: " + newPerilPlayer);
                            perilPlayer = newPerilPlayer;
                        } else {
                            llOwnerSay("⚠️ [Main Controller] No valid peril player candidates found after elimination!");
                            perilPlayer = "NONE";
                        }
                    }
                    
                    // Check for victory condition AFTER the 0 hearts display AND removal
                    if (llGetListLength(names) <= 1) {
                        if (llGetListLength(names) == 1) {
                            string winner = llList2String(names, 0);
                            llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
                            
                            llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
                            llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
                            
                            // CHANGED: Send to scoreboard, which will handle leaderboard updates
                            llMessageLinked(SCOREBOARD_LINK, MSG_GAME_WON, winner, NULL_KEY);
                            
                            llSleep(STATUS_DISPLAY_TIME * 0.8);
                            sendStatusMessage("Victory");
                            llSleep(STATUS_DISPLAY_TIME + 1.0);
                        } else {
                            llSay(0, "💀 DESPAIR WINS! No Ultimate Survivors remain!");
                            llSleep(STATUS_DISPLAY_TIME + 1.0);
                        }
                        resetGame();
                        return;
                    }
                    
                    updateHelpers();
                }
            }
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
        
        // Handle incoming sync updates from Roll Confetti Module
        if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                string currentLivesStr = llList2CSV(lives);
                string newLivesStr = llList2CSV(newLives);
                
                string newPerilPlayerCheck = llList2String(parts, 2);
                list newNames = llCSV2List(llList2String(parts, 3));
                
                // VALIDATION: Reject sync messages with invalid peril players to prevent loops
                if (newPerilPlayerCheck != "NONE" && newPerilPlayerCheck != "" && newPerilPlayerCheck != perilPlayer) {
                    // Check if the peril player exists in the new names list
                    integer perilPlayerExists = llListFindList(newNames, [newPerilPlayerCheck]) != -1;
                    if (!perilPlayerExists) {
                        llOwnerSay("⚠️ [Main Controller] REJECTING sync message with invalid peril player: " + newPerilPlayerCheck + " (player doesn't exist)");
                        return; // Reject the entire sync message
                    }
                    
                    // Check if peril player has 0 lives (eliminated)
                    integer perilPlayerIdx = llListFindList(newNames, [newPerilPlayerCheck]);
                    if (perilPlayerIdx != -1 && perilPlayerIdx < llGetListLength(newLives)) {
                        integer perilPlayerLives = llList2Integer(newLives, perilPlayerIdx);
                        if (perilPlayerLives <= 0) {
                            llOwnerSay("⚠️ [Main Controller] REJECTING sync message with eliminated peril player: " + newPerilPlayerCheck + " (0 lives)");
                            return; // Reject the entire sync message
                        }
                    }
                }
                
                if (newPerilPlayerCheck == "NONE" && perilPlayer != "" && perilPlayer != "NONE") {
                    integer perilStillInGame = llListFindList(names, [perilPlayer]) != -1;
                    if (perilStillInGame) {
                        return;
                    }
                }
                
                integer perilChanged = (perilPlayer != newPerilPlayerCheck);
                integer livesChanged = (newLivesStr != currentLivesStr);
                
                if (livesChanged || perilChanged) {
                    string encodedPicksDataStr = llList2String(parts, 1);
                    list newPicksData = [];
                    if (encodedPicksDataStr != "") {
                        list encodedEntries = llParseString2List(encodedPicksDataStr, ["^"], []);
                        integer i;
                        for (i = 0; i < llGetListLength(encodedEntries); i++) {
                            string entry = llList2String(encodedEntries, i);
                            list entryParts = llParseString2List(entry, ["|"], []);
                            if (llGetListLength(entryParts) >= 2) {
                                string playerName = llList2String(entryParts, 0);
                                string picks = llList2String(entryParts, 1);
                                picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                                newPicksData += [playerName + "|" + picks];
                            } else {
                                newPicksData += [entry];
                            }
                        }
                    }
                    string newPerilPlayer = llList2String(parts, 2);
                    list newNames = llCSV2List(llList2String(parts, 3));
                    
                    lives = newLives;
                    picksData = newPicksData;
                    perilPlayer = newPerilPlayer;
                    names = newNames;
                    
                    // Update scoreboard and other helpers with the new game state
                    updateHelpers();
                    
                    integer allPicksEmpty = TRUE;
                    integer i;
                    for (i = 0; i < llGetListLength(newPicksData) && allPicksEmpty; i++) {
                        string entry = llList2String(newPicksData, i);
                        list parts = llParseString2List(entry, ["|"], []);
                        if (llGetListLength(parts) >= 2 && llList2String(parts, 1) != "") {
                            allPicksEmpty = FALSE;
                        }
                    }
                    
                    if (livesChanged && newPerilPlayer != "" && newPerilPlayer != "NONE" && roundStarted && allPicksEmpty) {
                        llOwnerSay("🎯 Post-roll state update detected - Game Manager will handle round continuation");
                    }
                }
            }
            return;
        }
        
        // Handle start next round request - delegate to Game Manager
        if (num == 997) {
            if (sender == llGetLinkNumber()) {
                return;
            }
            
            if (roundStarted && str == "START_NEXT_ROUND") {
                llOwnerSay("⚠️ [Main Controller] Round already in progress, ignoring START_NEXT_ROUND");
                return;
            }
            
            llOwnerSay("🔄 [Main Controller] Starting new round - Game Manager will handle dice type");
            llMessageLinked(LINK_SET, num, str, id);
            return;
        }
        
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
        
        // Handle aggressive floater cleanup
        if (num == MSG_CLEANUP_ALL_FLOATERS) {
            integer i;
            for (i = 0; i < MAX_PLAYERS; i++) {
                integer ch = FLOATER_BASE_CHANNEL + i;
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 100), NULL_KEY);
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 1000), NULL_KEY);
            }
            floaterChannels = [];
            return;
        }
        
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
                    
                    // Update all other scripts with the new state
                    updateHelpers();
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
        
        // Handle memory monitor messages
        if (num == MSG_EMERGENCY_CLEANUP) {
            emergencyMemoryCleanup();
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
                llMessageLinked(LINK_SET, 997, "START_NEXT_ROUND", NULL_KEY);
                return;
            }
        }
        
        if (channel == DIALOG_CHANNEL) {
            // Handle owner choice dialog responses during gameplay
            if (id == llGetOwner() && roundStarted) {
                if (msg == "🔄 Recover Pick Dialog") {
                    string ownerName = getPlayerName(id);
                    llRegionSayTo(id, 0, "🔄 Restoring your number picking dialog...");
                    llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, ownerName, id);
                    return;
                }
                else if (msg == "🔄 Recover Roll Dialog") {
                    llRegionSayTo(id, 0, "🔄 Restoring your roll dialog...");
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
                    reportMemoryStats();
                    return;
                }
                if (msg == "Add Test Player") {
                    if (llGetListLength(players) >= MAX_PLAYERS) {
                        llOwnerSay("⚠️ Cannot add test player; the game is full (max " + (string)MAX_PLAYERS + ").");
                        return;
                    }
                    
                    // Create shorter bot names to avoid dialog button length issues
                    integer botNum = llGetListLength(players) + 1;
                    string testName = "Bot" + (string)botNum;
                    key fake = llGenerateKey();
                    llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, testName + "|" + (string)fake, NULL_KEY);
                    
                    integer ownerIdx = llListFindList(players, [llGetOwner()]);
                    integer ownerIsStarter = TRUE;
                    integer n;
                    for (n = 0; n < ownerIdx && ownerIsStarter; n++) {
                        string existingName = llList2String(names, n);
                        if (llSubStringIndex(existingName, "TestBot") != 0) {
                            ownerIsStarter = FALSE;
                        }
                    }
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)ownerIsStarter, llGetOwner());
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
                    
                    integer ownerIdx = llListFindList(players, [llGetOwner()]);
                    integer ownerIsStarter = TRUE;
                    integer n;
                    for (n = 0; n < ownerIdx && ownerIsStarter; n++) {
                        string existingName = llList2String(names, n);
                        if (llSubStringIndex(existingName, "Bot") != 0) {
                            ownerIsStarter = FALSE;
                        }
                    }
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)ownerIsStarter, llGetOwner());
                    return;
                }
            }
            
            // Allow starter to start the game
            if (msg == "Start Game") {
                if (llGetListLength(players) < 2) {
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
                
                llSetText("🎮 GAME IN PROGRESS\nRound " + (string)(llGetListLength(names)) + " players", <1.0, 0.2, 0.2>, 1.0);
                
                sendStatusMessage("Title");
                llMessageLinked(LINK_SET, 997, "START_NEXT_ROUND", NULL_KEY);
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
        else if (currentTimerMode == TIMER_TIMEOUT) {
            if (timeoutTimer > 0) {
                integer elapsed = llGetUnixTime() - timeoutTimer;
                if (elapsed >= TIMEOUT_SECONDS) {
                    llOwnerSay("⏰ Dialog timeout reached!");
                    timeoutTimer = 0;
                    currentTimerMode = TIMER_IDLE;
                    llSetTimerEvent(0);
                } else {
                    integer remaining = TIMEOUT_SECONDS - elapsed;
                    if (remaining <= warning30sec && lastWarning < warning30sec) {
                        llOwnerSay("⚠️ 30 seconds remaining for dialog response");
                        lastWarning = warning30sec;
                    } else if (remaining <= warning1min && lastWarning < warning1min) {
                        llOwnerSay("⚠️ 1 minute remaining for dialog response");
                        lastWarning = warning1min;
                    } else if (remaining <= warning90sec && lastWarning < warning90sec) {
                        llOwnerSay("⚠️ 1.5 minutes remaining for dialog response");
                        lastWarning = warning90sec;
                    }
                }
            }
        }
    }
}
