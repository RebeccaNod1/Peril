// === Roll and Confetti Module (with Roll Dialog Handler) ===

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_SHOW_ROLL_DIALOG = 301;

integer rollDialogChannel = -77999;

list names = [];
list lives = [];
list picksData = [];
string perilPlayer = "";

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
        llOwnerSay("🎲 Roll Confetti Module ready!");
        llListen(rollDialogChannel, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
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
                llOwnerSay("🎲 Prompting " + str + " to roll the dice.");
                // Check if this is a bot (TestBot names)
                if (llSubStringIndex(str, "TestBot") == 0) {
                    // Auto-roll for bots
                    llOwnerSay("🤖 " + str + " (bot) is auto-rolling...");
                    llMessageLinked(LINK_SET, 996, "GET_DICE_TYPE", NULL_KEY);
                } else {
                    // Show dialog for human players
                    llDialog(id, "🎲 THE MOMENT OF TRUTH! You're in ultimate peril. Will you face your fate?", ["ROLL THE DICE OF FATE"], rollDialogChannel);
                }
            }
        }

        else if (num == MSG_ROLL_RESULT) {
            integer diceType = (integer)str;
            integer result = rollDice(diceType);
            string resultStr = (string)result;
            llSay(0, "🎲 THE D" + (string)diceType + " OF FATE! " + perilPlayer + " rolled a " + resultStr + " on the " + (string)diceType + "-sided die! 🎲");

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
                llRegionSay(-12345, "GAME_STATUS|Plot Twist");
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
                        llRegionSay(-12345, updateMsg);
                        llOwnerSay("💗 Immediate scoreboard update: " + perilPlayer + " now has " + (string)newLives + " lives");
                    }
                    
                    // Check if peril player picked the rolled number
                    list perilPicks = getPicksFor(perilPlayer);
                    integer perilPickedIt = (llListFindList(perilPicks, [resultStr]) != -1);
                    
                    if (perilPickedIt) {
                        llSay(0, "🩸 DIRECT HIT! " + perilPlayer + " picked their own doom - the d" + (string)diceType + " landed on " + resultStr + "! 🩸");
                        // Send Direct Hit status to scoreboard
                        llRegionSay(-12345, "GAME_STATUS|Direct Hit");
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    } else {
                        llSay(0, "🩸 NO SHIELD! Nobody picked " + resultStr + " - " + perilPlayer + " takes the hit from the d" + (string)diceType + "! 🩸");
                        // Send No Shield status to scoreboard
                        llRegionSay(-12345, "GAME_STATUS|No Shield");
                        // Add delay to let status display before next phase
                        llSleep(2.0);
                    }
                    
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, perilPlayer, NULL_KEY);
                    
                    // Check for elimination
                    if (currentLives - 1 <= 0) {
                        // Show 0 hearts on scoreboard before elimination message
                        string eliminationUpdateMsg = "PLAYER_UPDATE|" + perilPlayer + "|0|" + (string)NULL_KEY;
                        llRegionSay(-12345, eliminationUpdateMsg);
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

            // Encode picksData with semicolons to avoid comma conflicts
            list encodedPicksData = [];
            integer k;
            for (k = 0; k < llGetListLength(picksData); k++) {
                string entry = llList2String(picksData, k);
                list parts = llParseString2List(entry, ["|"], []);
                if (llGetListLength(parts) >= 2) {
                    string playerName = llList2String(parts, 0);
                    string picks = llList2String(parts, 1);
                    // Only process picks if they're not empty
                    if (picks != "") {
                        // Parse picks, trim whitespace, then join with semicolons
                        list pickList = llParseString2List(picks, [","], []);
                        list cleanPickList = [];
                        integer j;
                        for (j = 0; j < llGetListLength(pickList); j++) {
                            string pick = llStringTrim(llList2String(pickList, j), STRING_TRIM);
                            if (pick != "") {
                                cleanPickList += [pick];
                            }
                        }
                        picks = llDumpList2String(cleanPickList, ";");
                    }
                    encodedPicksData += [playerName + "|" + picks];
                } else if (llSubStringIndex(entry, "|") != -1) {
                    // Handle entries with empty picks (e.g., "PlayerName|")
                    encodedPicksData += [entry];
                } else {
                    // Skip malformed entries without pipe separator
                    llOwnerSay("⚠️ Roll Module: Skipping malformed picksData entry: " + entry);
                }
            }
            string gameSync = llList2CSV(lives) + "~" + llDumpList2String(encodedPicksData, "^") + "~" + perilPlayer + "~" + llList2CSV(names);
            llOwnerSay("📤 Roll module sending sync with peril player: " + perilPlayer);
            llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
            llSleep(0.2);
            
            // Additional floater updates to ensure correct peril player display
            llOwnerSay("🔄 Updating all floaters with new peril player: " + perilPlayer);
            integer f;
            for (f = 0; f < llGetListLength(names); f++) {
                string fname = llList2String(names, f);
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, fname, NULL_KEY);
            }
            
            // Show start next round dialog to current peril player
            // Get the peril player's key from the main controller
            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer + "_NEXT_ROUND", NULL_KEY);
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (msg == "Roll" || msg == "ROLL THE DICE OF FATE") {
            // Handle dice roll - need to get dice type from main controller
            llOwnerSay("🎲 Roll button clicked by " + name + " (key: " + (string)id + ")");
            llMessageLinked(LINK_SET, 996, "GET_DICE_TYPE", NULL_KEY);
        } else {
            llMessageLinked(LINK_THIS, channel, msg, id);
        }
    }
}
