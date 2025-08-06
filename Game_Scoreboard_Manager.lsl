// Game Scoreboard Manager - Shows current game players in grid layout
// Each player gets a prim showing profile picture + heart texture (lives)

// Heart texture UUIDs - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
integer LEADERBOARD_CHANNEL = -12346;
list playerWins = []; // Store wins data for persistent leaderboard
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
string TEXTURE_LEADERBOARD = "5748decc-f629-461c-9a36-a35a221fe21f"; // Leaderboard texture

// Status textures - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
string TEXTURE_PERIL = "c5676fec-0c85-5567-3dd8-f939234e21d9"; // Elimination texture
string TEXTURE_PERIL_SELECTED = "a53ff601-3c8a-e312-9e0e-f6fa76f6773a"; // Peril Selected texture
string TEXTURE_VICTORY = "ec5bf10e-4970-fb63-e7bf-751e1dc27a8d"; // Victory texture
string TEXTURE_PUNISHMENT = "acfabed0-84ad-bfd1-cdfc-2ada0aeeaa2f"; // Punishment texture (fallback)
string TEXTURE_DIRECT_HIT = "ecd2dba2-3969-6c39-ad59-319747307f55"; // Direct Hit texture
string TEXTURE_NO_SHIELD = "2440174f-e385-44e2-8016-ac34934f11f5"; // No Shield texture
string TEXTURE_PLOT_TWIST = "ec533379-4f7f-8183-e877-e68af703dcce"; // Plot Twist texture
string TEXTURE_TITLE = "624bb7a7-e856-965c-bae8-94d75226c1bc"; // Title texture

// Player data - used for BOTH current game display AND leaderboard
list playerNames = []; // Current game players for display
list playerLives = []; // Current game player lives
list playerProfiles = []; // Maps to profile texture UUIDs

// Leaderboard data (persistent - stored in linkset data)
list leaderboardNames = []; // Loaded from linkset data at startup
list leaderboardWins = []; // Loaded from linkset data at startup

// HTTP tracking
list profileRequests = []; // Track which profile requests belong to which player
list httpRequests = []; // Track HTTP requests for profile pictures

// Profile picture extraction constants
string profile_key_prefix = "<meta name=\"imageid\" content=\"";
string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
integer profile_key_prefix_length;
integer profile_img_prefix_length;

// Grid layout settings - dual prim approach
float PRIM_WIDTH = 0.2;   // Smaller width for individual prims
float PRIM_HEIGHT = 0.3;
float PRIM_DEPTH = 0;
float SPACING_X = 0.7;    // Space between player pairs
float SPACING_Y = 0.25;
float PRIM_OFFSET = 0.16; // Distance between profile and heart prims
integer GRID_COLS = 2;    // 2 columns, 5 rows for 10 players

// Additional prims settings
float BACKGROUND_WIDTH = 4.0;
float BACKGROUND_HEIGHT = 3;
float BACKGROUND_DEPTH = 0.01;
float ACTIONS_WIDTH = 4;
float ACTIONS_HEIGHT = 0.4;
float ACTIONS_DEPTH = 0.02;
float LEADERBOARD_WIDTH = 0.8;
float LEADERBOARD_HEIGHT = 1.2;
float LEADERBOARD_DEPTH = 0.02;

// Prim indices (after root prim = 1)
integer BACKGROUND_PRIM = 2;
integer ACTIONS_PRIM = 3;
integer FIRST_PLAYER_PRIM = 4; // Player prims start from index 4 (no leaderboard prim)

// Communication
integer SCOREBOARD_CHANNEL = -12345;

