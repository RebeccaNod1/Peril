// === Dialog Handler (Owner & Player) with unified Ready/Leave menu and join support ===

// Helper function to get display name with fallback to username
string getPlayerName(key id) {
    string displayName = llGetDisplayName(id);
    if (displayName == "") {
        // Fallback to legacy username if display name is unavailable
        displayName = llKey2Name(id);
    }
    return displayName;
}
// Owners and players share the same Ready/Leave dialog.
// Owners also get an "Owner" button to access advanced options.
// Owners can join the game and receive a floating display.

// =============================================================================
// DYNAMIC CHANNEL CONFIGURATION
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
integer MAIN_DIALOG_CHANNEL;
integer SCOREBOARD_DATA_CHANNEL;
integer LEADERBOARD_DATA_CHANNEL; 
integer DICE_DATA_CHANNEL;

// Channel initialization function
initializeChannels() {
    MAIN_DIALOG_CHANNEL = calculateChannel(4);    // ~-77400 range to match Main.lsl
    SCOREBOARD_DATA_CHANNEL = calculateChannel(6);  // ~-83000 range
    LEADERBOARD_DATA_CHANNEL = calculateChannel(7); // ~-84000 range
    DICE_DATA_CHANNEL = calculateChannel(8);        // ~-85000 range
    
    // Report channel to owner for debugging
    llOwnerSay("🔧 [Owner/Player Dialog] Dynamic channels initialized:");
    llOwnerSay("  Main Dialog: " + (string)MAIN_DIALOG_CHANNEL);
    llOwnerSay("  Scoreboard: " + (string)SCOREBOARD_DATA_CHANNEL);
    llOwnerSay("  Leaderboard: " + (string)LEADERBOARD_DATA_CHANNEL);
    llOwnerSay("  Dice: " + (string)DICE_DATA_CHANNEL);
}

integer DIALOG_CHANNEL; // Legacy variable, will be set dynamically

// Listen handle management
integer listenHandle = -1;
integer scoreboardHandle = -1;
integer leaderboardHandle = -1;
integer diceHandle = -1;

// Position reset state variables
key controller_key;
vector controller_pos;
rotation controller_rot;
list foundDisplays; // Store found display info: [type, key, offset, rotation, ...]
integer scanInProgress = FALSE;

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
list mainOwnerOptions = ["👥 Player Management", "🔄 Reset Options", "🛠️ Troubleshooting", "⬅️ Back to Game"];
list mainOwnerOptionsLocked = ["👥 Player Management", "🔄 Reset Options", "🛠️ Troubleshooting", "🔓 Unlock Game", "⬅️ Back to Game"];
list mainOwnerOptionsUnlocked = ["👥 Player Management", "🔄 Reset Options", "🛠️ Troubleshooting", "🔒 Lock Game", "⬅️ Back to Game"];

// Sub-menu options for each category
list playerManagementOptions = ["Add Test Player", "Kick Player", "⬅️ Back to Main"];
list resetOptions = ["Reset Game", "Reset Leaderboard", "Reset All", "⬅️ Back to Main"];
list troubleshootingOptions = ["Cleanup Floaters", "Force Floaters", "⬅️ Back to Main"];

// State tracking for dynamic ready menu with race condition protection
key pendingMenuPlayer = NULL_KEY;
integer pendingMenuIsStarter = FALSE;
integer pendingMenuIsOwner = FALSE;
integer pendingMenuRequestID = 0;      // Unique ID for each menu request
integer currentRequestID = 0;           // Counter for generating unique request IDs
float pendingMenuTimestamp = 0.0;       // Timeout for pending requests
float MENU_REQUEST_TIMEOUT = 5.0;       // 5 second timeout for menu requests

// Lockout system - when TRUE, only owner can access menus
integer isLocked = FALSE;
key gameOwner;

