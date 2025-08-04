// === FloatManager (Consolidated) ===
// This version enforces a maximum of 10 players.

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_SYNC_GAME_STATE = 107;

// Maximum number of players allowed in the game
integer MAX_PLAYERS = 10;

list players = [];
list names = [];
list lives = [];
list picksData = [];
string perilPlayer = "";

// Returns a list of picks for the given player name, filtering out invalid values
list getPicksFor(string nameInput) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);

        if (llSubStringIndex(entry, "|") == -1) {
            if (entry != "") llOwnerSay("⚠️ Malformed picks entry (missing pipe): " + entry);
        } else {
            list parts = llParseString2List(entry, ["|"], []);
            // Handle entries ending with "|" (empty picks) - LSL drops trailing empty elements
            if (llGetListLength(parts) == 1 && llGetSubString(entry, -1, -1) == "|") {
                parts += [""];  // Add the empty picks part back
            }
            if (llGetListLength(parts) < 2) {
                if (entry != "") llOwnerSay("⚠️ Malformed picks entry (too few parts): " + entry);
            }
            else if (llList2String(parts, 0) == nameInput) {
                string pickString = llList2String(parts, 1);
                if (pickString == "") {
                    // Empty picks are normal during initialization, don't warn
                    return [];
                } else {
                    // Convert semicolons back to commas for display
                    list pickList = llParseString2List(pickString, [";"], []);
                    list filtered = [];
                    integer j;
                    for (j = 0; j < llGetListLength(pickList); j++) {
                        string val = llStringTrim(llList2String(pickList, j), STRING_TRIM);
                        if (val != "" && (string)((integer)val) == val) {
                            filtered += [val];
                        }
                    }
                    return filtered;
                }
            }
        }
    }
    return [];
}

// Converts a player's key into their name (if registered)
string getNameFromKey(key id) {
    integer i = llListFindList(players, [id]);
    if (i != -1) return llList2String(names, i);
    return (string)id;
}

