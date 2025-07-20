key target;
string displayText;

default {
    on_rez(integer start_param) {
        llOwnerSay("🧪 on_rez triggered with start_param: " + (string)start_param);
        llListen(start_param, "", NULL_KEY, "");
        llOwnerSay("📡 Listening on channel (on_rez): " + (string)start_param);
    }

    state_entry() {
        llOwnerSay("🧭 StatFloat active");
        llSetText("Waiting...", <1,1,1>, 1.0);
        llSetTimerEvent(1.0);
    }

    listen(integer channel, string name, key id, string message) {
        llOwnerSay("🔉 Heard on channel " + (string)channel + ": " + message);
        if (llSubStringIndex(message, "FLOAT:") == 0) {
            list parts = llParseString2List(message, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                target = (key)llGetSubString(llList2String(parts, 0), 6, -1);
                displayText = llList2String(parts, 1);
                llSetText(displayText, <1,1,1>, 1.0);
                llOwnerSay("✅ Received FLOAT for: " + (string)target);
            }
        } else if (message == "CLEANUP") {
            llOwnerSay("🧹 Cleaning up...");
            llDie();
        }
    }

    timer() {
        if (target != NULL_KEY && llKey2Name(target) != "") {
            vector pos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0) + <1,0,1>;
            llSetRegionPos(pos);
        }
    }
}
