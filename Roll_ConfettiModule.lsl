// === Roll and Confetti Module (with Roll Dialog Handler) ===

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SHOW_ROLL_DIALOG = 301;

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
                llRegionSay(SCOREBOARD_CHANNEL_3, "CLEAR_DICE");
                
                // Update peril player from the roll dialog message
                perilPlayer = str;
                llOwnerSay("🎲 Prompting " + str + " to roll the dice. Setting perilPlayer to: " + perilPlayer);
                
                // Check if this is a bot (TestBot names)
                if (llSubStringIndex(str, "TestBot") == 0) {
                    // Auto-roll for bots
                    llOwnerSay("🤖 " + str + " (bot) is auto-rolling...");
                    shouldRoll = TRUE; // Set flag for bot auto-roll
                    // Request dice type directly from Calculator
                    llMessageLinked(LINK_SET, 1001, (string)llGetListLength(names), NULL_KEY);
                } else {
                    // Show dialog for human players
                    llDialog(id, "🎲 THE MOMENT OF TRUTH! You're in ultimate peril. Will you face your fate?", ["ROLL THE DICE OF FATE"], rollDialogChannel);
                }
            }
        }

        // Handle dice type requests from listen() events
        else if (num == 996) {
            // This is a GET_DICE_TYPE request from our own listen handler
            // Forward it to the Main Controller to get the current dice type
            llMessageLinked(LINK_SET, 1001, (string)llGetListLength(names), NULL_KEY);
            return;
        }
        
        // Handle dice type response - store dice type and perform roll if requested
        else if (num == 1005) { // MSG_DICE_TYPE_RESULT 
            diceType = (integer)str;
            llOwnerSay("🎲 [Roll Module] Received dice type: d" + (string)diceType);
            
            // If roll was requested from listen handler, perform it now
            if (shouldRoll) {
                shouldRoll = FALSE; // Reset flag
                llOwnerSay("🎲 [Roll Module] Performing requested roll with d" + (string)diceType);
                
                // Use MSG_ROLL_RESULT handler to perform the actual roll
                llMessageLinked(LINK_THIS, MSG_ROLL_RESULT, (string)diceType, NULL_KEY);
            }
            return;
        }
        
        // Legacy MSG_ROLL_RESULT handler (if still used somewhere)
        else if (num == MSG_ROLL_RESULT) {
            integer diceType = (integer)str;
            integer result = rollDice(diceType);
            string resultStr = (string)result;
            llSay(0, "🎲 THE D" + (string)diceType + " OF FATE! " + perilPlayer + " rolled a " + resultStr + " on the " + (string)diceType + "-sided die! 🎲");

            // Send dice roll to scoreboard for display on dice screen
            llRegionSay(SCOREBOARD_CHANNEL_3, "DICE_ROLL|" + perilPlayer + "|" + resultStr + "|" + (string)diceType);

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
                
                // Send Plot Twist status to scoreboard
                llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_STATUS|Plot Twist");
                // Add delay to let status display before next phase
                llSleep(2.0);
                
                // Update floaters immediately to show correct peril player before sync
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, newPeril, NULL_KEY);
            } else {
                integer pidx = llListFindList(names, [perilPlayer]);
                if (pidx != -1) {
                    integer currentLives = llList2Integer(lives, pidx);
                    lives = llListReplaceList(lives, [currentLives - 1], pidx, pidx);
                    
                    // Immediately send updated heart count to scoreboard
                    integer newLives = currentLives - 1;
                    key perilKey = NULL_KEY; // We don't have player keys in this module, use NULL_KEY
                    if (pidx < llGetListLength(names)) {
                        string updateMsg = "PLAYER_UPDATE|" + perilPlayer + "|" + (string)newLives + "|" + (string)perilKey;
                        llRegionSay(SCOREBOARD_CHANNEL_1, updateMsg);
                        llOwnerSay("💗 Immediate scoreboard update: " + perilPlayer + " now has " + (string)newLives + " lives");
                    }
                    
                    // Check if peril player picked the rolled number
                    list perilPicks = getPicksFor(perilPlayer);
                    integer perilPickedIt = (llListFindList(perilPicks, [resultStr]) != -1);
                    
                    if (perilPickedIt) {
                        llSay(0, "🩸 DIRECT HIT! " + perilPlayer + " picked their own doom - the d" + (string)diceType + " landed on " + resultStr + "! 🩸");
                        // Send Direct Hit status to scoreboard
                        llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_STATUS|Direct Hit");
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    } else {
                        llSay(0, "🩸 NO SHIELD! Nobody picked " + resultStr + " - " + perilPlayer + " takes the hit from the d" + (string)diceType + "! 🩸");
                        // Send No Shield status to scoreboard
                        llRegionSay(SCOREBOARD_CHANNEL_1, "GAME_STATUS|No Shield");
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    }
                    
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, perilPlayer, NULL_KEY);
                    
                    // Check for elimination
                    if (currentLives - 1 <= 0) {
                        // Show 0 hearts on scoreboard before elimination message
                        string eliminationUpdateMsg = "PLAYER_UPDATE|" + perilPlayer + "|0|" + (string)NULL_KEY;
                        llRegionSay(SCOREBOARD_CHANNEL_1, eliminationUpdateMsg);
                        llOwnerSay("💀 Elimination update: " + perilPlayer + " now shows 0 hearts");
                        
                        llSay(0, "🐻 PUNISHMENT TIME! " + perilPlayer + " has been ELIMINATED!");
                        // Remove eliminated player (send message to main controller)
                        llMessageLinked(LINK_SET, 999, "ELIMINATE_PLAYER|" + perilPlayer, NULL_KEY);
                        // The Main Controller will handle peril player reassignment and game flow
                        // Don't continue processing this round since the player was eliminated
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
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (msg == "Roll" || msg == "ROLL THE DICE OF FATE") {
            // Handle dice roll - need to get dice type from Calculator
            llOwnerSay("🎲 Roll button clicked by " + name + " (key: " + (string)id + ")");
            shouldRoll = TRUE; // Set flag to perform roll when dice type is received
            // Request dice type directly from Calculator
            llMessageLinked(LINK_SET, 1001, (string)llGetListLength(names), NULL_KEY);
        } else {
            llMessageLinked(LINK_THIS, channel, msg, id);
        }
    }
}
