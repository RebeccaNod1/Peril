// Game Scoreboard Manager - Linkset Version
// Shows current game players in grid layout
// Each player gets a prim showing profile picture + heart texture (lives)

// =============================================================================
// LINKSET COMMUNICATION - NO DISCOVERY NEEDED
// =============================================================================

// Verbose logging control
integer VERBOSE_LOGGING = FALSE;  // Global flag for verbose debug logs - DISABLED to save memory
integer MSG_TOGGLE_VERBOSE_LOGS = 9998;  // Message to toggle verbose logging

// Message constants for link communication
// Scoreboard messages (from link 1 - controller)
integer MSG_GAME_STATUS = 3001;
integer MSG_PLAYER_UPDATE = 3002;
integer MSG_CLEAR_GAME = 3003;
integer MSG_REMOVE_PLAYER = 3004;
integer MSG_UPDATE_PERIL_PLAYER = 3005;
integer MSG_UPDATE_WINNER = 3006;

// Leaderboard messages (to link 35)  
integer MSG_GAME_WON = 3010;
integer MSG_GAME_LOST = 3011;
integer MSG_RESET_LEADERBOARD = 3012;

// Dice messages (to link 83)
integer MSG_DICE_ROLL = 3020;
integer MSG_CLEAR_DICE = 3021;

// Prim indices (UPDATED after overlay prim insertion - overlays are links 2-11)
integer BACKGROUND_PRIM = 13;     // Now link 13 (backboard)
integer ACTIONS_PRIM = 14;        // Now link 14 (title/action)
integer FIRST_PROFILE_PRIM = 15;  // Profile prims start at 15
integer LAST_PROFILE_PRIM = 34;   // Profile/life prims end at 34
integer FIRST_OVERLAY_PRIM = 2;   // Overlay prims start at 2
integer LAST_OVERLAY_PRIM = 11;   // Overlay prims end at 11

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

// Peril player tracking
string currentPerilPlayer = ""; // Track current peril player for glow effects
string currentWinner = ""; // Track current winner for green glow effects

// Leaderboard data (persistent - stored in linkset data)
list leaderboardNames = []; // Loaded from linkset data at startup
list leaderboardWins = []; // Loaded from linkset data at startup
list leaderboardLosses = []; // Loaded from linkset data at startup

// HTTP tracking
list profileRequests = []; // Track which profile requests belong to which player
list httpRequests = []; // Track HTTP requests for profile pictures

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

// Profile picture extraction constants
string profile_key_prefix = "<meta name=\"imageid\" content=\"";
string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
integer profile_key_prefix_length;
integer profile_img_prefix_length;

// Reset background prim to proper black background
resetBackgroundPrim() {
    // Reset main background prim (link 13)
    llSetLinkPrimitiveParamsFast(BACKGROUND_PRIM, [
        PRIM_TEXTURE, ALL_SIDES, TEXTURE_BACKGROUND, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black color
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove any text
    ]);
    
    if (VERBOSE_LOGGING) {
        llOwnerSay("🖤 Reset background prim " + (string)BACKGROUND_PRIM + " to black");
    }
}

