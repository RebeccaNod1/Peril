// Leaderboard Manager - Shows top 10 players ranked by total wins
// Displays as text on a prim face with persistent win tracking

// Communication
integer LEADERBOARD_CHANNEL = -12346;
integer MAIN_CHANNEL = -12340;

// Data storage
list playerNames = [];
list playerWins = [];

// Display settings
integer DISPLAY_FACE = 0; // Which face to show leaderboard text on
vector TEXT_COLOR = <1.0, 1.0, 0.0>; // Yellow text
float TEXT_ALPHA = 1.0;

default {
    state_entry() {
        // Listen for game results and commands
        llListen(LEADERBOARD_CHANNEL, "", "", "");
        llListen(MAIN_CHANNEL, "", "", "");
        
        // Load persistent data
        loadLeaderboardData();
        
        // Display current leaderboard
        updateLeaderboardDisplay();
        
        llOwnerSay("Leaderboard Manager ready - Win tracking active");
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == LEADERBOARD_CHANNEL) {
            if (llSubStringIndex(message, "GAME_WON|") == 0) {
                handleGameWon(message);
            }
            else if (message == "RESET_LEADERBOARD") {
                resetLeaderboard();
            }
            else if (message == "SHOW_LEADERBOARD") {
                updateLeaderboardDisplay();
            }
        }
        else if (channel == MAIN_CHANNEL) {
            // Listen for game end messages from main controller
            if (llSubStringIndex(message, "GAME_ENDED|") == 0) {
                handleGameEnded(message);
            }
        }
    }
    
    touch_start(integer total_number) {
        // Allow touching to refresh leaderboard display
        updateLeaderboardDisplay();
        llOwnerSay("Leaderboard refreshed");
    }
}

handleGameWon(string message) {
    // Format: "GAME_WON|PlayerName"
    list parts = llParseString2List(message, ["|"], []);
    if (llGetListLength(parts) < 2) return;
    
    string winnerName = llList2String(parts, 1);
    addWinToPlayer(winnerName);
    
    llOwnerSay("Win recorded for: " + winnerName);
}

handleGameEnded(string message) {
    // Format: "GAME_ENDED|WinnerName|PlayerList"
    list parts = llParseString2List(message, ["|"], []);
    if (llGetListLength(parts) >= 2) {
        string winnerName = llList2String(parts, 1);
        if (winnerName != "NONE" && winnerName != "") {
            addWinToPlayer(winnerName);
            llOwnerSay("Game ended - Win recorded for: " + winnerName);
        }
    }
}

addWinToPlayer(string playerName) {
    // Check if player already exists in leaderboard
    integer playerIndex = llListFindList(playerNames, [playerName]);
    
    if (playerIndex == -1) {
        // New player - add to lists
        playerNames += [playerName];
        playerWins += [1];
    } else {
        // Existing player - increment wins
        integer currentWins = llList2Integer(playerWins, playerIndex);
        playerWins = llListReplaceList(playerWins, [currentWins + 1], playerIndex, playerIndex);
    }
    
    // Save data and update display
    saveLeaderboardData();
    updateLeaderboardDisplay();
}

updateLeaderboardDisplay() {
    // Create sorted list of top 10 players
    list sortedData = getSortedLeaderboard();
    
    // Build display text
    string displayText = "═══ LEADERBOARD ═══\n";
    
    integer i;
    integer maxDisplay = llGetListLength(sortedData);
    if (maxDisplay > 10) maxDisplay = 10; // Show only top 10
    
    if (maxDisplay == 0) {
        displayText += "No games played yet\n";
    } else {
        for (i = 0; i < maxDisplay; i++) {
            list playerData = llParseString2List(llList2String(sortedData, i), [":"], []);
            string name = llList2String(playerData, 0);
            string wins = llList2String(playerData, 1);
            
            displayText += (string)(i + 1) + ". " + name + " - " + wins + " wins\n";
        }
    }
    
    displayText += "═══════════════════";
    
    // Set text on prim face
    llSetText("", <0,0,0>, 0.0); // Clear floating text
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_TEXT, displayText, TEXT_COLOR, TEXT_ALPHA
    ]);
    
    // Also set as texture text if supported
    // Note: This would require creating text textures dynamically
    // For now, we use floating text above the prim
}

