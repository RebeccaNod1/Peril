// Game Scoreboard Manager - Shows current game players in grid layout
// Each player gets a prim showing profile picture + heart texture (lives)

// =============================================================================
// CONTROLLER DISCOVERY SYSTEM
// =============================================================================

// Fixed discovery channel for finding controller
integer DISCOVERY_CHANNEL = -77000;

// Base channel offset - should match Main.lsl
integer CHANNEL_BASE = -77000;

// Controller discovery state
key CONTROLLER_KEY = NULL_KEY;
integer DISCOVERY_ATTEMPTS = 0;
integer MAX_DISCOVERY_ATTEMPTS = 10;
float MAX_CONTROLLER_DISTANCE = 75.0; // Maximum distance to accept controller (meters)
integer INITIALIZED = FALSE; // Flag to prevent multiple initializations

// Calculate channels dynamically using controller key for consistency
integer calculateChannelWithController(integer offset, key controllerKey) {
    // Use owner's key AND CONTROLLER's key to ensure all objects use same channels
    string ownerStr = (string)llGetOwner();
    string controllerStr = (string)controllerKey;
    string combinedStr = ownerStr + controllerStr;
    
    // Create a more unique hash using both keys
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2; // Creates 0-255 range
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Legacy function for backward compatibility (uses own key)
integer calculateChannel(integer offset) {
    string ownerStr = (string)llGetOwner();
    string objectStr = (string)llGetKey();
    string combinedStr = ownerStr + objectStr;
    
    string hashStr = llMD5String(combinedStr, 0);
    integer hash1 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 0, 0));
    integer hash2 = llSubStringIndex("0123456789abcdef", llGetSubString(hashStr, 1, 1));
    integer combinedHash = hash1 * 16 + hash2;
    
    return CHANNEL_BASE - (offset * 1000) - combinedHash;
}

// Dynamic channel variables
integer SCOREBOARD_CHANNEL;
integer SCOREBOARD_CHANNEL_2; 
integer SCOREBOARD_CHANNEL_3;
integer LEADERBOARD_CHANNEL; // Dynamic replacement for hardcoded channel
integer DICE_CHANNEL; // Dynamic replacement for hardcoded channel

// Controller discovery function
startControllerDiscovery() {
    llOwnerSay("📡 [Scoreboard] Starting controller discovery...");
    
    // Listen on discovery channel
    llListen(DISCOVERY_CHANNEL, "", "", "");
    
    // Broadcast discovery request
    llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|scoreboard");
    
    // Reset discovery attempts
    DISCOVERY_ATTEMPTS = 0;
    
    // Set timer for retry if needed
    llSetTimerEvent(5.0);
}

// Channel initialization function (with controller discovery)
initializeChannels() {
    if (CONTROLLER_KEY != NULL_KEY) {
        // Use controller-based channels for consistency
        SCOREBOARD_CHANNEL = calculateChannelWithController(6, CONTROLLER_KEY);     // ~-83000 range (Status messages)
        SCOREBOARD_CHANNEL_2 = calculateChannelWithController(7, CONTROLLER_KEY);   // ~-84000 range (Player updates)  
        SCOREBOARD_CHANNEL_3 = calculateChannelWithController(8, CONTROLLER_KEY);   // ~-85000 range (Dice rolls)
    } else {
        // Fallback to legacy channels during discovery
        SCOREBOARD_CHANNEL = calculateChannel(6);     // ~-83000 range (Status messages)
        SCOREBOARD_CHANNEL_2 = calculateChannel(7);   // ~-84000 range (Player updates)  
        SCOREBOARD_CHANNEL_3 = calculateChannel(8);   // ~-85000 range (Dice rolls)
    }
    
    // Use same channels for different purposes but with clear naming
    LEADERBOARD_CHANNEL = SCOREBOARD_CHANNEL_2;   // Use player update channel for leaderboard messages
    DICE_CHANNEL = SCOREBOARD_CHANNEL_3;          // Use dice channel for dice display
    
    // Report channels to owner for debugging
    llOwnerSay("🔧 [Scoreboard] Dynamic channels initialized:");
    llOwnerSay("  Status (CH1): " + (string)SCOREBOARD_CHANNEL);
    llOwnerSay("  Players (CH2): " + (string)SCOREBOARD_CHANNEL_2);
    llOwnerSay("  Dice (CH3): " + (string)SCOREBOARD_CHANNEL_3);
}

