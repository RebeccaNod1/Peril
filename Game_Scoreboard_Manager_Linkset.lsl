// Game Scoreboard Manager - Linkset Version
// Shows current game players in grid layout
// Each player gets a prim showing profile picture + heart texture (lives)

// =============================================================================
// LINKSET COMMUNICATION - NO DISCOVERY NEEDED
// =============================================================================

// Verbose logging control
integer VERBOSE_LOGGING = TRUE;  // Global flag for verbose debug logs
integer MSG_TOGGLE_VERBOSE_LOGS = 9998;  // Message to toggle verbose logging

// Message constants for link communication
// Scoreboard messages (from link 1 - controller)
integer MSG_GAME_STATUS = 3001;
integer MSG_PLAYER_UPDATE = 3002;
integer MSG_CLEAR_GAME = 3003;
integer MSG_REMOVE_PLAYER = 3004;

// Leaderboard messages (to link 25)  
integer MSG_GAME_WON = 3010;
integer MSG_GAME_LOST = 3011;
integer MSG_RESET_LEADERBOARD = 3012;

// Dice messages (to link 73)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;

// Prim indices (UPDATED for linkset - all shifted by +1 from standalone version)
integer BACKGROUND_PRIM = 3;      // Now link 3 (was 2)
integer ACTIONS_PRIM = 4;         // Now link 4 (was 3)
integer FIRST_PLAYER_PRIM = 5;    // Now link 5 (was 4)
integer LAST_PLAYER_PRIM = 24;    // Now link 24 (was 23) - SAFETY BOUNDARY

// Heart texture UUIDs - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
string TEXTURE_0_HEARTS = "7d8ae121-e171-12ae-f5b6-7cc3c0395c7b"; // 0 hearts (dead)
string TEXTURE_1_HEARTS = "6605d25f-8e2d-2870-eb87-77c58cd47fa9"; // 1 heart
string TEXTURE_2_HEARTS = "7ba6cb1e-f384-25a5-8e88-a90bbd7cc041"; // 2 hearts  
string TEXTURE_3_HEARTS = "a5d16715-4648-6526-5582-e8068293f792"; // 3 hearts

// Default textures - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
string TEXTURE_DEFAULT_PROFILE = "1ce89375-6c3c-3845-26b1-1dc666bc9169"; // Default avatar
string TEXTURE_BOT_PROFILE = "62f31722-04c1-8c29-c236-398543f2a6ae"; // Bot avatar picture
string BLANK_TEXTURE = "5748decc-f629-461c-9a36-a35a221fe21f"; // White texture UUID
string TEXTURE_BACKGROUND = "5748decc-f629-461c-9a36-a35a221fe21f"; // Background texture (blank + black color)
string TEXTURE_ACTIONS = "6aac8dce-1b83-f931-abe3-286f4f2faa29"; // Punishment texture

// Status textures - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
string TEXTURE_PERIL = "c5676fec-0c85-5567-3dd8-f939234e21d9"; // Elimination texture
string TEXTURE_PERIL_SELECTED = "a53ff601-3c8a-e312-9e0e-f6fa76f6773a"; // Peril Selected texture
string TEXTURE_VICTORY = "ec5bf10e-4970-fb63-e7bf-751e1dc27a8d"; // Victory texture
string TEXTURE_PUNISHMENT = "acfabed0-84ad-bfd1-cdfc-2ada0aeeaa2f"; // Punishment texture (fallback)
string TEXTURE_DIRECT_HIT = "ecd2dba2-3969-6c39-ad59-319747307f55"; // Direct Hit texture
string TEXTURE_NO_SHIELD = "2440174f-e385-44e2-8016-ac34934f11f5"; // No Shield texture
string TEXTURE_PLOT_TWIST = "ec533379-4f7f-8183-e877-e68af703dcce"; // Plot Twist texture
string TEXTURE_TITLE = "624bb7a7-e856-965c-bae8-94d75226c1bc"; // Title texture
string TEXTURE_ELIMINATED_X = "90524092-03b0-1b3c-bcea-3ea5118c6dba"; // Red X overlay for eliminated players

