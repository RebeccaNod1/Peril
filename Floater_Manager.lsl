// === FloatManager (Consolidated) ===
// This version enforces a maximum of 10 players.

integer MSG_SHOW_DIALOG = 101;
integer MSG_ROLL_RESULT = 102;
integer MSG_UPDATE_FLOAT = 103;
integer MSG_CLEANUP_FLOAT = 104;
integer MSG_REZ_FLOAT = 105;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_SYNC_GAME_STATE = 107;
integer MSG_CLEANUP_ALL_FLOATERS = 212;

// Debug control message constants
integer MSG_DEBUG_PICKS_ON = 7001;
integer MSG_DEBUG_PICKS_OFF = 7002;

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

// Debug control - set to TRUE for verbose pick debugging, FALSE for normal operation
integer DEBUG_PICKS = FALSE;

// Verbose logging control - affects general debug messages, toggled by owner
integer VERBOSE_LOGGING = FALSE;

// Memory reporting function
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    llOwnerSay("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

// ALIVE PLAYERS (shrinks during eliminations)
list alivePlayers = [];
list aliveNames = [];
list aliveLives = [];
list alivePicksData = [];

// ELIMINATED PLAYERS (grows during eliminations) 
list eliminatedPlayers = [];
list eliminatedNames = [];
list eliminatedChannels = [];

// ALL PLAYERS (never shrinks - for channel mapping)
list allPlayerNames = [];   // Names in registration order
list allPlayerChannels = []; // Corresponding channels

// SYNC STATE VARIABLES (received from Main Controller)
list names = [];        // Current player names from sync
list players = [];      // Current player keys from sync  
list lives = [];        // Current lives from sync
list picksData = [];    // Current picks data from sync
list playerNames = [];  // Legacy variable for cleanup compatibility
list playerChannels = []; // Legacy variable for cleanup compatibility

string perilPlayer = "";

// Move a player from alive to eliminated lists
eliminatePlayer(string playerName) {
    integer aliveIdx = llListFindList(aliveNames, [playerName]);
    if (aliveIdx == -1) {
        llOwnerSay("⚠️ [Floater Manager] Cannot eliminate " + playerName + " - not found in alive list");
        return;
    }
    
    // Get player data before removing from alive lists
    key playerKey = llList2Key(alivePlayers, aliveIdx);
    string picks = llList2String(alivePicksData, aliveIdx);
    
    // Find their original channel from permanent mapping
    integer channelIdx = llListFindList(allPlayerNames, [playerName]);
    integer playerChannel = -1;
    if (channelIdx != -1) {
        playerChannel = llList2Integer(allPlayerChannels, channelIdx);
    }
    
    // Add to eliminated lists
    eliminatedNames += [playerName];
    eliminatedPlayers += [playerKey];
    eliminatedChannels += [playerChannel];
    
    // Remove from alive lists
    alivePlayers = llDeleteSubList(alivePlayers, aliveIdx, aliveIdx);
    aliveNames = llDeleteSubList(aliveNames, aliveIdx, aliveIdx);
    aliveLives = llDeleteSubList(aliveLives, aliveIdx, aliveIdx);
    alivePicksData = llDeleteSubList(alivePicksData, aliveIdx, aliveIdx);
    
    llOwnerSay("🧹 [Floater Manager] Moved " + playerName + " from alive to eliminated lists");
}

// Returns a list of picks for the given player name, filtering out invalid values
list getPicksFor(string nameInput) {
    // ENHANCED DEBUG: Log the request and current data state
    if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] getPicksFor(" + nameInput + "), picksData entries: " + (string)llGetListLength(picksData));
    
    integer i;
    for (i = 0; i < llGetListLength(picksData); i++) {
        string entry = llList2String(picksData, i);
        if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Examining entry [" + (string)i + "]: " + entry);

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
                if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Found match for " + nameInput + ", pickString: '" + pickString + "'");
                
                if (pickString == "") {
                    // Empty picks are normal during initialization, don't warn
                    if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Empty picks for " + nameInput + ", returning []");
                    return [];
                } else {
                    // IMPROVED PARSING: Handle both comma AND semicolon delimited picks
                    // First, try parsing as comma-separated (most common format from Game Manager)
                    list pickList = llParseString2List(pickString, [","], []);
                    
                    // If that gives us only one item, try semicolon-separated
                    if (llGetListLength(pickList) == 1 && llSubStringIndex(pickString, ";") != -1) {
                        pickList = llParseString2List(pickString, [";"], []);
                        if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Using semicolon parsing for: " + pickString);
                    } else {
                        if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Using comma parsing for: " + pickString + ", got " + (string)llGetListLength(pickList) + " picks");
                    }
                    
                    list filtered = [];
                    integer j;
                    for (j = 0; j < llGetListLength(pickList); j++) {
                        string val = llStringTrim(llList2String(pickList, j), STRING_TRIM);
                        if (val != "" && (string)((integer)val) == val) {
                            filtered += [val];
                            if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Added valid pick: " + val);
                        } else if (val != "") {
                            if (DEBUG_PICKS) llOwnerSay("⚠️ [Floater Manager] Filtered out invalid pick: '" + val + "'");
                        }
                    }
                    
                    if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] Final filtered picks for " + nameInput + ": " + llList2CSV(filtered));
                    return filtered;
                }
            }
        }
    }
    
    if (DEBUG_PICKS) llOwnerSay("🔍 [Floater Manager] No picks found for " + nameInput + ", returning []");
    return [];
}