setupPlayerGrid() {
    // Create/position prims: 3 UI prims + 10 player slots (20 prims) = 23 prims total
    integer totalPrims = llGetNumberOfPrims();
    
    llOwnerSay("DEBUG: Total prims detected: " + (string)totalPrims);
    
    // Need 23 prims total: 1 root + 2 UI (background, actions) + 20 player prims (2 per player)
    // Note: Leaderboard is now a separate object
    if (totalPrims < 23) {
        llOwnerSay("Need 23 prims total: 1 root + 2 UI + 20 player prims (2 per player)");
        llOwnerSay("Current prims: " + (string)totalPrims + ", needed: 23");
        llOwnerSay("Note: Leaderboard is separate object now");
        return;
    }
    
    // Setup UI prims first
    setupUIPrims();
    
    llOwnerSay("DEBUG: Starting to position " + (string)totalPrims + " prims...");
    
    // Position prims for each player (2 prims per player)
    integer i;
    for (i = 0; i < 10; i++) {
        integer row = i / GRID_COLS;
        integer col = i % GRID_COLS;
        
        // Calculate base position for this player slot (relative to root prim)
        vector basePos = <col * SPACING_X - (GRID_COLS-1) * SPACING_X * 1.8,
                          0.0,
                          row * SPACING_Y - 1.0 * SPACING_Y + -1.5>;
        
        // Profile prim (left side)
        vector profilePos = basePos + <-PRIM_OFFSET, 0.0, 0.0>;
        integer profilePrimIndex = FIRST_PLAYER_PRIM + (i * 2); // Prims 4, 6, 8, 10...
        
        // Hearts prim (right side)
        vector heartsPos = basePos + <PRIM_OFFSET, 0.0, 0.0>;
        integer heartsPrimIndex = FIRST_PLAYER_PRIM + (i * 2) + 1; // Prims 5, 7, 9, 11...
        
        // Set profile prim properties
        if (profilePrimIndex <= totalPrims) {
            llOwnerSay("DEBUG: Setting profile prim " + (string)profilePrimIndex + " for player " + (string)i);
            llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                PRIM_POSITION, profilePos,
                PRIM_ROTATION, <-0.707107, 0.0, 0.0, 0.707107>, // Back to upright portrait rotation
                PRIM_SIZE, <PRIM_HEIGHT, PRIM_WIDTH, PRIM_DEPTH>, // Swap width/height for landscape
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0, // All faces
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0, // Fully opaque white
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
        } else {
            llOwnerSay("DEBUG: Skipping profile prim " + (string)profilePrimIndex + " (exceeds total prims)");
        }
        
        // Set hearts prim properties
        if (heartsPrimIndex <= totalPrims) {
            llSetLinkPrimitiveParamsFast(heartsPrimIndex, [
                PRIM_POSITION, heartsPos,
                PRIM_ROTATION, <-0.7, 0.0, 0.0, 0.7>, // Back to upright portrait rotation
                PRIM_SIZE, <PRIM_HEIGHT, PRIM_WIDTH, PRIM_DEPTH>, // Swap width/height for landscape
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0, // All faces
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0, // Fully opaque white
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
        }
    }
}

setupUIPrims() {
    // Background prim - centered behind the player grid
    vector bgPosition = <0.0, 0.04, -1.6>;
    llOwnerSay("DEBUG: Setting background prim " + (string)BACKGROUND_PRIM + " to position " + (string)bgPosition);
    llSetLinkPrimitiveParamsFast(BACKGROUND_PRIM, [
        PRIM_POSITION, bgPosition, // Behind the board and higher up
        PRIM_ROTATION, <0.0, 0.0, -0.04, 1.0>, // No rotation
        PRIM_SIZE, <BACKGROUND_WIDTH, BACKGROUND_DEPTH, BACKGROUND_HEIGHT>,
        PRIM_TEXTURE, ALL_SIDES, TEXTURE_BACKGROUND, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black background color
        PRIM_TEXT, "", <1,1,1>, 0.0
    ]);
    
    // Actions/status prim - rectangle above the player grid
    llSetLinkPrimitiveParamsFast(ACTIONS_PRIM, [
        PRIM_POSITION, <0.0, 0.01, -0.3>, // Even higher above the grid
        PRIM_ROTATION, <0.0, 0.0, -0.04, 1.0>, // No rotation
        PRIM_SIZE, <ACTIONS_WIDTH, ACTIONS_DEPTH, ACTIONS_HEIGHT>,
        PRIM_TEXTURE, ALL_SIDES, TEXTURE_TITLE, <1,1,0>, <0,0,0>, 0.0, // Start with title texture
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0, // White for texture visibility
        PRIM_TEXT, "", <0,0,0>, 0.0 // No floating text
    ]);
    
    // Note: Leaderboard is now a separate object
    
    llOwnerSay("DEBUG: UI prims setup complete");
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
        llOwnerSay("DEBUG: Unrecognized status '" + status + "' - keeping current texture");
        return; // Don't change texture for unrecognized statuses
    }
    
    llSetLinkPrimitiveParamsFast(ACTIONS_PRIM, [
        PRIM_TEXTURE, ALL_SIDES, textureToUse, <1,1,0>, <0,0,0>, 0.0,
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove existing floating text
    ]);
}

// XyzzyText Communication Constants
integer DISPLAY_STRING = 204000;
integer DISPLAY_EXTENDED = 204001;

// Generate leaderboard text for triple XyzzyText display (15 characters per line split across 3 prims)
generateLeaderboardText() {
    list sortedData = getSortedLeaderboard();
    integer maxDisplay = llGetListLength(sortedData);
    if (maxDisplay > 11) maxDisplay = 11; // Show top 11 entries to fit in display
    
    // Triple prim approach - split lines between left, middle, and right prims
    string leftText = "WINS:";
    string middleText = "     "; // 5 spaces to align with left prim
    string rightText = "     "; // 5 spaces to align with left prim
    
    integer i;
    for (i = 0; i < maxDisplay; i++) {
        list playerData = llParseString2List(llList2String(sortedData, i), [":"], []);
        string playerName = llList2String(playerData, 0);
        string winsText = llList2String(playerData, 1);
        
        // Create 15-character line: "PlayerNameHere  Wins" (player name + padding + wins)
        // Truncate name to max 12 characters to leave room for wins
        if (llStringLength(playerName) > 12) {
            playerName = llGetSubString(playerName, 0, 11);
        }
        
        // Format the complete line (15 chars total)
        string fullLine = playerName;
        
        // Add padding spaces
        integer padding = 13 - llStringLength(playerName); // Leave 2 chars for wins
        integer j;
        for (j = 0; j < padding; j++) {
            fullLine += " ";
        }
        
        // Add wins (max 2 digits)
        if (llStringLength(winsText) > 2) {
            winsText = llGetSubString(winsText, 0, 1); // Truncate to 2 digits
        }
        fullLine += winsText;
        
        // Ensure exactly 15 characters
        if (llStringLength(fullLine) > 15) {
            fullLine = llGetSubString(fullLine, 0, 14);
        } else if (llStringLength(fullLine) < 15) {
            // Pad with spaces if needed
            while (llStringLength(fullLine) < 15) {
                fullLine += " ";
            }
        }
        
        // Split the 15-character line: 5 chars each to left, middle, right prims
        string leftPart = llGetSubString(fullLine, 0, 4);   // Characters 0-4
        string middlePart = llGetSubString(fullLine, 5, 9);  // Characters 5-9
        string rightPart = llGetSubString(fullLine, 10, 14); // Characters 10-14
        
        leftText += "\n" + leftPart;
        middleText += "\n" + middlePart;
        rightText += "\n" + rightPart;
    }
    
    // If no data, show empty message
    if (maxDisplay == 0) {
        leftText = "NO   ";
        middleText = "GAMES";
        rightText = "     ";
    }
    
    // Send to separate leaderboard object via chat
    llOwnerSay("DEBUG: Sending to LEFT XyzzyText: " + leftText);
    llOwnerSay("DEBUG: Sending to MIDDLE XyzzyText: " + middleText);
    llOwnerSay("DEBUG: Sending to RIGHT XyzzyText: " + rightText);
    
    // Send to leaderboard bridge in separate object
    llRegionSay(LEADERBOARD_CHANNEL, "LEFT_TEXT|" + leftText);
    llRegionSay(LEADERBOARD_CHANNEL, "MIDDLE_TEXT|" + middleText);
    llRegionSay(LEADERBOARD_CHANNEL, "RIGHT_TEXT|" + rightText);
    
    // Also create combined floating text as backup display method
    string combinedText = "WINS:\n";
    for (i = 0; i < maxDisplay; i++) {
        list playerData = llParseString2List(llList2String(sortedData, i), [":"], []);
        string playerName = llList2String(playerData, 0);
        string winsText = llList2String(playerData, 1);
        
        if (llStringLength(playerName) > 12) {
            playerName = llGetSubString(playerName, 0, 11);
        }
        
        combinedText += playerName + ": " + winsText + "\n";
    }
    
    if (maxDisplay == 0) {
        combinedText = "No games played yet";
    }
    
    // Note: Leaderboard is now in separate object - no prim to update here
}

// Update leaderboard prim with current standings and update persistent data
updateLeaderboard(list topPlayers) {
    generateLeaderboardText();
}

// Handle game won message
handleGameWon(string winnerName) {
    integer playerIndex = llListFindList(leaderboardNames, [winnerName]);
    
    if (playerIndex == -1) {
        leaderboardNames += [winnerName];
        leaderboardWins += [1];
    } else {
        integer currentWins = llList2Integer(leaderboardWins, playerIndex);
        leaderboardWins = llListReplaceList(leaderboardWins, [currentWins + 1], playerIndex, playerIndex);
    }
    
    saveLeaderboardData();
    updateLeaderboard(leaderboardNames);
}

// Sort leaderboard by wins
list getSortedLeaderboard() {
    list combined = [];
    integer i;
    
    for (i = 0; i < llGetListLength(leaderboardNames); i++) {
        string playerName = llList2String(leaderboardNames, i);
        integer wins = llList2Integer(leaderboardWins, i);
        combined += [playerName + ":" + (string)wins];
    }
    
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

// Save leaderboard data
saveLeaderboardData() {
    integer i;
    llLinksetDataWrite("lb_count", (string)llGetListLength(leaderboardNames));
    for (i = 0; i < llGetListLength(leaderboardNames); i++) {
        string playerName = llList2String(leaderboardNames, i);
        integer wins = llList2Integer(leaderboardWins, i);
        llLinksetDataWrite("lb_player_" + (string)i, playerName);
        llLinksetDataWrite("lb_wins_" + (string)i, (string)wins);
    }
}

// Load leaderboard data
loadLeaderboardData() {
    string countStr = llLinksetDataRead("lb_count");
    if (countStr == "") return;
    
    integer count = (integer)countStr;
    leaderboardNames = [];
    leaderboardWins = [];
    integer i;
    for (i = 0; i < count; i++) {
        string playerName = llLinksetDataRead("lb_player_" + (string)i);
        string winsStr = llLinksetDataRead("lb_wins_" + (string)i);
        if (playerName != "" && winsStr != "") {
            leaderboardNames += [playerName];
            leaderboardWins += [(integer)winsStr];
        }
    }
}

// Reset leaderboard data
resetLeaderboard() {
    leaderboardNames = [];
    leaderboardWins = [];
    integer i;
    for (i = 0; i < 100; i++) {
        llLinksetDataDelete("lb_player_" + (string)i);
        llLinksetDataDelete("lb_wins_" + (string)i);
    }
    llLinksetDataDelete("lb_count");
    updateLeaderboard([]);
}

// Clear all current players from the scoreboard
clearAllPlayers() {
    llOwnerSay("DEBUG: Clearing all players from scoreboard");
    
    // Clear ONLY current game player data lists (NOT leaderboard data)
    playerNames = [];
    playerLives = [];
    playerProfiles = [];
    
    // NOTE: leaderboardNames and leaderboardWins are NOT cleared - they persist
    
    // Clear any pending HTTP requests
    httpRequests = [];
    profileRequests = [];
    
    // Reset all player prims to default state
    integer i;
    for (i = 0; i < 10; i++) {
        integer profilePrimIndex = FIRST_PLAYER_PRIM + (i * 2);
        integer heartsPrimIndex = FIRST_PLAYER_PRIM + (i * 2) + 1;
        
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

// Check if a player name indicates it's a bot
integer isBot(string playerName) {
    return (llSubStringIndex(playerName, "TestBot") == 0);
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
            llOwnerSay("WARNING: Maximum 10 players supported, ignoring: " + playerName);
            return;
        }
        
        // Add to tracking lists
        playerNames += [playerName];
        playerLives += [lives];
        playerProfiles += [profileUUID];
        
        llOwnerSay("DEBUG: Added new player " + playerName + " at slot " + (string)playerIndex);
    } else {
        // Update existing player
        playerLives = llListReplaceList(playerLives, [lives], playerIndex, playerIndex);
        // Don't overwrite cached profile texture with original UUID on updates
        // playerProfiles = llListReplaceList(playerProfiles, [profileUUID], playerIndex, playerIndex);
        
        llOwnerSay("DEBUG: Updated player " + playerName + " at slot " + (string)playerIndex + " with " + (string)lives + " lives");
    }
    
    // Update the physical prims for this player
    integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
    integer heartsPrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2) + 1;
    
    // Update profile prim texture
    string profileTexture = profileUUID;
    
    // Check if we already have a cached profile texture for this player
    if (playerIndex < llGetListLength(playerProfiles)) {
        string cachedTexture = llList2String(playerProfiles, playerIndex);
        if (cachedTexture != "" && cachedTexture != profileUUID && 
            cachedTexture != TEXTURE_DEFAULT_PROFILE && cachedTexture != TEXTURE_BOT_PROFILE) {
            // We have a previously fetched profile picture, use it
            profileTexture = cachedTexture;
            llOwnerSay("DEBUG: Using cached profile texture for " + playerName);
        }
    }
    
    // If no cached texture or using original UUID, determine what to use
    if (profileTexture == profileUUID) {
        if (isBot(playerName)) {
            profileTexture = TEXTURE_BOT_PROFILE;
            llOwnerSay("DEBUG: Using bot profile texture for " + playerName);
        } else if (profileTexture == "" || profileTexture == "00000000-0000-0000-0000-000000000000") {
            profileTexture = TEXTURE_DEFAULT_PROFILE;
            llOwnerSay("DEBUG: Using default profile texture for " + playerName);
        } else {
            // Request profile picture via HTTP (the correct method!)
            llOwnerSay("DEBUG: Requesting profile picture via HTTP for avatar UUID: " + profileUUID);
            string URL_RESIDENT = "https://world.secondlife.com/resident/";
            key httpRequestID = llHTTPRequest(URL_RESIDENT + profileUUID, [HTTP_METHOD, "GET"], "");
            
            // Store the HTTP request mapping: requestID -> playerIndex
            httpRequests += [httpRequestID, playerIndex];
            
            // For now, use the avatar UUID directly as texture
            llOwnerSay("DEBUG: Setting temporary profile texture: " + profileTexture);
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
        // Clear any old floating text on root prim
        llSetText("", <1,1,1>, 0.0);
        
        // Initialize profile picture extraction constants
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        
        llListen(SCOREBOARD_CHANNEL, "", "", "");
        llListen(LEADERBOARD_CHANNEL, "", "", "");
        loadLeaderboardData();
        setupPlayerGrid();
        
        // Generate initial leaderboard texture
        llSetTimerEvent(1.0); // Short delay to ensure prims are set up
        
        llOwnerSay("Game Scoreboard Manager ready - Grid layout initialized");
        llOwnerSay("Touch me to re-run setup.");
    }
    
    timer() {
        llSetTimerEvent(0.0); // Stop timer
        generateLeaderboardText(); // Generate initial leaderboard
    }
    
    listen(integer channel, string senderName, key id, string message) {
        if (channel == SCOREBOARD_CHANNEL) {
            if (llSubStringIndex(message, "PLAYER_UPDATE|") == 0) {
                // Handle player updates here if needed
                // Format: PLAYER_UPDATE|PlayerName|Lives|ProfileUUID
                llOwnerSay("DEBUG: Received player update: " + message);
                
                list parts = llParseString2List(message, ["|"], []);
                if (llGetListLength(parts) >= 4) {
                    string playerName = llList2String(parts, 1);
                    integer lives = (integer)llList2String(parts, 2);
                    string profileUUID = llList2String(parts, 3);
                    
                    updatePlayerDisplay(playerName, lives, profileUUID);
                }
            }
            else if (message == "CLEAR_GAME") {
                // Reset to default state
                clearAllPlayers(); // Clear all current players
                updateActionsPrim("Title"); // Reset to title instead of "Game Cleared"
                generateLeaderboardText(); // Refresh leaderboard display
            }
            else if (llSubStringIndex(message, "GAME_START|") == 0) {
                updateActionsPrim("Title");
            }
            else if (llSubStringIndex(message, "GAME_STATUS|") == 0) {
                // Format: GAME_STATUS|StatusText
                list parts = llParseString2List(message, ["|"], []);
                if (llGetListLength(parts) >= 2) {
                    string status = llList2String(parts, 1);
                    updateActionsPrim(status);
                }
            }
            else if (llSubStringIndex(message, "LEADERBOARD|") == 0) {
                // Format: LEADERBOARD|Player1:Score1|Player2:Score2|...
                list parts = llParseString2List(message, ["|"], []);
                list playerData = llDeleteSubList(parts, 0, 0); // Remove "LEADERBOARD"
                updateLeaderboard(playerData);
            } else if (llSubStringIndex(message, "GAME_WON|") == 0) {
                list parts = llParseString2List(message, ["|"], []);
                if (llGetListLength(parts) >= 2) {
                    string winnerName = llList2String(parts, 1);
                    handleGameWon(winnerName);
                }
            } else if (llSubStringIndex(message, "RESET_LEADERBOARD") == 0) {
                resetLeaderboard();
            }
        }
    }
    
    touch_start(integer total_number) {
        // Owner can touch to manually re-run setup
        if (llDetectedKey(0) == llGetOwner()) {
            llOwnerSay("Owner touched - re-running setup...");
            setupPlayerGrid();
        }
    }
    
    dataserver(key query_id, string data) {
        // Handle profile picture data responses
        integer requestIndex = llListFindList(profileRequests, [query_id]);
        if (requestIndex != -1) {
            // Found the request - get the corresponding player index and data type
            integer playerIndex = llList2Integer(profileRequests, requestIndex + 1);
            integer dataType = llList2Integer(profileRequests, requestIndex + 2);
            
            llOwnerSay("DEBUG: Data type " + (string)dataType + " returned: '" + data + "' for player at index " + (string)playerIndex);
            
            // Check if this looks like a valid texture UUID (36 characters, proper format)
            if (llStringLength(data) == 36 && llSubStringIndex(data, "-") != -1) {
                llOwnerSay("*** FOUND IT! Data type " + (string)dataType + " returned valid UUID: " + data + " ***");
                
                // Update the profile texture for this player
                integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                
                llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                    PRIM_TEXTURE, ALL_SIDES, data, <1,1,0>, <0,0,0>, 0.0,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                ]);
                
                llOwnerSay("Profile picture updated successfully for " + llList2String(playerNames, playerIndex));
            } else {
                // Not a valid UUID, continue testing other data types
                llOwnerSay("Data type " + (string)dataType + " did not return valid UUID");
            }
            
            // Clean up the completed request (3 elements: requestID, playerIndex, dataType)
            profileRequests = llDeleteSubList(profileRequests, requestIndex, requestIndex + 2);
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        // Handle HTTP response for profile picture requests
        integer requestIndex = llListFindList(httpRequests, [request_id]);
        if (requestIndex != -1) {
            integer playerIndex = llList2Integer(httpRequests, requestIndex + 1);
            
            llOwnerSay("DEBUG: HTTP response received for player at index " + (string)playerIndex + ", status: " + (string)status);
            
            if (status == 200) {
                // Try to extract profile picture UUID from HTML
                integer s1 = llSubStringIndex(body, profile_key_prefix);
                integer s1l = profile_key_prefix_length;
                
                if (s1 == -1) {
                    // Second try with img tag
                    s1 = llSubStringIndex(body, profile_img_prefix);
                    s1l = profile_img_prefix_length;
                    llOwnerSay("DEBUG: Trying img tag method for profile picture extraction");
                } else {
                    llOwnerSay("DEBUG: Found meta tag with profile image");
                }
                
                if (s1 == -1) {
                    // Still no match - use default texture
                    llOwnerSay("DEBUG: No profile picture found in HTML for player " + llList2String(playerNames, playerIndex));
                    
                    integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                    llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                        PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
                        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                    ]);
                } else {
                    // Extract the UUID
                    s1 += s1l;
                    key profileUUID = llGetSubString(body, s1, s1 + 35);
                    
                    if (profileUUID == NULL_KEY) {
                        llOwnerSay("DEBUG: Extracted NULL_KEY, using default texture");
                        integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                            PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
                            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                        ]);
                    } else {
                        llOwnerSay("*** SUCCESS! Found profile picture UUID: " + (string)profileUUID + " for player " + llList2String(playerNames, playerIndex) + " ***");
                        
                        // Cache the profile picture UUID
                        playerProfiles = llListReplaceList(playerProfiles, [(string)profileUUID], playerIndex, playerIndex);
                        
                        // Update the profile texture
                        integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                            PRIM_TEXTURE, ALL_SIDES, (string)profileUUID, <1,1,0>, <0,0,0>, 0.0,
                            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                        ]);
                    }
                }
            } else {
                llOwnerSay("DEBUG: HTTP request failed with status " + (string)status + " for player " + llList2String(playerNames, playerIndex));
                
                // Use default texture on HTTP failure
                integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                    PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                ]);
            }
            
            // Clean up the completed HTTP request (2 elements: requestID, playerIndex)
            httpRequests = llDeleteSubList(httpRequests, requestIndex, requestIndex + 1);
        }
    }
}