// Player data - used for BOTH current game display AND leaderboard
list playerNames = []; // Current game players for display
list playerLives = []; // Current game player lives
list playerProfiles = []; // Maps to profile texture UUIDs

// Leaderboard data (persistent - stored in linkset data)
list leaderboardNames = []; // Loaded from linkset data at startup
list leaderboardWins = []; // Loaded from linkset data at startup
list leaderboardLosses = []; // Loaded from linkset data at startup

// HTTP tracking
list profileRequests = []; // Track which profile requests belong to which player
list httpRequests = []; // Track HTTP requests for profile pictures

// Profile picture extraction constants
string profile_key_prefix = "<meta name=\"imageid\" content=\"";
string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
integer profile_key_prefix_length;
integer profile_img_prefix_length;

// Update actions prim with appropriate status texture
updateActionsPrim(string status) {
    string textureToUse = "";
    
    if (status == "Elimination") {
        textureToUse = TEXTURE_PERIL;
    } else if (status == "Victory") {
        textureToUse = TEXTURE_VICTORY;
    } else if (status == "Punishment") {
        textureToUse = TEXTURE_PUNISHMENT;
    } else if (status == "Direct Hit") {
        textureToUse = TEXTURE_DIRECT_HIT;
    } else if (status == "No Shield") {
        textureToUse = TEXTURE_NO_SHIELD;
    } else if (status == "Peril Selected") {
        textureToUse = TEXTURE_PERIL_SELECTED;
    } else if (status == "Plot Twist") {
        textureToUse = TEXTURE_PLOT_TWIST;
    } else if (status == "Title") {
        textureToUse = TEXTURE_TITLE;
    } else {
        return; // Don't change texture for unrecognized statuses
    }
    
    // SAFETY CHECK - prevent overflow into leaderboard prims
    if (ACTIONS_PRIM > LAST_PLAYER_PRIM) {
        if (VERBOSE_LOGGING) {
            llOwnerSay("❌ ERROR: ACTIONS_PRIM (" + (string)ACTIONS_PRIM + ") exceeds safety boundary (" + (string)LAST_PLAYER_PRIM + ")");
        }
        return;
    }
    
    llSetLinkPrimitiveParamsFast(ACTIONS_PRIM, [
        PRIM_TEXTURE, ALL_SIDES, textureToUse, <1,1,0>, <0,0,0>, 0.0,
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove existing floating text
    ]);
}

// Load leaderboard data from linkset data
loadLeaderboardData() {
    string countStr = llLinksetDataRead("lb_count");
    integer count = (integer)countStr;
    
    leaderboardNames = [];
    leaderboardWins = [];
    leaderboardLosses = [];
    
    if (count > 0) {
        integer i;
        for (i = 0; i < count; i++) {
            string name = llLinksetDataRead("lb_player_" + (string)i);
            string wins = llLinksetDataRead("lb_wins_" + (string)i);
            string losses = llLinksetDataRead("lb_losses_" + (string)i);
            
            if (name != "") {
                leaderboardNames += [name];
                leaderboardWins += [(integer)wins];
                leaderboardLosses += [(integer)losses];
            }
        }
    }
}

// Save leaderboard data to linkset data
saveLeaderboardData() {
    integer count = llGetListLength(leaderboardNames);
    llLinksetDataWrite("lb_count", (string)count);
    
    integer i;
    for (i = 0; i < count; i++) {
        llLinksetDataWrite("lb_player_" + (string)i, llList2String(leaderboardNames, i));
        llLinksetDataWrite("lb_wins_" + (string)i, (string)llList2Integer(leaderboardWins, i));
        llLinksetDataWrite("lb_losses_" + (string)i, (string)llList2Integer(leaderboardLosses, i));
    }
}

