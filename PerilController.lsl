// === Fully Unified Peril Dice Controller (Sequential Picks + Dynamic Dice Pool) ===

// Communication channels
integer syncChannel = -77777;
integer numberPickChannel = -77888;

// Game state
list players = [];
list names = [];
list lives = [];
list picksData = [];
string perilPlayer = "";
list globalPickedNumbers = [];
list floatSpawnMap = []; // stores avatar key and rezzed object key as pairs
string pendingUpdateName = ""; // for delayed float updates

// Sequential pick management
list pickQueue = [];
integer currentPickerIdx = -1;

// Dice and UI settings
integer diceType = 6;
integer page = 0;
integer maxPerPage = 12;

integer getDiceType(integer playerCount) {
    return ((playerCount + 1) / 2) * 6;
}

integer getPicksRequired(integer lifeCount) {
    if (lifeCount == 3) return 1;
    if (lifeCount == 2) return 2;
    return 3;
}

integer getPicksIndex(string nameInput) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        if (llSubStringIndex(entry, nameInput + "|") == 0) return i;
    }
    return -1;
}

list getPicksFor(string nameInput) {
    integer idx = getPicksIndex(nameInput);
    if (idx == -1) return [];
    string data = llList2String(picksData, idx);
    return llParseString2List(llList2String(llParseString2List(data, ["|"], []), 1), [","], []);
}

integer addPick(string nameInput, string number) {
    integer idx = getPicksIndex(nameInput);
    integer playerIdx = llListFindList(names, [nameInput]);
    integer perilIdx = llListFindList(names, [perilPlayer]);
    list picks;
    integer lifeCount = llList2Integer(lives, playerIdx);
    integer limit = getPicksRequired(lifeCount);
    if (perilIdx != -1) {
        limit = getPicksRequired(llList2Integer(lives, perilIdx));
    }

    if (idx == -1) {
        picks = [number];
        picksData += [nameInput + "|" + number];
    } else {
        picks = getPicksFor(nameInput);
        if (llListFindList(picks, [number]) != -1 || llGetListLength(picks) >= limit) {
        return 0;
    }
        picks += [number];
        picksData = llListReplaceList(picksData, [nameInput + "|" + llDumpList2String(picks, ",")], idx, idx);
    }
    globalPickedNumbers += [number];
    integer nameIdx = llListFindList(names, [nameInput]);
    pendingUpdateName = nameInput;
    llSetTimerEvent(0.3);
    updateFloater(nameInput);
    return 0;
}



showPickDialog(key id, string name) {
    list picks = getPicksFor(name);
    integer picksRequired = getPicksRequired(llList2Integer(lives, llListFindList(names, [name])));

    list options = [];
    integer start = page * maxPerPage + 1;
    integer endNum;
    if ((start + maxPerPage - 1) <= diceType) {
        endNum = start + maxPerPage - 1;
    } else {
        endNum = diceType;
    }

    integer i;
    for (i = start; i <= endNum; i++) {
        string s = (string)i;
        if (llListFindList(globalPickedNumbers, [s]) == -1) options += [s];
    }

    list buttons = [];
    if (page > 0) buttons += ["« Prev"];
    buttons += options;
    if ((page + 1) * maxPerPage < diceType) buttons += ["Next »"];

    llDialog(id, "Pick " + (string)picksRequired + " unique number(s):", buttons, numberPickChannel);
}

integer startNextPick() {
    if (currentPickerIdx >= llGetListLength(pickQueue)) {
        llOwnerSay("✅ All players have finished picking.");

        // Prompt peril player to roll
        integer pidx = llListFindList(names, [perilPlayer]);
        if (pidx != -1) {
            key pkey = llList2Key(players, pidx);
            llDialog(pkey, "🎲 All picks are in! Ready to roll the dice?", ["Roll"], syncChannel);
        }
        return 0;
    }
    string currentName = llList2String(pickQueue, currentPickerIdx);
            integer perilIdx = llListFindList(names, [perilPlayer]);
            if (perilIdx == -1) return 0;
            integer playerIdx = llListFindList(names, [currentName]);
    if (playerIdx == -1) {
        llOwnerSay("⚠️ Could not find player key for " + currentName);
        return 0;
    }
    key avKey = llList2Key(players, playerIdx);
    showPickDialog(avKey, currentName);
    return 0;
}