list getSortedLeaderboard() {
    // Create combined list of "PlayerName:Wins" for sorting
    list combined = [];
    integer i;
    
    for (i = 0; i < llGetListLength(playerNames); i++) {
        string playerName = llList2String(playerNames, i);
        integer wins = llList2Integer(playerWins, i);
        combined += [playerName + ":" + (string)wins];
    }
    
    // Sort by wins (descending) - bubble sort
    integer n = llGetListLength(combined);
    integer swapped = TRUE;
    
    while (swapped) {
        swapped = FALSE;
        for (i = 0; i < n - 1; i++) {
            list data1 = llParseString2List(llList2String(combined, i), [":"], []);
            list data2 = llParseString2List(llList2String(combined, i + 1), [":"], []);
            
            integer wins1 = (integer)llList2String(data1, 1);
            integer wins2 = (integer)llList2String(data2, 1);
            
            if (wins1 < wins2) {
                // Swap positions
                string temp = llList2String(combined, i);
                combined = llListReplaceList(combined, [llList2String(combined, i + 1)], i, i);
                combined = llListReplaceList(combined, [temp], i + 1, i + 1);
                swapped = TRUE;
            }
        }
        n--;
    }
    
    return combined;
}

saveLeaderboardData() {
    // Save to linkset data for persistence
    integer i;
    
    // Save player count
    llLinksetDataWrite("lb_count", (string)llGetListLength(playerNames));
    
    // Save each player's data
    for (i = 0; i < llGetListLength(playerNames); i++) {
        string playerName = llList2String(playerNames, i);
        integer wins = llList2Integer(playerWins, i);
        
        llLinksetDataWrite("lb_player_" + (string)i, playerName);
        llLinksetDataWrite("lb_wins_" + (string)i, (string)wins);
    }
}

loadLeaderboardData() {
    // Load from linkset data
    string countStr = llLinksetDataRead("lb_count");
    if (countStr == "") return; // No saved data
    
    integer count = (integer)countStr;
    playerNames = [];
    playerWins = [];
    
    integer i;
    for (i = 0; i < count; i++) {
        string playerName = llLinksetDataRead("lb_player_" + (string)i);
        string winsStr = llLinksetDataRead("lb_wins_" + (string)i);
        
        if (playerName != "" && winsStr != "") {
            playerNames += [playerName];
            playerWins += [(integer)winsStr];
        }
    }
    
    llOwnerSay("Loaded leaderboard data: " + (string)llGetListLength(playerNames) + " players");
}

resetLeaderboard() {
    // Clear all data
    playerNames = [];
    playerWins = [];
    
    // Clear persistent storage
    integer i;
    for (i = 0; i < 100; i++) { // Clear up to 100 possible entries
        llLinksetDataDelete("lb_player_" + (string)i);
        llLinksetDataDelete("lb_wins_" + (string)i);
    }
    llLinksetDataDelete("lb_count");
    
    // Update display
    updateLeaderboardDisplay();
    
    llOwnerSay("Leaderboard reset - all win data cleared");
}

// Public function to get current standings (for other scripts)
string getLeaderboardString() {
    list sortedData = getSortedLeaderboard();
    string result = "";
    
    integer i;
    integer maxDisplay = llGetListLength(sortedData);
    if (maxDisplay > 10) maxDisplay = 10;
    
    for (i = 0; i < maxDisplay; i++) {
        list playerData = llParseString2List(llList2String(sortedData, i), [":"], []);
        string name = llList2String(playerData, 0);
        string wins = llList2String(playerData, 1);
        
        if (i > 0) result += ", ";
        result += name + "(" + wins + ")";
    }
    
    return result;
}