// Handle game won - update leaderboard
handleGameWon(string winnerName) {
    integer idx = llListFindList(leaderboardNames, [winnerName]);
    if (idx == -1) {
        // New player
        leaderboardNames += [winnerName];
        leaderboardWins += [1];
        leaderboardLosses += [0];
    } else {
        // Existing player
        integer currentWins = llList2Integer(leaderboardWins, idx);
        leaderboardWins = llListReplaceList(leaderboardWins, [currentWins + 1], idx, idx);
    }
    
    saveLeaderboardData();
    generateLeaderboardText();
}

// Handle game lost - update leaderboard
handleGameLost(string loserName) {
    integer idx = llListFindList(leaderboardNames, [loserName]);
    if (idx == -1) {
        // New player
        leaderboardNames += [loserName];
        leaderboardWins += [0];
        leaderboardLosses += [1];
    } else {
        // Existing player
        integer currentLosses = llList2Integer(leaderboardLosses, idx);
        leaderboardLosses = llListReplaceList(leaderboardLosses, [currentLosses + 1], idx, idx);
    }
    
    saveLeaderboardData();
    generateLeaderboardText();
}

// Get sorted leaderboard data
list getSortedLeaderboard() {
    list sortedData = [];
    integer i;
    
    // Create combined data for sorting: "Name:Wins:Losses"
    for (i = 0; i < llGetListLength(leaderboardNames); i++) {
        string name = llList2String(leaderboardNames, i);
        integer wins = llList2Integer(leaderboardWins, i);
        integer losses = llList2Integer(leaderboardLosses, i);
        
        // Format: "Name:Wins:Losses" - wins as leading digits for sorting
        string entry = (string)wins + ":" + name + ":" + (string)wins + ":" + (string)losses;
        sortedData += [entry];
    }
    
    // Sort by wins (descending) - the leading wins digits will sort it
    sortedData = llListSort(sortedData, 1, FALSE); // FALSE = descending order
    
    // Clean up the format back to "Name:Wins:Losses"
    list cleanedData = [];
    for (i = 0; i < llGetListLength(sortedData); i++) {
        string entry = llList2String(sortedData, i);
        list parts = llParseString2List(entry, [":"], []);
        if (llGetListLength(parts) >= 4) {
            string name = llList2String(parts, 1);
            string wins = llList2String(parts, 2);
            string losses = llList2String(parts, 3);
            cleanedData += [name + ":" + wins + ":" + losses];
        }
    }
    
    return cleanedData;
}

