// === Roll and Confetti Module (with Roll Dialog Handler) ===

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SHOW_ROLL_DIALOG = 301;

// Dice messages (sent to Main Controller)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;

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
integer ROLLDIALOG_CHANNEL;
integer SCOREBOARD_CHANNEL_1;
integer SCOREBOARD_CHANNEL_3;

// Channel initialization function
initializeChannels() {
    ROLLDIALOG_CHANNEL = calculateChannel(3);     // ~-77300 range
    SCOREBOARD_CHANNEL_1 = calculateChannel(6);   // ~-77600 range
    SCOREBOARD_CHANNEL_3 = calculateChannel(8);   // ~-77800 range
    
    // Report channels to owner for debugging
    llOwnerSay("🔧 [Roll Confetti] Dynamic channels initialized:");
    llOwnerSay("  Roll Dialog: " + (string)ROLLDIALOG_CHANNEL);
    llOwnerSay("  Scoreboard 1: " + (string)SCOREBOARD_CHANNEL_1);
    llOwnerSay("  Scoreboard 3: " + (string)SCOREBOARD_CHANNEL_3);
}

integer rollDialogChannel; // Legacy variable, will be set dynamically

// Listen handle management
integer listenHandle = -1;

list names = [];
list lives = [];
list picksData = [];
string perilPlayer = "";
integer diceType = 6; // Store the dice type for rolling
integer shouldRoll = FALSE; // Flag to trigger roll after dice type is received
integer rollInProgress = FALSE; // Prevent multiple simultaneous rolls
integer lastRollTime = 0; // Track when last roll happened
integer diceTypeProcessed = FALSE; // Prevent duplicate dice type processing

// Verbose logging control - toggled by owner
integer VERBOSE_LOGGING = FALSE;

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

list getPicksFor(string nameInput) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        if (llList2String(parts, 0) == nameInput) {
            // Convert semicolons back to commas, then parse
            string picks = llList2String(parts, 1);
            string originalPicks = picks;
            
            // Check for corruption markers (^ symbols that shouldn't be in picks)
            if (llSubStringIndex(picks, "^") != -1) {
                return [];
            }
            
            if (picks == "") {
                return [];
            }
            
            picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
            list rawResult = llParseString2List(picks, [","], []);
            // Trim whitespace from each number to handle "5, 6" vs "5,6" formats
            list result = [];
            integer j;
            for (j = 0; j < llGetListLength(rawResult); j++) {
                string num = llStringTrim(llList2String(rawResult, j), STRING_TRIM);
                if (num != "") {
                    result += [num];
                }
            }
            return result;
        }
    }
    return [];
}

integer rollDice(integer diceType) {
    return 1 + (integer)llFrand(diceType);
}

confetti() {
    llParticleSystem([
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
        PSYS_PART_START_COLOR, <1,1,1>, PSYS_PART_END_COLOR, <1,1,1>,
        PSYS_PART_START_ALPHA, 1.0, PSYS_PART_END_ALPHA, 0.0,
        PSYS_PART_START_SCALE, <0.2,0.2,0>, PSYS_PART_END_SCALE, <0.5,0.5,0>,
        PSYS_PART_MAX_AGE, 2.0, PSYS_SRC_MAX_AGE, 2.0,
        PSYS_SRC_ACCEL, <0,0,-0.4>,
        PSYS_SRC_BURST_RATE, 0.01, PSYS_SRC_BURST_PART_COUNT, 50,
        PSYS_SRC_BURST_RADIUS, 0.2,
        PSYS_SRC_BURST_SPEED_MIN, 1.0, PSYS_SRC_BURST_SPEED_MAX, 2.0,
        PSYS_PART_FLAGS, PSYS_PART_INTERP_COLOR_MASK | PSYS_PART_INTERP_SCALE_MASK | PSYS_PART_EMISSIVE_MASK
    ]);
}