// Heart texture UUIDs - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
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
list leaderboardLosses = []; // Loaded from linkset data at startup

// HTTP tracking
list profileRequests = []; // Track which profile requests belong to which player
list httpRequests = []; // Track HTTP requests for profile pictures

// Profile picture extraction constants
string profile_key_prefix = "<meta name=\"imageid\" content=\"";
string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
integer profile_key_prefix_length;
integer profile_img_prefix_length;

// Grid layout settings - dual prim approach
float PRIM_WIDTH = .4;   // Smaller width for individual prims
float PRIM_HEIGHT = .4;
float PRIM_DEPTH = 0;
float SPACING_X = 1;    // Space between player pairs
float SPACING_Y = .5;
float PRIM_OFFSET = 0.2; // Distance between profile and heart prims
integer GRID_COLS = 2;    // 2 columns, 5 rows for 10 players

// Additional prims settings
float BACKGROUND_WIDTH = 6;
float BACKGROUND_HEIGHT = 4;
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

// Communication - channels are now set dynamically

// Listen handle management
integer scoreboardHandle = -1;
integer leaderboardHandle = -1;
integer diceHandle = -1;
integer dialogHandle = -1;

setupPlayerGrid() {
    // Create/position prims: 3 UI prims + 10 player slots (20 prims) = 23 prims total
    integer totalPrims = llGetNumberOfPrims();
    
    
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
    
    
    // Position prims for each player (2 prims per player)
    integer i;
    for (i = 0; i < 10; i++) {
        integer row = i / GRID_COLS;
        integer col = i % GRID_COLS;
        
        // Calculate base position for this player slot (relative to root prim)
        vector basePos = <col * SPACING_X - (GRID_COLS-1) * SPACING_X * 2.2,
                          0.0,
                          row * SPACING_Y - 2.5 * SPACING_Y + -1.5>;
        
        // Profile prim (left side)
        vector profilePos = basePos + <-PRIM_OFFSET, 0.0, 0.0>;
        integer profilePrimIndex = FIRST_PLAYER_PRIM + (i * 2); // Prims 4, 6, 8, 10...
        
        // Hearts prim (right side)
        vector heartsPos = basePos + <PRIM_OFFSET, 0.0, 0.0>;
        integer heartsPrimIndex = FIRST_PLAYER_PRIM + (i * 2) + 1; // Prims 5, 7, 9, 11...
        
        // Set profile prim properties
        if (profilePrimIndex <= totalPrims) {
            llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                PRIM_POSITION, profilePos,
                PRIM_ROTATION, <-0.707107, 0.0, 0.0, 0.707107>, // Back to upright portrait rotation
                PRIM_SIZE, <PRIM_HEIGHT, PRIM_WIDTH, PRIM_DEPTH>, // Swap width/height for landscape
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0, // All faces
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0, // Fully opaque white
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
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
    vector bgPosition = <0.0, 0.05, -2>;
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
    
    llSetLinkPrimitiveParamsFast(ACTIONS_PRIM, [
        PRIM_TEXTURE, ALL_SIDES, textureToUse, <1,1,0>, <0,0,0>, 0.0,
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove existing floating text
    ]);
}

// XyzzyText Communication Constants
integer DISPLAY_STRING = 204000;
integer DISPLAY_EXTENDED = 204001;
// DICE_CHANNEL now set dynamically in initializeChannels()

// Generate leaderboard text for quad XyzzyText display (40 characters per line split across 4 prims)
generateLeaderboardText() {
    list sortedData = getSortedLeaderboard();
    integer dataCount = llGetListLength(sortedData);
    
    // Quad prim approach - split lines between left, middle-left, middle-right, and right prims
    // Header: "LEADERBOARD" (11 chars) + spaces to make 40 total, then split into 10-char chunks
    string headerLine = "LEADERBOARD                             "; // Exactly 40 chars: LEADERBOARD (11) + 29 spaces
    
    // Split header into 4 parts of 10 characters each
    string leftText = llGetSubString(headerLine, 0, 9);    // Characters 0-9: "LEADERBOAR" (first 10 chars)
    string middleLeftText = llGetSubString(headerLine, 10, 19);  // Characters 10-19: "          " (10 spaces)
    string middleRightText = llGetSubString(headerLine, 20, 29); // Characters 20-29: "          " (10 spaces)
    string rightText = llGetSubString(headerLine, 30, 39);  // Characters 30-39: "          " (10 spaces)
    
    // Show positions 1-11, filling in player data where available
    integer i;
    for (i = 0; i < 11; i++) {
        string fullLine;
        
        if (i < dataCount) {
            // We have data for this position
            list playerData = llParseString2List(llList2String(sortedData, i), [":"], []);
            string playerName = llList2String(playerData, 0);
            string winsText = llList2String(playerData, 1);
            string lossesText = llList2String(playerData, 2);
            
            // Format: "1. PlayerName               W:xx L:yy"
            // With 40 chars: position(3) + name(27) + stats(10) = 40 total
            string position;
            if (i < 9) {
                position = (string)(i + 1) + ". "; // "1. ", "2. ", etc.
            } else {
                position = (string)(i + 1) + "."; // "10.", "11." (no extra space)
            }
            
            // Format wins and losses with 2-digit limit
            if (llStringLength(winsText) > 2) {
                winsText = llGetSubString(winsText, 0, 1);
            }
            if (llStringLength(lossesText) > 2) {
                lossesText = llGetSubString(lossesText, 0, 1);
            }
            
            string statsText = "W:" + winsText + " L:" + lossesText; // e.g., "W:12 L:3"
            
            // Calculate max name length (40 - position - stats - padding)
            integer maxNameLength = 40 - llStringLength(position) - llStringLength(statsText) - 1; // -1 for space
            
            if (llStringLength(playerName) > maxNameLength) {
                playerName = llGetSubString(playerName, 0, maxNameLength - 1);
            }
            
            fullLine = position + playerName;
            
            // Add padding spaces before stats
            integer padding = 40 - llStringLength(fullLine) - llStringLength(statsText);
            integer j;
            for (j = 0; j < padding && padding > 0; j++) {
                fullLine += " ";
            }
            
            fullLine += statsText;
        } else {
            // No data for this position, show empty slot
            string position;
            if (i < 9) {
                position = (string)(i + 1) + ". "; // "1. ", "2. ", etc.
            } else {
                position = (string)(i + 1) + "."; // "10.", "11." (no extra space)
            }
            fullLine = position;
            // Pad to 40 characters
            while (llStringLength(fullLine) < 40) {
                fullLine += " ";
            }
        }
        
        // Ensure exactly 40 characters
        if (llStringLength(fullLine) > 40) {
            fullLine = llGetSubString(fullLine, 0, 39);
        } else if (llStringLength(fullLine) < 40) {
            while (llStringLength(fullLine) < 40) {
                fullLine += " ";
            }
        }
        
        // Split the 40-character line: 10 chars each to left, middle-left, middle-right, right prims
        string leftPart = llGetSubString(fullLine, 0, 9);   // Characters 0-9
        string middleLeftPart = llGetSubString(fullLine, 10, 19);  // Characters 10-19
        string middleRightPart = llGetSubString(fullLine, 20, 29); // Characters 20-29
        string rightPart = llGetSubString(fullLine, 30, 39); // Characters 30-39
        
        leftText += "\n" + leftPart;
        middleLeftText += "\n" + middleLeftPart;
        middleRightText += "\n" + middleRightPart;
        rightText += "\n" + rightPart;
    }
    
    // We always show exactly 12 lines (header + 11 positions)
    integer totalLines = 12;
    integer currentLines = 12; // Header + 11 positions
    
    // Send to separate leaderboard object via chat
    
    // Send to leaderboard bridge in separate object
    llRegionSay(LEADERBOARD_CHANNEL, "LEFT_TEXT|" + leftText);
    llRegionSay(LEADERBOARD_CHANNEL, "MIDDLE_LEFT_TEXT|" + middleLeftText);
    llRegionSay(LEADERBOARD_CHANNEL, "MIDDLE_RIGHT_TEXT|" + middleRightText);
    llRegionSay(LEADERBOARD_CHANNEL, "RIGHT_TEXT|" + rightText);
    
    // Also create combined floating text as backup display method
    string combinedText = "Leaderboard:\n";
    for (i = 0; i < dataCount; i++) {
        list playerData = llParseString2List(llList2String(sortedData, i), [":"], []);
        string playerName = llList2String(playerData, 0);
        string winsText = llList2String(playerData, 1);
        
        if (llStringLength(playerName) > 12) {
            playerName = llGetSubString(playerName, 0, 11);
        }
        
        combinedText += (string)(i + 1) + ". " + playerName + ": " + winsText + "\n";
    }
    
    if (dataCount == 0) {
        combinedText = "Leaderboard: No games played yet";
    }
    
    // Note: Leaderboard is now in separate object - no prim to update here
}

// Update leaderboard prim with current standings and update persistent data
updateLeaderboard(list topPlayers) {
    generateLeaderboardText();
}

// Generate dice roll display text for dual XyzzyText display (20 characters total: 10 chars per prim)
generateDiceRollText(string playerName, integer diceValue, string rollType) {
    string fullLine;
    
    if (rollType == "CLEAR") {
        // Clear the dice display
        fullLine = "                    "; // 20 spaces
    } else {
        // Format: "Bob rolled 6" or "TestBot1 rolled 12" etc.
        string diceStr = (string)diceValue;
        string displayName = playerName;
        
        // Calculate available space: 20 total - " rolled " (8) - dice value (1-2 chars) = 11-10 chars for name
        integer maxNameLength = 20 - 8 - llStringLength(diceStr); // -8 for " rolled "
        
        if (llStringLength(displayName) > maxNameLength) {
            displayName = llGetSubString(displayName, 0, maxNameLength - 1);
        }
        
        fullLine = displayName + " rolled " + diceStr;
        
        // Pad to exactly 20 characters
        while (llStringLength(fullLine) < 20) {
            fullLine += " ";
        }
    }
    
    // Ensure exactly 20 characters
    if (llStringLength(fullLine) > 20) {
        fullLine = llGetSubString(fullLine, 0, 19);
    }
    
    // Split into 2 parts: 10 chars each for left and right prims
    string leftPart = llGetSubString(fullLine, 0, 9);   // Characters 0-9
    string rightPart = llGetSubString(fullLine, 10, 19); // Characters 10-19
    
    
    // Send to dice display XyzzyText prims
    llRegionSay(DICE_CHANNEL, "DICE_LEFT|" + leftPart);
    llRegionSay(DICE_CHANNEL, "DICE_RIGHT|" + rightPart);
}

// Handle game won message
handleGameWon(string winnerName) {
    integer playerIndex = llListFindList(leaderboardNames, [winnerName]);
    
    if (playerIndex == -1) {
        leaderboardNames += [winnerName];
        leaderboardWins += [1];
        leaderboardLosses += [0]; // No losses for new winner
    } else {
        integer currentWins = llList2Integer(leaderboardWins, playerIndex);
        leaderboardWins = llListReplaceList(leaderboardWins, [currentWins + 1], playerIndex, playerIndex);
    }
    
    saveLeaderboardData();
    updateLeaderboard(leaderboardNames);
}

// Handle game lost message
handleGameLost(string loserName) {
    integer playerIndex = llListFindList(leaderboardNames, [loserName]);
    
    if (playerIndex == -1) {
        leaderboardNames += [loserName];
        leaderboardWins += [0]; // No wins for new loser
        leaderboardLosses += [1];
    } else {
        integer currentLosses = 0;
        if (playerIndex < llGetListLength(leaderboardLosses)) {
            currentLosses = llList2Integer(leaderboardLosses, playerIndex);
        }
        // Extend losses list if needed
        while (llGetListLength(leaderboardLosses) <= playerIndex) {
            leaderboardLosses += [0];
        }
        leaderboardLosses = llListReplaceList(leaderboardLosses, [currentLosses + 1], playerIndex, playerIndex);
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
        integer losses = 0;
        if (i < llGetListLength(leaderboardLosses)) {
            losses = llList2Integer(leaderboardLosses, i);
        }
        combined += [playerName + ":" + (string)wins + ":" + (string)losses];
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
        integer losses = llList2Integer(leaderboardLosses, i);
        llLinksetDataWrite("lb_player_" + (string)i, playerName);
        llLinksetDataWrite("lb_wins_" + (string)i, (string)wins);
        llLinksetDataWrite("lb_losses_" + (string)i, (string)losses);
    }
}

// Load leaderboard data
loadLeaderboardData() {
    string countStr = llLinksetDataRead("lb_count");
    if (countStr == "") return;
    
    integer count = (integer)countStr;
    leaderboardNames = [];
    leaderboardWins = [];
    leaderboardLosses = [];
    integer i;
    for (i = 0; i < count; i++) {
        string playerName = llLinksetDataRead("lb_player_" + (string)i);
        string winsStr = llLinksetDataRead("lb_wins_" + (string)i);
        string lossesStr = llLinksetDataRead("lb_losses_" + (string)i);
        if (playerName != "" && winsStr != "") {
            leaderboardNames += [playerName];
            leaderboardWins += [(integer)winsStr];
            leaderboardLosses += [(integer)lossesStr]; // Default to 0 if empty
        }
    }
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
    updateLeaderboard([]);
}

// Clear all current players from the scoreboard
clearAllPlayers() {
    
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
        
    } else {
        // Update existing player
        playerLives = llListReplaceList(playerLives, [lives], playerIndex, playerIndex);
        // Don't overwrite cached profile texture with original UUID on updates
        // playerProfiles = llListReplaceList(playerProfiles, [profileUUID], playerIndex, playerIndex);
        
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
        }
    }
    
    // If no cached texture or using original UUID, determine what to use
    if (profileTexture == profileUUID) {
        if (isBot(playerName)) {
            profileTexture = TEXTURE_BOT_PROFILE;
        } else if (profileTexture == "" || profileTexture == "00000000-0000-0000-0000-000000000000") {
            profileTexture = TEXTURE_DEFAULT_PROFILE;
        } else {
            // Request profile picture via HTTP (the correct method!)
            string URL_RESIDENT = "https://world.secondlife.com/resident/";
            key httpRequestID = llHTTPRequest(URL_RESIDENT + profileUUID, [HTTP_METHOD, "GET"], "");
            
            // Store the HTTP request mapping: requestID -> playerIndex
            httpRequests += [httpRequestID, playerIndex];
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

// Function to initialize after controller discovery
initializeAfterDiscovery() {
    if (CONTROLLER_KEY != NULL_KEY) {
        llOwnerSay("✅ [Scoreboard] Controller found! Initializing channels and listeners...");
    } else {
        llOwnerSay("⚠️ [Scoreboard] Initializing in legacy mode (no controller found)...");
    }
    
    // Initialize dynamic channels with controller key (or legacy channels if NULL)
    initializeChannels();
    
    // Clean up any existing listeners
    if (scoreboardHandle != -1) llListenRemove(scoreboardHandle);
    if (leaderboardHandle != -1) llListenRemove(leaderboardHandle);
    if (diceHandle != -1) llListenRemove(diceHandle);
    if (dialogHandle != -1) llListenRemove(dialogHandle);
    
    // Set up managed listeners with dynamic channels
    scoreboardHandle = llListen(SCOREBOARD_CHANNEL, "", "", "");     // Status messages
    leaderboardHandle = llListen(SCOREBOARD_CHANNEL_2, "", "", "");   // Player updates  
    diceHandle = llListen(SCOREBOARD_CHANNEL_3, "", "", "");          // Dice rolls
    dialogHandle = llListen(-999, "", "", ""); // Dialog menu channel
    
    // Only set timer for leaderboard generation if we have a controller
    // Don't set timer in legacy mode to avoid discovery loop
    if (CONTROLLER_KEY != NULL_KEY) {
        llSetTimerEvent(1.0); // Short delay for leaderboard generation
    } else {
        // In legacy mode, generate leaderboard immediately without timer
        generateLeaderboardText();
    }
    
    // Mark as initialized to prevent repeated initialization
    INITIALIZED = TRUE;
    
    llOwnerSay("✅ Game Scoreboard Manager ready - Touch for menu");
    llOwnerSay("Use dialog menu to setup prims if needed.");
}

default {
    state_entry() {
        llOwnerSay("🎮 [Scoreboard] Starting and discovering controller...");
        
        // Start controller discovery first
        startControllerDiscovery();
        
        // Clear any old floating text on root prim
        llSetText("", <1,1,1>, 0.0);
        
        // Initialize profile picture extraction constants
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        
        loadLeaderboardData();
        
        llOwnerSay("Game Scoreboard Manager initializing - controller discovery in progress...");
    }
    
    timer() {
        // Handle controller discovery retries
        if (CONTROLLER_KEY == NULL_KEY) {
            DISCOVERY_ATTEMPTS++;
            
            if (DISCOVERY_ATTEMPTS <= MAX_DISCOVERY_ATTEMPTS) {
                llOwnerSay("⏱️ [Scoreboard] Controller discovery retry " + (string)DISCOVERY_ATTEMPTS + "/" + (string)MAX_DISCOVERY_ATTEMPTS);
                
                // Broadcast discovery request again
                llRegionSay(DISCOVERY_CHANNEL, "FIND_CONTROLLER|scoreboard");
                
                // Set timer for next retry (exponential backoff: 5s, 10s, 15s, etc.)
                llSetTimerEvent(5.0 * DISCOVERY_ATTEMPTS);
            } else {
                llOwnerSay("❌ [Scoreboard] Controller discovery failed after " + (string)MAX_DISCOVERY_ATTEMPTS + " attempts");
                llOwnerSay("   Operating in legacy mode with owner-based channels");
                
                // Stop timer and initialize with legacy channels
                llSetTimerEvent(0.0);
                initializeAfterDiscovery(); // This will use legacy channels since CONTROLLER_KEY is NULL
            }
        } else {
            // Controller found, generate initial leaderboard
            llSetTimerEvent(0.0); // Stop timer
            generateLeaderboardText(); // Generate initial leaderboard
        }
    }
    
    listen(integer channel, string senderName, key id, string message) {
        // Handle controller discovery responses
        if (channel == DISCOVERY_CHANNEL) {
            if (llSubStringIndex(message, "CONTROLLER_FOUND|") == 0) {
                list parts = llParseString2List(message, ["|"], []);
                key controllerKey = (key)llList2String(parts, 1);
                
                // Check proximity - only accept nearby controllers
                vector myPos = llGetPos();
                vector controllerPos = llList2Vector(llGetObjectDetails(controllerKey, [OBJECT_POS]), 0);
                float distance = llVecDist(myPos, controllerPos);
                
                if (distance <= MAX_CONTROLLER_DISTANCE) {
                    CONTROLLER_KEY = controllerKey;
                    
                    llOwnerSay("✅ [Scoreboard] Controller discovered: " + (string)CONTROLLER_KEY + " (distance: " + (string)llRound(distance) + "m)");
                    
                    // Notify controller that we've connected
                    llRegionSay(DISCOVERY_CHANNEL, "CLIENT_CONNECTED|scoreboard|" + (string)llGetKey());
                    
                    // Cancel discovery timer
                    llSetTimerEvent(0.0);
                    
                    // Initialize with controller key
                    initializeAfterDiscovery();
                    return;
                } else {
                    llOwnerSay("📍 [Scoreboard] Controller too far (" + (string)llRound(distance) + "m > " + (string)llRound(MAX_CONTROLLER_DISTANCE) + "m), ignoring");
                }
            }
            else if (llSubStringIndex(message, "CONTROLLER_AVAILABLE|") == 0) {
                // Handle broadcast availability messages - but only if not already initialized
                if (INITIALIZED) {
                    // Already initialized, ignore repeated availability messages
                    return;
                }
                
                // Set flag IMMEDIATELY to prevent race conditions from multiple broadcasts
                INITIALIZED = TRUE;
                
                list parts = llParseString2List(message, ["|"], []);
                key controllerKey = (key)llList2String(parts, 1);
                
                // Check proximity - only accept nearby controllers
                vector myPos = llGetPos();
                vector controllerPos = llList2Vector(llGetObjectDetails(controllerKey, [OBJECT_POS]), 0);
                float distance = llVecDist(myPos, controllerPos);
                
                if (distance <= MAX_CONTROLLER_DISTANCE) {
                    CONTROLLER_KEY = controllerKey;
                    
                    llOwnerSay("✅ [Scoreboard] Controller available: " + (string)CONTROLLER_KEY + " (distance: " + (string)llRound(distance) + "m)");
                    
                    // Notify controller that we've connected
                    llRegionSay(DISCOVERY_CHANNEL, "CLIENT_CONNECTED|scoreboard|" + (string)llGetKey());
                    
                    // Cancel discovery timer
                    llSetTimerEvent(0.0);
                    
                    // Initialize with controller key (flag already set above)
                    initializeAfterDiscovery();
                    return;
                } else {
                    llOwnerSay("📍 [Scoreboard] Controller too far (" + (string)llRound(distance) + "m > " + (string)llRound(MAX_CONTROLLER_DISTANCE) + "m), ignoring");
                    // Reset flag if we rejected this controller
                    INITIALIZED = FALSE;
                }
            }
        }
        
        if (channel == -999) {
            // Handle dialog menu responses
            if (id == llGetOwner()) {
                if (message == "Setup Prims") {
                    llOwnerSay("Running prim setup...");
                    setupPlayerGrid();
                } else if (message == "Clear Game") {
                    llOwnerSay("Clearing game...");
                    clearAllPlayers();
                    updateActionsPrim("Title");
                    llRegionSay(LEADERBOARD_CHANNEL, "CLEAR_LEADERBOARD");
                    generateLeaderboardText();
                } else if (message == "Reset Board") {
                    llOwnerSay("Resetting leaderboard...");
                    resetLeaderboard();
                } else if (message == "Gen Leaderboard") {
                    llOwnerSay("Generating leaderboard...");
                    generateLeaderboardText();
                } else if (message == "Cancel") {
                    llOwnerSay("Menu cancelled.");
                }
            }
            return;
        }
        
        // Handle messages from all three scoreboard channels
        if (channel == SCOREBOARD_CHANNEL || channel == SCOREBOARD_CHANNEL_2 || channel == SCOREBOARD_CHANNEL_3) {
            if (llSubStringIndex(message, "PLAYER_UPDATE|") == 0) {
                // Handle player updates here if needed
                // Format: PLAYER_UPDATE|PlayerName|Lives|ProfileUUID
                
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
                
                // Clear the leaderboard display completely
                llRegionSay(LEADERBOARD_CHANNEL, "CLEAR_LEADERBOARD");
                
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
            } else if (llSubStringIndex(message, "GAME_LOST|") == 0) {
                list parts = llParseString2List(message, ["|"], []);
                if (llGetListLength(parts) >= 2) {
                    string loserName = llList2String(parts, 1);
                    handleGameLost(loserName);
                }
            } else if (llSubStringIndex(message, "DICE_ROLL|") == 0) {
                // Handle dice roll display
                // Format: DICE_ROLL|PlayerName|DiceValue
                list parts = llParseString2List(message, ["|"], []);
                if (llGetListLength(parts) >= 3) {
                    string playerName = llList2String(parts, 1);
                    integer diceValue = (integer)llList2String(parts, 2);
                    generateDiceRollText(playerName, diceValue, "SHOW");
                }
            } else if (llSubStringIndex(message, "CLEAR_DICE") == 0) {
                // Clear dice roll display
                generateDiceRollText("", 0, "CLEAR");
            } else if (llSubStringIndex(message, "RESET_LEADERBOARD") == 0) {
                resetLeaderboard();
            }
        }
    }
    
    touch_start(integer total_number) {
        // Owner can access dialog menu
        if (llDetectedKey(0) == llGetOwner()) {
            llDialog(llDetectedKey(0), "Scoreboard Manager Options:", [
                "Setup Prims",
                "Clear Game", 
                "Reset Board",
                "Gen Leaderboard",
                "Cancel"
            ], -999);
        } else {
            llSay(0, "Only the owner can access this menu.");
        }
    }
    
    dataserver(key query_id, string data) {
        // Handle profile picture data responses
        integer requestIndex = llListFindList(profileRequests, [query_id]);
        if (requestIndex != -1) {
            // Found the request - get the corresponding player index and data type
            integer playerIndex = llList2Integer(profileRequests, requestIndex + 1);
            integer dataType = llList2Integer(profileRequests, requestIndex + 2);
            
            
            // Check if this looks like a valid texture UUID (36 characters, proper format)
            if (llStringLength(data) == 36 && llSubStringIndex(data, "-") != -1) {
                
                // Update the profile texture for this player
                integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                
                llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                    PRIM_TEXTURE, ALL_SIDES, data, <1,1,0>, <0,0,0>, 0.0,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                ]);
                
            } else {
                // Not a valid UUID, continue testing other data types
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
            
            
            if (status == 200) {
                // Try to extract profile picture UUID from HTML
                integer s1 = llSubStringIndex(body, profile_key_prefix);
                integer s1l = profile_key_prefix_length;
                
                if (s1 == -1) {
                    // Second try with img tag
                    s1 = llSubStringIndex(body, profile_img_prefix);
                    s1l = profile_img_prefix_length;
                } else {
                }
                
                if (s1 == -1) {
                    // Still no match - use default texture
                    
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
                        integer profilePrimIndex = FIRST_PLAYER_PRIM + (playerIndex * 2);
                        llSetLinkPrimitiveParamsFast(profilePrimIndex, [
                            PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
                            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                        ]);
                    } else {
                        
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
