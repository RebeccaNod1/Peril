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

list players = [];
list names = [];
list lives = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list picksData = [];
list readyPlayers = [];

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
integer MSG_SHOW_ROLL_DIALOG = 301;

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

// Forward game state to helpers when it changes
updateHelpers() {
    string serialized = llList2CSV(lives) + "~" + llList2CSV(picksData) +
        "~" + perilPlayer + "~" + llList2CSV(names);
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, serialized, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_SYNC_PICKQUEUE, llList2CSV(pickQueue), NULL_KEY);
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
    // Remove floats in reverse order so indices remain correct as entries are
    // deleted from the Floater Manager's lists.  Otherwise, deleting index 0
    // first shifts subsequent indices and some floats are left behind.
    integer i;
    for (i = llGetListLength(names) - 1; i >= 0; i--) {
        integer ch = -777000 + i;
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    players = names = lives = picksData = globalPickedNumbers = [];
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    llSay(syncChannel, "RESET");
    llOwnerSay(" Game reset!");
    llSleep(0.2);
    llSetTimerEvent(0);
    updateHelpers();
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
        llSay(0, " " + llList2String(names, 0) + " is the last player standing and wins the game!");
        resetGame();
        return;
    }
    picksData = [];
    globalPickedNumbers = [];
    pickQueue = names;
    currentPickerIdx = 0;
    integer j;
    for (j = 0; j < llGetListLength(names); j++) {
        picksData += [llList2String(names, j) + "|"];
    }
    updateHelpers();
    // requestDiceType(); // Removed to avoid recursion loop
}

showNextPickerDialog() {
    string firstName = llList2String(pickQueue, currentPickerIdx);
    currentPicker = llList2Key(players, llListFindList(names, [firstName]));
    string dialogPayload = firstName + "|" + (string)diceType;
    llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, currentPicker);
    timeoutTimer = llGetUnixTime();
    lastWarning = 0;
    llSetTimerEvent(60.0);
}

integer roundStarted = FALSE;

default {
    state_entry() {
        llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
    }

    touch_start(integer total_number) {
        llOwnerSay("Touched by: " + (string)llDetectedKey(0));
        key toucher = llDetectedKey(0);
        integer idx = llListFindList(players, [toucher]);
        if (toucher == llGetOwner()) {
            // Determine if this will be the first registered player (starter) before registration
            integer isStarter = FALSE;
            if (idx == -1) {
                // No index found; the owner is not yet registered.
                // If there are no existing players, they will become the starter.
                if (llGetListLength(players) == 0) {
                    isStarter = TRUE;
                }
                string ownerName = llKey2Name(toucher);
                // Send a registration request; Main.lsl will handle adding them and rezzing a float
                llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, ownerName + "|" + (string)toucher, NULL_KEY);
            } else {
                // Already registered; starter if at index 0
                isStarter = (idx == 0);
            }
            // Show the owner menu with the appropriate starter flag
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, toucher);
        } else if (idx != -1) {
            integer isStarter = (idx == 0);
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, toucher);
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
            // Do not register if already present
            integer existingIdx = llListFindList(players, [newKey]);
            if (existingIdx == -1) {
                // Add to local lists
                players += [newKey];
                names += [newName];
                lives += [3];
                picksData += [newName + "|"];
                // The float will be rezzed by the Floater Manager after it processes
                // this registration.  Avoid sending MSG_REZ_FLOAT here to prevent
                // race conditions; instead, request the float from Floater Manager
                // after it has updated its own lists.  Immediately propagate
                // helper updates now.
                updateHelpers();
                // Notify owner of registration
                llOwnerSay("🔔 Added player: " + newName);
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
                    // Remove player's float
                    integer ch = -777000 + idx;
                    llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                    // Remove from all lists
                    players = llDeleteSubList(players, idx, idx);
                    names = llDeleteSubList(names, idx, idx);
                    lives = llDeleteSubList(lives, idx, idx);
                    picksData = llDeleteSubList(picksData, idx, idx);
                    // Update helpers
                    updateHelpers();
                    llOwnerSay("👋 " + leavingName + " left the game");
                    // Check if game should end (less than 2 players)
                    if (llGetListLength(names) == 1) {
                        llSay(0, " " + llList2String(names, 0) + " is the last player standing and wins the game!");
                        resetGame();
                    } else if (llGetListLength(names) == 0) {
                        resetGame();
                    }
                }
            }
            return;
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (channel == DIALOG_CHANNEL) {
            // Owner-specific commands: only owner messages in the dialog should be processed here.
            if (id == llGetOwner()) {
                if (msg == "Reset Game") {
                    resetGame();
                    return;
                }
                // Note: do not handle "Start Game" here; allow the generic start logic below to apply,
                // so that minimum player checks are enforced and non-owner starters can initiate the game.
                if (msg == "Dump Players") {
                    llOwnerSay(" Players: " + llList2CSV(names));
                    return;
                }
                if (msg == "Manage Picks") {
                    llOwnerSay(" Fetching list of players for pick management...");
                    llMessageLinked(LINK_SET, 202, "REQUEST_PLAYER_LIST", llGetOwner());
                    return;
                }
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
                    // Show the owner menu again (not flagged as starter)
                    llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|0", llGetOwner());
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
                // Check if the sender is the owner
                if (id == llGetOwner()) {
                    startNextRound();
                    requestDiceType();
                    return;
                }
                // Otherwise, check if the sender is the very first player registered
                if (llGetListLength(players) > 0) {
                    key firstPlayer = llList2Key(players, 0);
                    if (id == firstPlayer) {
                        startNextRound();
                        requestDiceType();
                        return;
                    }
                }
            }
            // If the message text matches a player name, request their pick list
            if (llListFindList(names, [msg]) != -1) {
                llMessageLinked(LINK_SET, 206, msg, id);
            }
        }
    }
}