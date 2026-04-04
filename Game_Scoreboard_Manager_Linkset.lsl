#include "Peril_Constants.lsl"

// Game Scoreboard Manager - Linkset Version
// Shows current game players in grid layout
// Each player gets a prim showing profile picture + heart texture (lives)

// --- DYNAMIC LINK DISCOVERY ---
integer BACKGROUND_PRIM = -1;
integer ACTIONS_PRIM = -1;

// Link mappings for player grid (Rows 0-4, Columns 0-1)
list profileLinks = [0,0,0,0,0,0,0,0,0,0];
list heartsLinks = [0,0,0,0,0,0,0,0,0,0];
list overlayLinks = [0,0,0,0,0,0,0,0,0,0];

// Discover all relevant prims by name at startup
discoverLinks() {
    integer i;
    integer total = llGetNumberOfPrims();
    
    // Reset lists
    profileLinks = [0,0,0,0,0,0,0,0,0,0];
    heartsLinks = [0,0,0,0,0,0,0,0,0,0];
    overlayLinks = [0,0,0,0,0,0,0,0,0,0];
    
    for (i = 1; i <= total; i++) {
        string name = llGetLinkName(i);
        
        if (name == "backboard:0:0") BACKGROUND_PRIM = i;
        else if (name == "TitleAction:0:0") ACTIONS_PRIM = i;
        else if (name == "Scoreboard:0:0") LINK_SCOREBOARD = i;
        else {
            // Pattern match: "type:row:col"
            list parts = llParseString2List(name, [":"], []);
            if (llGetListLength(parts) == 3) {
                string type = llList2String(parts, 0);
                integer row = (integer)llList2String(parts, 1);
                integer col = (integer)llList2String(parts, 2);
                integer index = (row * 2) + col;
                
                if (index >= 0 && index < 10) {
                    if (type == "profile") profileLinks = llListReplaceList(profileLinks, [i], index, index);
                    else if (type == "life") heartsLinks = llListReplaceList(heartsLinks, [i], index, index);
                    else if (type == "overlay") overlayLinks = llListReplaceList(overlayLinks, [i], index, index);
                }
            }
        }
    }
    
    dbg("📈 [Scoreboard Manager] 🔍 Dynamic Discovery complete!");
    if (BACKGROUND_PRIM == -1) dbg("⚠️ WARNING: Background prim ('backboard:0:0') not found!");
}

// --- Leaderboard Configuration ---
#define LEADERBOARD_WIDTH 32    // Standard width for 4x8 character Furware grids (4 columns of 8)
#define MAX_LEADERBOARD_ENTRIES 11 // Fits within 12-row board (+1 for title)

// Heart texture UUIDs - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
#define TEXTURE_0_HEARTS "7d8ae121-e171-12ae-f5b6-7cc3c0395c7b" // 0 hearts (dead)
#define TEXTURE_1_HEARTS "6605d25f-8e2d-2870-eb87-77c58cd47fa9" // 1 heart
#define TEXTURE_2_HEARTS "7ba6cb1e-f384-25a5-8e88-a90bbd7cc041" // 2 hearts
#define TEXTURE_3_HEARTS "a5d16715-4648-6526-5582-e8068293f792" // 3 hearts

// Default textures - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
#define TEXTURE_DEFAULT_PROFILE "1ce89375-6c3c-3845-26b1-1dc666bc9169" // Default avatar
#define TEXTURE_BOT_PROFILE "62f31722-04c1-8c29-c236-398543f2a6ae" // Bot avatar picture
#define BLANK_TEXTURE "5748decc-f629-461c-9a36-a35a221fe21f" // White texture UUID
#define TEXTURE_BACKGROUND "5748decc-f629-461c-9a36-a35a221fe21f" // Background texture (blank + black color)
#define TEXTURE_ACTIONS "6aac8dce-1b83-f931-abe3-286f4f2faa29" // Punishment texture

