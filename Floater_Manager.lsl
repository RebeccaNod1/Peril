#include "Peril_Constants.lsl"

// === FloatManager (Consolidated) ===
// This version enforces a maximum of 10 players.

// =============================================================================
// DYNAMIC CHANNEL CONFIGURATION FOR FLOATERS
// =============================================================================

// Base channel offset must match Main.lsl
#define CHANNEL_BASE -77000

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
#define MAX_PLAYERS 10

// Debug control - set to TRUE for verbose pick debugging, FALSE for normal operation
integer DEBUG_PICKS = FALSE;

// Memory reporting function
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    dbg("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

// ALL REGISTERED PLAYERS (for channel mapping - order never changes)
list allPlayerNames = [];   // Names in registration order

// CURRENT GAME STATE (Synced from Main Controller)
list names = [];        // Current player names in game
list players = [];      // Current player keys in game  
list lives = [];        // Current health from sync
list picksData = [];    // Current picks data from sync

string perilPlayer = "";

// Helper to get picks for a player, handles both comma (human) and semicolon (bot)
list getPicksFor(string nameInput) {
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        integer pipeIdx = llSubStringIndex(entry, "|");
        if (pipeIdx != -1 && llGetSubString(entry, 0, pipeIdx - 1) == nameInput) {
            string pickString = llGetSubString(entry, pipeIdx + 1, -1);
            if (pickString == "") return [];
            list pickList = llParseString2List(pickString, [",", ";"], []); // Parse both at once
            list filtered = [];
            integer j;
            for (j = 0; j < llGetListLength(pickList); j++) {
                string val = llStringTrim(llList2String(pickList, j), STRING_TRIM);
                if (val != "") filtered += [val];
            }
            return filtered;
        }
    }
    return [];
}