default {
    state_entry() {
        reportMemoryUsage("🎲 Roll Confetti Module");
        
        // Initialize dynamic channels
        initializeChannels();
        rollDialogChannel = ROLLDIALOG_CHANNEL; // Set legacy variable
        
        // Clean up any existing listeners
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Initialize/reset game state variables
        names = [];
        lives = [];
        picksData = [];
        perilPlayer = "";
        diceType = 6;
        shouldRoll = FALSE;
        rollInProgress = FALSE;
        lastRollTime = 0;
        diceTypeProcessed = FALSE;
        
        // Set up managed listener with dynamic channel
        listenHandle = llListen(rollDialogChannel, "", NULL_KEY, "");
        llOwnerSay("🎲 Roll Confetti Module ready!");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("🎲 Roll Confetti Module");
        llOwnerSay("🔄 Roll Confetti Module rezzed - reinitializing...");
        
        // Re-initialize dynamic channels
        initializeChannels();
        rollDialogChannel = ROLLDIALOG_CHANNEL;
        
        // Clean up any existing listeners
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Reset all game state variables
        names = [];
        lives = [];
        picksData = [];
        perilPlayer = "";
        diceType = 6;
        shouldRoll = FALSE;
        rollInProgress = FALSE;
        lastRollTime = 0;
        diceTypeProcessed = FALSE;
        
        // Stop any active particles
        llParticleSystem([]);
        
        // Set up managed listener with dynamic channel
        listenHandle = llListen(rollDialogChannel, "", NULL_KEY, "");
        llOwnerSay("✅ Roll Confetti Module reset complete after rez!");
    }

    link_message(integer sender, integer num, string str, key id) {
        // Debug: Log critical messages to see if Roll Module is working
        if (num == MSG_SHOW_ROLL_DIALOG) {
            llOwnerSay("🎲 [Roll Module] RECEIVED MSG_SHOW_ROLL_DIALOG: " + str + " id: " + (string)id);
        }
        if (num == 301) {
            llOwnerSay("🎲 [Roll Module] RECEIVED 301: " + str + " id: " + (string)id);
        }
        if (num == 996) {
            llOwnerSay("🎲 [Roll Module] RECEIVED GET_DICE_TYPE: " + str);
        }
        
        // Handle verbose logging toggle from Main Controller
        if (num == 9011 && llSubStringIndex(str, "VERBOSE_LOGGING|") == 0) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                VERBOSE_LOGGING = (integer)llList2String(parts, 1);
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔍 [Roll Module] Verbose logging ON");
                } else {
                    llOwnerSay("🔍 [Roll Module] Verbose logging OFF");
                }
            }
            return;
        }
        
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Reset roll confetti module state
            names = [];
            lives = [];
            picksData = [];
            perilPlayer = "";
            // Stop any active particles
            llParticleSystem([]);
            llOwnerSay("🎆 Roll Confetti Module reset!");
            return;
        }
        
        // Handle game state sync from main controller
        if (num == MSG_SYNC_GAME_STATE) {
            if (VERBOSE_LOGGING) llOwnerSay("🔍 [Roll Module] Received sync: " + str);
            list parts = llParseString2List(str, ["~"], []);
            if (VERBOSE_LOGGING) llOwnerSay("🔍 [Roll Module] Parsed into " + (string)llGetListLength(parts) + " parts");
            
            // Handle special RESET sync message
            if (llGetListLength(parts) >= 5 && llList2String(parts, 0) == "RESET") {
                llOwnerSay("🔄 [Roll Module] Received reset sync - ignoring during reset");
                return;
            }
            
            if (llGetListLength(parts) >= 4) {
                lives = llCSV2List(llList2String(parts, 0));
                // Use ^ delimiter for picksData to avoid comma conflicts
                string picksDataStr = llList2String(parts, 1);
                if (VERBOSE_LOGGING) llOwnerSay("🔍 [Roll Module] Received picksDataStr: '" + picksDataStr + "'");
                if (picksDataStr == "" || picksDataStr == "EMPTY") {
                    picksData = [];
                    if (VERBOSE_LOGGING) llOwnerSay("🔍 [Roll Module] Set picksData to empty");
                } else {
                    picksData = llParseString2List(picksDataStr, ["^"], []);
                    if (VERBOSE_LOGGING) llOwnerSay("🔍 [Roll Module] Set picksData: " + llDumpList2String(picksData, " | "));
                }
                string receivedPeril = llList2String(parts, 2);
                if (receivedPeril == "NONE") {
                    perilPlayer = "";
                } else {
                    perilPlayer = receivedPeril;
                }
                names = llCSV2List(llList2String(parts, 3));
                if (VERBOSE_LOGGING) llOwnerSay("🔍 [Roll Module] Updated names: " + llDumpList2String(names, ", "));
            }
            return;
        }
        
        if (num == 995) {
            if (str == "VICTORY_CONFETTI") {
                llOwnerSay("✨ ULTIMATE VICTORY CELEBRATION!");
                confetti();
            }
            return;
        }
        
        if (num == MSG_SHOW_ROLL_DIALOG) {
            // Check if this is a next round prompt
            if (llSubStringIndex(str, "_NEXT_ROUND") != -1) {
                string playerName = llGetSubString(str, 0, llSubStringIndex(str, "_NEXT_ROUND") - 1);
                llOwnerSay("🎯 Prompting " + playerName + " to start next round...");
                // Send continuation directly to Game Manager (more efficient than through Main Controller)
                llMessageLinked(LINK_SET, 998, "", NULL_KEY); // Empty peril player - Game Manager will select one
            } else {
                // Clear dice display directly (link 83)
                llMessageLinked(83, 3021, "", NULL_KEY);
                
                // Update peril player from the roll dialog message
                perilPlayer = str;
                llOwnerSay("🎲 Prompting " + str + " to roll the dice. Setting perilPlayer to: " + perilPlayer);
                
                // Check if this is a bot (Bot names)
                if (llSubStringIndex(str, "Bot") == 0) {
                    // Auto-roll for bots - request dice type first
                    llOwnerSay("🤖 " + str + " (bot) is requesting dice type for auto-roll...");
                    rollInProgress = TRUE; // Set roll in progress for bot
                    shouldRoll = TRUE; // Set flag to perform roll when dice type is received
                    // Request current dice type from Calculator
                    llMessageLinked(LINK_SET, 1001, (string)llGetListLength(names), NULL_KEY);
                } else {
                    // Reset any previous roll state before showing dialog
                    rollInProgress = FALSE;
                    shouldRoll = FALSE;
                    // Show dialog for human players
                    llDialog(id, "🎲 THE MOMENT OF TRUTH! You're in ultimate peril. Will you face your fate?", ["ROLL THE DICE OF FATE"], rollDialogChannel);
                }
            }
        }

        
        // Handle dice type response - store dice type and perform roll if requested
        else if (num == 1005) { // MSG_DICE_TYPE_RESULT 
            diceType = (integer)str;
            llOwnerSay("🎲 [Roll Module] Received dice type: d" + (string)diceType);
            
            // If roll was requested from listen handler, perform it now
            if (shouldRoll && rollInProgress) {
                shouldRoll = FALSE; // Reset flag
                llOwnerSay("🎲 [Roll Module] Performing requested roll with d" + (string)diceType);
                
                // Use MSG_ROLL_RESULT handler to perform the actual roll
                llMessageLinked(LINK_THIS, MSG_ROLL_RESULT, (string)diceType, NULL_KEY);
            } else if (shouldRoll && !rollInProgress) {
                llOwnerSay("⚠️ [Roll Module] Roll was cancelled or already completed, ignoring dice type");
                shouldRoll = FALSE; // Clear stale flag
            }
            return;
        }
        
        // Legacy MSG_ROLL_RESULT handler (if still used somewhere)
        else if (num == MSG_ROLL_RESULT) {
            // Additional safety check
            if (!rollInProgress) {
                llOwnerSay("⚠️ [Roll Module] Ignoring roll request - no roll in progress");
                return;
            }
            
            // CRITICAL: Verify we have picks data for at least some players before processing roll
            integer hasAnyPicks = FALSE;
            integer validationIdx;
            for (validationIdx = 0; validationIdx < llGetListLength(picksData) && !hasAnyPicks; validationIdx++) {
                string entry = llList2String(picksData, validationIdx);
                list entryParts = llParseString2List(entry, ["|"], []);
                if (llGetListLength(entryParts) >= 2 && llList2String(entryParts, 1) != "") {
                    hasAnyPicks = TRUE;
                }
            }
            
            if (!hasAnyPicks) {
                llOwnerSay("⚠️ [Roll Module] No picks data available - delaying roll to wait for sync");
                rollInProgress = FALSE; // Reset roll state
                // Request a re-sync of game state
                llMessageLinked(LINK_SET, 998, "REQUEST_SYNC", NULL_KEY);
                return;
            }
            
            integer diceType = (integer)str;
            integer result = rollDice(diceType);
            string resultStr = (string)result;
            lastRollTime = llGetUnixTime(); // Record roll time
            llSay(0, "🎲 THE D" + (string)diceType + " OF FATE! " + perilPlayer + " rolled a " + resultStr + " on the " + (string)diceType + "-sided die! 🎲");

            // Send dice roll directly to dice display (link 83)
            llMessageLinked(83, 3020, perilPlayer + "|" + resultStr, NULL_KEY);

            string newPeril = "";
            integer matched = FALSE;
            list matchedPlayers = [];
            integer i;
            
            
            // Find all players who picked the rolled number
            llOwnerSay("🔍 [Roll Module] Checking picks for rolled number: " + resultStr);
            llOwnerSay("🔍 [Roll Module] Current picksData: " + llDumpList2String(picksData, " | "));
            for (i = 0; i < llGetListLength(names); i++) {
                string pname = llList2String(names, i);
                list picks = getPicksFor(pname);
                llOwnerSay("🔍 [Roll Module] " + pname + "'s picks: " + llDumpList2String(picks, ","));
                if (llListFindList(picks, [resultStr]) != -1) {
                    matched = TRUE;
                    matchedPlayers += [pname];
                    llOwnerSay("🔍 [Roll Module] MATCH! " + pname + " picked " + resultStr);
                }
            }
            llOwnerSay("🔍 [Roll Module] Final matched status: " + (string)matched + ", players: " + llDumpList2String(matchedPlayers, ","));
            
            
            // If anyone matched, pick the first non-peril player as new peril
            // If only the current peril player matched, they stay in peril (no change)
            for (i = 0; i < llGetListLength(matchedPlayers) && newPeril == ""; i++) {
                string pname = llList2String(matchedPlayers, i);
                if (pname != perilPlayer) {
                    newPeril = pname;
                }
            }

            if (matched && newPeril != "") {
                llSay(0, "⚡ PLOT TWIST! " + newPeril + " picked " + resultStr + " (rolled on d" + (string)diceType + ") and is now in ULTIMATE PERIL! ⚡");
                perilPlayer = newPeril;
                
                // Direct scoreboard status update
                llMessageLinked(12, 3001, "Plot Twist", NULL_KEY);
                
                // IMPORTANT: Send peril player update to scoreboard for glow effect
                llMessageLinked(12, 3005, newPeril, NULL_KEY);  // MSG_UPDATE_PERIL_PLAYER
                
                // Add delay to let status display before next phase
                llSleep(2.0);
                
                // Update floaters immediately to show correct peril player before sync
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, newPeril, NULL_KEY);
            } else {
                integer pidx = llListFindList(names, [perilPlayer]);
                if (pidx != -1) {
                    integer currentLives = llList2Integer(lives, pidx);
                    llOwnerSay("🔧 DEBUG: Before lives update - " + perilPlayer + " at index " + (string)pidx + " has " + (string)currentLives + " lives");
                    llOwnerSay("🔧 DEBUG: Current lives list: " + llList2CSV(lives));
                    lives = llListReplaceList(lives, [currentLives - 1], pidx, pidx);
                    llOwnerSay("🔧 DEBUG: After lives update - lives list: " + llList2CSV(lives));
                    
                    // Send direct scoreboard update when lives change
                    llMessageLinked(12, 3002, perilPlayer + "|" + (string)(currentLives - 1) + "|" + "NULL_KEY", NULL_KEY);
                    llOwnerSay("💗 Player lives updated: " + perilPlayer + " now has " + (string)(currentLives - 1) + " lives");
                    
                    // Check if peril player picked the rolled number
                    list perilPicks = getPicksFor(perilPlayer);
                    integer perilPickedIt = (llListFindList(perilPicks, [resultStr]) != -1);
                    
                    // FIXED: Use the correct logic for shield detection
                    // - If ANYONE picked the number (matched=TRUE) but peril player also picked it = DIRECT HIT
                    // - If NOBODY picked the number (matched=FALSE) = NO SHIELD  
                    // - If SOMEONE ELSE picked it but not peril player = This case is handled above as PLOT TWIST
                    
                    if (matched && perilPickedIt) {
                        llSay(0, "🩸 DIRECT HIT! " + perilPlayer + " picked their own doom - the d" + (string)diceType + " landed on " + resultStr + "! 🩸");
                        // Direct scoreboard status update
                        llMessageLinked(12, 3001, "Direct Hit", NULL_KEY);
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    } else if (!matched) {
                        llSay(0, "🩸 NO SHIELD! Nobody picked " + resultStr + " - " + perilPlayer + " takes the hit from the d" + (string)diceType + "! 🩸");
                        // Direct scoreboard status update
                        llMessageLinked(12, 3001, "No Shield", NULL_KEY);
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    } else {
                        // This should never happen in normal game flow since Plot Twist case is handled above
                        // But if it does, it means someone else picked it - this should have been Plot Twist
                        llOwnerSay("⚠️ LOGIC ERROR: Someone picked " + resultStr + " but not handled as Plot Twist!");
                        llSay(0, "🩸 SHIELD FAILED! " + perilPlayer + " takes the hit despite someone picking " + resultStr + "! 🩸");
                        llSleep(2.0);
                    }
                    
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, perilPlayer, NULL_KEY);
                    
                    // Check for elimination
                    if (currentLives - 1 <= 0) {
                        // Player elimination will be handled by Main Controller via sync and elimination messages
                        llOwnerSay("💀 Elimination detected: " + perilPlayer + " has 0 hearts remaining");
                        
                        llSay(0, "🐻 PUNISHMENT TIME! " + perilPlayer + " has been ELIMINATED!");
                        
                        // CRITICAL FIX: DO NOT update our local state to remove the eliminated player
                        // This would corrupt the sync message. Instead, just mark the player as having 0 lives
                        // but keep them in the lists. Main Controller will handle the actual removal.
                        integer elimIdx = llListFindList(names, [perilPlayer]);
                        if (elimIdx != -1) {
                            // Set player's lives to 0 in our local state, but keep them in the lists
                            lives = llListReplaceList(lives, [0], elimIdx, elimIdx);
                            llOwnerSay("🔄 [Roll Module] Updated local state - set " + perilPlayer + "'s lives to 0 but kept in lists");
                            llOwnerSay("🔄 [Roll Module] This ensures proper sync message format before Main Controller handles elimination");
                        }
                        
                        // Send message to main controller to handle elimination
                        llMessageLinked(LINK_SET, 999, "ELIMINATE_PLAYER|" + perilPlayer, NULL_KEY);
                        
                        // CRITICAL: Don't send any sync messages after elimination
                        // Let Main Controller handle all state sync, peril player reassignment, AND game continuation
                        llOwnerSay("🎯 [Roll Module] Elimination complete - letting Main Controller handle state sync and continuation");
                        
                        // Clear roll protection after processing is complete
                        rollInProgress = FALSE;
                        return;
                    }
                }
            }

            // Note: Win condition checking is handled by Main Controller after elimination

            // IMPORTANT: After processing a roll, preserve the actual picks data that was used for validation
            // These picks will be used by Game Manager for building complete avoidance lists
            list encodedPicksData = [];
            integer k;
            for (k = 0; k < llGetListLength(picksData); k++) {
                string entry = llList2String(picksData, k);
                // Preserve the actual picks data that was used for validation
                encodedPicksData += [entry];
            }
            // Validate perilPlayer is not empty before syncing
            string perilForSync = perilPlayer;
            if (perilForSync == "") {
                perilForSync = "NONE";
                llOwnerSay("⚠️ Roll Module: perilPlayer is empty, using NONE placeholder");
            }
            
            string gameSync = llList2CSV(lives) + "~" + llDumpList2String(encodedPicksData, "^") + "~" + perilForSync + "~" + llList2CSV(names);
            llOwnerSay("📤 Roll module sending sync with peril player: " + perilForSync);
            llOwnerSay("🔍 DEBUG - encodedPicksData: " + llDumpList2String(encodedPicksData, " | "));
            llOwnerSay("🔍 DEBUG - gameSync: " + gameSync);
            llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
            llSleep(0.2);
            
            // Additional floater updates to ensure correct peril player display
            llOwnerSay("🔄 Updating all floaters with new peril player: " + perilPlayer);
            integer f;
            for (f = 0; f < llGetListLength(names); f++) {
                string fname = llList2String(names, f);
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, fname, NULL_KEY);
            }
            
            // After roll is processed and sync is sent, send continuation directly to Game Manager
            llOwnerSay("🎯 Round complete - sending continuation directly to Game Manager");
            
            // Brief delay to ensure sync propagates
            llSleep(0.5);
            
            // Send continuation directly to Game Manager (more efficient than through Main Controller)
            // For non-elimination cases, continue with current peril player
            llMessageLinked(LINK_SET, 998, perilForSync, NULL_KEY);
            
            // Clear roll protection after processing is complete
            rollInProgress = FALSE;
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (msg == "Roll" || msg == "ROLL THE DICE OF FATE") {
            // Prevent multiple rolls within 3 seconds
            integer currentTime = llGetUnixTime();
            if (rollInProgress) {
                llOwnerSay("⚠️ Roll already in progress, ignoring duplicate click by " + name);
                return;
            }
            if (currentTime - lastRollTime < 3) {
                llOwnerSay("⚠️ Roll too soon after previous roll, ignoring click by " + name);
                return;
            }
            
            // Handle dice roll - request current dice type from Calculator
            llOwnerSay("🎲 Roll button clicked by " + name + " (key: " + (string)id + ")");
            rollInProgress = TRUE; // Lock out other rolls
            shouldRoll = TRUE; // Set flag to perform roll when dice type is received
            // Request current dice type from Calculator
            llMessageLinked(LINK_SET, 1001, (string)llGetListLength(names), NULL_KEY);
        } else {
            llMessageLinked(LINK_THIS, channel, msg, id);
        }
    }
}