// Status textures - REPLACE WITH YOUR ACTUAL TEXTURE UUIDs
#define TEXTURE_PERIL "c5676fec-0c85-5567-3dd8-f939234e21d9" // Elimination texture
#define TEXTURE_PERIL_SELECTED "a53ff601-3c8a-e312-9e0e-f6fa76f6773a" // Peril Selected texture
#define TEXTURE_VICTORY "ec5bf10e-4970-fb63-e7bf-751e1dc27a8d" // Victory texture
#define TEXTURE_PUNISHMENT "acfabed0-84ad-bfd1-cdfc-2ada0aeeaa2f" // Punishment texture (fallback)
#define TEXTURE_DIRECT_HIT "ecd2dba2-3969-6c39-ad59-319747307f55" // Direct Hit texture
#define TEXTURE_NO_SHIELD "2440174f-e385-44e2-8016-ac34934f11f5" // No Shield texture
#define TEXTURE_PLOT_TWIST "ec533379-4f7f-8183-e877-e68af703dcce" // Plot Twist texture
#define TEXTURE_TITLE "624bb7a7-e856-965c-bae8-94d75226c1bc" // Title texture
#define TEXTURE_ELIMINATED_X "90524092-03b0-1b3c-bcea-3ea5118c6dba" // Red X overlay for eliminated players

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

// KVP tracking
key kvpReadReq;
key kvpWriteReq;
string pendingSerialize;

// Memory reporting function
integer reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    dbg("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
    return 0;
}

// Profile picture extraction constants
string profile_key_prefix = "<meta name=\"imageid\" content=\"";
string profile_img_prefix = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
integer profile_key_prefix_length;
integer profile_img_prefix_length;

// Reset background prim to proper black background
integer resetBackgroundPrim() {
    // Reset main background prim (link 13)
    llSetLinkPrimitiveParamsFast(BACKGROUND_PRIM, [
        PRIM_TEXTURE, ALL_SIDES, TEXTURE_BACKGROUND, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black color
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove any text
    ]);
    
    dbg("📈 [Scoreboard Manager] 🖤 Reset background prim " + (string)BACKGROUND_PRIM + " to black");
    return 0;
}

// Reset the scoreboard manager cube (link 12) to neutral state
integer resetManagerCube() {
    llSetLinkPrimitiveParamsFast(LINK_SCOREBOARD, [
        PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black color to blend in
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove any text
    ]);
    
    dbg("📈 [Scoreboard Manager] 📦 Reset manager cube (link 12) to black");
    return 0;
}

// Update actions prim with appropriate status texture
integer updateActionsPrim(string status) {
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
        return 0; // Don't change texture for unrecognized statuses
    }
    
    // Replace with action prim texture update
    if (ACTIONS_PRIM != -1) {
        llSetLinkPrimitiveParamsFast(ACTIONS_PRIM, [
            PRIM_TEXTURE, ALL_SIDES, textureToUse, <1,1,0>, <0,0,0>, 0.0,
            PRIM_TEXT, "", <0,0,0>, 0.0 // Remove existing floating text
        ]);
    }
    return 0;
}

// Load leaderboard data from Experience KVP database
integer loadLeaderboardData() {
    kvpReadReq = llReadKeyValue("Peril_LB_Top50");
    dbg("📈 [Scoreboard Manager] 🔍 Requesting global scoreboard from Experience database...");
    return 0;
}

// Save leaderboard data to Experience KVP database
integer saveLeaderboardData() {
    string serialized = "";
    integer saveCount = llGetListLength(leaderboardNames);
    if (saveCount > 50) saveCount = 50; // Cap at Top 50 to fit safely in KVP 4Kb limit
    
    integer saveI;
    for (saveI = 0; saveI < saveCount; saveI++) {
        string save_entry = llList2String(leaderboardNames, saveI) + ":" + 
                       (string)llList2Integer(leaderboardWins, saveI) + ":" + 
                       (string)llList2Integer(leaderboardLosses, saveI);
        if (serialized != "") serialized += "|";
        serialized += save_entry;
    }
    
    pendingSerialize = serialized;
    kvpWriteReq = llUpdateKeyValue("Peril_LB_Top50", serialized, FALSE, "");
    
    dbg("📈 [Scoreboard Manager] 💾 Synced " + (string)saveCount + " players to global scoreboard database.");
    return 0;
}

// Handle game won - update leaderboard
integer handleGameWon(string winnerName) {
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
    return 0;
}