// Generate leaderboard text and send to separate leaderboard object
generateLeaderboardText() {
    list sortedData = getSortedLeaderboard();
    
    // Build formatted leaderboard text (40 chars per line)
    string leaderboardText = "        TOP BATTLE RECORDS        \n";
    
    integer i;
    // Add actual player data (up to 11 players)
    for (i = 0; i < llGetListLength(sortedData) && i < 11; i++) {
        string playerData = llList2String(sortedData, i);
        list playerParts = llParseString2List(playerData, [":"], []);
        
        if (llGetListLength(playerParts) >= 3) {
            string playerName = llList2String(playerParts, 0);
            string wins = llList2String(playerParts, 1);
            string losses = llList2String(playerParts, 2);
            
            // Truncate long names to fit better spacing
            if (llStringLength(playerName) > 12) {
                playerName = llGetSubString(playerName, 0, 9) + "...";
            }
            
            // Format rank
            integer rankNumber = i + 1;
            string rank = (string)rankNumber;
            if (rankNumber < 10) rank = " " + rank; // Pad single digits
            
            // Create well-spaced line to fill full 40-character width
            string leftPart = rank + ". " + playerName;
            string rightPart = "W:" + wins + "/L:" + losses;
            
            // Calculate spaces needed to fill exactly 40 characters
            integer spaceNeeded = 40 - llStringLength(leftPart) - llStringLength(rightPart);
            if (spaceNeeded < 1) spaceNeeded = 1; // At least 1 space
            
            string spacer = "";
            integer s;
            for (s = 0; s < spaceNeeded; s++) {
                spacer += " ";
            }
            
            string line = leftPart + spacer + rightPart;
            leaderboardText += line + "\n";
        }
    }
    
    // Fill remaining positions with placeholders to always show 11 positions
    integer actualPlayers = llGetListLength(sortedData);
    for (i = actualPlayers; i < 11; i++) {
        integer rankNumber = i + 1;
        string rank = (string)rankNumber;
        if (rankNumber < 10) rank = " " + rank; // Pad single digits
        
        // Create placeholder line to fill full 40-character width
        string leftPart = rank + ". --------";
        string rightPart = "W:0/L:0";
        
        // Calculate spaces needed to fill exactly 40 characters
        integer spaceNeeded = 40 - llStringLength(leftPart) - llStringLength(rightPart);
        if (spaceNeeded < 1) spaceNeeded = 1; // At least 1 space
        
        string spacer = "";
        integer s;
        for (s = 0; s < spaceNeeded; s++) {
            spacer += " ";
        }
        
        string line = leftPart + spacer + rightPart;
        leaderboardText += line + "\n";
    }
    
    // Send formatted text to leaderboard bridge
    llMessageLinked(25, MSG_RESET_LEADERBOARD, "FORMATTED_TEXT|" + leaderboardText, NULL_KEY);
}

// Reset leaderboard data
resetLeaderboard() {
    leaderboardNames = [];
    leaderboardWins = [];
    leaderboardLosses = [];
    integer i;
    for (i = 0; i < 100; i++) {
        llLinksetDataDelete("lb_player_" + (string)i);
        llLinksetDataDelete("lb_wins_" + (string)i);
        llLinksetDataDelete("lb_losses_" + (string)i);
    }
    llLinksetDataDelete("lb_count");
    generateLeaderboardText(); // Send empty leaderboard
}

// Clear all current players from the scoreboard
clearAllPlayers() {
    // Clear ONLY current game player data lists (NOT leaderboard data)
    playerNames = [];
    playerLives = [];
    playerProfiles = [];
    
    // Clear any pending HTTP requests
    httpRequests = [];
    profileRequests = [];
    
    // Reset all player prims to default state
    integer i;
    for (i = 0; i < 10; i++) {
        integer profilePrimIndex = FIRST_PLAYER_PRIM + (i * 2);
        integer heartsPrimIndex = FIRST_PLAYER_PRIM + (i * 2) + 1;
        
        // SAFETY CHECK - prevent overflow into leaderboard prims
        if (profilePrimIndex > LAST_PLAYER_PRIM || heartsPrimIndex > LAST_PLAYER_PRIM) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("❌ ERROR: Player prim index overflow! Attempted: " + (string)profilePrimIndex +
                           " or " + (string)heartsPrimIndex + ", max allowed: " + (string)LAST_PLAYER_PRIM);
            }
            return; // Don't modify prims outside our range!
        }
        
        // Reset profile prim to default
        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        // Reset hearts prim to 3 hearts
        llSetLinkPrimitiveParamsFast(heartsPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    }
}

// Remove a single player from the scoreboard display
removePlayer(string playerName) {
    integer idx = llListFindList(playerNames, [playerName]);
    if (idx != -1) {
        // Remove player from internal lists
        playerNames = llDeleteSubList(playerNames, idx, idx);
        playerLives = llDeleteSubList(playerLives, idx, idx);
        playerProfiles = llDeleteSubList(playerProfiles, idx, idx);
        
        // Refresh the entire display to shift remaining players up
        refreshPlayerDisplay();
        
        if (VERBOSE_LOGGING) {
            llOwnerSay("📊 Removed " + playerName + " from the scoreboard and shifted remaining players.");
        }
    }
}

