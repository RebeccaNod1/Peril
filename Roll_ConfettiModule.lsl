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
            list result = llParseString2List(picks, [","], []);
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
        // Initialize dynamic channels
        initializeChannels();
        rollDialogChannel = ROLLDIALOG_CHANNEL; // Set legacy variable
        
        // Clean up any existing listeners
        if (listenHandle != -1) {
            llListenRemove(listenHandle);
        }
        
        // Set up managed listener with dynamic channel
        listenHandle = llListen(rollDialogChannel, "", NULL_KEY, "");
        llOwnerSay("🎲 Roll Confetti Module ready!");
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
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                lives = llCSV2List(llList2String(parts, 0));
                // Use ^ delimiter for picksData to avoid comma conflicts
                string picksDataStr = llList2String(parts, 1);
                if (picksDataStr == "" || picksDataStr == "EMPTY") {
                    picksData = [];
                } else {
                    picksData = llParseString2List(picksDataStr, ["^"], []);
                }
                string receivedPeril = llList2String(parts, 2);
                if (receivedPeril == "NONE") {
                    perilPlayer = "";
                } else {
                    perilPlayer = receivedPeril;
                }
                names = llCSV2List(llList2String(parts, 3));
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
                // Send message to main controller to get the player's key and show dialog
                llMessageLinked(LINK_SET, 997, "START_NEXT_ROUND_DIALOG|" + playerName, NULL_KEY);
            } else {
                // Clear dice display before showing new roll dialog
                llMessageLinked(LINK_SET, MSG_CLEAR_DICE, "", NULL_KEY);
                
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
            
            integer diceType = (integer)str;
            integer result = rollDice(diceType);
            string resultStr = (string)result;
            lastRollTime = llGetUnixTime(); // Record roll time
            llSay(0, "🎲 THE D" + (string)diceType + " OF FATE! " + perilPlayer + " rolled a " + resultStr + " on the " + (string)diceType + "-sided die! 🎲");

            // Send dice roll to Main Controller for forwarding to dice display
            llMessageLinked(LINK_SET, MSG_DICE_ROLL, perilPlayer + "|" + resultStr + "|" + (string)diceType, NULL_KEY);

            string newPeril = "";
            integer matched = FALSE;
            list matchedPlayers = [];
            integer i;
            
            
            // Find all players who picked the rolled number
            for (i = 0; i < llGetListLength(names); i++) {
                string pname = llList2String(names, i);
                list picks = getPicksFor(pname);
                if (llListFindList(picks, [resultStr]) != -1) {
                    matched = TRUE;
                    matchedPlayers += [pname];
                }
            }
            
            
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
                
                // Plot Twist status will be sent by Main Controller via link messages
                // Add delay to let status display before next phase
                llSleep(2.0);
                
                // Update floaters immediately to show correct peril player before sync
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, newPeril, NULL_KEY);
            } else {
                integer pidx = llListFindList(names, [perilPlayer]);
                if (pidx != -1) {
                    integer currentLives = llList2Integer(lives, pidx);
                    lives = llListReplaceList(lives, [currentLives - 1], pidx, pidx);
                    
                    // Player update will be sent by Main Controller via sync message and updateHelpers()
                    llOwnerSay("💗 Player lives updated: " + perilPlayer + " now has " + (string)(currentLives - 1) + " lives");
                    
                    // Check if peril player picked the rolled number
                    list perilPicks = getPicksFor(perilPlayer);
                    integer perilPickedIt = (llListFindList(perilPicks, [resultStr]) != -1);
                    
                    if (perilPickedIt) {
                        llSay(0, "🩸 DIRECT HIT! " + perilPlayer + " picked their own doom - the d" + (string)diceType + " landed on " + resultStr + "! 🩸");
                        // Direct Hit status will be sent by Main Controller via link messages
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    } else {
                        llSay(0, "🩸 NO SHIELD! Nobody picked " + resultStr + " - " + perilPlayer + " takes the hit from the d" + (string)diceType + "! 🩸");
                        // No Shield status will be sent by Main Controller via link messages
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    }
                    
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, perilPlayer, NULL_KEY);
                    
                    // Check for elimination
                    if (currentLives - 1 <= 0) {
                        // Player elimination will be handled by Main Controller via sync and elimination messages
                        llOwnerSay("💀 Elimination detected: " + perilPlayer + " has 0 hearts remaining");
                        
                        llSay(0, "🐻 PUNISHMENT TIME! " + perilPlayer + " has been ELIMINATED!");
                        
                        // IMPORTANT: Update our local state to reflect the elimination
                        // Remove the eliminated player from our names and lives lists to prevent stale data
                        integer elimIdx = llListFindList(names, [perilPlayer]);
                        if (elimIdx != -1) {
                            names = llDeleteSubList(names, elimIdx, elimIdx);
                            lives = llDeleteSubList(lives, elimIdx, elimIdx);
                            // Also clean up their picks data
                            integer pickIdx = -1;
                            integer p;
                            // LSL doesn't support break, so use a flag instead
                            integer foundEntry = FALSE;
                            for (p = 0; p < llGetListLength(picksData) && !foundEntry; p++) {
                                string entry = llList2String(picksData, p);
                                if (llSubStringIndex(entry, perilPlayer + "|") == 0) {
                                    pickIdx = p;
                                    foundEntry = TRUE;
                                }
                            }
                            if (pickIdx != -1) {
                                picksData = llDeleteSubList(picksData, pickIdx, pickIdx);
                            }
                            llOwnerSay("🔄 [Roll Module] Updated local state - removed " + perilPlayer + " from names/lives/picks");
                        }
                        
                        // Send message to main controller to handle elimination
                        llMessageLinked(LINK_SET, 999, "ELIMINATE_PLAYER|" + perilPlayer, NULL_KEY);
                        
                        // CRITICAL: Don't send any sync messages after elimination
                        // Let Main Controller handle all state sync and peril player reassignment
                        llOwnerSay("🎯 [Roll Module] Elimination complete - letting Main Controller handle state sync");
                        
                        // Clear roll protection after processing is complete
                        rollInProgress = FALSE;
                        return;
                    }
                }
            }

            // Note: Win condition checking is handled by Main Controller after elimination

            // IMPORTANT: After processing a roll, clear picks data for the next round
            // The round is complete, so we should send empty picks to trigger next round logic
            list encodedPicksData = [];
            integer k;
            for (k = 0; k < llGetListLength(names); k++) {
                string playerName = llList2String(names, k);
                // Send empty picks for all players since round is complete
                encodedPicksData += [playerName + "|"];
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
            
            // Let Main Controller handle next round logic to avoid loops
            // Don't immediately trigger next round dialog - let game flow naturally
            llOwnerSay("🎯 Round complete, waiting for Main Controller to handle next phase...");
            
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