// Reset the scoreboard manager cube (link 12) to neutral state
resetManagerCube() {
    llSetLinkPrimitiveParamsFast(12, [
        PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black color to blend in
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove any text
    ]);
    
    if (VERBOSE_LOGGING) {
        llOwnerSay("📦 Reset manager cube (link 12) to black");
    }
}

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
    if (ACTIONS_PRIM > LAST_PROFILE_PRIM) {
        if (VERBOSE_LOGGING) {
            llOwnerSay("❌ ERROR: ACTIONS_PRIM (" + (string)ACTIONS_PRIM + ") exceeds safety boundary (" + (string)LAST_PROFILE_PRIM + ")");
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
    integer loadCount = (integer)countStr;
    
    leaderboardNames = [];
    leaderboardWins = [];
    leaderboardLosses = [];
    
    if (loadCount > 0) {
        integer loadI;
        for (loadI = 0; loadI < loadCount; loadI++) {
            string name = llLinksetDataRead("lb_player_" + (string)loadI);
            string wins = llLinksetDataRead("lb_wins_" + (string)loadI);
            string losses = llLinksetDataRead("lb_losses_" + (string)loadI);
            
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
    integer saveCount = llGetListLength(leaderboardNames);
    llLinksetDataWrite("lb_count", (string)saveCount);
    
    integer saveI;
    for (saveI = 0; saveI < saveCount; saveI++) {
        llLinksetDataWrite("lb_player_" + (string)saveI, llList2String(leaderboardNames, saveI));
        llLinksetDataWrite("lb_wins_" + (string)saveI, (string)llList2Integer(leaderboardWins, saveI));
        llLinksetDataWrite("lb_losses_" + (string)saveI, (string)llList2Integer(leaderboardLosses, saveI));
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
    integer lostIdx = llListFindList(leaderboardNames, [loserName]);
    if (lostIdx == -1) {
        // New player
        leaderboardNames += [loserName];
        leaderboardWins += [0];
        leaderboardLosses += [1];
    } else {
        // Existing player
        integer currentLosses = llList2Integer(leaderboardLosses, lostIdx);
        leaderboardLosses = llListReplaceList(leaderboardLosses, [currentLosses + 1], lostIdx, lostIdx);
    }
    
    saveLeaderboardData();
    generateLeaderboardText();
}

// Get sorted leaderboard data
list getSortedLeaderboard() {
    list sortedLbData = [];
    integer sortI;
    string sortName;
    integer sortWins;
    integer sortLosses;
    string paddedWins;
    string paddedLosses;
    integer invertedLosses;
    string sortKey;
    string entry;
    list parts;
    list cleanedData = [];
    string winsStr;
    string lossesStr;
    
    // Create combined data for sorting with padded wins and losses for proper multi-level sorting
    for (sortI = 0; sortI < llGetListLength(leaderboardNames); sortI++) {
        sortName = llList2String(leaderboardNames, sortI);
        sortWins = llList2Integer(leaderboardWins, sortI);
        sortLosses = llList2Integer(leaderboardLosses, sortI);
        
        // Pad wins to 4 digits (higher wins = better rank)
        paddedWins = (string)(10000 + sortWins);
        paddedWins = llGetSubString(paddedWins, 1, -1);  // Remove the "1" prefix
        
        // Pad losses to 4 digits, but INVERTED for tiebreaker (lower losses = better rank)
        // Use 9999 - losses so lower losses get higher sort value
        invertedLosses = 9999 - sortLosses;
        paddedLosses = (string)(10000 + invertedLosses);
        paddedLosses = llGetSubString(paddedLosses, 1, -1);  // Remove the "1" prefix
        
        // Format: "PaddedWins-PaddedInvertedLosses:Name:ActualWins:ActualLosses"
        // This sorts first by wins (descending), then by losses (ascending) for tiebreaker
        sortKey = paddedWins + "-" + paddedLosses;
        entry = sortKey + ":" + sortName + ":" + (string)sortWins + ":" + (string)sortLosses;
        sortedLbData += [entry];
    }
    
    // Sort by combined key (wins descending, losses ascending) - FALSE = descending order
    sortedLbData = llListSort(sortedLbData, 1, FALSE);
    
    // Clean up the format back to "Name:Wins:Losses" (skip padded wins in position 0)
    cleanedData = [];
    for (sortI = 0; sortI < llGetListLength(sortedLbData); sortI++) {
        entry = llList2String(sortedLbData, sortI);
        parts = llParseString2List(entry, [":"], []);
        if (llGetListLength(parts) >= 4) {
            // parts[0] = paddedWins (skip), parts[1] = name, parts[2] = actualWins, parts[3] = losses
            sortName = llList2String(parts, 1);
            winsStr = llList2String(parts, 2);
            lossesStr = llList2String(parts, 3);
            cleanedData += [sortName + ":" + winsStr + ":" + lossesStr];
        }
    }
    
    return cleanedData;
}

// Generate leaderboard text and send to separate leaderboard object
generateLeaderboardText() {
    list sortedData = getSortedLeaderboard();
    
    // Build formatted leaderboard text (40 chars per line)
    string leaderboardText = "        TOP BATTLE RECORDS        \n";
    
    integer genI;
    string playerData;
    list playerParts;
    string playerName;
    string genWins;
    string genLosses;
    integer rankNumber;
    string rank;
    string leftPart;
    string rightPart;
    integer spaceNeeded;
    string spacer;
    integer s;
    string line;
    integer actualPlayers;
    
    // Add actual player data (up to 11 players)
    for (genI = 0; genI < llGetListLength(sortedData) && genI < 11; genI++) {
        playerData = llList2String(sortedData, genI);
        playerParts = llParseString2List(playerData, [":"], []);
        
        if (llGetListLength(playerParts) >= 3) {
            playerName = llList2String(playerParts, 0);
            genWins = llList2String(playerParts, 1);
            genLosses = llList2String(playerParts, 2);
            
            // Truncate long names to fit better spacing
            if (llStringLength(playerName) > 12) {
                playerName = llGetSubString(playerName, 0, 9) + "...";
            }
            
            // Format rank
            rankNumber = genI + 1;
            rank = (string)rankNumber;
            if (rankNumber < 10) rank = " " + rank; // Pad single digits
            
            // Create well-spaced line to fill full 40-character width
            leftPart = rank + ". " + playerName;
            rightPart = "W:" + genWins + "/L:" + genLosses;
            
            // Calculate spaces needed to fill exactly 40 characters
            spaceNeeded = 40 - llStringLength(leftPart) - llStringLength(rightPart);
            if (spaceNeeded < 1) spaceNeeded = 1; // At least 1 space
            
            spacer = "";
            for (s = 0; s < spaceNeeded; s++) {
                spacer += " ";
            }
            
            line = leftPart + spacer + rightPart;
            leaderboardText += line + "\n";
        }
    }
    
    // Fill remaining positions with placeholders to always show 11 positions
    actualPlayers = llGetListLength(sortedData);
    for (genI = actualPlayers; genI < 11; genI++) {
        rankNumber = genI + 1;
        rank = (string)rankNumber;
        if (rankNumber < 10) rank = " " + rank; // Pad single digits
        
        // Create placeholder line to fill full 40-character width
        leftPart = rank + ". --------";
        rightPart = "W:0/L:0";
        
        // Calculate spaces needed to fill exactly 40 characters
        spaceNeeded = 40 - llStringLength(leftPart) - llStringLength(rightPart);
        if (spaceNeeded < 1) spaceNeeded = 1; // At least 1 space
        
        spacer = "";
        for (s = 0; s < spaceNeeded; s++) {
            spacer += " ";
        }
        
        line = leftPart + spacer + rightPart;
        leaderboardText += line + "\n";
    }
    
    // Send formatted text to leaderboard bridge
    llMessageLinked(35, MSG_RESET_LEADERBOARD, "FORMATTED_TEXT|" + leaderboardText, NULL_KEY);
}

// Reset leaderboard data
resetLeaderboard() {
    leaderboardNames = [];
    leaderboardWins = [];
    leaderboardLosses = [];
    integer resetI;
    for (resetI = 0; resetI < 100; resetI++) {
        llLinksetDataDelete("lb_player_" + (string)resetI);
        llLinksetDataDelete("lb_wins_" + (string)resetI);
        llLinksetDataDelete("lb_losses_" + (string)resetI);
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
    integer clearI;
    for (clearI = 0; clearI < 10; clearI++) {
        integer clearProfilePrimIndex = getProfilePrimLink(clearI);
        integer clearHeartsPrimIndex = getHeartsPrimLink(clearI);
        integer clearOverlayPrimIndex = getOverlayPrimLink(clearI);
        
        // SAFETY CHECK - prevent overflow into leaderboard prims
        if (clearProfilePrimIndex < FIRST_PROFILE_PRIM || clearProfilePrimIndex > LAST_PROFILE_PRIM) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("❌ ERROR: Player prim index out of range! Profile: " + (string)clearProfilePrimIndex);
            }
            return; // Don't modify prims outside our range!
        }
        
        // Reset profile prim to default and clear any glow
        llSetLinkPrimitiveParamsFast(clearProfilePrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0,
            PRIM_GLOW, ALL_SIDES, 0.0  // Explicitly clear glow
        ]);
        
        // Reset hearts prim to 3 hearts and clear any glow
        llSetLinkPrimitiveParamsFast(clearHeartsPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0,
            PRIM_GLOW, ALL_SIDES, 0.0  // Explicitly clear glow
        ]);
        
        // Reset overlay prim to transparent
        llSetLinkPrimitiveParamsFast(clearOverlayPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Fully transparent
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    }
}

// Remove a single player from the scoreboard display
removePlayer(string playerName) {
    integer removeIdx = llListFindList(playerNames, [playerName]);
    if (removeIdx != -1) {
        // Remove player from internal lists
        playerNames = llDeleteSubList(playerNames, removeIdx, removeIdx);
        playerLives = llDeleteSubList(playerLives, removeIdx, removeIdx);
        playerProfiles = llDeleteSubList(playerProfiles, removeIdx, removeIdx);
        
        // Refresh the entire display to shift remaining players up
        refreshPlayerDisplay();
        
        if (VERBOSE_LOGGING) {
            llOwnerSay("📊 Removed " + playerName + " from the scoreboard and shifted remaining players.");
        }
    }
}

// Refresh the entire player display - shows all current players in order
refreshPlayerDisplay() {
    // Clear only unused player slots (beyond current player count)
    integer numActivePlayers = llGetListLength(playerNames);
    integer refreshI;
    
    // Only reset prims for unused slots (avoid flickering for active players)
    for (refreshI = numActivePlayers; refreshI < 10; refreshI++) {
        integer refreshProfilePrimIndex = getProfilePrimLink(refreshI);
        integer refreshHeartsPrimIndex = getHeartsPrimLink(refreshI);
        integer refreshOverlayPrimIndex = getOverlayPrimLink(refreshI);
        
        // SAFETY CHECK
        if (refreshProfilePrimIndex < FIRST_PROFILE_PRIM || refreshProfilePrimIndex > LAST_PROFILE_PRIM) {
            return; // Stop if we'd go out of bounds
        }
        
        // Reset to default only for unused slots
        llSetLinkPrimitiveParamsFast(refreshProfilePrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        llSetLinkPrimitiveParamsFast(refreshHeartsPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        // Hide overlay prim (make transparent)
        llSetLinkPrimitiveParamsFast(refreshOverlayPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Fully transparent
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    }
    
    // Now display all current players in their new positions
    for (refreshI = 0; refreshI < llGetListLength(playerNames); refreshI++) {
        string name = llList2String(playerNames, refreshI);
        integer lives = llList2Integer(playerLives, refreshI);
        string profileTexture = llList2String(playerProfiles, refreshI);
        
        // Calculate prim indices for this position
        integer refreshProfileIdx = getProfilePrimLink(refreshI);
        integer refreshHeartsIdx = getHeartsPrimLink(refreshI);
        integer refreshOverlayIdx = getOverlayPrimLink(refreshI);
        
        // SAFETY CHECK
        if (refreshProfileIdx < FIRST_PROFILE_PRIM || refreshProfileIdx > LAST_PROFILE_PRIM) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("⚠️ Warning: Player " + name + " cannot be displayed - out of prim range");
            }
            return;
        }
        
        // Determine profile texture to use - don't replace with X, keep profile
        if (isBot(name)) {
            profileTexture = TEXTURE_BOT_PROFILE;
        } else if (profileTexture == "" || profileTexture == "00000000-0000-0000-0000-000000000000") {
            profileTexture = TEXTURE_DEFAULT_PROFILE;
        }
        // Note: If we have a cached profile texture, use it; otherwise use default for now
        // HTTP requests for new profile pictures will update later
        
        // Set profile texture (always normal coloring now)
        llSetLinkPrimitiveParamsFast(refreshProfileIdx, [
            PRIM_TEXTURE, ALL_SIDES, profileTexture, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        // Set hearts texture
        string heartTexture = getHeartTexture(lives);
        llSetLinkPrimitiveParamsFast(refreshHeartsIdx, [
            PRIM_TEXTURE, ALL_SIDES, heartTexture, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
        
        // Control overlay prim - show red X if eliminated, hide if alive
        if (lives <= 0) {
            // Show red X overlay for eliminated player
            llSetLinkPrimitiveParamsFast(refreshOverlayIdx, [
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0, // Fully visible
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
        } else {
            // Hide overlay for alive player
            llSetLinkPrimitiveParamsFast(refreshOverlayIdx, [
                PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Fully transparent
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
        }
    }
    
    // Update player glow effects after refreshing all players
    updatePlayerGlowEffects();
}

// Check if a player name indicates it's a bot
integer isBot(string playerName) {
    return (llSubStringIndex(playerName, "Bot") == 0);
}

// Map player index to profile prim link number
integer getProfilePrimLink(integer playerIndex) {
    // From link scan: Row 1 (top) has profile 31,33; Row 2 has 27,29; etc.
    // Player index 0,1 = row 1; 2,3 = row 2; 4,5 = row 3; etc.
    // Each row has 4 prims: profile col1, hearts col1, profile col2, hearts col2
    
    integer profileRow = playerIndex / 2;  // Which row (0=top, 1=second, etc)
    integer profileCol = playerIndex % 2;  // Which column (0=left, 1=right)
    
    // Base link for each row (profile col1): 31, 27, 23, 19, 15
    integer profileBaseLink = 31 - (profileRow * 4);
    
    if (profileCol == 0) {
        // Column 1 (left): profile prim
        return profileBaseLink;
    } else {
        // Column 2 (right): profile prim (skip hearts prim)
        return profileBaseLink + 2;
    }
}

// Map player index to hearts prim link number
integer getHeartsPrimLink(integer playerIndex) {
    // Hearts prims are adjacent to profile prims
    // Row 1: profile 31->hearts 32, profile 33->hearts 34
    // Row 2: profile 27->hearts 28, profile 29->hearts 30, etc.
    
    integer heartsRow = playerIndex / 2;  // Which row (0=top, 1=second, etc)
    integer heartsCol = playerIndex % 2;  // Which column (0=left, 1=right)
    
    // Base link for each row (hearts col1): 32, 28, 24, 20, 16
    integer heartsBaseLink = 32 - (heartsRow * 4);
    
    if (heartsCol == 0) {
        // Column 1 (left): hearts prim
        return heartsBaseLink;
    } else {
        // Column 2 (right): hearts prim (skip profile prim)
        return heartsBaseLink + 2;
    }
}

// Map player index to overlay prim link number
integer getOverlayPrimLink(integer playerIndex) {
    // Overlay prims arrangement: row 1 col 1=3, row 1 col 2=2, row 2 col 1=5, row 2 col 2=4, etc.
    // Pattern: odd rows (0,2,4,6,8) start at 3,7,11 for col1 and 2,6,10 for col2
    //          Wait, let me check the actual pattern from the scan...
    // Link 2: overlay row 1 col 2, Link 3: overlay row 1 col 1
    // Link 4: overlay row 2 col 2, Link 5: overlay row 2 col 1
    // So pattern is: row N col 1 = 3 + (row * 2), row N col 2 = 2 + (row * 2)
    integer overlayRow = playerIndex / 2;
    integer overlayCol = playerIndex % 2;
    
    if (overlayCol == 0) {
        // Column 1: 3, 5, 7, 9, 11
        return 3 + (overlayRow * 2);
    } else {
        // Column 2: 2, 4, 6, 8, 10
        return 2 + (overlayRow * 2);
    }
}

string getHeartTexture(integer lives) {
    if (lives <= 0) return TEXTURE_0_HEARTS;
    else if (lives == 1) return TEXTURE_1_HEARTS;
    else if (lives == 2) return TEXTURE_2_HEARTS;
    else return TEXTURE_3_HEARTS; // 3 or more
}

// Update all glow effects (peril and winner)
updatePlayerGlowEffects() {
    // First, remove glow and reset tint from all players
    integer glowI;
    for (glowI = 0; glowI < llGetListLength(playerNames); glowI++) {
        integer glowProfilePrimIndex = getProfilePrimLink(glowI);
        integer glowHeartsPrimIndex = getHeartsPrimLink(glowI);
        
        // SAFETY CHECK
        if (glowProfilePrimIndex >= FIRST_PROFILE_PRIM && glowProfilePrimIndex <= LAST_PROFILE_PRIM) {
            llSetLinkPrimitiveParamsFast(glowProfilePrimIndex, [
                PRIM_GLOW, ALL_SIDES, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
            ]);
            llSetLinkPrimitiveParamsFast(glowHeartsPrimIndex, [
                PRIM_GLOW, ALL_SIDES, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
            ]);
        }
    }
    
    // Priority 1: Green glow for winner (overrides peril glow)
    if (currentWinner != "" && currentWinner != "NONE") {
        integer winnerIndex = llListFindList(playerNames, [currentWinner]);
        if (winnerIndex != -1) {
            integer winnerProfilePrimIndex = getProfilePrimLink(winnerIndex);
            integer winnerHeartsPrimIndex = getHeartsPrimLink(winnerIndex);
            
            // SAFETY CHECK
            if (winnerProfilePrimIndex >= FIRST_PROFILE_PRIM && winnerProfilePrimIndex <= LAST_PROFILE_PRIM) {
                // Add green glow + green tint to winner
                llSetLinkPrimitiveParamsFast(winnerProfilePrimIndex, [
                    PRIM_GLOW, ALL_SIDES, 0.3,
                    PRIM_COLOR, ALL_SIDES, <0.0, 1.0, 0.0>, 1.0
                ]);
                llSetLinkPrimitiveParamsFast(winnerHeartsPrimIndex, [
                    PRIM_GLOW, ALL_SIDES, 0.3,
                    PRIM_COLOR, ALL_SIDES, <0.0, 1.0, 0.0>, 1.0
                ]);
                
                if (VERBOSE_LOGGING) {
                    llOwnerSay("🏆 Added green glow to winner: " + currentWinner);
                }
            }
        }
    }
    // Priority 2: Yellow glow for peril player (only if not the winner)
    else if (currentPerilPlayer != "" && currentPerilPlayer != "NONE") {
        integer perilIndex = llListFindList(playerNames, [currentPerilPlayer]);
        if (perilIndex != -1) {
            integer perilProfilePrimIndex = getProfilePrimLink(perilIndex);
            integer perilHeartsPrimIndex = getHeartsPrimLink(perilIndex);
            
            // SAFETY CHECK
            if (perilProfilePrimIndex >= FIRST_PROFILE_PRIM && perilProfilePrimIndex <= LAST_PROFILE_PRIM) {
                // Add yellow glow + yellow tint to peril player
                llSetLinkPrimitiveParamsFast(perilProfilePrimIndex, [
                    PRIM_GLOW, ALL_SIDES, 0.2,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 0.0>, 1.0
                ]);
                llSetLinkPrimitiveParamsFast(perilHeartsPrimIndex, [
                    PRIM_GLOW, ALL_SIDES, 0.2,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 0.0>, 1.0
                ]);
                
                if (VERBOSE_LOGGING) {
                    llOwnerSay("✨ Added yellow glow to peril player: " + currentPerilPlayer);
                }
            }
        }
    }
}

// Backward compatibility wrapper
updatePerilPlayerGlow() {
    updatePlayerGlowEffects();
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
        // For bots, always store the bot texture UUID to prevent HTTP requests
        if (isBot(playerName)) {
            playerProfiles += [TEXTURE_BOT_PROFILE];
        } else {
            playerProfiles += [profileUUID];
        }
        
        // DEBUG: Show prim mapping - DISABLED to save memory
        // if (VERBOSE_LOGGING) {
        //     integer debugProfile = getProfilePrimLink(playerIndex);
        //     integer debugHearts = getHeartsPrimLink(playerIndex);
        //     integer debugOverlay = getOverlayPrimLink(playerIndex);
        //     llOwnerSay("🔧 [Scoreboard] Player " + (string)playerIndex + " (" + playerName + "): Profile=" + (string)debugProfile + ", Hearts=" + (string)debugHearts + ", Overlay=" + (string)debugOverlay);
        //     llOwnerSay("🔍 [Scoreboard] Prim ranges: FIRST_PROFILE=" + (string)FIRST_PROFILE_PRIM + ", LAST_PROFILE=" + (string)LAST_PROFILE_PRIM);
        //     
        //     // Test if the calculated prim is actually valid
        //     if (debugProfile < FIRST_PROFILE_PRIM || debugProfile > LAST_PROFILE_PRIM) {
        //         llOwnerSay("⚠️ [Scoreboard] WARNING: Calculated profile prim " + (string)debugProfile + " is outside valid range!");
        //     }
        // }
        
    } else {
        // Update existing player
        playerLives = llListReplaceList(playerLives, [lives], playerIndex, playerIndex);
        // Don't overwrite cached profile texture with original UUID on updates
    }
    
    // Update the physical prims for this player
    integer updateProfilePrimIndex = getProfilePrimLink(playerIndex);
    integer updateHeartsPrimIndex = getHeartsPrimLink(playerIndex);
    integer updateOverlayPrimIndex = getOverlayPrimLink(playerIndex);
    
    // SAFETY CHECK - prevent overflow
    if (updateProfilePrimIndex < FIRST_PROFILE_PRIM || updateProfilePrimIndex > LAST_PROFILE_PRIM || 
        updateOverlayPrimIndex < FIRST_OVERLAY_PRIM || updateOverlayPrimIndex > LAST_OVERLAY_PRIM) {
        if (VERBOSE_LOGGING) {
            llOwnerSay("❌ ERROR: Player prim index out of range! Profile: " + (string)updateProfilePrimIndex + 
                       ", Overlay: " + (string)updateOverlayPrimIndex + ", Player: " + (string)playerIndex);
        }
        return; // Don't modify prims outside our range!
    }
    
    // Update profile prim texture - show red X if eliminated, otherwise show profile
    string updateProfileTexture;
    
    if (lives <= 0) {
        // Player is eliminated - keep profile picture but show red X on overlay prim
        if (VERBOSE_LOGGING) {
            llOwnerSay("💀 Scoreboard: Showing elimination X overlay for " + playerName);
        }
        
        // CRITICAL: Still need to set updateProfileTexture for eliminated players
        if (isBot(playerName)) {
            updateProfileTexture = TEXTURE_BOT_PROFILE;
        } else if (playerIndex < llGetListLength(playerProfiles)) {
            string updateCachedTexture = llList2String(playerProfiles, playerIndex);
            if (updateCachedTexture != "" && updateCachedTexture != profileUUID && 
                updateCachedTexture != TEXTURE_DEFAULT_PROFILE && updateCachedTexture != TEXTURE_BOT_PROFILE &&
                updateCachedTexture != TEXTURE_ELIMINATED_X) {
                // We have a previously fetched profile picture, use it
                updateProfileTexture = updateCachedTexture;
            } else {
                updateProfileTexture = TEXTURE_DEFAULT_PROFILE;
            }
        } else {
            updateProfileTexture = TEXTURE_DEFAULT_PROFILE;
        }
    } else {
        // Player is alive - determine profile texture to use
        updateProfileTexture = profileUUID;
        
        // Check if we already have a cached profile texture for this player
        if (playerIndex < llGetListLength(playerProfiles)) {
            string liveCachedTexture = llList2String(playerProfiles, playerIndex);
            if (liveCachedTexture != "" && liveCachedTexture != profileUUID && 
                liveCachedTexture != TEXTURE_DEFAULT_PROFILE && liveCachedTexture != TEXTURE_BOT_PROFILE &&
                liveCachedTexture != TEXTURE_ELIMINATED_X) {
                // We have a previously fetched profile picture, use it
                updateProfileTexture = liveCachedTexture;
            }
        }
        
        // If no cached texture or using original UUID, determine what to use
        // if (VERBOSE_LOGGING) {
        //     llOwnerSay("🔍 [DEBUG] " + playerName + " - profileTexture='" + profileTexture + "', profileUUID='" + profileUUID + "', isBot=" + (string)isBot(playerName));
        // }
        
        if (updateProfileTexture == profileUUID) {
            if (isBot(playerName)) {
                updateProfileTexture = TEXTURE_BOT_PROFILE;
                // if (VERBOSE_LOGGING) {
                //     llOwnerSay("🤖 [DEBUG] " + playerName + " is a bot, using bot texture");
                // }
            } else if (updateProfileTexture == "" || updateProfileTexture == "00000000-0000-0000-0000-000000000000") {
                updateProfileTexture = TEXTURE_DEFAULT_PROFILE;
                if (VERBOSE_LOGGING) {
                    llOwnerSay("❓ [DEBUG] " + playerName + " has empty/null UUID, using default texture");
                }
            } else {
                // CRITICAL: Set default texture FIRST, then request profile picture
                updateProfileTexture = TEXTURE_DEFAULT_PROFILE;
                
                // if (VERBOSE_LOGGING) {
                //     llOwnerSay("🔄 [DEBUG] " + playerName + " making HTTP request for UUID: " + profileUUID);
                // }
                
                // Request profile picture via HTTP (will update later)
                string URL_RESIDENT = "https://world.secondlife.com/resident/";
                key httpRequestID = llHTTPRequest(URL_RESIDENT + profileUUID, [HTTP_METHOD, "GET"], "");
                
                // Store the HTTP request mapping: requestID -> playerIndex
                httpRequests += [httpRequestID, playerIndex];
                
                // if (VERBOSE_LOGGING) {
                //     llOwnerSay("🔄 [Scoreboard] Requesting profile pic for " + playerName + ", showing default for now");
                // }
            }
        } else {
            // if (VERBOSE_LOGGING) {
            //     llOwnerSay("🔍 [DEBUG] " + playerName + " - profileTexture != profileUUID, not making HTTP request");
            // }
        }
    }
    
    // Enhanced visual effects for eliminated vs alive players
    vector primColor;
    if (lives <= 0) {
        // Eliminated player - red tint to make X more prominent
        primColor = <1.0, 0.3, 0.3>; // Red tinted
    } else {
        // Alive player - normal coloring
        primColor = <1.0, 1.0, 1.0>; // White/normal
    }
    
    // AGGRESSIVE VISUAL UPDATE: Force immediate rendering with glow
    llSetLinkPrimitiveParamsFast(updateProfilePrimIndex, [
        PRIM_TEXTURE, ALL_SIDES, updateProfileTexture, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, primColor, 1.0,
        PRIM_TEXT, "", <1,1,1>, 0.0, // Remove player name text
        PRIM_GLOW, ALL_SIDES, 0.01 // Tiny glow to force re-render
    ]);
    
    // Remove the glow after a moment to make it normal
    llSleep(0.1);
    llSetLinkPrimitiveParamsFast(updateProfilePrimIndex, [
        PRIM_GLOW, ALL_SIDES, 0.0 // Remove glow
    ]);
    
    // if (VERBOSE_LOGGING) {
    //     llOwnerSay("🖼️ [Scoreboard] Applied texture " + profileTexture + " to prim " + (string)profilePrimIndex + " with forced refresh");
    // }
    
    // Update hearts prim texture
    string updateHeartTexture = getHeartTexture(lives);
    llSetLinkPrimitiveParamsFast(updateHeartsPrimIndex, [
        PRIM_TEXTURE, ALL_SIDES, updateHeartTexture, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
        PRIM_TEXT, "", <1,0,0>, 0.0 // Remove lives text
    ]);
    
    // Update overlay prim - show red X if eliminated, hide if alive
    if (lives <= 0) {
        // Show red X overlay for eliminated player
        llSetLinkPrimitiveParamsFast(updateOverlayPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0, // Fully visible
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    } else {
        // Hide overlay for alive player (make it transparent)
        llSetLinkPrimitiveParamsFast(updateOverlayPrimIndex, [
            PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Fully transparent
            PRIM_TEXT, "", <1,1,1>, 0.0
        ]);
    }
    
    // Update player glow effects after display changes
    updatePlayerGlowEffects();
}

default {
    state_entry() {
        reportMemoryUsage("Scoreboard Manager");
        if (VERBOSE_LOGGING) {
            llOwnerSay("📈 Scoreboard Manager ready! (Linkset Version)");
            llOwnerSay("📈 Managing prims " + (string)FIRST_PROFILE_PRIM + "-" + (string)LAST_PROFILE_PRIM);
        }
        
        // Initialize profile picture extraction constants
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        
        // Reset background prim to proper state
        resetBackgroundPrim();
        
        // Reset manager cube to neutral state
        resetManagerCube();
        
        // Load persistent leaderboard data
        loadLeaderboardData();
        
        // Generate initial leaderboard
        generateLeaderboardText();
        
        // Ensure no glow effects remain from previous sessions
        currentPerilPlayer = "";
        currentWinner = "";
        updatePlayerGlowEffects();
        
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
                
                // Debug: Show what data scoreboard received - DISABLED to save memory
                // if (VERBOSE_LOGGING) {
                //     llOwnerSay("📈 Scoreboard received update: " + playerName + " has " + (string)lives + " hearts");
                // }
                
                updatePlayerDisplay(playerName, lives, profileUUID);
            }
        }
        else if (num == MSG_CLEAR_GAME) {
            // Reset to default state
            resetBackgroundPrim(); // Reset background to black
            resetManagerCube(); // Reset manager cube to neutral
            clearAllPlayers(); // Clear all current players
            updateActionsPrim("Title"); // Reset to title
            
            // Clear peril player and winner tracking and remove any remaining glow
            currentPerilPlayer = "";
            currentWinner = "";
            updatePlayerGlowEffects(); // This will remove glow from all players
            
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
        else if (num == MSG_UPDATE_PERIL_PLAYER) {
            // Update peril player and refresh glow effects
            string oldPeril = currentPerilPlayer;
            currentPerilPlayer = str;
            if (currentPerilPlayer == "NONE") {
                currentPerilPlayer = "";
            }
            
            if (VERBOSE_LOGGING && oldPeril != currentPerilPlayer) {
                llOwnerSay("🎯 Peril player changed from '" + oldPeril + "' to '" + currentPerilPlayer + "'");
            }
            
            // Update glow effects
            updatePlayerGlowEffects();
        }
        else if (num == MSG_UPDATE_WINNER) {
            // Update winner and refresh glow effects
            string oldWinner = currentWinner;
            currentWinner = str;
            if (currentWinner == "NONE") {
                currentWinner = "";
            }
            
            if (VERBOSE_LOGGING && oldWinner != currentWinner) {
                llOwnerSay("🏆 Winner changed from '" + oldWinner + "' to '" + currentWinner + "'");
            }
            
            // Update glow effects - winner glow overrides peril glow
            updatePlayerGlowEffects();
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
                    
                    // Update the physical prim using correct mapping
                    integer profilePrimIndex = getProfilePrimLink(playerIndex);
                    
                    // SAFETY CHECK
                    if (profilePrimIndex >= FIRST_PROFILE_PRIM && profilePrimIndex <= LAST_PROFILE_PRIM) {
                        // AGGRESSIVE VISUAL UPDATE: Force immediate rendering
                        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                            PRIM_TEXTURE, ALL_SIDES, profileUUID, <1,1,0>, <0,0,0>, 0.0,
                            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
                            PRIM_GLOW, ALL_SIDES, 0.01 // Tiny glow to force re-render
                        ]);
                        
                        // Remove the glow after a moment to make it normal
                        llSleep(0.1);
                        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                            PRIM_GLOW, ALL_SIDES, 0.0 // Remove glow
                        ]);
                        
                        if (VERBOSE_LOGGING) {
                            string playerName = llList2String(playerNames, playerIndex);
                            llOwnerSay("🖼️ Updated profile picture for " + playerName + " on prim " + (string)profilePrimIndex + " with forced refresh");
                        }
                    } else {
                        if (VERBOSE_LOGGING) {
                            llOwnerSay("❌ ERROR: HTTP response tried to update invalid prim " + (string)profilePrimIndex + " for player " + (string)playerIndex);
                        }
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
