// === Dialog Handler (Owner & Player) with unified Ready/Leave menu and join support ===
// Owners and players share the same Ready/Leave dialog.
// Owners also get an "Owner" button to access advanced options.
// Owners can join the game and receive a floating display.

integer DIALOG_CHANNEL = -88888;
integer MSG_SHOW_MENU = 201;
integer MSG_PICK_ACTION = 204;
integer MSG_PLAYER_LIST_RESULT = 203;
integer MSG_PICK_LIST_RESULT = 205;
integer MSG_LIFE_LOOKUP = 207;
integer MSG_REGISTER_PLAYER = 106;
integer MSG_REZ_FLOAT = 105;
integer MSG_TOGGLE_READY = 202;
integer MSG_QUERY_READY_STATE = 210;
integer MSG_READY_STATE_RESULT = 211;
integer MSG_CLEANUP_ALL_FLOATERS = 212;
integer MSG_GET_CURRENT_DIALOG = 302;

// Categorized owner menu system
list mainOwnerOptions = ["🎮 Game Participation", "👥 Player Management", "🔄 Reset Options", "🛠️ Troubleshooting", "⬅️ Back to Game"];

// Sub-menu options for each category
list gameParticipationOptions = ["Join Game", "Leave Game", "⬅️ Back to Main"];
list playerManagementOptions = ["Add Test Player", "⬅️ Back to Main"];
list resetOptions = ["Reset Game", "Reset Leaderboard", "Reset All", "⬅️ Back to Main"];
list troubleshootingOptions = ["Cleanup Floaters", "⬅️ Back to Main"];

// State tracking for dynamic ready menu
key pendingMenuPlayer = NULL_KEY;
integer pendingMenuIsStarter = FALSE;
integer pendingMenuIsOwner = FALSE;

// Display the main categorized owner menu
showOwnerMenu(key id) {
    llDialog(id, "🔧 Owner Menu - Select Category", mainOwnerOptions, DIALOG_CHANNEL);
}

// Display category sub-menus
showGameParticipationMenu(key id) {
    llDialog(id, "🎮 Game Participation", gameParticipationOptions, DIALOG_CHANNEL);
}

showPlayerManagementMenu(key id) {
    llDialog(id, "👥 Player Management", playerManagementOptions, DIALOG_CHANNEL);
}

showResetOptionsMenu(key id) {
    llDialog(id, "🔄 Reset Options", resetOptions, DIALOG_CHANNEL);
}

showTroubleshootingMenu(key id) {
    llDialog(id, "🛠️ Troubleshooting", troubleshootingOptions, DIALOG_CHANNEL);
}

// Display the combined Ready/Leave menu for both players and owners
// If the caller is the starter, the first button is "Start"; otherwise shows dynamic ready state.
// Owners receive an extra "Owner" button to access the advanced owner menu.
showReadyLeaveMenu(key id, integer isStarter, integer isOwner) {
    // Store pending menu state and query ready status
    pendingMenuPlayer = id;
    pendingMenuIsStarter = isStarter;
    pendingMenuIsOwner = isOwner;
    
    string playerName = llKey2Name(id);
    llMessageLinked(LINK_SET, MSG_QUERY_READY_STATE, playerName, id);
}

// Internal function to show the menu once we have ready state
showReadyLeaveMenuWithState(key id, integer isStarter, integer isOwner, integer isReady, integer isBot) {
    // Bots don't get dialogs - they're managed by the owner
    if (isBot) {
        return;
    }
    
    list options;
    string menuText = "Select an option:";
    
    if (isStarter) {
        options = ["Start Game", "Leave Game"];
        menuText = "You are the game starter. You can start the game when all other players are ready.";
    } else {
        // Dynamic ready button based on current state
        if (isReady) {
            options = ["Not Ready", "Leave Game"];
            menuText = "You are READY to play. Click 'Not Ready' to change your status.";
        } else {
            options = ["Ready", "Leave Game"];
            menuText = "You are NOT READY to play. Click 'Ready' when you want to participate.";
        }
    }
    
    if (isOwner) {
        options += ["Owner"];
    }
    
    // Display the menu with contextual information
    llDialog(id, menuText, options, DIALOG_CHANNEL);
}