// Main event handler
default {
    state_entry() {
        llOwnerSay("📦 Floater Manager ready!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_REGISTER_PLAYER) {
            // Enforce the maximum number of players
            if (llGetListLength(players) >= MAX_PLAYERS) {
                llOwnerSay("⚠️ Cannot register new player; the game is full (max " + (string)MAX_PLAYERS + ").");
                return;
            }
            // Register a new player: store their name and avatar key
            list info = llParseString2List(str, ["|"], []);
            string name = llList2String(info, 0);
            key avKey = llList2Key(info, 1);
            names += [name];
            players += [avKey];
            llSay(0, "💀 " + name + " has entered the deadly game! Welcome to your potential doom! 💀");

            // Immediately rez the float after registration.  This ensures the
            // float manager has updated its internal lists before attempting
            // to look up the player's index.  Without this, other scripts
            // sending MSG_REZ_FLOAT in parallel could cause a race condition
            // where the float manager has not yet seen the new name, so it
            // cannot resolve the index and fails to rez the float.  By
            // initiating the rezzing here, we guarantee the float is created
            // only after the registration is complete.
            llMessageLinked(LINK_SET, MSG_REZ_FLOAT, name, avKey);
        }
        else if (num == MSG_REZ_FLOAT) {
            string name = str;
            integer idx = llListFindList(names, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(players, idx);
            // Determine the rez position.  For real avatars, use their current
            // location plus an offset.  For test players (fake keys) or when
            // OBJECT_POS cannot be obtained, fall back to rezzing relative to
            // the object's own position to ensure a float is created.
            list details = llGetObjectDetails(avKey, [OBJECT_POS]);
            vector basePos;
            if (llGetListLength(details) > 0) {
                basePos = llList2Vector(details, 0);
            } else {
                basePos = llGetPos();
            }
            vector pos;
            if (llGetListLength(details) > 0) {
                // Real avatars: rez next to the avatar with the standard offset
                pos = basePos + <1, 0, 1>;
            } else {
                // Test players: space floats apart along the X axis so they don't overlap.
                // Each test player gets an additional 0.5m offset based on their index.
                // This uses the current prim's position as the base since there's no
                // avatar position available.
                pos = basePos + <1 + (float)idx * 0.5, 0, 1>;
            }
            integer ch = -777000 + idx;
            llSetObjectDesc(name);
            llRezObject("StatFloat", pos, ZERO_VECTOR, ZERO_ROTATION, ch);
            // After rezzing, immediately update the float so it displays the
            // correct lives, picks and peril status.  Use the avatar key as
            // the id to keep the float tied to the player.  This ensures that
            // test players also receive an update even if they don’t have a
            // valid avatar key.
            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, name, avKey);
        }
        else if (num == MSG_UPDATE_FLOAT) {
            string name = str;
            integer idx = llListFindList(names, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(players, idx);
            integer ch = -777000 + idx;
            integer lifeCount = llList2Integer(lives, idx);

            list picks = getPicksFor(name);


            string perilName;
            // If the perilPlayer string is empty or contains a comma (indicating
            // multiple names), treat the game as not yet started.  This avoids
            // showing multiple players as the peril player before the first
            // round begins.  Once a single peril player is assigned, it will
            // not contain a comma and will be displayed normally.
            if (perilPlayer == "" || llSubStringIndex(perilPlayer, ",") != -1) {
                perilName = "🧍 Status: Waiting for game to start...";
            } else {
                // perilPlayer is already a name string, not a key
                perilName = "🧍 Peril: " + perilPlayer;
            }

            string picksDisplay = llList2CSV(picks);
            string txt = "🎲 Peril Dice\n👤 " + name + "\n❤️ Lives: " + (string)lifeCount + "\n" + perilName + "\n🔢 Picks: " + picksDisplay;
            llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
        }
        else if (num == MSG_CLEANUP_FLOAT) {
            integer ch = (integer)str;
            integer idx = ch - (-777000);
            
            // Always send cleanup message to the channel (even for orphaned floaters)
            llRegionSay(ch, "CLEANUP");
            
            // Only clean up internal lists if this corresponds to a valid player
            if (idx >= 0 && idx < llGetListLength(players)) {
                players = llDeleteSubList(players, idx, idx);
                names = llDeleteSubList(names, idx, idx);
                lives = llDeleteSubList(lives, idx, idx);
                picksData = llDeleteSubList(picksData, idx, idx);
            }
        }
        else if (num == MSG_SYNC_GAME_STATE) {
            // Synchronize the lists for lives and picksData when receiving a new game state
            list parts = llParseString2List(str, ["~"], []);
            string livesStr = llList2String(parts, 0);
            lives = llCSV2List(livesStr);
            // Use ^ delimiter for picksData to avoid comma conflicts
            string picksDataStr = llList2String(parts, 1);
            if (picksDataStr == "" || picksDataStr == "EMPTY") {
                picksData = [];
            } else {
                picksData = llParseString2List(picksDataStr, ["^"], []);
            }
            string receivedPeril = llList2String(parts, 2);
            string oldPeril = perilPlayer;
            if (receivedPeril == "NONE") {
                perilPlayer = "";  // Convert placeholder back to empty
            } else {
                perilPlayer = receivedPeril;
            }
            

            // After synchronizing the game state, update all existing floats so
            // they reflect the current peril status.  Without this, floats
            // created in previous rounds may continue to display an old
            // peril name until another manual update occurs.
            integer idx;
            for (idx = 0; idx < llGetListLength(names); idx++) {
                string n = llList2String(names, idx);
                // Use the player's key if it exists; fallback to NULL_KEY for test bots
                key k;
                if (idx < llGetListLength(players)) {
                    k = llList2Key(players, idx);
                } else {
                    k = NULL_KEY;
                }
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, n, k);
            }
        }
    }
}