// Handle game lost - update leaderboard
integer handleGameLost(string loserName) {
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
    return 0;
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
    string sorted_entry;
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
        sorted_entry = sortKey + ":" + sortName + ":" + (string)sortWins + ":" + (string)sortLosses;
        sortedLbData += [sorted_entry];
    }
    
    // Sort by combined key (wins descending, losses ascending) - FALSE = descending order
    sortedLbData = llListSort(sortedLbData, 1, FALSE);
    
    // Clean up the format back to "Name:Wins:Losses" (skip padded wins in position 0)
    cleanedData = [];
    for (sortI = 0; sortI < llGetListLength(sortedLbData); sortI++) {
        sorted_entry = llList2String(sortedLbData, sortI);
        parts = llParseString2List(sorted_entry, [":"], []);
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
integer generateLeaderboardText() {
    list sortedData = getSortedLeaderboard();
    
    // 1. Build Title Row (Centered)
    string title = "TOP BATTLE RECORDS";
    integer titleLen = llStringLength(title);
    integer titleMargin = (LEADERBOARD_WIDTH - titleLen) / 2;
    if (titleMargin < 0) titleMargin = 0;
    
    string titleSpaces = "";
    integer ts;
    for (ts = 0; ts < titleMargin; ts++) titleSpaces += " ";
    
    string leaderboardText = titleSpaces + title + "\n";
    
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
    
    // Add actual player data (up to MAX_LEADERBOARD_ENTRIES)
    for (genI = 0; genI < llGetListLength(sortedData) && genI < MAX_LEADERBOARD_ENTRIES; genI++) {
        playerData = llList2String(sortedData, genI);
        playerParts = llParseString2List(playerData, [":"], []);
        
        if (llGetListLength(playerParts) >= 3) {
            playerName = llList2String(playerParts, 0);
            genWins = llList2String(playerParts, 1);
            genLosses = llList2String(playerParts, 2);
            
            // [Rank(4) + Name(14) + Gaps + Stats(10) = 32 chars total]
            if (llStringLength(playerName) > 12) {
                playerName = llGetSubString(playerName, 0, 9) + "...";
            }
            
            // Format rank string: "01. " through "10. " (always 4 chars)
            rankNumber = genI + 1;
            rank = (string)rankNumber + ". ";
            if (rankNumber < 10) rank = "0" + rank;
            
            // Format stats with fixed-width padding to align columns
            // Standardizing to 10 characters: "W: 99/L: 9"
            string sWins = (string)genWins;
            while (llStringLength(sWins) < 3) sWins = " " + sWins;
            string sLosses = (string)genLosses;
            while (llStringLength(sLosses) < 2) sLosses = " " + sLosses;
            
            leftPart = rank + playerName;
            rightPart = "W:" + sWins + "/L:" + sLosses; // Exactly 10 characters
            
            // Push rightPart to column 32
            spaceNeeded = LEADERBOARD_WIDTH - llStringLength(leftPart) - llStringLength(rightPart);
            if (spaceNeeded < 1) spaceNeeded = 1;
            
            spacer = "";
            for (s = 0; s < spaceNeeded; s++) spacer += " ";
            
            line = leftPart + spacer + rightPart;
            leaderboardText += line + "\n";
        }
    }
    
    // Fill remaining positions with placeholders
    actualPlayers = llGetListLength(sortedData);
    for (genI = actualPlayers; genI < MAX_LEADERBOARD_ENTRIES; genI++) {
        rankNumber = genI + 1;
        rank = (string)rankNumber + ". ";
        if (rankNumber < 10) rank = "0" + rank;
        
        // Use EXACT same formatting as players so columns align!
        leftPart = rank + "----------";
        rightPart = "W:  0/L: 0"; // Matches 10-char fixed width
        
        spaceNeeded = LEADERBOARD_WIDTH - llStringLength(leftPart) - llStringLength(rightPart);
        if (spaceNeeded < 1) spaceNeeded = 1;
        
        spacer = "";
        for (s = 0; s < spaceNeeded; s++) spacer += " ";
        
        line = leftPart + spacer + rightPart;
        leaderboardText += line + "\n";
    }
    
    // Send formatted text to leaderboard bridge
    llMessageLinked(LINK_LEADERBOARD_BRIDGE, MSG_RESET_LEADERBOARD, "FORMATTED_TEXT|" + leaderboardText, NULL_KEY);
    return 0;
}

// Reset leaderboard data (SECURED for Creator Only)
integer resetLeaderboard() {
    // PROTECT THE GLOBAL DATABASE!
    if (llGetOwner() != llGetCreator()) {
        llOwnerSay("❌ Access Denied: Only the creator of Peril Dice can wipe the Global Scoreboard!");
        return 0;
    }
    
    leaderboardNames = [];
    leaderboardWins = [];
    leaderboardLosses = [];
    pendingSerialize = "";
    kvpWriteReq = llUpdateKeyValue("Peril_LB_Top50", "", FALSE, "");
    generateLeaderboardText(); // Send empty leaderboard immediately
    return 0;
}

// Clear all current players from the scoreboard
integer clearAllPlayers() {
    // Clear ONLY current game player data lists (NOT leaderboard data)
    playerNames = [];
    playerLives = [];
    playerProfiles = [];
    
    // Clear any pending HTTP requests
    httpRequests = [];
    profileRequests = [];
    
    // Variable declarations for the loop
    integer clearI;
    integer clearProfilePrimIndex;
    integer clearHeartsPrimIndex;
    integer clearOverlayPrimIndex;
    
    // Reset all player prims to default state
    for (clearI = 0; clearI < 10; clearI++) {
        clearProfilePrimIndex = llList2Integer(profileLinks, clearI);
        clearHeartsPrimIndex = llList2Integer(heartsLinks, clearI);
        clearOverlayPrimIndex = llList2Integer(overlayLinks, clearI);
        
        // SAFETY CHECK - use if block instead of continue for maximum compatibility
        if (clearProfilePrimIndex > 0) {
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
    return 0;
}

// Remove a single player from the scoreboard display
integer removePlayer(string playerName) {
    integer removeIdx = llListFindList(playerNames, [playerName]);
    if (removeIdx != -1) {
        // Remove player from internal lists
        playerNames = llDeleteSubList(playerNames, removeIdx, removeIdx);
        playerLives = llDeleteSubList(playerLives, removeIdx, removeIdx);
        playerProfiles = llDeleteSubList(playerProfiles, removeIdx, removeIdx);
        
        // Refresh the entire display to shift remaining players up
        refreshPlayerDisplay();
        
        dbg("📈 [Scoreboard Manager] 📊 Removed " + playerName + " from the scoreboard and shifted remaining players.");
    }
    return 0;
}

// Refresh the entire player display - shows all current players in order
integer refreshPlayerDisplay() {
    integer numActivePlayers = llGetListLength(playerNames);
    integer refreshI;
    integer refreshProfilePrimIndex = 0;
    integer refreshHeartsPrimIndex = 0;
    integer refreshOverlayPrimIndex = 0;
    
    // Position-specific variables
    string r_name;
    integer r_lives;
    string r_profileTexture;
    integer r_profileIdx;
    integer r_heartsIdx;
    integer r_overlayIdx;
    
    // Only reset prims for unused slots (avoid flickering for active players)
    for (refreshI = numActivePlayers; refreshI < 10; refreshI++) {
        refreshProfilePrimIndex = llList2Integer(profileLinks, refreshI);
        refreshHeartsPrimIndex = llList2Integer(heartsLinks, refreshI);
        refreshOverlayPrimIndex = llList2Integer(overlayLinks, refreshI);
        
        if (refreshProfilePrimIndex > 0) {
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
    }
    
    // Now display all current players in their new positions
    for (refreshI = 0; refreshI < numActivePlayers; refreshI++) {
        r_name = llList2String(playerNames, refreshI);
        r_lives = llList2Integer(playerLives, refreshI);
        r_profileTexture = llList2String(playerProfiles, refreshI);
        
        // Calculate prim indices for this position
        r_profileIdx = llList2Integer(profileLinks, refreshI);
        r_heartsIdx = llList2Integer(heartsLinks, refreshI);
        r_overlayIdx = llList2Integer(overlayLinks, refreshI);
        
        if (r_profileIdx > 0) {
            // Determine profile texture to use
            if (isBot(r_name)) {
                r_profileTexture = TEXTURE_BOT_PROFILE;
            } else if (r_profileTexture == "" || r_profileTexture == "00000000-0000-0000-0000-000000000000") {
                r_profileTexture = TEXTURE_DEFAULT_PROFILE;
            }
            
            // Set profile texture
            llSetLinkPrimitiveParamsFast(r_profileIdx, [
                PRIM_TEXTURE, ALL_SIDES, r_profileTexture, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
            
            // Set hearts texture
            string heartTexture = getHeartTexture(r_lives);
            llSetLinkPrimitiveParamsFast(r_heartsIdx, [
                PRIM_TEXTURE, ALL_SIDES, heartTexture, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
            
            // Control overlay prim - show red X if eliminated, hide if alive
            if (r_lives <= 0) {
                llSetLinkPrimitiveParamsFast(r_overlayIdx, [
                    PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
                    PRIM_TEXT, "", <1,1,1>, 0.0
                ]);
            } else {
                llSetLinkPrimitiveParamsFast(r_overlayIdx, [
                    PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0,
                    PRIM_TEXT, "", <1,1,1>, 0.0
                ]);
            }
        }
    }
    
    // Update player glow effects after refreshing all players
    updatePlayerGlowEffects();
    return 0;
}

// Check if a player name indicates it's a bot
integer isBot(string playerName) {
    return (llSubStringIndex(playerName, "Bot") == 0);
}

// Map player index to profile prim link number
// Functions relocated to avoid hardcoded math
integer getProfilePrimLink(integer playerIndex) { return llList2Integer(profileLinks, playerIndex); }
integer getHeartsPrimLink(integer playerIndex) { return llList2Integer(heartsLinks, playerIndex); }
integer getOverlayPrimLink(integer playerIndex) { return llList2Integer(overlayLinks, playerIndex); }

string getHeartTexture(integer lives) {
    if (lives <= 0) return TEXTURE_0_HEARTS;
    else if (lives == 1) return TEXTURE_1_HEARTS;
    else if (lives == 2) return TEXTURE_2_HEARTS;
    else return TEXTURE_3_HEARTS; // 3 or more
}

// Update all glow effects (peril and winner)
integer updatePlayerGlowEffects() {
    // First, remove glow and reset tint from all players
    integer glowI;
    integer glowProfilePrimIndex;
    integer glowHeartsPrimIndex;
    
    for (glowI = 0; glowI < llGetListLength(playerNames); glowI++) {
        glowProfilePrimIndex = llList2Integer(profileLinks, glowI);
        glowHeartsPrimIndex = llList2Integer(heartsLinks, glowI);
        
        if (glowProfilePrimIndex > 0) {
            llSetLinkPrimitiveParamsFast(glowProfilePrimIndex, [
                PRIM_GLOW, ALL_SIDES, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
            ]);
        }
        if (glowHeartsPrimIndex > 0) {
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
            
            // Check if the prim exists (discovered index > 0)
            if (winnerProfilePrimIndex > 0) {
                // Add green glow + green tint to winner
                llSetLinkPrimitiveParamsFast(winnerProfilePrimIndex, [
                    PRIM_GLOW, ALL_SIDES, 0.3,
                    PRIM_COLOR, ALL_SIDES, <0.0, 1.0, 0.0>, 1.0
                ]);
                
                // Also add glow to hearts if found
                if (winnerHeartsPrimIndex > 0) {
                    llSetLinkPrimitiveParamsFast(winnerHeartsPrimIndex, [
                        PRIM_GLOW, ALL_SIDES, 0.3,
                        PRIM_COLOR, ALL_SIDES, <0.0, 1.0, 0.0>, 1.0
                    ]);
                }
                
                dbg("📈 [Scoreboard Manager] 🏆 Added green glow to winner: " + currentWinner);
            }
        }
    }
    // Priority 2: Yellow glow for peril player (only if not the winner)
    else if (currentPerilPlayer != "" && currentPerilPlayer != "NONE") {
        integer perilIndex = llListFindList(playerNames, [currentPerilPlayer]);
        if (perilIndex != -1) {
            integer perilProfilePrimIndex = getProfilePrimLink(perilIndex);
            integer perilHeartsPrimIndex = getHeartsPrimLink(perilIndex);
            
            // Check if the prim exists (discovered index > 0)
            if (perilProfilePrimIndex > 0) {
                // Add yellow glow + yellow tint to peril player
                llSetLinkPrimitiveParamsFast(perilProfilePrimIndex, [
                    PRIM_GLOW, ALL_SIDES, 0.2,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 0.0>, 1.0
                ]);
                
                // Also add glow to hearts if found
                if (perilHeartsPrimIndex > 0) {
                    llSetLinkPrimitiveParamsFast(perilHeartsPrimIndex, [
                        PRIM_GLOW, ALL_SIDES, 0.2,
                        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 0.0>, 1.0
                    ]);
                }
                
                dbg("📈 [Scoreboard Manager] ✨ Added yellow glow to peril player: " + currentPerilPlayer);
            }
        }
    }
    return 0;
}

// Backward compatibility wrapper
integer updatePerilPlayerGlow() {
    updatePlayerGlowEffects();
    return 0;
}

// Update player display on the grid
integer updatePlayerDisplay(string playerName, integer lives, string profileUUID) {
    // Find existing player or add new one
    integer playerIndex = llListFindList(playerNames, [playerName]);
    
    if (playerIndex == -1) {
        // New player - find next available slot
        playerIndex = llGetListLength(playerNames);
        if (playerIndex >= 10) {
            dbg("📈 [Scoreboard Manager] ⚠️ WARNING: Maximum 10 players supported, ignoring: " + playerName);
            return 0;
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
    integer updateProfilePrimIndex = llList2Integer(profileLinks, playerIndex);
    integer updateHeartsPrimIndex = llList2Integer(heartsLinks, playerIndex);
    integer updateOverlayPrimIndex = llList2Integer(overlayLinks, playerIndex);
    
    if (updateProfilePrimIndex <= 0) return 0;
    
    // Update profile prim texture - show red X if eliminated, otherwise show profile
    string updateProfileTexture;
    
    if (lives <= 0) {
        // Player is eliminated - keep profile picture but show red X on overlay prim
        dbg("📈 [Scoreboard Manager] 💀 Scoreboard: Showing elimination X overlay for " + playerName);
        
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
                dbg("📈 [Scoreboard Manager] ❓ [DEBUG] " + playerName + " has empty/null UUID, using default texture");
            } else {
                // CRITICAL: Set default texture FIRST, then request profile picture
                updateProfileTexture = TEXTURE_DEFAULT_PROFILE;
                
                // if (VERBOSE_LOGGING) {
                //     llOwnerSay("🔄 [DEBUG] " + playerName + " making HTTP request for UUID: " + profileUUID);
                // }
                
                // Request profile picture via HTTP (will update later)
                #define URL_RESIDENT "https://world.secondlife.com/resident/"
                key httpRequestID = llHTTPRequest(URL_RESIDENT + profileUUID, [HTTP_METHOD, "GET"], "");
                
                // Store the HTTP request mapping: requestID -> playerIndex
                httpRequests += [httpRequestID, playerIndex];
                
                // if (VERBOSE_LOGGING) {
                //     llOwnerSay("🔄 [Scoreboard] Requesting profile pic for " + playerName + ", showing default for now");
                // }
            }
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
    return 0;
}

default {
    on_rez(integer start_param) {
        discoverLinks();
        llResetScript(); 
    }
    state_entry() {
        discoverLinks();
        llListen(1, "", llGetOwner(), ""); 
        reportMemoryUsage("Scoreboard Manager");
        dbg("📈 [Scoreboard Manager] 📈 Managing profile and heart prims via dynamic discovery.");
        
        // Initialize profile picture extraction constants
        profile_key_prefix_length = llStringLength(profile_key_prefix);
        profile_img_prefix_length = llStringLength(profile_img_prefix);
        
        // Reset background prim to proper state
        resetBackgroundPrim();
        
        // Reset manager cube to neutral state
        resetManagerCube();
        
        // Load persistent leaderboard data from KVP Experience database
        loadLeaderboardData();
        // Set a timer to passively auto-refresh the global scoreboard every 5 minutes
        llSetTimerEvent(300.0);
        // NOTE: generateLeaderboardText() will be triggered by dataserver automatically when data arrives
        // No need to generate it randomly before data arrives
        
        // Ensure no glow effects remain from previous sessions
        currentPerilPlayer = "";
        currentWinner = "";
        updatePlayerGlowEffects();
        
        dbg("📈 [Scoreboard Manager] ✅ Linkset communication active - no discovery needed!");
        dbg("📈 [Scoreboard Manager] 📊 Loaded " + (string)llGetListLength(leaderboardNames) + " players from leaderboard data");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Only listen to messages from the main controller (link 1)
        if (sender != LINK_CONTROLLER) return;
        
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
                dbg("📈 Scoreboard received update: " + playerName + " has " + (string)lives + " hearts");
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
            
            dbg("📈 [Scoreboard Manager] 🎯 Peril player changed from '" + oldPeril + "' to '" + currentPerilPlayer + "'");
            
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
            
            dbg("📈 [Scoreboard Manager] 🏆 Winner changed from '" + oldWinner + "' to '" + currentWinner + "'");
            
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
                    
                    // Safety check: Ensure the prim link was found 
                    if (profilePrimIndex > 0) {
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
                        
                        string playerName = llList2String(playerNames, playerIndex);
                        dbg("📈 [Scoreboard Manager] 🖼️ Updated profile picture for " + playerName + " on prim " + (string)profilePrimIndex + " with forced refresh");
                    } else {
                        dbg("📈 [Scoreboard Manager] ❌ ERROR: HTTP response tried to update invalid prim " + (string)profilePrimIndex + " for player " + (string)playerIndex);
                    }
                }
            }
        }
    }
    
    dataserver(key queryid, string data) {
        integer comma;
        if (queryid == kvpReadReq) {
            comma = llSubStringIndex(data, ",");
            if (comma != -1) {
                string status = llGetSubString(data, 0, comma - 1);
                string val = llGetSubString(data, comma + 1, -1);
                
                if (status == "1") {
                    leaderboardNames = [];
                    leaderboardWins = [];
                    leaderboardLosses = [];
                    
                    list entries = llParseString2List(val, ["|"], []);
                    integer i;
                    for (i = 0; i < llGetListLength(entries); i++) {
                        string data_entry = llList2String(entries, i);
                        list parts = llParseString2List(data_entry, [":"], []);
                        if (llGetListLength(parts) >= 3) {
                            leaderboardNames += [llList2String(parts, 0)];
                            leaderboardWins += [(integer)llList2String(parts, 1)];
                            leaderboardLosses += [(integer)llList2String(parts, 2)];
                        }
                    }
                    dbg("📈 [Scoreboard Manager] ✅ Loaded global scoreboard containing " + (string)llGetListLength(leaderboardNames) + " players!");
                } else if (status == "3") { // XP_ERROR_KEY_NOT_FOUND
                    leaderboardNames = [];
                    leaderboardWins = [];
                    leaderboardLosses = [];
                    dbg("📈 [Scoreboard Manager] ℹ️ Global scoreboard is currently empty (database fresh).");
                } else {
                    dbg("📈 [Scoreboard Manager] ⚠️ Failed to load global scoreboard (Status: " + status + ")");
                }
            }
            // Generate board with downloaded or empty data
            generateLeaderboardText();
        } else if (queryid == kvpWriteReq) {
            comma = llSubStringIndex(data, ",");
            if (comma != -1) {
                string status = llGetSubString(data, 0, comma - 1);
                if (status == "3") {
                    // Update failed because key didn't exist yet! Create it.
                    llCreateKeyValue("Peril_LB_Top50", pendingSerialize);
                } else if (status == "1") {
                    dbg("📈 [Scoreboard Manager] ✅ Global scoreboard synced successfully.");
                }
            }
        }
    }
    
    
    timer() {
        dbg("📈 [Scoreboard Manager] ⏱️ Auto-refreshing Global Scoreboard Data...");
        loadLeaderboardData();
    }
    
    listen(integer channel, string name, key id, string message) {
        string msg = llToLower(llStringTrim(message, STRING_TRIM));
        if (msg == "testx") {
            llOwnerSay("Testing X overlays on all 10 player slots...");
            integer i;
            integer overlayIdx;
            for (i = 0; i < 10; i++) {
                overlayIdx = getOverlayPrimLink(i);
                if (overlayIdx > 0) {
                    llSetLinkPrimitiveParamsFast(overlayIdx, [
                        PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0,
                        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                    ]);
                }
            }
        }
        else if (msg == "clearx") {
            dbg("Refreshing display to clear test X overlays...");
            refreshPlayerDisplay();
        }
    }
}
