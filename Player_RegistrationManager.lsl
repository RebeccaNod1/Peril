// === Player Registration Manager ===
// Handles all player registration, join/leave operations to reduce Main Controller memory usage
// This script takes over the memory-heavy player management operations

// Message constants for communication
integer MSG_REGISTER_PLAYER_REQUEST = 9050;  // Dedicated message from Main Controller for registration
integer MSG_OWNER_MESSAGE = 9030;
integer MSG_PUBLIC_MESSAGE = 9031;
integer MSG_REGION_MESSAGE = 9032;
integer MSG_SHOW_MENU = 201;
integer MSG_UPDATE_MAIN_LISTS = 9040;  // Optimized message to update main controller lists
integer MSG_SYNC_GAME_STATE = 107;

// Scoreboard and display message constants
integer SCOREBOARD_LINK = 12;
integer MSG_PLAYER_UPDATE = 3002;

// Dialog forwarding constants
integer MSG_SHOW_DIALOG = 101;
integer MSG_SHOW_ROLL_DIALOG = 301;
integer MSG_DIALOG_FORWARD_REQUEST = 9060; // New message for dialog forwarding requests

// Game state tracking (synced from Main Controller)
list players = [];
list names = [];
list lives = [];
list readyPlayers = [];
integer MAX_PLAYERS = 10;
integer FLOATER_BASE_CHANNEL = -86000;
integer roundStarted = FALSE;
integer gameStarting = FALSE;

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

// Helper functions
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        displayName = llKey2Name(id);
    }
    return displayName;
}

ownerMsg(string msg) {
    llMessageLinked(LINK_SET, MSG_OWNER_MESSAGE, msg, NULL_KEY);
}

publicMsg(string msg) {
    llMessageLinked(LINK_SET, MSG_PUBLIC_MESSAGE, msg, NULL_KEY);
}

regionMsg(key player, string msg) {
    llMessageLinked(LINK_SET, MSG_REGION_MESSAGE, (string)player + "|" + msg, NULL_KEY);
}

// Handle player registration with all the complex logic moved here
handlePlayerRegistration(string regData, key requesterId) {
    // MEMORY DEBUG: Check memory at start
    integer memStart = llGetFreeMemory();
    llOwnerSay("🧠 [RegMgr] Memory at start: " + (string)memStart + " free");
    
    list parts = llParseString2List(regData, ["|"], []);
    string newName = llList2String(parts, 0);
    key newKey = (key)llList2String(parts, 1);
    
    // Check game state restrictions
    if ((roundStarted || gameStarting) && newKey != llGetOwner()) {
        ownerMsg("ERROR|" + newName + " cannot join - game started");
        regionMsg(newKey, "Game already started - wait for current game to end");
        return;
    }
    
    // Check if already exists
    integer existingIdx = llListFindList(players, [newKey]);
    if (existingIdx != -1) {
        ownerMsg("ERROR|" + newName + " already registered");
        return;
    }
    
    // Check max players
    if (llGetListLength(players) >= MAX_PLAYERS) {
        ownerMsg("ERROR|Game full - max " + (string)MAX_PLAYERS + " players");
        regionMsg(newKey, "Game is full - maximum " + (string)MAX_PLAYERS + " players allowed");
        return;
    }
    
    // Add player to local lists
    players += [newKey];
    names += [newName];
    lives += [3];
    
    // MEMORY DEBUG: Check memory after adding to lists
    integer memAfterLists = llGetFreeMemory();
    llOwnerSay("🧠 [RegMgr] Memory after adding to lists: " + (string)memAfterLists + " free (used " + (string)(memStart - memAfterLists) + ")");
    
    // Count human players to determine if this is the starter (needed for both bot and human logic)
    integer humanCount = 0;
    integer i;
    for (i = 0; i < llGetListLength(names); i++) {
        string playerName = llList2String(names, i);
        if (llSubStringIndex(playerName, "Bot") != 0) {
            humanCount++;
        }
    }
    
    // Handle bot vs human logic
    if (llSubStringIndex(newName, "Bot") == 0) {
        readyPlayers += [newName];
        publicMsg("GAME|" + newName + " (Bot) ready to play!");
    } else {
        if (humanCount == 1) {
            publicMsg("👑 " + newName + " steps forward as the game starter! Touch to set your ready status.");
        } else {
            publicMsg("🎮 " + newName + " has joined the deadly game! Touch to set your ready status.");
        }
    }
    
    // Calculate floater channel
    integer newPlayerIdx = llGetListLength(names) - 1;
    integer ch = FLOATER_BASE_CHANNEL + newPlayerIdx;
    
    // OPTIMIZED: Handle all heavy processing here to minimize Main Controller work
    
    // Send direct scoreboard update (Main Controller doesn't need to do this)
    llMessageLinked(SCOREBOARD_LINK, MSG_PLAYER_UPDATE, newName + "|3|" + (string)newKey, NULL_KEY);
    
    // Prepare sync message (Main Controller doesn't need to build this)
    string syncMessage = "";
    if (llGetListLength(names) == 1) {
        syncMessage = "3~EMPTY~NONE~" + newName;
    } else {
        // Build lives string dynamically
        string livesStr = "";
        integer i;
        for (i = 0; i < llGetListLength(names); i++) {
            if (i > 0) livesStr += ",";
            livesStr += "3"; // Everyone starts with 3 lives
        }
        syncMessage = livesStr + "~EMPTY~NONE~" + llList2CSV(names);
    }
    
    // Send pre-built sync message
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, syncMessage, NULL_KEY);
    
    // Send minimal update to Main Controller - just the essential data it needs
    string updateData = (string)ch + "~" + newName;
    llMessageLinked(LINK_SET, MSG_UPDATE_MAIN_LISTS, updateData, newKey);
    
    // Show appropriate menu to the new player
    if (newKey == llGetOwner()) {
        integer isStarter = (humanCount <= 1);
        llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, newKey);
    }
    
    ownerMsg("JOIN|" + newName);
}

