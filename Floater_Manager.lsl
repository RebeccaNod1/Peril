// === FloatManager (Consolidated) ===
// This version enforces a maximum of 10 players.

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_SYNC_GAME_STATE = 107;

// =============================================================================
// DYNAMIC CHANNEL CONFIGURATION FOR FLOATERS
// =============================================================================

// Base channel offset - should match Main.lsl
integer CHANNEL_BASE = -77000;

// Calculate channels dynamically to avoid hardcoded conflicts
integer calculateChannel(integer offset) {
    // Use BOTH owner's key AND object's key to make channels unique per game instance
    // This prevents interference when same owner has multiple game tables
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetKey();
    string combinedStr = ownerStr + objectStr;
    
    // Create a more unique hash using both keys
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2; // Creates 0-255 range
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Dynamic channel variables
integer FLOATER_BASE_CHANNEL;

// Channel initialization function
initializeChannels() {
    FLOATER_BASE_CHANNEL = calculateChannel(9);   // ~-86000 range base for floaters
}

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
        initializeChannels();
        
        // Initialize/reset all state variables
        players = [];
        names = [];
        lives = [];
        picksData = [];
        perilPlayer = "";
        
        llOwnerSay("📦 Floater Manager ready!");
    }
    
    on_rez(integer start_param) {
        llOwnerSay("🔄 Floater Manager rezzed - reinitializing...");
        
        // Re-initialize dynamic channels
        initializeChannels();
        
        // Reset all state variables on rez
        players = [];
        names = [];
        lives = [];
        picksData = [];
        perilPlayer = "";
        
        llOwnerSay("✅ Floater Manager reset complete after rez!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Reset all game state
            players = [];
            names = [];
            lives = [];
            picksData = [];
            perilPlayer = "";
            llOwnerSay("📦 Floater Manager reset!");
            return;
        }
        
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
            
            // Check if this player is already registered to prevent duplicate floaters
            if (llListFindList(players, [avKey]) != -1) {
                llOwnerSay("⚠️ Player " + name + " is already registered, ignoring duplicate registration");
                return;
            }
            
            names += [name];
            players += [avKey];
            lives += [3]; // Initialize with 3 lives for new players
            picksData += [name + "|"];  // Initialize with empty picks
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
                // Test players: space floats apart and away from the scoreboard/leaderboard area.
                // Move them further away (3-5 meters) and spread them out more.
                // This prevents them from spawning directly on the leaderboard.
                pos = basePos + <-4.0 - (float)idx * 1.0, 2.0 + (float)idx * 0.8, 1>;
            }
            integer ch = FLOATER_BASE_CHANNEL + idx;
            llRezObject("StatFloat", pos, ZERO_VECTOR, ZERO_ROTATION, ch);
            // Wait a moment then set the description
            llSleep(0.2);
            // Find the rezzed object and set its description
            list nearby = llGetObjectDetails(llGetKey(), [OBJECT_POS]);
            if (llGetListLength(nearby) > 0) {
                // Use llRegionSay to tell the StatFloat its name
                llRegionSay(ch, "SET_NAME:" + name);
            }
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
            integer ch = FLOATER_BASE_CHANNEL + idx;
            integer lifeCount = llList2Integer(lives, idx);

            list picks = getPicksFor(name);


            string perilName;
            // Show proper peril status based on current game state
            // Check if we have any players with lives > 0 to determine if game is active
            integer gameActive = FALSE;
            integer i;
            for (i = 0; i < llGetListLength(lives); i++) {
                if (llList2Integer(lives, i) > 0) {
                    gameActive = TRUE;
                }
            }
            
            if (!gameActive || perilPlayer == "" || perilPlayer == "NONE" || llSubStringIndex(perilPlayer, ",") != -1) {
                perilName = "🧑 Status: Waiting for game to start...";
            } else if (name == perilPlayer) {
                // This player is currently in peril
                perilName = "⚡ YOU ARE IN PERIL! ⚡";
            } else {
                // Show who is currently in peril
                perilName = "🧑 Peril Player: " + perilPlayer;
            }

            string picksDisplay = llList2CSV(picks);
            string txt = "🎲 Peril Dice\n👤 " + name + "\nLives: " + (string)lifeCount + "\n" + perilName + "\n🔢 Picks: " + picksDisplay;
            llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
        }
        else if (num == MSG_CLEANUP_FLOAT) {
            integer ch = (integer)str;
            integer idx = ch - FLOATER_BASE_CHANNEL;
            
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
            if (llGetListLength(parts) < 4) {
                llOwnerSay("⚠️ Floater Manager: Incomplete sync message received, parts: " + (string)llGetListLength(parts));
                return;
            }
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
            // IMPORTANT: Also sync the names list to prevent desynchronization
            string namesStr = llList2String(parts, 3);
            names = llCSV2List(namesStr);
            
            // Sync players list if available (5th part)
            if (llGetListLength(parts) >= 5) {
                string playersStr = llList2String(parts, 4);
                players = llCSV2List(playersStr);
            }
            
            // Debug the peril player status change
            if (oldPeril != perilPlayer) {
                llOwnerSay("🎯 Floater Manager: Peril player updated from '" + oldPeril + "' to '" + perilPlayer + "'");
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