// Refresh the entire player display - shows all current players in order
refreshPlayerDisplay() {
    // Clear all player slots first
    integer i;
    for (i = 0; i < 10; i++) {
        integer profilePrimIndex = FIRST_PLAYER_PRIM + (i * 2);
        integer heartsPrimIndex = FIRST_PLAYER_PRIM + (i * 2) + 1;
        
        // SAFETY CHECK
        if (profilePrimIndex > LAST_PLAYER_PRIM || heartsPrimIndex > LAST_PLAYER_PRIM) {
            return; // Stop if we'd go out of bounds
        }
        
        // Reset to default
        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        llSetLinkPrimitiveParamsFast(heartsPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    }
    
    // Now display all current players in their new positions
    for (i = 0; i < llGetListLength(playerNames); i++) {
        string name = llList2String(playerNames, i);
        integer lives = llList2Integer(playerLives, i);
        string profileTexture = llList2String(playerProfiles, i);
        
        // Calculate prim indices for this position
        integer profilePrimIndex = FIRST_PLAYER_PRIM + (i * 2);
        integer heartsPrimIndex = FIRST_PLAYER_PRIM + (i * 2) + 1;
        
        // SAFETY CHECK
        if (profilePrimIndex > LAST_PLAYER_PRIM || heartsPrimIndex > LAST_PLAYER_PRIM) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("⚠️ Warning: Player " + name + " cannot be displayed - out of prim range");
            }
            return;
        }
        
        // Determine profile texture to use - check for elimination first
        if (lives <= 0) {
            // Player is eliminated - show red X overlay
            profileTexture = TEXTURE_ELIMINATED_X;
        } else if (isBot(name)) {
            profileTexture = TEXTURE_BOT_PROFILE;
        } else if (profileTexture == "" || profileTexture == "00000000-0000-0000-0000-000000000000") {
            profileTexture = TEXTURE_DEFAULT_PROFILE;
        }
        // Note: If we have a cached profile texture, use it; otherwise use default for now
        // HTTP requests for new profile pictures will update later
        
        // Set profile texture
        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, profileTexture, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        // Set hearts texture
        string heartTexture = getHeartTexture(lives);
        llSetLinkPrimitiveParamsFast(heartsPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, heartTexture, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    }
}

// Check if a player name indicates it's a bot
integer isBot(string playerName) {
    return (llSubStringIndex(playerName, "Bot") == 0);
}

string getHeartTexture(integer lives) {
    if (lives <= 0) return TEXTURE_0_HEARTS;
    else if (lives == 1) return TEXTURE_1_HEARTS;
    else if (lives == 2) return TEXTURE_2_HEARTS;
    else return TEXTURE_3_HEARTS; // 3 or more
}

