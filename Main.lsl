// === Main Peril Dice Controller (Refactored with Game Helpers Integration, with dynamic player join) ===

//
// This version of the main game controller includes support for players (including
// the owner) joining the game at runtime via a MSG_REGISTER_PLAYER message. When
// a new player registers, they are added to the internal lists (players, names,
// lives and picksData), a floating display is rezzed for them, and helpers are
// updated. This mirrors the behaviour used when adding a test player, but now
// applies to any avatar joining the game via the dialog handler.

integer syncChannel = -77777;
integer numberPickChannel = -77888;
integer rollDialogChannel = -77999;
integer DIALOG_CHANNEL = -88888;

// Game timing settings to prevent dialog system overload
float BOT_PICK_DELAY = 2.0;      // Delay after bot picks before next action
float HUMAN_PICK_DELAY = 1.0;    // Delay after human picks before next action
float DIALOG_DELAY = 1.5;        // Delay before showing dialogs
integer gameTimer = 0;           // Timer for game flow delays

// Status message timing
float STATUS_DISPLAY_TIME = 8.0; // How long to show status messages on scoreboard
integer statusTimer = 0;         // Track when status messages were sent
string lastStatus = "";          // Track last status sent

list players = [];
list names = [];
list lives = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list picksData = [];
list readyPlayers = [];
list floaterChannels = []; // Track actual floater channels for cleanup

list pickQueue = [];
integer currentPickerIdx = 0;
integer diceType = 6;

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
integer MSG_SHOW_ROLL_DIALOG = 301;
integer MSG_GET_CURRENT_DIALOG = 302;
integer MSG_PLAYER_WON = 551;
integer MSG_RESET_LEADERBOARD = 553; // Custom message to reset leaderboard

// Display configuration
integer CONTROLLER_FACE = 1;  // Face to display start image on (front face)
string TEXTURE_START = "title_start";  // Start image texture
string TEXTURE_GAME_ACTIVE = "game_active";  // Optional: different texture during game

integer MSG_GET_DICE_TYPE = 1001;
integer MSG_GET_PICKS_REQUIRED = 1002;
integer MSG_GET_PICKER_INDEX = 1003;
integer MSG_DICE_TYPE_RESULT = 1005;
integer MSG_SERIALIZE_GAME_STATE = 1004;
integer MSG_SYNC_PICKQUEUE = 2001;

// Maximum number of players allowed (including test players). This should
// mirror the value used in Floater Manager to avoid inconsistencies.
integer MAX_PLAYERS = 10;

integer TIMEOUT_SECONDS = 600;
integer timeoutTimer;

integer warning2min = 120;
integer warning5min = 300;
integer warning9min = 540;
integer lastWarning = 0;

key currentPicker;

// Send status message to scoreboard with timing
sendStatusMessage(string status) {
    statusTimer = llGetUnixTime();
    lastStatus = status;
    llRegionSay(-12345, "GAME_STATUS|" + status);
    llOwnerSay("📢 Status: " + status + " (showing for " + (string)STATUS_DISPLAY_TIME + "s)");
    
    // Start timer to automatically clear status after display time
    llSetTimerEvent(STATUS_DISPLAY_TIME + 1.0); // Add 1 second buffer
}

// Forward game state to helpers when it changes
updateHelpers() {
    // Don't send peril player name if game hasn't started yet
    string perilForSync = "NONE";  // Use placeholder instead of empty string
    if (roundStarted) {
        perilForSync = perilPlayer;
    }
    // Encode picksData with a safe delimiter that won't conflict with player names or picks
    // Replace commas in picks with semicolons to avoid CSV conflicts
    list encodedPicksData = [];
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        // Replace commas with semicolons in the picks portion only
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
            llOwnerSay("⚠️ Skipping malformed picksData entry: " + entry);
        }
    }
    string picksDataStr = llDumpList2String(encodedPicksData, "^");
    // Ensure we always send valid format even with empty picks
    if (picksDataStr == "") {
        picksDataStr = "EMPTY";  // Use a clear placeholder for empty picks data
    }
    string serialized = llList2CSV(lives) + "~" + picksDataStr +
        "~" + perilForSync + "~" + llList2CSV(names);
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, serialized, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_SYNC_PICKQUEUE, llList2CSV(pickQueue), NULL_KEY);
    
    
    // Send player updates to scoreboard
    integer j;
    for (j = 0; j < llGetListLength(names); j++) {
        string playerName = llList2String(names, j);
        integer playerLives = llList2Integer(lives, j);
        key playerKey = llList2Key(players, j);
        
        // Use the actual player key as the profile UUID
        string profileUUID = (string)playerKey;
        
        // Send PLAYER_UPDATE message to scoreboard
        string updateMsg = "PLAYER_UPDATE|" + playerName + "|" + (string)playerLives + "|" + profileUUID;
        llRegionSay(-12345, updateMsg);
    }
}

// Request helper-calculated values
requestDiceType() {
    llMessageLinked(LINK_SET, MSG_GET_DICE_TYPE, (string)llGetListLength(names), NULL_KEY);
}

requestPicksRequired(integer idx) {
    llMessageLinked(LINK_SET, MSG_GET_PICKS_REQUIRED, llList2String(names, idx), NULL_KEY);
}

requestPickerIndex(string name) {
    llMessageLinked(LINK_SET, MSG_GET_PICKER_INDEX, name, NULL_KEY);
}

string generateSerializedState() {
    return llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
}