// Main event handler
default {
    state_entry() {
        reportMemoryUsage("💬 Floater Manager");
        
        initializeChannels();
        
        // Initialize/reset all state variables
        allPlayerNames = [];
        names = [];
        players = [];
        lives = [];
        picksData = [];
        perilPlayer = "";
        
        dbg("💬 [Floater Manager] 📦 Floater Manager ready!");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("💬 Floater Manager");
        dbg("💬 [Floater Manager] 🔄 Floater Manager rezzed - reinitializing...");
        
        initializeChannels();
        
        // Reset all state variables on rez
        allPlayerNames = [];
        names = [];
        players = [];
        lives = [];
        picksData = [];
        dbg("💬 [Floater Manager] ✅ Floater Manager reset complete after rez!");
    }

    link_message(integer sender, integer num, string str, key id) {
        // Handle full reset from main controller
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            allPlayerNames = [];
            names = [];
            players = [];
            lives = [];
            picksData = [];
            perilPlayer = "";
            dbg("💬 [Floater Manager] 📦 Floater Manager reset!");
            return;
        }
        
        if (num == MSG_REGISTER_PLAYER) {
            if (llGetListLength(allPlayerNames) >= MAX_PLAYERS) {
                dbg("💬 [Floater Manager] ⚠️ Game is full (max " + (string)MAX_PLAYERS + ").");
                return;
            }
            list info = llParseString2List(str, ["|"], []);
            string name = llList2String(info, 0);
            key avKey = llList2Key(info, 1);
            
            if (llListFindList(allPlayerNames, [name]) != -1) return;
            
            allPlayerNames += [name]; // Permanent map
            llSay(0, "💀 " + name + " has entered the deadly game! 💀");
            llMessageLinked(LINK_SET, MSG_REZ_FLOAT, name, avKey);
        }
        else if (num == MSG_REZ_FLOAT) {
            string name = str;
            integer channelIdx = llListFindList(allPlayerNames, [name]);
            if (channelIdx == -1) return;
            
            key avKey = id; // Passed from MSG_REGISTER_PLAYER or MSG_REZ_FLOAT
            
            list details = llGetObjectDetails(avKey, [OBJECT_POS]);
            vector basePos = llGetPos();
            if (llGetListLength(details) > 0) basePos = llList2Vector(details, 0);

            vector pos;
            if (llGetListLength(details) > 0) {
                pos = basePos + <1, 0, 1>; // Avatar relative
            } else {
                // Test players: grid layout
                integer row = channelIdx / 5;
                integer col = channelIdx % 5;
                pos = basePos + <-3.0 - (float)col * 1.5, 2.0 + (float)row * 2.0, 1>;
            }
            
            integer ch = FLOATER_BASE_CHANNEL + channelIdx;
            llRezObject("StatFloat", pos, ZERO_VECTOR, ZERO_ROTATION, ch);
            llSleep(0.2);
            llRegionSay(ch, "SET_NAME:" + name);
            llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, name, avKey);
        }
        else if (num == MSG_UPDATE_FLOAT) {
            string name = str;
            integer channelIdx = llListFindList(allPlayerNames, [name]);
            if (channelIdx == -1) return;
            integer ch = FLOATER_BASE_CHANNEL + channelIdx;
            
            integer syncIdx = llListFindList(names, [name]);
            key avKey = id;
            integer lifeCount = 0;
            
            if (syncIdx != -1) {
                if (syncIdx < llGetListLength(players)) avKey = llList2Key(players, syncIdx);
                if (syncIdx < llGetListLength(lives)) lifeCount = llList2Integer(lives, syncIdx);
            }

            list picks = getPicksFor(name);
            string picksDisplay = llList2CSV(picks);
            
            // Visual Settings
            float glow = 0.0;
            vector color = <1,1,1>;
            string heartTexture = (string)lifeCount + "_hearts";
            
            // Status String Logic
            string perilStatus;
            if (perilPlayer == "" || perilPlayer == "NONE") perilStatus = "🧑 Status: Waiting...";
            else if (name == perilPlayer) perilStatus = "⚡ YOU ARE IN PERIL! ⚡";
            else perilStatus = "🧑 Peril Player: " + perilPlayer;

            // Winner detection
            integer livingPlayers = 0;
            integer i;
            for (i = 0; i < llGetListLength(lives); i++) {
                if (llList2Integer(lives, i) > 0) livingPlayers++;
            }
            
            string txt = "🎲 Peril Dice\n👤 " + name + "\n" + perilStatus + "\n🔢 Picks: " + picksDisplay;
            
            if (lifeCount <= 0) {
                glow = 0.3;
                color = <1,0,0>; // Red
                txt = "🎲 Peril Dice\n👤 " + name + "\n🔢 Picks: " + picksDisplay + "\n💀 ELIMINATED! 💀";
            } else if (livingPlayers == 1 && llGetListLength(names) >= 2) {
                glow = 0.3;
                color = <0,1,0>; // Green
                txt = "🎲 Peril Dice\n👤 " + name + "\n✨ ULTIMATE VICTORY! ✨\n🏆 ULTIMATE SURVIVOR 🏆\n🔢 Final Picks: " + picksDisplay;
            } else if (name == perilPlayer) {
                glow = 0.2;
                color = <1,1,0>; // Yellow
            }
            
            // Send Universal API command
            llRegionSay(ch, "CMD:" + (string)avKey + 
                "|T=" + txt + 
                "|G=" + (string)glow + 
                "|C=" + (string)color + 
                "|H=" + heartTexture);
        }
        else if (num == MSG_CLEANUP_FLOAT) {
            integer ch = (integer)str;
            llRegionSay(ch, "CLEANUP");
            
            integer foundIdx = ch - FLOATER_BASE_CHANNEL;
            if (foundIdx >= 0 && foundIdx < llGetListLength(allPlayerNames)) {
                string removedPlayer = llList2String(allPlayerNames, foundIdx);
                integer currentIdx = llListFindList(names, [removedPlayer]);
                if (currentIdx != -1) {
                    if (currentIdx < llGetListLength(players)) players = llDeleteSubList(players, currentIdx, currentIdx);
                    if (currentIdx < llGetListLength(names)) names = llDeleteSubList(names, currentIdx, currentIdx);
                    if (currentIdx < llGetListLength(lives)) lives = llDeleteSubList(lives, currentIdx, currentIdx);
                }
                
                integer pickIdx = -1;
                integer p;
                for (p = 0; p < llGetListLength(picksData); p++) {
                    if (llSubStringIndex(llList2String(picksData, p), removedPlayer + "|") == 0) {
                        pickIdx = p;
                        p = llGetListLength(picksData);
                    }
                }
                if (pickIdx != -1) picksData = llDeleteSubList(picksData, pickIdx, pickIdx);
            }
        }
        else if (num == MSG_SYNC_GAME_STATE) {
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) < 4) return;
            
            lives = llCSV2List(llList2String(parts, 0));
            string picksDataStr = llList2String(parts, 1);
            if (picksDataStr == "" || picksDataStr == "EMPTY") {
                picksData = [];
            } else {
                picksData = llParseString2List(picksDataStr, ["^"], []);
            }
            
            string receivedPeril = llList2String(parts, 2);
            if (receivedPeril == "NONE") {
                perilPlayer = "";
            } else {
                perilPlayer = receivedPeril;
            }
            names = llCSV2List(llList2String(parts, 3));
            
            if (llGetListLength(allPlayerNames) == 0 && llGetListLength(names) > 0) allPlayerNames = names;
            if (llGetListLength(parts) >= 5) players = llCSV2List(llList2String(parts, 4));

            integer idx;
            for (idx = 0; idx < llGetListLength(allPlayerNames); idx++) {
                string n = llList2String(allPlayerNames, idx);
                key k = NULL_KEY;
                integer aliveIdx = llListFindList(names, [n]);
                if (aliveIdx != -1 && aliveIdx < llGetListLength(players)) k = llList2Key(players, aliveIdx);
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, n, k);
            }
        }
        else if (num == MSG_CLEANUP_ALL_FLOATERS) {
            integer i;
            for (i = 0; i < llGetListLength(allPlayerNames); i++) {
                llRegionSay(FLOATER_BASE_CHANNEL + i, "CLEANUP");
            }
            players = []; names = []; lives = []; picksData = []; perilPlayer = "";
        }
        else if (num == MSG_DEBUG_PICKS_ON) DEBUG_PICKS = TRUE;
        else if (num == MSG_DEBUG_PICKS_OFF) DEBUG_PICKS = FALSE;
    }
}
