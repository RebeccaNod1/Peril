// === Dialog Handler (Updated for Peril Dice) ===

integer MSG_SHOW_DIALOG = 101;
integer numberPickChannel = -77888;

list getDialogButtons(integer diceType) {
    list buttons = [];
    integer i;
    for (i = 1; i <= diceType; i++) {
        buttons += [(string)i];
    }
    return buttons;
}

showPickDialog(string name, key id, integer diceType) {
    if (diceType <= 0) {
        llOwnerSay("⚠️ Cannot show dialog: diceType is 0 or invalid.");
        return;
    }

    list options = getDialogButtons(diceType);
    llOwnerSay("🗨️ Showing dialog to: " + name);
    llOwnerSay("📋 Page: 0, DiceType: " + (string)diceType);
    llOwnerSay("🔢 Options: " + llList2CSV(options));
    llDialog(id, "Choose a number (1 - " + (string)diceType + "):", options, numberPickChannel);
}

default {
    state_entry() {
        llListen(numberPickChannel, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_SHOW_DIALOG) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) < 2) {
                llOwnerSay("⚠️ Malformed MSG_SHOW_DIALOG input: " + str);
                return;
            }

            string name = llList2String(parts, 0);
            integer diceType = (integer)llList2String(parts, 1);
            showPickDialog(name, id, diceType);
        }
    }

    listen(integer channel, string name, key id, string message) {
        llOwnerSay("🔊 Listen triggered on channel: " + (string)channel + ", msg: " + message + ", from: " + name + " (" + (string)id + ")");
    }
}
