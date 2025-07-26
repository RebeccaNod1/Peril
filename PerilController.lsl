// === Main Peril Dice Controller (Modular) ===

integer syncChannel = -77777;
integer numberPickChannel = -77888;

list players = [];
list names = [];
list lives = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list picksData = [];

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

integer getDiceType(integer playerCount) {
    return ((playerCount + 1) / 2) * 6;
}

integer getPicksRequired(integer lifeCount) {
    if (lifeCount == 3) return 1;
    if (lifeCount == 2) return 2;
    return 3;
}

string serializeGameState() {
    return llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
}

resetGame() {
    string gameSync;
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        integer ch = -777000 + i;
        llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
    }
    players = names = lives = picksData = globalPickedNumbers = [];
    perilPlayer = "";
    pickQueue = [];
    currentPickerIdx = 0;
    llSay(syncChannel, "RESET");
    llOwnerSay("🔄 Game reset!");
    llSleep(0.2);
}

default {
    state_entry() {
        llListen(0, "", NULL_KEY, "");
        llListen(syncChannel, "", NULL_KEY, "");
        llListen(numberPickChannel, "", NULL_KEY, "");
        llListen(-88888, "", NULL_KEY, "");
        llOwnerSay("🎲 Modular Peril Controller Ready");
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        string name = llDetectedName(0);
        integer idx = llListFindList(players, [toucher]);
        if (~idx) {
            llDialog(toucher, "❓ You are already in the game. Leave the game?", ["Yes", "No"], -88888);
            return;
        }

        players += [toucher];
        names += [name];
        lives += [3];
        picksData += [name + "|0"]; // Initialize pick with default "0"
        llOwnerSay("✅ " + name + " has joined the game with 3 lives.");
        llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, name + "|" + (string)toucher, NULL_KEY);
        llMessageLinked(LINK_SET, MSG_REZ_FLOAT, name, toucher);
        llSleep(0.2);
        string gameSync = serializeGameState();
        llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
        llSleep(0.2);
        llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, name, toucher);
    }

    listen(integer chan, string speakerName, key id, string msg) {
        string gameSync;

        if (chan == -88888 && msg == "Yes") {
            integer i = llListFindList(players, [id]);
            if (i != -1) {
                integer ch = -777000 + i;
                llMessageLinked(LINK_SET, MSG_CLEANUP_FLOAT, (string)ch, NULL_KEY);
                players = llDeleteSubList(players, i, i);
                names = llDeleteSubList(names, i, i);
                lives = llDeleteSubList(lives, i, i);
                picksData = llDeleteSubList(picksData, i, i);
                globalPickedNumbers = llDeleteSubList(globalPickedNumbers, i, i);
                llOwnerSay("👋 Player left the game: " + llKey2Name(id));
                gameSync = serializeGameState();
                llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
                llSleep(0.2);
            }
        }
        else if (chan == 0 && llToLower(msg) == "/reset" && id == llGetOwner()) {
            resetGame();
        }
        else if (chan == 0 && llToLower(msg) == "/start" && id == llGetOwner()) {
            if (llGetListLength(names) == 0) {
                llOwnerSay("⚠️ No players to choose from.");
                return;
            }
            integer r = (integer)llFrand(llGetListLength(names));
            perilPlayer = llList2String(names, r);
            picksData = [];
            integer j;
            for (j = 0; j < llGetListLength(names); j++) {
                picksData += [llList2String(names, j) + "|0"]; // Initialize picks with default "0"
            }
            globalPickedNumbers = [];
            diceType = getDiceType(llGetListLength(names));
            pickQueue = names;
            currentPickerIdx = 0;

            llSay(syncChannel, "PERIL:" + perilPlayer);
            llOwnerSay("🔥 Peril player is: " + perilPlayer);
            gameSync = serializeGameState();
            llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
            llSleep(0.2);

            for (j = 0; j < llGetListLength(names); j++) {
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, llList2String(names, j), llList2Key(players, j));
            }

            string firstName = llList2String(pickQueue, currentPickerIdx);
            key firstKey = llList2Key(players, llListFindList(names, [firstName]));
            llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, firstName + "|" + (string)diceType, firstKey);
            gameSync = serializeGameState();
            llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
        }
        else if (chan == numberPickChannel) {
            integer idx = llListFindList(players, [id]);
            string playerName = "";
            if (idx != -1) {
                playerName = llList2String(names, idx);
                string newPick = msg;
                integer i;
                for (i = 0; i < llGetListLength(picksData); i++) {
                    string entry = llList2String(picksData, i);
                    if (llSubStringIndex(entry, playerName + "|") == 0) {
                        list parts = llParseString2List(entry, ["|"], []);
                        string pickStr = llList2String(parts, 1);
                        llOwnerSay("🔍 Existing pick for " + playerName + ": " + pickStr);

                        // If the pick is still "0", update it with the new pick
                        if (pickStr == "0") {
                            pickStr = newPick;
                        } else {
                            pickStr = newPick; // Replacing rather than appending
                        }
                        picksData = llListReplaceList(picksData, [playerName + "|" + pickStr], i, i);
                        llOwnerSay("✅ " + playerName + "'s pick updated to: " + newPick);
                        
                        // Immediately send updated data to floats
                        gameSync = serializeGameState();
                        llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);

                        // Update the float
                        llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, playerName, id);
                        return;
                    }
                }
            }
        }
    }
}