resetGame() {
    // Clean up all tracked floater channels
    integer i;
    for (i = 0; i < llGetListLength(floaterChannels); i++) {
        integer ch = llList2Integer(floaterChannels, i);
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    
    // Only send cleanup for channels that might actually have floaters
    // Check up to the number of players that were registered
    integer maxUsedIdx = llGetListLength(names);
    for (i = 0; i < maxUsedIdx; i++) {
        integer ch = -777000 + i;
        // Only send cleanup if not already in tracked channels
        if (llListFindList(floaterChannels, [ch]) == -1) {
            llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
        }
    }
    
    // Reset all game state variables
    players = names = lives = picksData = globalPickedNumbers = readyPlayers = [];
    floaterChannels = []; // Clear the tracked channels
    pendingRegistrations = []; // Clear pending registrations
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    roundStarted = FALSE; // Reset round flag
    gameStarting = FALSE; // Reset game starting flag
    currentPicker = NULL_KEY; // Reset current picker
    timeoutTimer = 0; // Reset timeout timer
    lastWarning = 0; // Reset warning timer
    diceType = 6; // Reset dice type to default
    
    // Send reset message to all other scripts to clear their state
    llMessageLinked(LINK_SET, -99999, "FULL_RESET", NULL_KEY);
    llSay(syncChannel, "RESET");
    
    // Send CLEAR_GAME message to scoreboard to reset display
    llRegionSay(-12345, "CLEAR_GAME");
    llOwnerSay("🎮 Game reset! All state cleared (including scoreboard).");
    
    // Clear status tracking
    statusTimer = 0;
    lastStatus = "";
    
    // Reset controller display to start image
    llSetTexture(TEXTURE_START, CONTROLLER_FACE);
    llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
    
    llSleep(0.5); // Give other scripts time to process reset
    llSetTimerEvent(0);
    updateHelpers();
}

continueCurrentRound() {
    // Continue the current round after elimination with existing picks intact
    // This is different from startNextRound() which resets picks for a new round
    llOwnerSay("🔄 Continuing current round with new peril player: " + perilPlayer);
    
    // Remove eliminated player's pick data but keep others
    integer i;
    list newPicksData = [];
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(parts) >= 1) {
            string entryPlayerName = llList2String(parts, 0);
            // Only keep picks from players still in the game
            if (llListFindList(names, [entryPlayerName]) != -1) {
                newPicksData += [entry];
            }
        }
    }
    picksData = newPicksData;
    
    // Update global picked numbers to match remaining players' picks
    globalPickedNumbers = [];
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        list parts = llParseString2List(entry, ["|"], []);
        if (llGetListLength(parts) >= 2) {
            string picks = llList2String(parts, 1);
            if (picks != "") {
                // Handle semicolon encoding for picks
                string decodedPicks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                list playerPicks = llParseString2List(decodedPicks, [","], []);
                globalPickedNumbers += playerPicks;
            }
        }
    }
    
    // Check if all remaining players have picked
    integer allPicked = TRUE;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        // Check if this player has picks
        integer hasPicksEntry = FALSE;
        integer j;
        for (j = 0; j < llGetListLength(picksData); j++) {
            string entry = llList2String(picksData, j);
            list parts = llParseString2List(entry, ["|"], []);
            if (llGetListLength(parts) >= 1 && llList2String(parts, 0) == playerName) {
                string picks = "";
                if (llGetListLength(parts) >= 2) {
                    picks = llList2String(parts, 1);
                }
                if (picks != "") {
                    hasPicksEntry = TRUE;
                }
            }
        }
        if (!hasPicksEntry) {
            allPicked = FALSE;
        }
    }
    
    if (allPicked) {
        // All players have picked, prompt peril player to roll
        llOwnerSay("✅ All remaining players have picks, prompting " + perilPlayer + " to roll");
        integer perilIdx = llListFindList(names, [perilPlayer]);
        if (perilIdx != -1) {
            key perilKey = llList2Key(players, perilIdx);
            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
        }
    } else {
        // Some players still need to pick, continue with pick phase
        llOwnerSay("⏳ Some players still need to pick, continuing pick phase");
        updateHelpers();
        // Check if peril player needs to pick
        showNextPickerDialog();
    }
}

startNextRound() {
    // Do not start a round if there are fewer than 2 players. This guard prevents
    // accidental starts when only one player is present (e.g. after a reset or
    // before any other participants join).
    if (llGetListLength(names) < 2) {
        llOwnerSay("⚠️ Need at least 2 players to start the game.");
        return;
    }
    // If somehow called with exactly one player, treat them as the winner and reset.
if (llGetListLength(names) == 1) {
string winner = llList2String(names, 0);
llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
// Trigger victory confetti and record win
llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
llRegionSay(-12345, "GAME_WON|" + winner); // Send winner info to scoreboard
sendStatusMessage("Victory");  // Show victory status
                        // Wait for victory status to display before reset
                        llSleep(STATUS_DISPLAY_TIME + 1.0);
resetGame();
        return;
    }
    // DON'T reset round flag during continuation rounds - only reset for brand new games
    // This prevents peril player from being lost during round transitions
    
    
    // Select random initial peril player if none is set (only for very first round)
    if (perilPlayer == "" || perilPlayer == "NONE") {
        integer randomIdx = (integer)llFrand(llGetListLength(names));
        perilPlayer = llList2String(names, randomIdx);
        llSay(0, "🎯 " + perilPlayer + " has been randomly selected and is now in peril!");
        sendStatusMessage("Peril Selected");  // Show peril selected status when peril player is chosen
    } else {
        // Continue showing peril selected status for existing peril player
        sendStatusMessage("Peril Selected");
        // Add delay to allow this status to display before next phase
        llSleep(STATUS_DISPLAY_TIME * 0.6); // Wait 60% of status display time (~5 seconds)
    }
    picksData = [];
    globalPickedNumbers = [];
    // Create pick queue with peril player first, then all others
    pickQueue = [perilPlayer];
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        if (playerName != perilPlayer) {
            pickQueue += [playerName];
        }
    }
    currentPickerIdx = 0;
    // Don't pre-populate picksData with empty entries - let them be added as picks are made
    // This prevents encoding corruption with empty "|" entries
    updateHelpers();
    // requestDiceType(); // Removed to avoid recursion loop
}