// Update player display on the grid
updatePlayerDisplay(string playerName, integer lives, string profileUUID) {
    // Find existing player or add new one
    integer playerIndex = llListFindList(playerNames, [playerName]);
    
    if (playerIndex == -1) {
        // New player - find next available slot
        playerIndex = llGetListLength(playerNames);
        if (playerIndex >= 10) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("WARNING: Maximum 10 players supported, ignoring: " + playerName);
            }
            return;
        }
        
        // Add to tracking lists
        playerNames += [playerName];
        playerLives += [lives];
        playerProfiles += [profileUUID];
        
    } else {
        // Update existing player
        playerLives = llListReplaceList(playerLives, [lives], playerIndex, playerIndex);
        // Don't overwrite cached profile texture with original UUID on updates
    }
    
    // Update the physical prims for this player
    integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
    integer heartsPrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2) + 1;
    
    // SAFETY CHECK - prevent overflow into leaderboard prims
    if (profilePrimIndex > LAST_PLAYER_PRIM || heartsPrimIndex > LAST_PLAYER_PRIM) {
        if (VERBOSE_LOGGING) {
            llOwnerSay("❌ ERROR: Player prim index overflow! Attempted: " + (string)profilePrimIndex + 
                       " or " + (string)heartsPrimIndex + ", max allowed: " + (string)LAST_PLAYER_PRIM);
        }
        return; // Don't modify prims outside our range!
    }
    
    // Update profile prim texture - show red X if eliminated, otherwise show profile
    string profileTexture;
    
    if (lives <= 0) {
        // Player is eliminated - show red X (replaces profile picture)
        profileTexture = TEXTURE_ELIMINATED_X;
        if (VERBOSE_LOGGING) {
            llOwnerSay("💀 Scoreboard: Showing elimination X for " + playerName);
        }
    } else {
        // Player is alive - determine profile texture to use
        profileTexture = profileUUID;
        
        // Check if we already have a cached profile texture for this player
        if (playerIndex < llGetListLength(playerProfiles)) {
            string cachedTexture = llList2String(playerProfiles, playerIndex);
            if (cachedTexture != "" && cachedTexture != profileUUID && 
                cachedTexture != TEXTURE_DEFAULT_PROFILE && cachedTexture != TEXTURE_BOT_PROFILE &&
                cachedTexture != TEXTURE_ELIMINATED_X) {
                // We have a previously fetched profile picture, use it
                profileTexture = cachedTexture;
            }
        }
        
        // If no cached texture or using original UUID, determine what to use
        if (profileTexture == profileUUID) {
            if (isBot(playerName)) {
                profileTexture = TEXTURE_BOT_PROFILE;
            } else if (profileTexture == "" || profileTexture == "00000000-0000-0000-0000-000000000000") {
                profileTexture = TEXTURE_DEFAULT_PROFILE;
            } else {
                // Request profile picture via HTTP
                string URL_RESIDENT = "https://world.secondlife.com/resident/";
                key httpRequestID = llHTTPRequest(URL_RESIDENT + profileUUID, [HTTP_METHOD, "GET"], "");
                
                // Store the HTTP request mapping: requestID -> playerIndex
                httpRequests += [httpRequestID, playerIndex];
            }
        }
    }
    
    llSetLinkPrimitiveParamsFast(profilePrimIndex, [
        PRIM_TEXTURE, ALL_SIDES, profileTexture, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
        PRIM_TEXT, "", <1,1,1>, 0.0 // Remove player name text
    ]);
    
    // Update hearts prim texture
    string heartTexture = getHeartTexture(lives);
    llSetLinkPrimitiveParamsFast(heartsPrimIndex, [
        PRIM_TEXTURE, ALL_SIDES, heartTexture, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
        PRIM_TEXT, "", <1,0,0>, 0.0 // Remove lives text
    ]);
}