// Display the main categorized owner menu with lock/unlock controls
showOwnerMenu(key id) {
    // Only show full menu to owner
    if (id != gameOwner) {
        llRegionSayTo(id, 0, "⚠️ Access denied. Only the game owner can access this menu.");
        return;
    }
    
    list menuOptions;
    string menuTitle = "🔧 Owner Menu - Select Category";
    
    if (isLocked) {
        menuOptions = mainOwnerOptionsLocked;
        menuTitle += "\n🔒 GAME IS LOCKED - Only owner can access menus";
    } else {
        menuOptions = mainOwnerOptionsUnlocked;
        menuTitle += "\n🔓 GAME IS UNLOCKED - All players can access menus";
    }
    
    llDialog(id, menuTitle, menuOptions, DIALOG_CHANNEL);
}

// Display category sub-menus
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
    // Check for timeout of previous request
    if (pendingMenuPlayer != NULL_KEY && (llGetTime() - pendingMenuTimestamp) > MENU_REQUEST_TIMEOUT) {
        llOwnerSay("⏰ Previous menu request timed out, clearing pending state");
        pendingMenuPlayer = NULL_KEY;
    }
    
    // Generate unique request ID and store pending menu state
    currentRequestID++;
    if (currentRequestID > 1000000) currentRequestID = 1; // Prevent overflow
    
    pendingMenuPlayer = id;
    pendingMenuIsStarter = isStarter;
    pendingMenuIsOwner = isOwner;
    pendingMenuRequestID = currentRequestID;
    pendingMenuTimestamp = llGetTime();
    
    string playerName = getPlayerName(id);
    // Include request ID in the query to track responses
    string queryData = playerName + "|" + (string)currentRequestID;
    llMessageLinked(LINK_SET, MSG_QUERY_READY_STATE, queryData, id);
}

