#include "Peril_Constants.lsl"

// === Player Registration Manager ===
// Handles all player registration, join/leave operations to reduce Main Controller memory usage
// This script takes over the memory-heavy player management operations

// Game state tracking (synced from Main Controller)
list players = [];
list names = [];
list lives = [];
list readyPlayers = [];
#define MAX_PLAYERS 10

// Dynamic channel system
#define CHANNEL_BASE -77000
integer FLOATER_BASE_CHANNEL;
integer roundStarted = FALSE;
integer gameStarting = FALSE;

integer resetInProgress = FALSE; // Lockout for reset syncs

integer calculateChannel(integer offset) {
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetLinkKey(1);
    string combinedStr = ownerStr + objectStr;
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2;
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

initializeChannels() {
    FLOATER_BASE_CHANNEL = calculateChannel(9);
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
    dbg("🔍 [RegMgr] Memory at start: " + (string)memStart + " free");
    
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
    dbg("🔍 [RegMgr] Memory after adding to lists: " + (string)memAfterLists + " free (used " + (string)(memStart - memAfterLists) + ")");
    
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
    llMessageLinked(LINK_SCOREBOARD, MSG_PLAYER_UPDATE, newName + "|3|" + (string)newKey, NULL_KEY);
    
    // Prepare sync message (Main Controller doesn't need to build this)
    string syncMessage = "";
    if (llGetListLength(names) == 1) {
        syncMessage = "3~EMPTY~NONE~" + newName;
    } else {
        // Build lives string dynamically
        string livesStr = "";
        integer j;
        for (j = 0; j < llGetListLength(names); j++) {
            if (j > 0) livesStr += ",";
            livesStr += "3"; // Everyone starts with 3 lives
        }
        syncMessage = livesStr + "~EMPTY~NONE~" + llList2CSV(names);
    }
    
    // CRITICAL FIX: Send floater rez message to Floater Manager first
    llMessageLinked(LINK_SET, MSG_REZ_FLOATER, newName + "|" + (string)newKey, newKey);
    
    // Then send the sync message to update everyone on the new state
    llMessageLinked(LINK_SET, MSG_SYNC_GAME_STATE, syncMessage, NULL_KEY);
    
    // Send minimal update to Main Controller - just the essential data it needs
    string updateData = (string)ch + "~" + newName;
    llMessageLinked(LINK_SET, MSG_UPDATE_MAIN_LISTS, updateData, newKey);
    
    // Show appropriate menu to the new player
    if (newKey == llGetOwner()) {
        integer isStarter = (humanCount <= 1);
        llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|" + (string)isStarter, newKey);
    } else {
        // NEW: Also show menu for non-owners immediately after registration
        integer isStarter = (humanCount <= 1);
        llMessageLinked(LINK_SET, MSG_SHOW_MENU, "player|" + (string)isStarter, newKey);
    }
    
    ownerMsg("JOIN|" + newName);
}

default {
    state_entry() {
        DISCOVER_CORE_LINKS();
        initializeChannels();
        REPORT_MEMORY();
        dbg("🎯 [RegMgr] Player Registration Manager ready - discovery complete! Scoreboard: " + (string)LINK_SCOREBOARD);
    }
    
    on_rez(integer start_param) {
        DISCOVER_CORE_LINKS();
        initializeChannels();
        REPORT_MEMORY();
        dbg("🎯 [RegMgr] Player Registration Manager rezzed - resetting state...");
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
            if (resetInProgress) return; // IGNORE stale syncs during reset lockout
            
            // PRESERVE PLAYER KEYS: Don't overwrite our authoritative player registry
            list parts = llParseStringKeepNulls(str, ["~"], []);
            if (llGetListLength(parts) >= 4) {
                list newLives = llCSV2List(llList2String(parts, 0));
                string picksPart = llList2String(parts, 1);
                list newNames = llCSV2List(llList2String(parts, 3));
                
                if (llGetListLength(newLives) == llGetListLength(players)) {
                    lives = newLives;
                }
                if (llGetListLength(newNames) == llGetListLength(players)) {
                    names = newNames;
                }
                
                dbg("🔄 [RegMgr] Synced game state, preserving " + (string)llGetListLength(players) + " player keys");
            }
            return;
        }

        // --- Status Queries ---
        if (num == MSG_QUERY_READY_STATE) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string name = llList2String(parts, 0);
                string requestId = llList2String(parts, 1);
                
                integer isReady = (llListFindList(readyPlayers, [name]) != -1);
                integer isBot = (llSubStringIndex(name, "Bot") == 0);
                
                llMessageLinked(LINK_SET, MSG_READY_STATE_RESULT, 
                               name + "|" + (string)isReady + "|" + (string)isBot + "|" + requestId, id);
            }
            return;
        }
        
        if (num == MSG_QUERY_OWNER_STATUS) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string name = llList2String(parts, 0);
                string requestId = llList2String(parts, 1);
                
                integer isRegistered = (llListFindList(players, [id]) != -1);
                integer isPending = FALSE; 
                
                integer isStarter = FALSE;
                if (isRegistered) {
                    integer starterIdx = -1;
                    integer i;
                    for (i = 0; i < llGetListLength(names) && starterIdx == -1; i++) {
                        if (llSubStringIndex(llList2String(names, i), "Bot") != 0) starterIdx = i;
                    }
                    if (starterIdx != -1 && llList2Key(players, starterIdx) == id) isStarter = TRUE;
                }
                
                dbg("📤 [RegMgr] Responding to OWNER STATUS (" + requestId + ") - Registered: " + (string)isRegistered);
                llMessageLinked(LINK_SET, MSG_OWNER_STATUS_RESULT, 
                               name + "|" + (string)isRegistered + "|" + (string)isPending + "|" + (string)isStarter + "|" + requestId, id);
            }
            return;
        }
        
        if (num == MSG_TOGGLE_READY) {
            string name = str;
            integer idx = llListFindList(readyPlayers, [name]);
            if (idx == -1) {
                readyPlayers += [name];
                publicMsg("GAME|" + name + " is NOW READY!");
            } else {
                readyPlayers = llDeleteSubList(readyPlayers, idx, idx);
                publicMsg("GAME|" + name + " is NO LONGER READY.");
            }
            // Broadcast the official state list to all scripts (Main Controller needs this)
            llMessageLinked(LINK_SET, MSG_UPDATE_MAIN_LISTS, "READY_LIST|" + llList2CSV(readyPlayers), NULL_KEY);
            return;
        }

        if (num == MSG_REMOVE_PLAYER) {
            string leavingName = str;
            integer idx = llListFindList(names, [leavingName]);
            if (idx != -1) {
                // Scrub from all synchronized lists
                players = llDeleteSubList(players, idx, idx);
                names = llDeleteSubList(names, idx, idx);
                lives = llDeleteSubList(lives, idx, idx);
                
                // ALSO scrub from ready list if they were there
                integer rIdx = llListFindList(readyPlayers, [leavingName]);
                if (rIdx != -1) readyPlayers = llDeleteSubList(readyPlayers, rIdx, rIdx);
                
                dbg("🎯 [RegMgr] Deep Scrub Complete: " + leavingName + " removed from all registries.");
                
                // Broadcast updated lists to keep Main Controller in sync
                llMessageLinked(LINK_SET, MSG_UPDATE_MAIN_LISTS, "READY_LIST|" + llList2CSV(readyPlayers), NULL_KEY);
            }
            return;
        }

        // Handle dialog forwarding requests from Game Manager
        if (num == MSG_DIALOG_FORWARD_REQUEST) {
            list parts = llParseString2List(str, ["~"], []); // Fixed delimiter to match forwarder
            if (llGetListLength(parts) >= 3) {
                string dialogType = llList2String(parts, 0); 
                string targetPlayerName = llList2String(parts, 1);
                
                string dialogPayload = "";
                integer i;
                for (i = 2; i < llGetListLength(parts); i++) {
                    if (i > 2) dialogPayload += "|"; 
                    dialogPayload += llList2String(parts, i);
                }
                
                integer playerIdx = llListFindList(names, [targetPlayerName]);
                if (playerIdx != -1 && playerIdx < llGetListLength(players)) {
                    key playerKey = llList2Key(players, playerIdx);
                    if (playerKey != NULL_KEY) {
                        if (dialogType == "SHOW_DIALOG") {
                            llMessageLinked(LINK_SET, MSG_SHOW_DIALOG, dialogPayload, playerKey);
                        } else if (dialogType == "SHOW_ROLL_DIALOG") {
                            llMessageLinked(LINK_SET, MSG_SHOW_ROLL_DIALOG, dialogPayload, playerKey);
                        }
                    }
                }
            }
            return;
        }
        
        if (num == MSG_RESET_ALL && str == "FULL_RESET") {
            resetInProgress = TRUE;
            players = []; names = []; lives = []; readyPlayers = [];
            roundStarted = FALSE; gameStarting = FALSE;
            
            // Activate brief lockout timer to ignore stale syncs while Linkset settles
            llSetTimerEvent(0.2); 
            
            dbg("🎯 [RegMgr] Player Registration Manager reset complete (Lockout Active)");
            return;
        }
    }

    timer() {
        resetInProgress = FALSE;
        llSetTimerEvent(0);
        dbg("🎯 [RegMgr] Reset lockout complete - sync active.");
    }
}