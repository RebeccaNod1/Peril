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
            return llParseString2List(llList2String(parts, 1), [","], []);
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
        llListen(rollDialogChannel, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SHOW_ROLL_DIALOG) {
            llOwnerSay("🎲 Prompting " + str + " to roll the dice.");
            llDialog(id, "🎲 All picks are in! You're the peril player. Roll the dice?", ["Roll"], rollDialogChannel);
        }

        else if (num == MSG_ROLL_RESULT) {
            integer diceType = (integer)str;
            integer result = rollDice(diceType);
            string resultStr = (string)result;
            llSay(0, "🎲 " + perilPlayer + " rolled a " + resultStr + "!");

            string newPeril = "";
            integer matched = FALSE;
            integer i;
            for (i = 0; i < llGetListLength(names); i++) {
                string pname = llList2String(names, i);
                list picks = getPicksFor(pname);
                if (llListFindList(picks, [resultStr]) != -1) {
                    matched = TRUE;
                    if (pname != perilPlayer && newPeril == "") {
                        newPeril = pname;
                    }
                }
            }

            if (matched && newPeril != "") {
                llSay(0, "🎯 " + newPeril + " matched the roll and becomes the new peril player!");
                perilPlayer = newPeril;
                llMessageLinked(LINK_SET, MSG_REZ_FLOAT, newPeril, NULL_KEY);
            } else {
                integer pidx = llListFindList(names, [perilPlayer]);
                if (pidx != -1) {
                    integer currentLives = llList2Integer(lives, pidx);
                    lives = llListReplaceList(lives, [currentLives - 1], pidx, pidx);
                    llSay(0, "💀 " + perilPlayer + " was hit and lost a life!");
                    confetti();
                    llMessageLinked(LINK_SET, MSG_REZ_FLOAT, perilPlayer, NULL_KEY);
                }
            }

            string gameSync = llList2CSV(lives) + "~" + llList2CSV(picksData) + "~" + perilPlayer + "~" + llList2CSV(names);
            llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, gameSync, NULL_KEY);
            llSleep(0.2);
        }
    }

    listen(integer channel, string name, key id, string msg) {
        llMessageLinked(LINK_THIS, channel, msg, id);
    }
}
