// === Dialog Handler (Owner & Player) ===

integer DIALOG_CHANNEL = -88888;
integer MSG_SHOW_MENU = 201;
integer MSG_PICK_ACTION = 204;
integer MSG_PLAYER_LIST_RESULT = 203;
integer MSG_PICK_LIST_RESULT = 205;
integer MSG_LIFE_LOOKUP = 207;

list ownerOptions = ["Join Game", "Leave Game", "Add Test Player", "Manage Picks", "Start Game", "Reset Game", "Dump Players"];
list playerOptions = ["Start", "Ready"];

list currentPickList;
string currentPickTarget;
integer currentPickLimit = 3;

showOwnerMenu(key id) {
    llDialog(id, "🔧 Debug Menu", ownerOptions, DIALOG_CHANNEL);
}

showPlayerMenu(key id, integer isStarter) {
    if (isStarter) {
        llDialog(id, "You are the game starter. Click Start to begin when all are ready.", playerOptions, DIALOG_CHANNEL);
    } else {
        llDialog(id, "Click Ready when you are ready to begin.", ["Ready"], DIALOG_CHANNEL);
    }
}

showPickManageMenu(key id, list playerNames) {
    list options = [];
    integer i;
    for (i = 0; i < llGetListLength(playerNames); i++) {
        string pname = llList2String(playerNames, i);
        options += ["🛠 " + pname];
    }
    options += ["⬅️ Back"];
    llDialog(id, "📋 Manage Picks for: ", options, DIALOG_CHANNEL);
}

showPickListMenu(key id) {
    list options = [];
    integer i;
    for (i = 0; i < llGetListLength(currentPickList); i++) {
        string pick = llList2String(currentPickList, i);
        if (llStringLength(pick) > 0) {
            options += ["REMOVE: " + pick];
        }
    }
    options += ["Add Pick", "⬅️ Back"];
    llDialog(id, "🛠 Picks for: " + currentPickTarget, options, DIALOG_CHANNEL);
}

askForNewPick(key id) {
    llTextBox(id, "🔢 Enter a number to add for " + currentPickTarget + ":", DIALOG_CHANNEL);
}

default {
    state_entry() {
        llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SHOW_MENU) {
            llOwnerSay("📨 Received MSG_SHOW_MENU with: " + str);
            list args = llParseString2List(str, ["|"], []);
            if (llGetListLength(args) < 2) {
                llOwnerSay("⚠️ Invalid message format: " + str);
                return;
            }
            string targetType = llList2String(args, 0);
            integer isStarter = (integer)llList2String(args, 1);

            if (targetType == "owner") {
                llOwnerSay("👤 Showing owner menu");
                showOwnerMenu(id);
            } else if (targetType == "player") {
                llOwnerSay("👥 Showing player menu");
                showPlayerMenu(id, isStarter);
            }
        }
        else if (num == MSG_PLAYER_LIST_RESULT) {
            list playerNames = llParseString2List(str, [","], []);
            llOwnerSay("📋 Fetching list of players for pick management...");
            showPickManageMenu(id, playerNames);
        }
        else if (num == MSG_PICK_LIST_RESULT) {
            list parts = llParseString2List(str, ["|"], []);
            string returnedName = llList2String(parts, 0);
            string picks = llList2String(parts, 1);
            if (llStringTrim(returnedName, STRING_TRIM) == llStringTrim(currentPickTarget, STRING_TRIM)) {
                llOwnerSay("✅ Matched pick list for: " + returnedName);
                currentPickList = llCSV2List(picks);
                llMessageLinked(LINK_THIS, MSG_LIFE_LOOKUP, currentPickTarget, id);
            } else {
                llOwnerSay("❌ Name mismatch: got " + returnedName + " but expected " + currentPickTarget);
            }
        }
        else if (num == MSG_LIFE_LOOKUP) {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == currentPickTarget) {
                currentPickLimit = (integer)llList2String(parts, 1);
                showPickListMenu(id);
            }
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (msg == "Manage Picks") {
            llMessageLinked(LINK_THIS, 202, "REQUEST_PLAYER_LIST", id);
        }
        else if (llSubStringIndex(msg, "🛠 ") == 0) {
            currentPickTarget = llStringTrim(llDeleteSubString(msg, 0, 1), STRING_TRIM);
            llOwnerSay("🎯 Pick target set to: " + currentPickTarget);
            currentPickList = [];
            llMessageLinked(LINK_THIS, 206, currentPickTarget, id);
        }
        else if (msg == "Add Pick") {
            askForNewPick(id);
        }
        else if (msg == "⬅️ Back") {
            llMessageLinked(LINK_THIS, 202, "REQUEST_PLAYER_LIST", id);
        }
        else if (llSubStringIndex(msg, "REMOVE: ") == 0) {
            string pick = llGetSubString(msg, 8, -1);
            string payload = "REMOVE_PICK~" + currentPickTarget + "|" + pick;
            llMessageLinked(LINK_THIS, MSG_PICK_ACTION, payload, id);
            llSleep(0.2);
            llMessageLinked(LINK_THIS, 206, currentPickTarget, id);
        }
        else if ((integer)msg > 0) {
            if (llGetListLength(currentPickList) >= currentPickLimit) {
                llOwnerSay("⚠️ Reached pick limit of " + (string)currentPickLimit + " for " + currentPickTarget);
                showPickListMenu(id);
                return;
            }

            if (llListFindList(currentPickList, [msg]) != -1) {
                llOwnerSay("⚠️ Pick already exists: " + msg);
                showPickListMenu(id);
                return;
            }

            integer i;
            for (i = 0; i < llGetListLength(currentPickList); i++) {
                if (llList2String(currentPickList, i) == msg) {
                    llOwnerSay("⚠️ Duplicate pick detected.");
                    return;
                }
            }

            string payload = "ADD_PICK~" + currentPickTarget + "|" + msg;
            llMessageLinked(LINK_THIS, MSG_PICK_ACTION, payload, id);
            llSleep(0.2);
            llMessageLinked(LINK_THIS, 206, currentPickTarget, id);
        }
    }
}