showNextPickerDialog() {
    if (diceType <= 0) {
        llOwnerSay("❌ Cannot show picker dialog: diceType not set (" + (string)diceType + ")");
        return;
    }
    
    string firstName = llList2String(pickQueue, currentPickerIdx);
    currentPicker = llList2Key(players, llListFindList(names, [firstName]));
    
    // Add delay before showing dialog to prevent system overload
    llSleep(DIALOG_DELAY);
    
    // Check if this is a bot (TestBot names)
    if (llSubStringIndex(firstName, "TestBot") == 0) {
        // Get number of picks needed based on peril player's lives
        integer perilIdx = llListFindList(names, [perilPlayer]);
        integer perilLives = 3; // default
        if (perilIdx != -1) {
            perilLives = llList2Integer(lives, perilIdx);
        }
        // Pick count = 4 - peril player's lives (3 lives=1 pick, 2 lives=2 picks, 1 life=3 picks)
        integer picksNeeded = 4 - perilLives;
        
        // Send command to Bot Manager to auto-pick numbers (include already picked numbers)
        // CRITICAL: Use the most current globalPickedNumbers to prevent race conditions
        string alreadyPicked = llList2CSV(globalPickedNumbers);
        string botCommand = "BOT_PICK:" + firstName + ":" + (string)picksNeeded + ":" + (string)diceType + ":" + alreadyPicked;
        llMessageLinked(LINK_SET, -9999, botCommand, NULL_KEY);
        llOwnerSay("🤖 " + firstName + " is automatically picking " + (string)picksNeeded + " numbers...");
    } else {
        // Show dialog for human players - calculate picks needed
        integer perilIdx = llListFindList(names, [perilPlayer]);
        integer perilLives = 3; // default
        if (perilIdx != -1) {
            perilLives = llList2Integer(lives, perilIdx);
        }
        integer picksNeeded = 4 - perilLives;
        
        // Include already picked numbers so player can't pick duplicates
        string alreadyPicked = llList2CSV(globalPickedNumbers);
        string dialogPayload = firstName + "|" + (string)diceType + "|" + (string)picksNeeded + "|" + alreadyPicked;
        llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, currentPicker);
        timeoutTimer = llGetUnixTime();
        lastWarning = 0;
        llSetTimerEvent(60.0);
    }
}

integer roundStarted = FALSE;
integer gameStarting = FALSE;  // Track when game is in startup sequence

// Prevent duplicate registration by tracking pending registrations
list pendingRegistrations = [];  // Keys of players who have registration in progress
integer REGISTRATION_TIMEOUT = 10;  // Seconds to keep pending registration