showStatus(string name) {
    integer idx = llListFindList(names, [name]);
    if (idx == -1) return;
    key avKey = llList2Key(players, idx);

    // Check if already in floatSpawnMap
    if (llListFindList(floatSpawnMap, [avKey]) != -1) return;

    integer lifeCount = llList2Integer(lives, idx);
    list picks = getPicksFor(name);
    string txt = "🎲 Peril Dice
👤 " + name +
                 "
❤️ Lives: " + (string)lifeCount +
                 "
🧍 Peril: " + perilPlayer +
                 "
🔢 Picks: " + llList2CSV(picks);

    vector pos = llList2Vector(llGetObjectDetails(avKey, [OBJECT_POS]), 0);
    vector rezPos = pos + <1,0,1>;
    integer channel = -777000 + idx;
    llOwnerSay("📦 Attempting to rez statFloat at: " + (string)rezPos);
    llRezObject("StatFloat", rezPos, ZERO_VECTOR, ZERO_ROTATION, channel);
    floatSpawnMap += [avKey, (string)channel];
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

checkForWinner() {
    integer alive = 0;
    string last;
    integer i;
    for (i = 0; i < llGetListLength(lives); i++) {
        if (llList2Integer(lives, i) > 0) {
            alive++;
            last = llList2String(names, i);
        }
    }
    if (alive == 1) {
        llSay(0, "🏆 Winner: " + last + "!");
        resetGame();
    }
}

updateFloater(string name) {
    integer idx = llListFindList(names, [name]);
    if (idx == -1) return;
    key avKey = llList2Key(players, idx);
    integer ch = -777000 + idx;
    integer lifeCount = llList2Integer(lives, idx);
    list picks = getPicksFor(name);
    string txt = "🎲 Peril Dice
👤 " + name +
                 "
❤️ Lives: " + (string)lifeCount +
                 "
🧍 Peril: " + perilPlayer +
                 "
🔢 Picks: " + llList2CSV(picks);
    llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
}

resetGame() {
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        integer ch = -777000 + i;
        llRegionSay(ch, "CLEANUP");
    }
    players = names = lives = picksData = globalPickedNumbers = [];
    perilPlayer = "";
    page = 0;
    llSay(syncChannel, "RESET");
    llOwnerSay("🔄 Game reset!");
}

integer rollDice() {
    return 1 + (integer)llFrand(diceType);
}