default {
    state_entry() {
        reportMemoryUsage("Player Registration Manager");
        llOwnerSay("🎯 Player Registration Manager ready - handling player join/leave operations");
    }
    
    on_rez(integer start_param) {
        reportMemoryUsage("Player Registration Manager");
        llOwnerSay("🎯 Player Registration Manager rezzed - ready for player management");
        // Reset local state
        players = [];
        names = [];
        lives = [];
        readyPlayers = [];
        roundStarted = FALSE;
        gameStarting = FALSE;
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle player registration requests from Main Controller
        if (num == MSG_REGISTER_PLAYER_REQUEST) {
            handlePlayerRegistration(str, id);
            return;
        }
        
        // Handle game state sync from Main Controller
        if (num == MSG_SYNC_GAME_STATE) {
            // PRESERVE PLAYER KEYS: Don't overwrite our authoritative player registry
            // We only sync lives and names, but keep our real player keys
            list parts = llParseString2List(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                list newNames = llCSV2List(llList2String(parts, 3));
                
                // Only update lives if list length matches (safety check)
                if (llGetListLength(newLives) == llGetListLength(players)) {
                    lives = newLives;
                }
                
                // Only update names if they match our current registry
                // This prevents sync messages from overwriting our authoritative data
                if (llGetListLength(newNames) == llGetListLength(players)) {
                    names = newNames;
                }
                
                // KEEP our player keys - they are authoritative
                llOwnerSay("🔄 [RegMgr] Synced game state, preserving " + (string)llGetListLength(players) + " player keys");
            }
            return;
        }
        
        // Handle dialog forwarding requests from Game Manager
        if (num == MSG_DIALOG_FORWARD_REQUEST) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 3) {
                string dialogType = llList2String(parts, 0); // "SHOW_DIALOG" or "SHOW_ROLL_DIALOG"
                string targetPlayerName = llList2String(parts, 1);
                
                // Reconstruct dialog payload from remaining parts
                string dialogPayload = "";
                integer i;
                for (i = 2; i < llGetListLength(parts); i++) {
                    if (i > 2) dialogPayload += "|"; // Add separator between parts
                    dialogPayload += llList2String(parts, i);
                }
                
                // Find player key in our authoritative registry
                integer playerIdx = llListFindList(names, [targetPlayerName]);
                if (playerIdx != -1 && playerIdx < llGetListLength(players)) {
                    key playerKey = llList2Key(players, playerIdx);
                    if (playerKey != NULL_KEY) {
                        if (dialogType == "SHOW_DIALOG") {
                            llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, playerKey);
                            llOwnerSay("📋 [RegMgr] Forwarded dialog to " + targetPlayerName + ": " + dialogPayload);
                        } else if (dialogType == "SHOW_ROLL_DIALOG") {
                            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, dialogPayload, playerKey);
                            llOwnerSay("🎲 [RegMgr] Forwarded roll dialog to " + targetPlayerName);
                        }
                    } else {
                        llOwnerSay("⚠️ [RegMgr] Player " + targetPlayerName + " has NULL_KEY");
                    }
                } else {
                    llOwnerSay("⚠️ [RegMgr] Player " + targetPlayerName + " not found in registry");
                }
            }
            return;
        }
        
        // Handle reset
        if (num == -99999 && str == "FULL_RESET") {
            players = [];
            names = [];
            lives = [];
            readyPlayers = [];
            roundStarted = FALSE;
            gameStarting = FALSE;
            llOwnerSay("🎯 Player Registration Manager reset complete");
            return;
        }
    }
}