// Internal function to show the menu once we have ready state
showReadyLeaveMenuWithState(key id, integer isStarter, integer isOwner, integer isReady, integer isBot) {
    // Bots don't get dialogs - they're managed by the owner
    if (isBot) {
        return;
    }
    
    // Lockout system: Block dialog generation for non-owners when locked
    if (isLocked && id != gameOwner) {
        llRegionSayTo(id, 0, "🔒 Game is LOCKED. Only the owner can access any features. Contact " + getPlayerName(gameOwner) + " to unlock.");
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

// Track mapping between truncated display names and original names for kick functionality
list kickDisplayNames = [];  // What the user sees in the dialog
list kickOriginalNames = []; // The actual player names

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

// Show kick player menu - displays all registered players for selection
showKickPlayerMenu(key id, list playerNames) {
    if (llGetListLength(playerNames) == 0) {
        llRegionSayTo(id, 0, "⚠️ No players are currently registered to kick.");
        showPlayerManagementMenu(id);
        return;
    }
    
    list options = [];
    kickDisplayNames = [];  // Reset mapping
    kickOriginalNames = [];
    
    integer i;
    for (i = 0; i < llGetListLength(playerNames); i++) {
        string originalName = llList2String(playerNames, i);
        string displayName = originalName;
        
        // Truncate long names to fit within 24 character button limit ("👢 " = 3 chars)
        if (llStringLength(displayName) > 21) {
            displayName = llGetSubString(displayName, 0, 18) + "...";
        }
        
        string buttonLabel = "👢 " + displayName;
        
        // Debug: Check button length
        llOwnerSay("🔍 Debug kick button: '" + buttonLabel + "' = " + (string)llStringLength(buttonLabel) + " chars");
        
        options += [buttonLabel];
        kickDisplayNames += [buttonLabel];  // Store the full button label
        kickOriginalNames += [originalName];  // Store the original name
    }
    options += ["⬅️ Back"];
    llDialog(id, "👢 Select player to kick from game:", options, DIALOG_CHANNEL);
}

default {
    state_entry() {
        // Initialize dynamic channels
        initializeChannels();
        DIALOG_CHANNEL = MAIN_DIALOG_CHANNEL; // Set legacy variable
        
        // Initialize lockout system
        gameOwner = llGetOwner();
        isLocked = FALSE; // Default to unlocked
        
        // Initialize position reset variables
        controller_key = llGetKey();
        
        // Clean up any existing listeners
        if (listenHandle != -1) llListenRemove(listenHandle);
        if (scoreboardHandle != -1) llListenRemove(scoreboardHandle);
        if (leaderboardHandle != -1) llListenRemove(leaderboardHandle);
        if (diceHandle != -1) llListenRemove(diceHandle);
        
        // Set up managed listeners with dynamic channels
        listenHandle = llListen(DIALOG_CHANNEL, "", NULL_KEY, "");
        scoreboardHandle = llListen(SCOREBOARD_DATA_CHANNEL, "", "", "");
        leaderboardHandle = llListen(LEADERBOARD_DATA_CHANNEL, "", "", "");
        diceHandle = llListen(DICE_DATA_CHANNEL, "", "", "");
        
        llOwnerSay("🎭 Owner and Player Dialog Handler ready with lockout system!");
        llOwnerSay("🔓 Game is UNLOCKED - All players can access menus");
    }

    link_message(integer sender, integer num, string str, key id) {
        // Handle full reset from main controller
        if (num == -99999 && str == "FULL_RESET") {
            // Reset dialog state including race condition protection
            pendingMenuPlayer = NULL_KEY;
            pendingMenuIsStarter = FALSE;
            pendingMenuIsOwner = FALSE;
            pendingMenuRequestID = 0;
            currentRequestID = 0;
            pendingMenuTimestamp = 0.0;
            currentPickList = [];
            currentPickTarget = "";
            currentPickLimit = 3;
            llOwnerSay("🎭 Owner and Player Dialog Handler reset!");
            return;
        }
        
        if (num == MSG_SHOW_MENU) {
            list args = llParseString2List(str, ["|"], []);
            if (llGetListLength(args) < 2) {
                llOwnerSay("⚠️ Invalid message format: " + str);
                return;
            }
            string targetType = llList2String(args, 0);
            integer isStarter = (integer)llList2String(args, 1);
            if (targetType == "owner") {
                // Both starter and non-starter owners get ready/leave menu with Owner button
                showReadyLeaveMenu(id, isStarter, TRUE);
            } else if (targetType == "player") {
                showReadyLeaveMenu(id, isStarter, FALSE);
            } else if (targetType == "admin") {
                // Show admin category menu directly
                showOwnerMenu(id);
            }
        }
        else if (num == MSG_READY_STATE_RESULT) {
            // Parse ready state response and show appropriate menu
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 4) {
                string playerName = llList2String(parts, 0);
                integer isReady = (integer)llList2String(parts, 1);
                integer isBot = (integer)llList2String(parts, 2);
                integer responseRequestID = (integer)llList2String(parts, 3);
                
                // Validate that this response matches our pending request
                if (pendingMenuPlayer == id && responseRequestID == pendingMenuRequestID) {
                    // Check for timeout
                    if ((llGetTime() - pendingMenuTimestamp) > MENU_REQUEST_TIMEOUT) {
                        llOwnerSay("⏰ Menu request timed out, ignoring response");
                        pendingMenuPlayer = NULL_KEY;
                        return;
                    }
                    
                    showReadyLeaveMenuWithState(pendingMenuPlayer, pendingMenuIsStarter, pendingMenuIsOwner, isReady, isBot);
                    // Reset pending state
                    pendingMenuPlayer = NULL_KEY;
                    pendingMenuRequestID = 0;
                }
            } else {
                llOwnerSay("⚠️ Invalid ready state result format - expected 4 parts, got " + (string)llGetListLength(parts));
            }
            return;
        }
        else if (num == MSG_PLAYER_LIST_RESULT) {
            list playerNames = llParseString2List(str, [","], []);
            llOwnerSay("📋 Fetching list of players for pick management...");
            showPickManageMenu(id, playerNames);
        }
        // Handle player list result for kick functionality
        else if (num == 8009) {
            llOwnerSay("🔍 [Dialog Handler] Received kick player list string: '" + str + "'");
            list rawNames = llParseString2List(str, [","], []);
            llOwnerSay("🔍 [Dialog Handler] Raw parsed into " + (string)llGetListLength(rawNames) + " names: " + llList2CSV(rawNames));
            
            // Filter out any command strings that might have gotten mixed in
            list playerNames = [];
            integer i;
            for (i = 0; i < llGetListLength(rawNames); i++) {
                string name = llStringTrim(llList2String(rawNames, i), STRING_TRIM);
                // Skip empty names and command strings
                if (name != "" && 
                    llSubStringIndex(name, "REQUEST_") != 0 &&
                    llSubStringIndex(name, "COMMAND_") != 0 &&
                    llSubStringIndex(name, "MSG_") != 0) {
                    playerNames += [name];
                } else {
                    llOwnerSay("⚠️ [Dialog Handler] Filtered out invalid name: '" + name + "'");
                }
            }
            
            llOwnerSay("🔍 [Dialog Handler] Filtered to " + (string)llGetListLength(playerNames) + " valid names: " + llList2CSV(playerNames));
            showKickPlayerMenu(id, playerNames);
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
        // Lockout system: Check if game is locked and user is not owner
        if (isLocked && id != gameOwner) {
            // Block ALL access for non-owners when locked
            llRegionSayTo(id, 0, "🔒 Game is LOCKED. Only the owner can access any features. Contact " + getPlayerName(gameOwner) + " to unlock.");
            return;
        }
        
        // Handle "Owner" button to show owner options
        if (msg == "Owner") {
            showOwnerMenu(id);
        }
        // Handle lock/unlock controls
        else if (msg == "🔒 Lock Game") {
            if (id == gameOwner) {
                isLocked = TRUE;
                // Notify Main Controller to update floating text
                llMessageLinked(LINK_SET, 9001, "LOCK_GAME", id);
                llOwnerSay("🔒 Game has been LOCKED - Only owner can access any features");
                llSay(0, "🔒 Game has been locked by the owner. Only the owner can access any features.");
                showOwnerMenu(id); // Refresh the owner menu
            } else {
                llRegionSayTo(id, 0, "⚠️ Only the game owner can lock the game.");
            }
        }
        else if (msg == "🔓 Unlock Game") {
            if (id == gameOwner) {
                isLocked = FALSE;
                // Notify Main Controller to update floating text
                llMessageLinked(LINK_SET, 9002, "UNLOCK_GAME", id);
                llOwnerSay("🔓 Game has been UNLOCKED - All players can access menus");
                llSay(0, "🔓 Game has been unlocked by the owner. All features are now available.");
                showOwnerMenu(id); // Refresh the owner menu
            } else {
                llRegionSayTo(id, 0, "⚠️ Only the game owner can unlock the game.");
            }
        }
        // Handle category menu navigation
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
            string pname = getPlayerName(id);
            llMessageLinked(LINK_SET, MSG_REGISTER_PLAYER, pname + "|" + (string)id, NULL_KEY);
            // Floater Manager will automatically rez the floater during registration
        }
        else if (msg == "Leave Game") {
            // Send leave game message to Controller_MessageHandler (not sync channel 107!)
            string pname = getPlayerName(id);
            llMessageLinked(LINK_SET, 8007, "LEAVE_GAME|" + pname + "|" + (string)id, NULL_KEY);
        }
        else if (msg == "Ready" || msg == "Not Ready") {
            // Toggle ready state (both buttons do the same thing - toggle)
            string pname = getPlayerName(id);
            llMessageLinked(LINK_SET, MSG_TOGGLE_READY, pname, NULL_KEY);
        }
        else if (msg == "Kick Player") {
            // Show kick player menu - request player list first
            llMessageLinked(LINK_SET, 8009, "REQUEST_PLAYER_LIST_KICK", id);
        }
        else if (msg == "Cleanup Floaters") {
            // Universal floater cleanup that works even after script resets
            llOwnerSay("🧩 Force cleaning ALL possible floater channels...");
            llMessageLinked(LINK_SET, MSG_CLEANUP_ALL_FLOATERS, "", NULL_KEY);
        }
        else if (msg == "Force Floaters") {
            // Force creation of floaters for all registered players - send as dialog response to Main Controller
            llOwnerSay("🔧 Requesting floater creation for all registered players...");
            // This will be handled by Main Controller's dialog listener
            // No need to forward via link_message - the Main Controller is already listening on DIALOG_CHANNEL
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
        // Handle kick player selection
        else if (llSubStringIndex(msg, "👢 ") == 0) {
            // Find the original name using the display name mapping
            integer idx = llListFindList(kickDisplayNames, [msg]);
            if (idx != -1) {
                string playerToKick = llList2String(kickOriginalNames, idx);
                llRegionSayTo(id, 0, "👢 Kicking player: " + playerToKick + " from the game...");
                // Send kick message to Controller_MessageHandler (not sync channel 107!)
                llMessageLinked(LINK_SET, 8007, "KICK_PLAYER|" + playerToKick + "|" + (string)id, NULL_KEY);
            } else {
                llOwnerSay("⚠️ Could not find original name for kick selection: " + msg);
            }
            // Return to player management menu
            showPlayerManagementMenu(id);
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
        // Handle position scan responses from follower displays
        else if ((channel == SCOREBOARD_DATA_CHANNEL || channel == LEADERBOARD_DATA_CHANNEL || channel == DICE_DATA_CHANNEL) && 
                 llSubStringIndex(msg, "POSITION_RESPONSE|") == 0) {
            
            if (!scanInProgress) return; // Ignore if not scanning
            
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 4) {
                string object_type = llList2String(parts, 1);
                vector object_pos = (vector)llList2String(parts, 2);
                rotation object_rot = (rotation)llList2String(parts, 3);
                
                // Calculate offset and relative rotation
                vector offset = (object_pos - controller_pos) / controller_rot;
                rotation rel_rot = object_rot / controller_rot;
                
                // Store display info: [type, offset, rotation, ...]
                foundDisplays += [object_type, offset, rel_rot];
                
                llOwnerSay("✅ Found " + object_type + " display at position " + (string)object_pos);
                llOwnerSay("   Config: " + object_type + "_offset=" + (string)offset);
                llOwnerSay("   Rotation: " + object_type + "_rotation=" + (string)rel_rot);
            }
        }
        // Note: Automatic auto-config requests are now handled by Controller_Discovery.lsl
        // This script only handles manual position reset dialogs
    }
    
    timer() {
        llSetTimerEvent(0.0);
        scanInProgress = FALSE;
        
        integer numDisplays = llGetListLength(foundDisplays) / 3; // 3 items per display (type, offset, rotation)
        
        if (numDisplays == 0) {
            llOwnerSay("\n⚠️ No follower displays found within 20 meters.");
            llOwnerSay("📝 Make sure your displays have the follower script and are close enough.");
            llOwnerSay("🔄 Check that they use the same dynamic channel system as this controller.");
        } else {
            llOwnerSay("\n🎉 Position scan complete! Found " + (string)numDisplays + " display(s).");
            llOwnerSay("\n📄 CONFIG UPDATE METHODS:");
            llOwnerSay("1️⃣ MANUAL: Copy the config lines above to each display's 'config' notecard");
            llOwnerSay("2️⃣ AUTOMATIC: The displays should move to their new positions automatically!");
            llOwnerSay("\n📆 The new positions are now saved and will be remembered when objects are rezzed.");
            
            // Send position update commands to displays (future enhancement)
            llOwnerSay("🔄 Broadcasting position updates to all found displays...");
            
            // Broadcast updates to each found display
            integer i;
            for (i = 0; i < llGetListLength(foundDisplays); i += 3) {
                string displayType = llList2String(foundDisplays, i);
                vector displayOffset = (vector)llList2String(foundDisplays, i + 1);
                rotation displayRotation = (rotation)llList2String(foundDisplays, i + 2);
                
                // Send update to appropriate channel
                integer updateChannel;
                if (displayType == "scoreboard") updateChannel = SCOREBOARD_DATA_CHANNEL;
                else if (displayType == "leaderboard") updateChannel = LEADERBOARD_DATA_CHANNEL;
                else if (displayType == "dice") updateChannel = DICE_DATA_CHANNEL;
                else {
                    // Skip unknown display types
                    llOwnerSay("⚠️ Unknown display type: " + displayType);
                }
                
                // Only send update if we found a valid channel
                if (displayType == "scoreboard" || displayType == "leaderboard" || displayType == "dice") {
                    string updateMsg = "POSITION_UPDATE|" + displayType + "|" + (string)displayOffset + "|" + (string)displayRotation;
                    llRegionSay(updateChannel, updateMsg);
                    llOwnerSay("✅ Sent position update to " + displayType + " display");
                }
            }
            
            llOwnerSay("\n✨ Position reset complete! Your displays should now be in the correct positions.");
        }
    }
}