default {

timer() {
    if (pendingUpdateName != "") {
        updateFloater(pendingUpdateName);
        pendingUpdateName = "";
    }
}

object_rez(key id) {
    integer i;
    for (i = 0; i < llGetListLength(floatSpawnMap); i += 2) {
        key avKey = llList2Key(floatSpawnMap, i);
        integer ch = (integer)llList2String(floatSpawnMap, i + 1);
        integer idx = llListFindList(players, [avKey]);
        if (idx != -1 && ch == -777000 + idx) {
            string name = llList2String(names, idx);
            integer lifeCount = llList2Integer(lives, idx);
            list picks = getPicksFor(name);
            string txt = "🎲 Peril Dice
👤 " + name +
                         "
❤️ Lives: " + (string)lifeCount +
                         "
🧍 Peril: " + perilPlayer +
                         "
🔢 Picks: " + llList2CSV(picks);
            llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
            floatSpawnMap = llDeleteSubList(floatSpawnMap, i, i + 1);
            return;
        }
    }
}

state_entry() {
    llVolumeDetect(TRUE);
    llSetStatus(STATUS_PHYSICS, FALSE);
    llSetClickAction(CLICK_ACTION_TOUCH);
    llListen(-88888, "", NULL_KEY, "");
    llListen(0, "", NULL_KEY, "");
    llListen(syncChannel, "", NULL_KEY, "");
    llListen(numberPickChannel, "", NULL_KEY, "");
    llOwnerSay("🎲 Unified Peril Controller Ready");
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
    llOwnerSay("✅ " + name + " has joined the game with 3 lives.");
    showStatus(name);
}

listen(integer chan, string speakerName, key id, string msg) {
    if (chan == syncChannel && msg == "Roll" && llKey2Name(id) != "") {
        if (llList2String(names, llListFindList(players, [id])) != perilPlayer) return;
        string newPeril = "";
        integer result = rollDice();
        string resultStr = (string)result;
        llSay(0, "🎲 " + perilPlayer + " rolled a " + resultStr + "!");

                integer matched = FALSE;
        integer i;
        for (i = 0; i < llGetListLength(names); i++) {
            string pname = llList2String(names, i);
            list picks = getPicksFor(pname);
            if (llListFindList(picks, [resultStr]) != -1) {
                matched = TRUE;
                if (pname != perilPlayer) {
                    newPeril = pname;
                    return;
                }
            }
        }
        if (matched && newPeril != "") {
            llSay(0, "🎯 " + newPeril + " matched the roll and becomes the new peril player!");
            perilPlayer = newPeril;
        } else {
            integer pidx = llListFindList(names, [perilPlayer]);
            if (pidx != -1) {
                integer currentLives = llList2Integer(lives, pidx);
                lives = llListReplaceList(lives, [currentLives - 1], pidx, pidx);
                llSay(0, "💀 " + perilPlayer + " was hit and lost a life!");
                confetti();
                showStatus(perilPlayer);
            }
        }

        checkForWinner();
    }

    else if (chan == numberPickChannel) {
        string currentName = llList2String(pickQueue, currentPickerIdx);
        integer playerIdx = llListFindList(names, [currentName]);
        if (playerIdx == -1) return;
        key playerKey = llList2Key(players, playerIdx);

        if (id != playerKey) return; // Not their turn

        if (msg == "Next »") {
            page++;
            showPickDialog(id, currentName);
        } else if (msg == "« Prev") {
            if (page > 0) page--;
            showPickDialog(id, currentName);
        } else {
            addPick(currentName, msg);
            list picks = getPicksFor(currentName);
            integer perilIdx = llListFindList(names, [perilPlayer]);
            if (perilIdx == -1) return;
            integer required = getPicksRequired(llList2Integer(lives, perilIdx));
            if (llGetListLength(picks) >= required) {
                currentPickerIdx++;
            }
            page = 0;
            startNextPick();
        }
    }
    else if (chan == -88888 && msg == "Yes") {
        integer i = llListFindList(players, [id]);
        if (i != -1) {
            integer ch = -777000 + i;
            llRegionSay(ch, "CLEANUP");
            players = llDeleteSubList(players, i, i);
            names = llDeleteSubList(names, i, i);
            lives = llDeleteSubList(lives, i, i);
            llOwnerSay("👋 Player left the game: " + llKey2Name(id));
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
        string chosen = llList2String(names, r);
        perilPlayer = chosen;
        picksData = globalPickedNumbers = [];
        page = 0;
        diceType = getDiceType(llGetListLength(names));

        pickQueue = names;
        currentPickerIdx = 0;

        llSay(syncChannel, "PERIL:" + perilPlayer);
        llOwnerSay("🔥 Peril player is: " + perilPlayer);

        integer j;
        for (j = 0; j < llGetListLength(names); j++) {
            showStatus(llList2String(names, j));
        }

        startNextPick();
            }
    }
} // end of default state
// end of script