default {
    state_entry() {
        if (VERBOSE_LOGGING) {
            llOwnerSay("📊 Scoreboard Manager ready! (Linkset Version)");
            llOwnerSay("📊 Managing prims " + (string)FIRST_PLAYER_PRIM + "-" + (string)LAST_PLAYER_PRIM);
        }
        
        // Initialize profile picture extraction constants
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        
        // Load persistent leaderboard data
        loadLeaderboardData();
        
        // Generate initial leaderboard
        generateLeaderboardText();
        
        if (VERBOSE_LOGGING) {
            llOwnerSay("✅ Linkset communication active - no discovery needed!");
            llOwnerSay("📊 Loaded " + (string)llGetListLength(leaderboardNames) + " players from leaderboard data");
        }
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle verbose logging toggle
        if (num == MSG_TOGGLE_VERBOSE_LOGS) {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔊 [Scoreboard] Verbose logging ENABLED");
            } else {
                llOwnerSay("🔊 [Scoreboard] Verbose logging DISABLED");
            }
            return;
        }
        
        // Only listen to messages from the main controller (link 1)
        if (sender != 1) return;
        
        if (num == MSG_GAME_STATUS) {
            updateActionsPrim(str);
        }
        else if (num == MSG_PLAYER_UPDATE) {
            list parts = llParseString2List(str, ["|"], []);
            if (llGetListLength(parts) >= 3) {
                string playerName = llList2String(parts, 0);
                integer lives = (integer)llList2String(parts, 1);
                string profileUUID = llList2String(parts, 2);
                
                // Debug: Show what data scoreboard received
                if (VERBOSE_LOGGING) {
                    llOwnerSay("📊 Scoreboard received update: " + playerName + " has " + (string)lives + " hearts");
                }
                
                updatePlayerDisplay(playerName, lives, profileUUID);
            }
        }
        else if (num == MSG_CLEAR_GAME) {
            // Reset to default state
            clearAllPlayers(); // Clear all current players
            updateActionsPrim("Title"); // Reset to title
            
            generateLeaderboardText(); // Refresh leaderboard display
        }
        else if (num == MSG_GAME_WON) {
            handleGameWon(str);
        }
        else if (num == MSG_GAME_LOST) {
            handleGameLost(str);
        }
        else if (num == MSG_RESET_LEADERBOARD) {
            resetLeaderboard();
        }
        else if (num == MSG_REMOVE_PLAYER) {
            removePlayer(str);
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        // Handle profile picture HTTP responses
        integer requestIndex = llListFindList(httpRequests, [request_id]);
        if (requestIndex != -1) {
            integer playerIndex = llList2Integer(httpRequests, requestIndex + 1);
            
            // Remove this request from tracking
            httpRequests = llDeleteSubList(httpRequests, requestIndex, requestIndex + 1);
            
            if (status == 200 && playerIndex < llGetListLength(playerNames)) {
                // Parse the HTML to extract profile image UUID
                string profileUUID = "";
                
                // Try the meta tag method first
                integer metaStart = llSubStringIndex(body, profile_key_prefix);
                if (metaStart != -1) {
                    metaStart += profile_key_prefix_length;
                    string remainingBody = llGetSubString(body, metaStart, -1);
                    integer metaEnd = llSubStringIndex(remainingBody, "\"");
                    if (metaEnd != -1) {
                        profileUUID = llGetSubString(remainingBody, 0, metaEnd - 1);
                    }
                }
                
                // If meta tag failed, try img src method
                if (profileUUID == "") {
                    integer imgStart = llSubStringIndex(body, profile_img_prefix);
                    if (imgStart != -1) {
                        imgStart += profile_img_prefix_length;
                        string remainingBody = llGetSubString(body, imgStart, -1);
                        integer imgEnd = llSubStringIndex(remainingBody, "/");
                        if (imgEnd != -1) {
                            profileUUID = llGetSubString(remainingBody, 0, imgEnd - 1);
                        }
                    }
                }
                
                // If we got a valid UUID, update the profile prim and cache it
                if (profileUUID != "" && profileUUID != "00000000-0000-0000-0000-000000000000") {
                    // Update the cached profile texture
                    playerProfiles = llListReplaceList(playerProfiles, [profileUUID], playerIndex, playerIndex);
                    
                    // Update the physical prim
                    integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                    
                    // SAFETY CHECK
                    if (profilePrimIndex <= LAST_PLAYER_PRIM) {
                        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                            PRIM_TEXTURE, ALL_SIDES, profileUUID, <1,1,0>, <0,0,0>, 0.0
                        ]);
                    }
                }
            }
        }
    }
    
    touch_start(integer total_number) {
        // Owner can still access some debug functions by touching scoreboard
        if (llDetectedKey(0) == llGetOwner()) {
            llOwnerSay("📊 Scoreboard Status:");
            llOwnerSay("  Active players: " + (string)llGetListLength(playerNames));
            llOwnerSay("  Leaderboard entries: " + (string)llGetListLength(leaderboardNames));
            llOwnerSay("  HTTP requests pending: " + (string)(llGetListLength(httpRequests) / 2));
        }
    }
}