// Converts a player's key into their name (if registered)
string getNameFromKey(key id) {
    integer i = llListFindList(alivePlayers, [id]);
    if (i != -1) return llList2String(aliveNames, i);
    return (string)id;
}

// Main event handler
default {
    state_entry() {
        reportMemoryUsage("💬 Floater Manager");
        
        initializeChannels();
        
        // Initialize/reset all state variables
        alivePlayers = [];
        aliveNames = [];
        aliveLives = [];
        alivePicksData = [];
        eliminatedPlayers = [];
        eliminatedNames = [];
        eliminatedChannels = [];
        allPlayerNames = [];
        allPlayerChannels = [];
        
        // Initialize sync state variables
        names = [];
        players = [];
        lives = [];
        picksData = [];
        playerNames = [];
        playerChannels = [];
        perilPlayer = "";
        
        llOwnerSay("📦 Floater Manager ready!");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("💬 Floater Manager");
        
        llOwnerSay("🔄 Floater Manager rezzed - reinitializing...");
        
        // Re-initialize dynamic channels
        initializeChannels();
        
        // Reset all state variables on rez
        alivePlayers = [];
        aliveNames = [];
        aliveLives = [];
        alivePicksData = [];
        eliminatedPlayers = [];
        eliminatedNames = [];
        eliminatedChannels = [];
        allPlayerNames = [];
        allPlayerChannels = [];
        
        // Initialize sync state variables
        names = [];
        players = [];
        lives = [];
        picksData = [];
        playerNames = [];
        playerChannels = [];
        perilPlayer = "";
        
        llOwnerSay("✅ Floater Manager reset complete after rez!");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Reset all game state
            alivePlayers = [];
            aliveNames = [];
            aliveLives = [];
            alivePicksData = [];
            eliminatedPlayers = [];
            eliminatedNames = [];
            eliminatedChannels = [];
            allPlayerNames = [];
            allPlayerChannels = [];
            
            // Reset sync state variables
            names = [];
            players = [];
            lives = [];
            picksData = [];
            playerNames = [];
            playerChannels = [];
            perilPlayer = "";
            llOwnerSay("📦 Floater Manager reset!");
            return;
        }
        
        // Handle verbose logging toggle from Main Controller
        if (num == 9011 && llSubStringIndex(str, "VERBOSE_LOGGING|") == 0) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                VERBOSE_LOGGING = (integer)llList2String(parts, 1);
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔍 [Floater Manager] Verbose logging ON");
                } else {
                    llOwnerSay("🔍 [Floater Manager] Verbose logging OFF");
                }
            }
            return;
        }
        
        if (num == MSG_REGISTER_PLAYER) {
            // Enforce the maximum number of players
            if (llGetListLength(alivePlayers) >= MAX_PLAYERS) {
                llOwnerSay("⚠️ Cannot register new player; the game is full (max " + (string)MAX_PLAYERS + ").");
                return;
            }
            // Register a new player: store their name and avatar key
            list info = llParseString2List(str, ["|"], []);
            string name = llList2String(info, 0);
            key avKey = llList2Key(info, 1);
            
            // Check if this player is already registered to prevent duplicate floaters
            if (llListFindList(alivePlayers, [avKey]) != -1) {
                llOwnerSay("⚠️ Player " + name + " is already registered, ignoring duplicate registration");
                return;
            }
            
            // Add to ALIVE lists
            aliveNames += [name];
            alivePlayers += [avKey];
            aliveLives += [3]; // Initialize with 3 lives for new players
            alivePicksData += [name + "|"];  // Initialize with empty picks
            
            // Add to PERMANENT mapping (never changes after registration)
            integer playerIdx = llGetListLength(allPlayerNames);
            integer ch = FLOATER_BASE_CHANNEL + playerIdx;
            allPlayerNames += [name];
            allPlayerChannels += [ch];
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
            integer idx = llListFindList(aliveNames, [name]);
            if (idx == -1) return;
            key avKey = llList2Key(alivePlayers, idx);
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
            // Use permanent channel mapping instead of alive list index
            integer channelIdx = llListFindList(allPlayerNames, [name]);
            integer ch;
            if (channelIdx != -1) {
                ch = llList2Integer(allPlayerChannels, channelIdx);
            } else {
                // Fallback - this shouldn't happen but use idx as backup
                llOwnerSay("⚠️ [Floater Manager] WARNING: " + name + " not in permanent mapping during rez, using fallback");
                ch = FLOATER_BASE_CHANNEL + idx;
            }
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
            
            // FIXED: Use permanent channel mapping that doesn't change during eliminations
            integer channelIdx = llListFindList(allPlayerNames, [name]);
            integer ch;
            if (channelIdx != -1) {
                ch = llList2Integer(allPlayerChannels, channelIdx);
            } else {
                // Fallback - this shouldn't happen if permanent mapping is working
                llOwnerSay("⚠️ [Floater Manager] WARNING: Player " + name + " not in permanent mapping");
                return;
            }
            
            // Try to find player in current sync data (names/lives from Main Controller)
            // This works for both alive and eliminated players during the elimination sync
            integer syncIdx = llListFindList(names, [name]);
            key avKey = NULL_KEY;
            integer lifeCount = 0;
            
            if (syncIdx != -1) {
                // Player found in current sync data
                if (syncIdx < llGetListLength(players)) {
                    avKey = llList2Key(players, syncIdx);
                }
                if (syncIdx < llGetListLength(lives)) {
                    lifeCount = llList2Integer(lives, syncIdx);
                }
            } else {
                // Player not in sync data - they might be eliminated
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔍 [Floater Manager] Player " + name + " not in current sync - might be eliminated");
                }
                // Continue with lifeCount = 0 to show eliminated status
            }

            if (VERBOSE_LOGGING) llOwnerSay("🔄 [Floater Manager] Updating floater for " + name + " (lives: " + (string)lifeCount + ")");
            list picks = getPicksFor(name);
            if (VERBOSE_LOGGING) llOwnerSay("🔄 [Floater Manager] Retrieved picks for " + name + ": " + llList2CSV(picks));

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
            
            // Check if this player is the winner (only one player with lives > 0)
            integer livingPlayers = 0;
            integer isWinner = FALSE;
            for (i = 0; i < llGetListLength(lives); i++) {
                if (llList2Integer(lives, i) > 0) {
                    livingPlayers++;
                }
            }
            
            // If only one player has lives > 0 and this player has lives > 0, they're the winner
            if (livingPlayers == 1 && lifeCount > 0) {
                isWinner = TRUE;
            }
            
            string txt;
            if (isWinner) {
                // Winner display with victory text (triggers green glow in PlayerStatus_Float.lsl)
                txt = "🎲 Peril Dice\n👤 " + name + "\n✨ ULTIMATE VICTORY! ✨\n🏆 ULTIMATE SURVIVOR 🏆\nLives: " + (string)lifeCount + "\n🔢 Final Picks: " + picksDisplay;
            } else {
                // Normal display
                txt = "🎲 Peril Dice\n👤 " + name + "\nLives: " + (string)lifeCount + "\n" + perilName + "\n🔢 Picks: " + picksDisplay;
            }
            
            llRegionSay(ch, "FLOAT:" + (string)avKey + "|" + txt);
        }
        else if (num == MSG_CLEANUP_FLOAT) {
            integer ch = (integer)str;
            
            // Always send cleanup message to the channel (even for orphaned floaters)
            llRegionSay(ch, "CLEANUP");
            
            // FIXED: Find player by searching the permanent channel mapping
            string removedPlayer = "";
            integer foundIdx = -1;
            
            // Search for the channel in our permanent mapping
            foundIdx = llListFindList(allPlayerChannels, [ch]);
            if (foundIdx != -1) {
                removedPlayer = llList2String(allPlayerNames, foundIdx);
            }
            
            if (foundIdx != -1 && removedPlayer != "") {
                // Find the current index of this player in the active names list
                integer currentIdx = llListFindList(names, [removedPlayer]);
                llOwnerSay("🧹 [Floater Manager] Cleaning up floater for: " + removedPlayer + " (channel: " + (string)ch + ")");
                
                // Remove from current game lists using the current index
                if (currentIdx != -1) {
                    if (currentIdx < llGetListLength(players)) players = llDeleteSubList(players, currentIdx, currentIdx);
                    if (currentIdx < llGetListLength(names)) names = llDeleteSubList(names, currentIdx, currentIdx);
                    if (currentIdx < llGetListLength(lives)) lives = llDeleteSubList(lives, currentIdx, currentIdx);
                } else {
                    llOwnerSay("⚠️ [Floater Manager] WARNING: " + removedPlayer + " not found in current names list for removal");
                }
                
                // IMPORTANT: Keep permanent mapping intact - never remove from playerNames/playerChannels
                // This preserves the original channel assignments
                
                // Remove from picksData by searching for the player name
                integer pickIdx = -1;
                integer p;
                for (p = 0; p < llGetListLength(picksData); p++) {
                    string entry = llList2String(picksData, p);
                    if (llSubStringIndex(entry, removedPlayer + "|") == 0) {
                        pickIdx = p;
                        jump found_pick;
                    }
                }
                @found_pick;
                if (pickIdx != -1) {
                    picksData = llDeleteSubList(picksData, pickIdx, pickIdx);
                }
                
                // CRITICAL: Update all remaining floaters to refresh peril status after player removal
                // This prevents stale peril player information from persisting in floaters
                llSleep(0.2); // Brief delay to ensure cleanup completes
                integer i;
                for (i = 0; i < llGetListLength(names); i++) {
                    string remainingPlayerName = llList2String(names, i);
                    key remainingPlayerKey = NULL_KEY;
                    if (i < llGetListLength(players)) {
                        remainingPlayerKey = llList2Key(players, i);
                    }
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, remainingPlayerName, remainingPlayerKey);
                }
            } else {
                // Orphaned floater cleanup - channel not found in our tracking
                llOwnerSay("🧹 [Floater Manager] Cleaned up orphaned floater (channel: " + (string)ch + ") - not in tracking list");
            }
        }
        else if (num == MSG_SYNC_GAME_STATE) {
            // Synchronize the lists for lives and picksData when receiving a new game state
            list parts = llParseString2List(str, ["~"], []);
            
            // Handle special RESET sync message
            if (llGetListLength(parts) >= 5 && llList2String(parts, 0) == "RESET") {
                llOwnerSay("🔄 [Floater Manager] Received reset sync - ignoring during reset");
                return;
            }
            
            if (llGetListLength(parts) < 4) {
                llOwnerSay("⚠️ Floater Manager: Incomplete sync message received, parts: " + (string)llGetListLength(parts));
                return;
            }
            string livesStr = llList2String(parts, 0);
            lives = llCSV2List(livesStr);
            
            // ENHANCED DEBUG: Log the received picks data
            string picksDataStr = llList2String(parts, 1);
            if (VERBOSE_LOGGING) llOwnerSay("📥 [Floater Manager] Received picks data: '" + picksDataStr + "'");
            
            // Use ^ delimiter for picksData to avoid comma conflicts
            if (picksDataStr == "" || picksDataStr == "EMPTY") {
                picksData = [];
                if (VERBOSE_LOGGING) llOwnerSay("📥 [Floater Manager] Picks data empty, cleared picksData list");
            } else {
                picksData = llParseString2List(picksDataStr, ["^"], []);
                if (VERBOSE_LOGGING) {
                    llOwnerSay("📥 [Floater Manager] Parsed " + (string)llGetListLength(picksData) + " picks data entries:");
                    integer debugIdx;
                    for (debugIdx = 0; debugIdx < llGetListLength(picksData); debugIdx++) {
                        llOwnerSay("  [" + (string)debugIdx + "]: " + llList2String(picksData, debugIdx));
                    }
                }
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
            list newNames = llCSV2List(namesStr);
            
            // CRITICAL: If names list changed size, rebuild permanent mapping if needed
            if (llGetListLength(allPlayerNames) == 0 && llGetListLength(newNames) > 0) {
                // Initial population of permanent mapping from sync
                allPlayerNames = newNames;
                allPlayerChannels = [];
                integer i;
                for (i = 0; i < llGetListLength(newNames); i++) {
                    integer ch = FLOATER_BASE_CHANNEL + i;
                    allPlayerChannels += [ch];
                }
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🔄 [Floater Manager] Built permanent mapping: " + llList2CSV(allPlayerNames) + " -> " + llList2CSV(allPlayerChannels));
                }
            }
            
            names = newNames;
            
            // Sync players list if available (5th part)
            if (llGetListLength(parts) >= 5) {
                string playersStr = llList2String(parts, 4);
                players = llCSV2List(playersStr);
            }
            
            // Debug the peril player status change
            if (oldPeril != perilPlayer) {
                llOwnerSay("🎯 Floater Manager: Peril player updated from '" + oldPeril + "' to '" + perilPlayer + "'");
            }

            // CRITICAL: After synchronizing the game state, ALWAYS update ALL registered floaters
            // This includes both alive and eliminated players so eliminated floaters show proper status
            integer idx;
            for (idx = 0; idx < llGetListLength(allPlayerNames); idx++) {
                string n = llList2String(allPlayerNames, idx);
                // Find player key if they're still alive, otherwise use NULL_KEY
                key k = NULL_KEY;
                integer aliveIdx = llListFindList(names, [n]);
                if (aliveIdx != -1 && aliveIdx < llGetListLength(players)) {
                    k = llList2Key(players, aliveIdx);
                }
                llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, n, k);
            }
            
            // Additional safety: If there was a peril player change, add a brief delay and update again
            // This handles edge cases where floater updates might race with other state changes
            if (oldPeril != perilPlayer && perilPlayer != "" && perilPlayer != "NONE") {
                llOwnerSay("🔄 [Floater Manager] Peril player changed - scheduling secondary update for stability");
                llSleep(0.3); // Brief delay to let initial updates complete
                for (idx = 0; idx < llGetListLength(allPlayerNames); idx++) {
                    string n = llList2String(allPlayerNames, idx);
                    // Find player key if they're still alive, otherwise use NULL_KEY
                    key k = NULL_KEY;
                    integer aliveIdx = llListFindList(names, [n]);
                    if (aliveIdx != -1 && aliveIdx < llGetListLength(players)) {
                        k = llList2Key(players, aliveIdx);
                    }
                    llMessageLinked(LINK_SET, MSG_UPDATE_FLOAT, n, k);
                }
            }
        }
        
        // Handle aggressive floater cleanup requests
        else if (num == MSG_CLEANUP_ALL_FLOATERS) {
            string context = str; // "RESET" for conservative, empty for aggressive
            
            if (context == "RESET") {
                // Conservative cleanup during reset - only clean known floaters using permanent mapping
                if (llGetListLength(allPlayerChannels) > 0) {
                    llOwnerSay("🧹 [Floater Manager] Cleaning up floaters for " + (string)llGetListLength(allPlayerChannels) + " registered channels...");
                    integer i;
                    for (i = 0; i < llGetListLength(allPlayerChannels); i++) {
                        integer ch = llList2Integer(allPlayerChannels, i);
                        llRegionSay(ch, "CLEANUP");
                    }
                }
            } else {
                // Aggressive cleanup for troubleshooting - scan all possible channels
                llOwnerSay("🧽 [Floater Manager] Performing aggressive floater cleanup...");
                integer i;
                for (i = 0; i < MAX_PLAYERS; i++) {
                    integer ch = FLOATER_BASE_CHANNEL + i;
                    llRegionSay(ch, "CLEANUP");
                    llRegionSay(ch + 100, "CLEANUP");
                    llRegionSay(ch + 1000, "CLEANUP");
                }
                llOwnerSay("✅ [Floater Manager] Aggressive cleanup complete");
            }
            
            // Clear our internal tracking
            players = [];
            names = [];
            lives = [];
            picksData = [];
            perilPlayer = "";
            playerNames = [];
            playerChannels = [];
        }
        // Handle debug control messages
        else if (num == MSG_DEBUG_PICKS_ON) {
            DEBUG_PICKS = TRUE;
            llOwnerSay("🔍 [Floater Manager] Pick debugging ENABLED");
        }
        else if (num == MSG_DEBUG_PICKS_OFF) {
            DEBUG_PICKS = FALSE;
            llOwnerSay("🔇 [Floater Manager] Pick debugging DISABLED");
        }
    }
}