// Manage picks UI helpers remain unchanged
list currentPickList;
string currentPickTarget;
integer currentPickLimit = 3;

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
        llOwnerSay("🎭 Owner and Player Dialog Handler ready!");
        llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string str, key id) {
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Reset dialog state
            pendingMenuPlayer = NULL_KEY;
            pendingMenuIsStarter = FALSE;
            pendingMenuIsOwner = FALSE;
            currentPickList = [];
            currentPickTarget = "";
            currentPickLimit = 3;
            llOwnerSay("🎭 Owner and Player Dialog Handler reset!");
            return;
        }
        
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
                // Both starter and non-starter owners get ready/leave menu with Owner button
                llOwnerSay("DEBUG: Owner menu request - isStarter=" + (string)isStarter + ", calling showReadyLeaveMenu");
                showReadyLeaveMenu(id, isStarter, TRUE);
            } else if (targetType == "player") {
                llOwnerSay("DEBUG: Player menu request - isStarter=" + (string)isStarter + ", calling showReadyLeaveMenu");
                showReadyLeaveMenu(id, isStarter, FALSE);
            }
        }
        else if (num == MSG_READY_STATE_RESULT) {
            // Parse ready state response and show appropriate menu
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 0);
                integer isReady = (integer)llList2String(parts, 1);
                integer isBot = (integer)llList2String(parts, 2);
                
                llOwnerSay("DEBUG: Ready state result for " + playerName + ": ready=" + (string)isReady + ", bot=" + (string)isBot);
                llOwnerSay("DEBUG: Pending menu - starter=" + (string)pendingMenuIsStarter + ", owner=" + (string)pendingMenuIsOwner);
                
                // Show menu with the current ready state
                if (pendingMenuPlayer == id) {
                    llOwnerSay("DEBUG: Calling showReadyLeaveMenuWithState");
                    showReadyLeaveMenuWithState(pendingMenuPlayer, pendingMenuIsStarter, pendingMenuIsOwner, isReady, isBot);
                    // Reset pending state
                    pendingMenuPlayer = NULL_KEY;
                } else {
                    llOwnerSay("DEBUG: Pending menu player mismatch: expected " + (string)pendingMenuPlayer + ", got " + (string)id);
                }
            }
            return;
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
        // Handle "Owner" button to show owner options
        if (msg == "Owner") {
            showOwnerMenu(id);
        }
        // Handle category menu navigation
        else if (msg == "🎮 Game Participation") {
            showGameParticipationMenu(id);
        }
        else if (msg == "👥 Player Management") {
            showPlayerManagementMenu(id);
        }
        else if (msg == "🔄 Reset Options") {
            showResetOptionsMenu(id);
        }
        else if (msg == "🛠️ Troubleshooting") {
            showTroubleshootingMenu(id);
        }
        else if (msg == "⬅️ Back to Main") {
            showOwnerMenu(id);
        }
        else if (msg == "⬅️ Back to Game") {
            // Return to the owner's ready/leave menu
            // Need to determine if owner is starter
            llMessageLinked(LINK_SET, MSG_SHOW_MENU, "owner|1", id); // Assume starter for now, will be corrected by main controller
        }
        // Owner joins the game: register and rez a float for them
        else if (msg == "Join Game") {
            // Use the avatar's key as the identifier
            string pname = llKey2Name(id);
            llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, pname + "|" + (string)id, NULL_KEY);
            // Floater Manager will automatically rez the floater during registration
        }
        else if (msg == "Leave Game") {
            // Send leave game message to main controller
            string pname = llKey2Name(id);
            llMessageLinked(LINK_SET, 107, "LEAVE_GAME|" + pname + "|" + (string)id, NULL_KEY);
        }
        else if (msg == "Ready" || msg == "Not Ready") {
            // Toggle ready state (both buttons do the same thing - toggle)
            string pname = llKey2Name(id);
            llMessageLinked(LINK_SET, MSG_TOGGLE_READY, pname, NULL_KEY);
        }
        else if (msg == "Cleanup Floaters") {
            // Send aggressive floater cleanup command
            llOwnerSay("🧹 Sending aggressive floater cleanup command...");
            llMessageLinked(LINK_SET, MSG_CLEANUP_ALL_FLOATERS, "", NULL_KEY);
        }
        else if (msg == "Manage Picks") {
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
        // Forward numeric picks to the game logic
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