default {
    state_entry() {
        llOwnerSay("🎮 Main Controller ready!");
        llOwnerSay("🎮 Main Controller key: " + (string)llGetKey());
        llOwnerSay("🎮 Main Controller position: " + (string)llGetPos());
        
        // Set the start image on the controller prim
        llSetTexture(TEXTURE_START, CONTROLLER_FACE);
        llSetText("🎮 PERIL DICE GAME\nTouch to play!", <1.0, 1.0, 0.0>, 1.0);
        
        llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
        llListen(-9999, "", NULL_KEY, ""); // Listen for bot responses
        llListen(rollDialogChannel, "", NULL_KEY, ""); // Listen for roll dialog responses
    }

    touch_start(integer total_number) {
        llOwnerSay("Touched by: " + (string)llDetectedKey(0));
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        
// Check if player has a current dialog they can recover
if (idx != -1 && toucher != llGetOwner() && roundStarted) {
    string playerName = llList2String(names, idx);
    // Check if this player is the current picker waiting for a dialog
    if (currentPicker == toucher) {
        llRegionSayTo(toucher, 0, "🔄 Restoring your number picking dialog...");
        llMessageLinked(LINK_SET, MSG_GET_CURRENT_DIALOG, playerName, toucher);
        return;
    }
    // Check if this player is the peril player who might need a roll dialog
    else if (playerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
        llRegionSayTo(toucher, 0, "🔄 Restoring your roll dialog...");
        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, toucher);
        return;
    }
}

// Special handling for owner during gameplay
if (toucher == llGetOwner() && roundStarted) {
    string ownerName = llKey2Name(toucher);
    list options = [];
    string menuText = "Game in progress. What would you like to do?";
    
    // Check if owner has active dialogs they can recover
    integer hasActiveDialog = FALSE;
    if (currentPicker == toucher) {
        options += ["🔄 Recover Pick Dialog"];
        hasActiveDialog = TRUE;
    }
    if (ownerName == perilPlayer && currentPickerIdx >= llGetListLength(pickQueue)) {
        options += ["🔄 Recover Roll Dialog"];
        hasActiveDialog = TRUE;
    }
    
    // Always offer admin menu
    options += ["🔧 Admin Menu"];
    
    // If no active dialogs, just show admin menu directly
    if (!hasActiveDialog) {
        llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", toucher);
        return;
    }
    
    // Show choice dialog
    llDialog(toucher, menuText, options, DIALOG_CHANNEL);
    return;
}
        
        if (toucher == llGetOwner()) {
            // Determine if this will be the first registered player (starter) before registration
            integer isStarter = FALSE;
            if (idx == -1) {
                // Check if registration is already pending for this player
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    llOwnerSay("⏳ Registration already in progress for " + llKey2Name(toucher));
                    return;
                }
                
                // No index found; the owner is not yet registered.
                // Owner becomes starter if there are no existing human players (excluding bots)
                isStarter = TRUE;  // Default to TRUE for owner
                integer j;
                for (j = 0; j < llGetListLength(names) && isStarter; j++) {
                    string existingName = llList2String(names, j);
                    // If there's already a human player (not a bot), owner is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                    }
                }
                string ownerName = llKey2Name(toucher);
                // Add to pending registrations
                pendingRegistrations += [toucher];
                // Send a registration request; Main.lsl will handle adding them and rezzing a float
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, ownerName + "|" + (string)toucher, NULL_KEY);
            } else {
                // Already registered; check if owner is the first human player
                // Owner is starter if they are at index 0 OR if all players before them are bots
                isStarter = TRUE;  // Default to TRUE for owner
                integer k;
                for (k = 0; k < idx && isStarter; k++) {
                    string existingName = llList2String(names, k);
                    // If there's a human player before the owner, owner is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                    }
                }
                // Special case: if owner is at index 0, they are definitely the starter
                if (idx == 0) {
                    isStarter = TRUE;
                }
            }
            // Show the owner menu with the appropriate starter flag
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, toucher);
        } else if (idx != -1) {
            // For non-owner players, check if they're the first human player
            integer isStarter = TRUE;  // Default to TRUE
            integer m;
            for (m = 0; m < idx && isStarter; m++) {
                string existingName = llList2String(names, m);
                // If there's a human player before this player, they're not starter
                if (llSubStringIndex(existingName, "TestBot") != 0) {
                    isStarter = FALSE;
                }
            }
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
        } else {
            // Unregistered non-owner player - register them and show menu
            string playerName = llKey2Name(toucher);
            if (playerName != "") {
                // Check if registration is already pending for this player
                if (llListFindList(pendingRegistrations, [toucher]) != -1) {
                    llOwnerSay("⏳ Registration already in progress for " + playerName);
                    return;
                }
                
                // Add to pending registrations
                pendingRegistrations += [toucher];
                // Send a registration request; Main.lsl will handle adding them and rezzing a float
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, playerName + "|" + (string)toucher, NULL_KEY);
                // Determine if this will be the first human player (starter)
                integer isStarter = TRUE;  // Default to TRUE
                integer n;
                for (n = 0; n < llGetListLength(names) && isStarter; n++) {
                    string existingName = llList2String(names, n);
                    // If there's already a human player (not a bot), this player is not starter
                    if (llSubStringIndex(existingName, "TestBot") != 0) {
                        isStarter = FALSE;
                    }
                }
                // Show the player menu with the appropriate starter flag
                llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
            } else {
                llOwnerSay("⚠️ Could not get name for toucher: " + (string)toucher);
            }
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        // Player list and pick list handling remain unchanged
        if (num == 202 && str == "REQUEST_PLAYER_LIST") {
            string namesCSV = llList2CSV(names);
            llMessageLinked(LINK_SET, 203, namesCSV, id);
            return;
        }
        if (num == 206) {
            string targetName = str;
            integer i;
            for (i = 0; i < llGetListLength(picksData); i++) {
                string rawEntry = llList2String(picksData, i);
                list parts = llParseString2List(rawEntry, ["|"], []);
                if (llList2String(parts, 0) == targetName) {
                    llMessageLinked(LINK_SET, 205, targetName + "|" + llList2String(parts, 1), id);
                    return;
                }
            }
            llMessageLinked(LINK_SET, 205, targetName + "|", id);
            return;
        }
        if (num == 208) {
            string playerName = str;
            integer idx = llListFindList(names, [playerName]);
            if (idx != -1) {
                string lifeVal = llList2String(lives, idx);
                llMessageLinked(LINK_SET, 208, playerName + "|" + lifeVal, id);
            }
            return;
        }
        // Handle dice type result from helper
        if (num == MSG_DICE_TYPE_RESULT) {
            if (!roundStarted) {
                roundStarted = TRUE;
                diceType = (integer)str;
                llOwnerSay(" Dice type set to: " + str);
                // Update helpers now that game has started - this will sync peril player
                updateHelpers();
                showNextPickerDialog();
            } else {
                // Game already started, but dice type changed (e.g., after elimination)
                diceType = (integer)str;
                llOwnerSay(" Dice type set to: " + str);
                updateHelpers();
                showNextPickerDialog();
            }
            return;
        }
        if (num == MSG_GET_PICKS_REQUIRED) {
            integer picksRequired = (integer)str;
            llOwnerSay(" Picks required: " + str);
            return;
        }
        if (num == MSG_GET_PICKER_INDEX) {
            integer pickIndex = (integer)str;
            llOwnerSay(" Picker index: " + str);
            return;
        }
        if (num == MSG_SERIALIZE_GAME_STATE) {
            string serialized = str;
            llOwnerSay(" Serialized game state: " + serialized);
            return;
        }
        // Handle pick actions
        if (num == 204) {
            list parts = llParseString2List(str, ["~"], []);
            string action = llList2String(parts, 0);
            list args = llParseString2List(llList2String(parts, 1), ["|"], []);
            string name = llList2String(args, 0);
            string pick = llList2String(args, 1);
            integer i;
            for (i = 0; i < llGetListLength(picksData); i++) {
                string entry = llList2String(picksData, i);
                list pdParts = llParseString2List(entry, ["|"], []);
                if (llList2String(pdParts, 0) == name) {
                    list pickList = [];
                    string rawPicks = llList2String(pdParts, 1);
                    if (rawPicks != "") {
                        pickList = llParseString2List(rawPicks, [","], []);
                    }
                    if (action == "ADD_PICK") {
                        if (llListFindList(pickList, [pick]) == -1) {
                            pickList += [pick];
                            llOwnerSay("➕ Added " + pick + " to " + name);
                        }
                    } else if (action == "REMOVE_PICK") {
                        integer idx = llListFindList(pickList, [pick]);
                        if (idx != -1) {
                            pickList = llDeleteSubList(pickList, idx, idx);
                            llOwnerSay("➖ Removed " + pick + " from " + name);
                        }
                    }
                    picksData = llListReplaceList(picksData, [name + "|" + llList2CSV(pickList)], i, i);
                    updateHelpers();
                    return;
                }
            }
            return;
        }
        // New: handle dynamic registration of players (owner or players) via MSG_REGISTER_PLAYER
        if (num == MSG_REGISTER_PLAYER) {
            // str is in the format "Name|<key>"
            list parts = llParseString2List(str, ["|"], []);
            string newName = llList2String(parts, 0);
            key newKey = (key)llList2String(parts, 1);
            
            // Prevent joining game in progress or during startup (except owner accessing menu)
            if ((roundStarted || gameStarting) && newKey != llGetOwner()) {
                llOwnerSay("🚫 " + newName + " cannot join - the killing game has begun!");
                llRegionSayTo(newKey, 0, "🚫 The killing game has already begun! Wait for the current game to end.");
                return;
            }
            
            // Do not register if already present
            integer existingIdx = llListFindList(players, [newKey]);
            if (existingIdx == -1) {
                // Add to local lists
                players += [newKey];
                names += [newName];
                lives += [3];
                picksData += [newName + "|"];
                // Track the floater channel for this player
                integer newPlayerIdx = llGetListLength(names) - 1;
                integer ch = -777000 + newPlayerIdx;
                floaterChannels += [ch];
                // Auto-mark bots as ready, leave humans as not ready
                if (llSubStringIndex(newName, "TestBot") == 0) {
                    readyPlayers += [newName];
                    llSay(0, "🤖 " + newName + " boots up with deadly precision - ready to play! 🤖");
                } else {
                    // Check if this is the first human player (starter - automatically ready only if owner)
                    integer humanCount = 0;
                    integer i;
                    for (i = 0; i < llGetListLength(names); i++) {
                        string playerName = llList2String(names, i);
                        if (llSubStringIndex(playerName, "TestBot") != 0) {
                            humanCount++;
                        }
                    }
                    if (humanCount == 1) { // This is the first human player
                        if (newKey == llGetOwner()) {
                            // Owner is auto-ready as starter
                            readyPlayers += [newName];
                            llSay(0, "👑 " + newName + " steps forward as the game master - automatically ready for the deadly challenge! 👑");
                        } else {
                            // Non-owner starter can toggle ready state
                            llSay(0, "👑 " + newName + " steps forward as the game master! Touch to set your ready status.");
                        }
                    }
                }
                // The float will be rezzed by the Floater Manager after it processes
                // this registration.  Avoid sending MSG_REZ_FLOAT here to prevent
                // race conditions; instead, request the float from Floater Manager
                // after it has updated its own lists.  Immediately propagate
                // helper updates now.
                updateHelpers();
                // Notify owner of registration
                llOwnerSay("🔔 Added player: " + newName);
            }
            
            // Remove from pending registrations whether successful or not
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
                    // Remove player's float using the tracked channel
                    integer ch = llList2Integer(floaterChannels, idx);
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // Remove from all lists
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    
                    llOwnerSay("🗑️ Eliminated " + eliminatedPlayer + ". Remaining players: " + (string)llGetListLength(names));
                    
                    // Show elimination status when someone is actually eliminated
                    sendStatusMessage("Elimination");
                    
                    // Update all scripts with the new player lists after elimination
                    updateHelpers();
                    
                    // Check if game should end (1 or fewer players remaining)
                    if (llGetListLength(names) <= 1) {
if (llGetListLength(names) == 1) {
string winner = llList2String(names, 0);
llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
// Trigger victory confetti and record win
llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
llRegionSay(-12345, "GAME_WON|" + winner); // Send winner info to scoreboard
                            // Wait for elimination status to display before showing victory
                            llSleep(STATUS_DISPLAY_TIME * 0.8); // Wait 80% of status display time (~6.4 seconds)
sendStatusMessage("Victory");  // Show victory status
                            // Wait for victory status to display before reset
                            llSleep(STATUS_DISPLAY_TIME + 1.0);
                        } else {
                            llSay(0, "💀 DESPAIR WINS! No Ultimate Survivors remain!");
                            // Wait for elimination status to display before reset (elimination already sent above)
                            llSleep(STATUS_DISPLAY_TIME + 1.0);
                        }
                        resetGame();
                        return;
                    }
                    
                    // If the eliminated player was the peril player, assign a new one and continue game
                    if (eliminatedPlayer == perilPlayer) {
                        // Find first remaining alive player to be new peril player
                        perilPlayer = "";
                        integer k;
                        for (k = 0; k < llGetListLength(names) && perilPlayer == ""; k++) {
                            string candidateName = llList2String(names, k);
                            if (llList2Integer(lives, k) > 0) {
                                perilPlayer = candidateName;
                                llOwnerSay("🔄 After elimination, new peril player: " + perilPlayer);
                            }
                        }
                        
                        // Continue the game with the new peril player (don't reset roundStarted)
                        if (perilPlayer != "") {
                            llOwnerSay("🎯 Continuing game with " + perilPlayer + " as new peril player");
                            // Reset picks and queue for new round, but keep roundStarted = TRUE
                            picksData = [];
                            globalPickedNumbers = [];
                            pickQueue = [perilPlayer];
                            integer i;
                            for (i = 0; i < llGetListLength(names); i++) {
                                string playerName = llList2String(names, i);
                                if (playerName != perilPlayer) {
                                    pickQueue += [playerName];
                                }
                            }
                            currentPickerIdx = 0;
                            updateHelpers();
                            requestDiceType();
                        }
                    } else {
                        // Continue with existing peril player
                        updateHelpers();
                    }
                }
            }
            return;
        }
        // Handle game won
        if (num == 998) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "GAME_WON") {
string winner = llList2String(parts, 1);
llRegionSay(-12346, "GAME_WON|" + winner); // Send winner info to scoreboard
llSleep(2.0); // Let celebration message display
resetGame();
            }
            return;
        }
        // Handle incoming sync updates from Roll Confetti Module (only after rolls)
        if (num == MSG_SYNC_GAME_STATE) {
            // Only accept sync if it contains different data than what we have
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                string currentLivesStr = llList2CSV(lives);
                string newLivesStr = llList2CSV(newLives);
                
                // Check if we need to update (lives changed OR peril player changed)
                string newPerilPlayerCheck = llList2String(parts, 2);
                
                // Don't accept "NONE" as a valid peril player if we already have a real one,
                // UNLESS the eliminated player is trying to be set as peril player
                if (newPerilPlayerCheck == "NONE" && perilPlayer != "" && perilPlayer != "NONE") {
                    // Check if current peril player is still in the game
                    integer perilStillInGame = llListFindList(names, [perilPlayer]) != -1;
                    if (perilStillInGame) {
                        return; // Don't process this sync update
                    }
                }
                
                integer perilChanged = (perilPlayer != newPerilPlayerCheck);
                integer livesChanged = (newLivesStr != currentLivesStr);
                
                if (livesChanged || perilChanged) {
                    // Decode the pickData from the encoded format
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
                                // Convert semicolons back to commas
                                picks = llDumpList2String(llParseString2List(picks, [";"], []), ",");
                                newPicksData += [playerName + "|" + picks];
                            } else {
                                newPicksData += [entry];
                            }
                        }
                    }
                    string newPerilPlayer = llList2String(parts, 2);
                    list newNames = llCSV2List(llList2String(parts, 3));
                    
                    
                    // Update our game state with the new data
                    lives = newLives;
                    picksData = newPicksData;
                    perilPlayer = newPerilPlayer;
                    names = newNames;
                    
                    
                    // Don't call updateHelpers() here to avoid loop - other modules already have the data
                }
            }
            return;
        }
        // Handle start next round request
        if (num == 997) {
            if (str == "START_NEXT_ROUND") {
                startNextRound();
                requestDiceType();
            }
            else if (llSubStringIndex(str, "START_NEXT_ROUND_DIALOG|") == 0) {
                string playerName = llGetSubString(str, 24, -1); // Remove "START_NEXT_ROUND_DIALOG|" prefix
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    key playerKey = llList2Key(players, idx);
                    llOwnerSay("🎯 Showing next round dialog to " + playerName);
                    // Check if it's a bot
                    if (llSubStringIndex(playerName, "TestBot") == 0) {
                        // Auto-start for bots with delay to allow sync to complete
                        llOwnerSay("🤖 " + playerName + " (bot) auto-starting next round...");
                        llSleep(0.5); // Give sync time to complete
                        startNextRound();
                        requestDiceType();
                    } else {
                        // Show dialog for humans
                        llDialog(playerKey, "💀 YOU ARE IN ULTIMATE PERIL! Are you ready to face the deadly challenge?", ["BEGIN KILLING GAME"], -77999);
                    }
                }
            }
            return;
        }
        // Handle dice type request from roll module
        if (num == 996) {
            if (str == "GET_DICE_TYPE") {
                llOwnerSay("🎲 Main Controller sending dice type: " + (string)diceType);
                llMessageLinked(LINK_SET, MSG_ROLL_RESULT, (string)diceType, NULL_KEY);
            }
            return;
        }
        // Handle leave game requests
        if (num == 107) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == "LEAVE_GAME") {
                string leavingName = llList2String(parts, 1);
                key leavingKey = (key)llList2String(parts, 2);
                integer idx = llListFindList(players, [leavingKey]);
                if (idx != -1) {
                    // Remove player's float using the tracked channel
                    integer ch = llList2Integer(floaterChannels, idx);
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // Remove from all lists including ready state
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    floaterChannels = llDeleteSubList(floaterChannels, idx, idx);
                    // Remove from ready list if present
                    integer readyIdx = llListFindList(readyPlayers, [leavingName]);
                    if (readyIdx != -1) {
                        readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    }
                    // Update helpers
                    updateHelpers();
                    llOwnerSay("👋 " + leavingName + " left the game");
                    // Check if game should end (less than 2 players)
if (llGetListLength(names) == 1) {
string winner = llList2String(names, 0);
llSay(0, "✨ ULTIMATE VICTORY! " + winner + " is the Ultimate Survivor!");
// Trigger victory confetti and record win
llMessageLinked(LINK_SET, MSG_PLAYER_WON, winner, NULL_KEY);
llMessageLinked(LINK_SET, 995, "VICTORY_CONFETTI", NULL_KEY);
llRegionSay(-12345, "GAME_WON|" + winner); // Send winner info to scoreboard
sendStatusMessage("Victory");  // Show victory status
                        // Wait for victory status to display before reset
                        llSleep(STATUS_DISPLAY_TIME + 1.0);
resetGame();
                    }
                }
            }
            return;
        }
        // Handle ready state toggle
        if (num == MSG_TOGGLE_READY) {
            string playerName = str;
            integer idx = llListFindList(names, [playerName]);
            if (idx != -1) {
                // Don't allow bots to toggle ready state (they're always ready)
                if (llSubStringIndex(playerName, "TestBot") == 0) {
                    llOwnerSay("🤖 Bots are always ready and cannot change state");
                    return;
                }
                
                integer readyIdx = llListFindList(readyPlayers, [playerName]);
                if (readyIdx == -1) {
                    // Player is not ready, make them ready
                    readyPlayers += [playerName];
                    llSay(0, "⚔️ " + playerName + " steels themselves for the deadly challenge ahead! ⚔️");
                } else {
                    // Player is ready, make them not ready
                    readyPlayers = llDeleteSubList(readyPlayers, readyIdx, readyIdx);
                    llSay(0, "🏃 " + playerName + " loses their nerve and backs away from the challenge! 🏃");
                }
            }
            return;
        }
        // Handle ready state queries
        if (num == MSG_QUERY_READY_STATE) {
            string playerName = str;
            integer isReady = llListFindList(readyPlayers, [playerName]) != -1;
            integer isBot = llSubStringIndex(playerName, "TestBot") == 0;
            string result = playerName + "|" + (string)isReady + "|" + (string)isBot;
            llMessageLinked(LINK_SET, MSG_READY_STATE_RESULT, result, id);
            return;
        }
        // Handle aggressive floater cleanup
        if (num == MSG_CLEANUP_ALL_FLOATERS) {
            integer i;
            for (i = 0; i < MAX_PLAYERS; i++) {
                integer ch = -777000 + i;
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                // Also try some potential duplicate channels
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 100), NULL_KEY);
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)(ch + 1000), NULL_KEY);
            }
            // Reset our tracked channels list
            floaterChannels = [];
            return;
        }
        // Handle HUMAN_PICKED messages from dialog handler
        if (num == -9998 && llSubStringIndex(str, "HUMAN_PICKED:") == 0) {
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                // Update the player's picks in picksData
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    // Find existing picks entry or add new one
                    integer picksIdx = -1;
                    integer k;
                    for (k = 0; k < llGetListLength(picksData); k++) {
                        string entry = llList2String(picksData, k);
                        if (llSubStringIndex(entry, playerName + "|") == 0) {
                            picksIdx = k;
                        }
                    }
                    string newEntry = playerName + "|" + picksStr;
                    if (picksIdx == -1) {
                        picksData += [newEntry];
                    } else {
                        picksData = llListReplaceList(picksData, [newEntry], picksIdx, picksIdx);
                    }
                    // Update global picked numbers list
                    list newPicks = llParseString2List(picksStr, [","], []);
                    integer i;
                    for (i = 0; i < llGetListLength(newPicks); i++) {
                        string pick = llList2String(newPicks, i);
                        if (llListFindList(globalPickedNumbers, [pick]) == -1) {
                            globalPickedNumbers += [pick];
                        }
                    }
                    updateHelpers();
                    llSay(0, "🎯 " + playerName + " stakes their life on numbers: " + picksStr + " 🎲");
                    
                    // Add delay before moving to next picker to prevent dialog system overload
                    llSleep(HUMAN_PICK_DELAY);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        showNextPickerDialog();
                    } else {
                        llOwnerSay("✅ All players have picked their numbers!");
                        // Show roll dialog to peril player
                        if (perilPlayer == "" || perilPlayer == "NONE") {
                            llOwnerSay("❌ ERROR: Cannot show roll dialog - perilPlayer is invalid: '" + perilPlayer + "'");
                            return;
                        }
                        key perilKey = llList2Key(players, llListFindList(names, [perilPlayer]));
                        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                    }
                }
            }
            return;
        }
        // Handle BOT_PICKED messages from Bot Manager
        if (num == -9997 && llSubStringIndex(str, "BOT_PICKED:") == 0) {
            list parts = llParseString2List(str, [":"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 1);
                string picksStr = llList2String(parts, 2);
                
                
                // Update the player's picks in picksData
                integer idx = llListFindList(names, [playerName]);
                if (idx != -1) {
                    // Find existing picks entry or add new one
                    integer picksIdx = -1;
                    integer k;
                    for (k = 0; k < llGetListLength(picksData); k++) {
                        string entry = llList2String(picksData, k);
                        if (llSubStringIndex(entry, playerName + "|") == 0) {
                            picksIdx = k;
                        }
                    }
                    string newEntry = playerName + "|" + picksStr;
                    if (picksIdx == -1) {
                        picksData += [newEntry];
                    } else {
                        picksData = llListReplaceList(picksData, [newEntry], picksIdx, picksIdx);
                    }
                    // Update global picked numbers list - bot picks use semicolon delimiters
                    list newPicks = llParseString2List(picksStr, [";"], []);
                    integer j;
                    for (j = 0; j < llGetListLength(newPicks); j++) {
                        string pick = llList2String(newPicks, j);
                        if (llListFindList(globalPickedNumbers, [pick]) == -1) {
                            globalPickedNumbers += [pick];
                        } else {
                            llOwnerSay("⚠️ WARNING: " + playerName + " picked " + pick + " which was already in globalPickedNumbers!");
                        }
                    }
                    updateHelpers();
                    llSay(0, "🎯 " + playerName + " (bot) stakes their digital life on numbers: " + picksStr + " 🎲");
                    
                    // Add delay after bot picks to prevent dialog system overload
                    llSleep(BOT_PICK_DELAY);
                    
                    // Move to next picker
                    currentPickerIdx++;
                    if (currentPickerIdx < llGetListLength(pickQueue)) {
                        string nextPicker = llList2String(pickQueue, currentPickerIdx);
                        showNextPickerDialog();
                    } else {
                        llOwnerSay("✅ All players have picked their numbers!");
                        // Show roll dialog to peril player
                        if (perilPlayer == "" || perilPlayer == "NONE") {
                            llOwnerSay("❌ ERROR: Cannot show roll dialog - perilPlayer is invalid: '" + perilPlayer + "'");
                            return;
                        }
                        key perilKey = llList2Key(players, llListFindList(names, [perilPlayer]));
                        llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, perilPlayer, perilKey);
                    }
                }
            }
            return;
        }
    }


    listen(integer channel, string name, key id, string msg) {
        
        if (channel == rollDialogChannel) {
            if (msg == "Start Next Round" || msg == "BEGIN KILLING GAME") {
                llSay(0, "⚡ THE KILLING GAME CONTINUES! " + perilPlayer + " begins the next deadly round!");
                startNextRound();
                requestDiceType();
                return;
            }
        }
        
        if (channel == DIALOG_CHANNEL) {
            // Handle owner choice dialog responses during gameplay
            if (id == llGetOwner() && roundStarted) {
                if (msg == "🔄 Recover Pick Dialog") {
                    string ownerName = llKey2Name(id);
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
            
            // Owner-specific commands: only owner messages in the dialog should be processed here.
            if (id == llGetOwner()) {
if (msg == "Reset Game") {
resetGame(); // Only reset current game, keep leaderboard
                    return;
                }
                if (msg == "Reset Leaderboard") {
llRegionSay(-12345, "RESET_LEADERBOARD"); // Reset only leaderboard scores
                    llOwnerSay("🏆 Leaderboard scores reset - game wins cleared!");
                    return;
                }
                if (msg == "Reset All") {
                    resetGame(); // Reset current game
llRegionSay(-12345, "RESET_LEADERBOARD"); // Reset leaderboard scores
                    llOwnerSay("🔄 Complete reset - game and leaderboard cleared!");
                    return;
                }
                // Note: do not handle "Start Game" here; allow the generic start logic below to apply,
                // so that minimum player checks are enforced and non-owner starters can initiate the game.
                if (msg == "Add Test Player") {
                    // Ensure we do not exceed the maximum allowed players
                    if (llGetListLength(players) >= MAX_PLAYERS) {
                        llOwnerSay("⚠️ Cannot add test player; the game is full (max " + (string)MAX_PLAYERS + ").");
                        return;
                    }
                    // Generate a unique name and key for the test player
                    string testName = "TestBot" + (string)llGetUnixTime();
                    key fake = llGenerateKey();
                    // Delegate registration to the MSG_REGISTER_PLAYER handler; it will add to lists and rez a float
                    llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, testName + "|" + (string)fake, NULL_KEY);
                    // Show the owner menu again - owner should still be starter after adding bots
                    integer ownerIdx = llListFindList(players, [llGetOwner()]);
                    integer ownerIsStarter = TRUE;  // Default to TRUE for owner
                    integer n;
                    for (n = 0; n < ownerIdx && ownerIsStarter; n++) {
                        string existingName = llList2String(names, n);
                        // If there's a human player before the owner, owner is not starter
                        if (llSubStringIndex(existingName, "TestBot") != 0) {
                            ownerIsStarter = FALSE;
                        }
                    }
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)ownerIsStarter, llGetOwner());
                    return;
                }
            }
            // Allow the first registered player (index 0) or the owner to start the game.
            // When the starter clicks "Start Game", begin the round.
            if (msg == "Start Game") {
                // Enforce a minimum of 2 players before starting
                if (llGetListLength(players) < 2) {
                    llOwnerSay("⚠️ Need at least 2 players to start the game.");
                    return;
                }
                
                // Check if all non-starter players are ready
                string starterName = "";
                if (id == llGetOwner()) {
                    starterName = llKey2Name(llGetOwner());
                } else if (llGetListLength(players) > 0) {
                    key firstPlayer = llList2Key(players, 0);
                    if (id == firstPlayer) {
                        starterName = llKey2Name(firstPlayer);
                    }
                }
                
                if (starterName == "") {
                    llOwnerSay("⚠️ Only the game starter can start the game.");
                    return;
                }
                
                // Check if all non-starter human players are ready
                list notReadyPlayers = [];
                integer i;
                for (i = 0; i < llGetListLength(names); i++) {
                    string playerName = llList2String(names, i);
                    // Skip the starter and bots (bots are auto-ready)
                    if (playerName != starterName && llSubStringIndex(playerName, "TestBot") != 0) {
                        if (llListFindList(readyPlayers, [playerName]) == -1) {
                            notReadyPlayers += [playerName];
                        }
                    }
                }
                
                if (llGetListLength(notReadyPlayers) > 0) {
                    llOwnerSay("⚠️ Cannot start game. These players are not ready: " + llList2CSV(notReadyPlayers));
                    return;
                }
                
                // All checks passed, start the game
                gameStarting = TRUE; // Prevent new players from joining during startup
                llSay(0, "⚡ ALL PARTICIPANTS READY! THE DEADLY PERIL DICE GAME BEGINS! ⚡");
                
                // Change controller display to show game is active
                llSetText("🎮 GAME IN PROGRESS\nRound " + (string)(llGetListLength(names)) + " players", <1.0, 0.2, 0.2>, 1.0);
                
                sendStatusMessage("Title");  // Show title status at game start
                startNextRound();
                requestDiceType();
            }
            // If the message text matches a player name, request their pick list
            if (llListFindList(names, [msg]) != -1) {
                llMessageLinked(LINK_SET, 206, msg, id);
            }
        }
    }
    
    timer() {
        // Check if we need to clear status message
        if (statusTimer > 0 && (llGetUnixTime() - statusTimer) >= STATUS_DISPLAY_TIME) {
            // Clear the status and revert to title
            statusTimer = 0;
            lastStatus = "";
            llRegionSay(-12345, "GAME_STATUS|Title");
            llOwnerSay("📢 Status cleared - reverted to Title");
            llSetTimerEvent(0); // Stop timer if no other timing needed
        }
        
        // Handle dialog timeout warnings (existing code)
        if (timeoutTimer > 0) {
            integer elapsed = llGetUnixTime() - timeoutTimer;
            if (elapsed >= TIMEOUT_SECONDS) {
                llOwnerSay("⏰ Dialog timeout reached!");
                llSetTimerEvent(0);
                timeoutTimer = 0;
            } else {
                integer remaining = TIMEOUT_SECONDS - elapsed;
                if (remaining <= warning2min && lastWarning < warning2min) {
                    llOwnerSay("⚠️ " + (string)(remaining / 60) + " minutes remaining for dialog response");
                    lastWarning = warning2min;
                } else if (remaining <= warning5min && lastWarning < warning5min) {
                    llOwnerSay("⚠️ " + (string)(remaining / 60) + " minutes remaining for dialog response");
                    lastWarning = warning5min;
                } else if (remaining <= warning9min && lastWarning < warning9min) {
                    llOwnerSay("⚠️ " + (string)(remaining / 60) + " minutes remaining for dialog response");
                    lastWarning = warning9min;
                }
            }
        }
    }
}
