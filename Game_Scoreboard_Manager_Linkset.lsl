#include "Peril_Constants.lsl"

// Game Scoreboard Manager - Linkset Version
// Shows current game players in grid layout
// Each player gets a prim showing profile picture + heart texture (lives)

// --- DYNAMIC LINK DISCOVERY ---
integer BACKGROUND_PRIM = -1;
integer ACTIONS_PRIM = -1;

// Grid link mappings for player grid (Stride 3: Profile, Hearts, Overlay)
list gridLinks = [
    0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0,
    0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0
];

// Discover all relevant prims by name at startup
discoverLinks() {
    integer i;
    integer total = llGetNumberOfPrims();
    
    // Reset list (30 elements for 10 slots * 3 prims)
    gridLinks = [
        0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0,
        0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0
    ];
    
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
                    integer gridBase = index * 3;
                    if (type == "profile") gridLinks = llListReplaceList(gridLinks, [i], gridBase, gridBase);
                    else if (type == "life") gridLinks = llListReplaceList(gridLinks, [i], gridBase + 1, gridBase + 1);
                    else if (type == "overlay") gridLinks = llListReplaceList(gridLinks, [i], gridBase + 2, gridBase + 2);
                }
            }
        }
    }
    
    dbg("Discovery done");
    if (BACKGROUND_PRIM == -1) { dbg("No backboard"); }
    
    // Safety Fallback: Use Root if Scoreboard prim is missing
    if (LINK_SCOREBOARD == -1) LINK_SCOREBOARD = 1;
}

// --- Leaderboard Configuration ---
#define LEADERBOARD_WIDTH 32    // Standard width for 4x8 character Furware grids (4 columns of 8)
#define MAX_LEADERBOARD_ENTRIES 11 // Fits within 11 remaining rows (after 1-row header)

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
list activePlayers = []; // Current game state (Stride 3: Name, Lives, UUID)

// Peril player tracking
string currentPerilPlayer = ""; // Track current peril player for glow effects
string currentWinner = ""; // Track current winner for green glow effects

// Leaderboard data (persistent - stored in linkset data) - Stride of 3 [Name, Wins, Losses]
list leaderboardData = []; 

// HTTP tracking
list profileRequests = []; // Track which profile requests belong to which player
list httpRequests = []; // Track HTTP requests for profile pictures

// KVP tracking
key kvpReadReq;
key kvpWriteReq;
string pendingSerialize;


// Profile picture extraction constants
// Profile picture extraction constants
#define PROFILE_KEY_PREFIX "<meta name=\"imageid\" content=\""
#define PROFILE_IMG_PREFIX "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/"
#define PROFILE_KEY_PREFIX_LENGTH 30
#define PROFILE_IMG_PREFIX_LENGTH 59

// Reset background prim to proper black background
integer resetBackgroundPrim() {
    // Reset main background prim (link 13)
    llSetLinkPrimitiveParamsFast(BACKGROUND_PRIM, [
        PRIM_TEXTURE, ALL_SIDES, TEXTURE_BACKGROUND, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black color
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove any text
    ]);
    
    dbg("Backboard Reset");
    return 0;
}

// Reset the scoreboard manager cube (link 12) to neutral state
integer resetManagerCube() {
    llSetLinkPrimitiveParamsFast(LINK_SCOREBOARD, [
        PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, // Black color to blend in
        PRIM_TEXT, "", <0,0,0>, 0.0 // Remove any text
    ]);
    
    dbg("Manager Reset");
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
    dbg("LB Requesting");
    return 0;
}

// Save leaderboard data to Experience KVP database
integer saveLeaderboardData() {
    string serialized = "";
    integer totalEntries = llGetListLength(leaderboardData) / 3;
    integer saveCount = totalEntries;
    integer saveI = 0;
    integer base = 0;
    string save_entry = "";
    
    if (saveCount > 50) saveCount = 50; // Cap at Top 50 
    
    for (saveI = 0; saveI < saveCount; saveI++) {
        base = saveI * 3;
        save_entry = llList2String(leaderboardData, base) + ":" + 
                       (string)llList2Integer(leaderboardData, base + 1) + ":" + 
                       (string)llList2Integer(leaderboardData, base + 2);
        if (serialized != "") serialized += "|";
        serialized += save_entry;
    }
    
    pendingSerialize = serialized;
    kvpWriteReq = llUpdateKeyValue("Peril_LB_Top50", serialized, FALSE, "");
    
    dbg("LB Saving");
    return 0;
}

// Handle game won - update leaderboard
integer handleGameWon(string winnerName) {
    integer idx = llListFindList(leaderboardData, [winnerName]);
    if (idx == -1) {
        // New player
        leaderboardData += [winnerName, 1, 0];
    } else {
        // Existing player
        integer currentWins = llList2Integer(leaderboardData, idx + 1);
        leaderboardData = llListReplaceList(leaderboardData, [currentWins + 1], idx + 1, idx + 1);
    }
    
    saveLeaderboardData();
    generateLeaderboardText();
    return 0;
}

// Handle game lost - update leaderboard
integer handleGameLost(string loserName) {
    integer lostIdx = llListFindList(leaderboardData, [loserName]);
    if (lostIdx == -1) {
        // New player
        leaderboardData += [loserName, 0, 1];
    } else {
        // Existing player
        integer currentLosses = llList2Integer(leaderboardData, lostIdx + 2);
        leaderboardData = llListReplaceList(leaderboardData, [currentLosses + 1], lostIdx + 2, lostIdx + 2);
    }
    
    saveLeaderboardData();
    generateLeaderboardText();
    return 0;
}

list getSortedLeaderboard() {
    list sortList = [];
    integer i = 0;
    integer totalEntries = llGetListLength(leaderboardData) / 3;
    integer base = 0;
    integer wins = 0;
    integer losses = 0;
    integer sortKey = 0;
    list sortedData = [];
    integer origIdx = 0;
    
    for (i = 0; i < totalEntries; i++) {
        base = i * 3;
        wins = llList2Integer(leaderboardData, base + 1);
        losses = llList2Integer(leaderboardData, base + 2);
        
        if (wins > 65535) wins = 65535;
        if (losses > 65535) losses = 65535;
        
        sortKey = (wins << 16) | (65535 - losses);
        sortList += [sortKey, i];
    }
    
    // 2. Sort by key (stride of 2) in descending order (highest score first)
    sortList = llListSort(sortList, 2, FALSE);
    
    // 3. Rebuild the leaderboard data in sorted order (Stided list: Name, Wins, Losses)
    for (i = 0; i < llGetListLength(sortList); i += 2) {
        origIdx = llList2Integer(sortList, i + 1);
        base = origIdx * 3;
        sortedData += [
            llList2String(leaderboardData, base),
            llList2Integer(leaderboardData, base + 1),
            llList2Integer(leaderboardData, base + 2)
        ];
    }
    
    return sortedData;
}

// Generate leaderboard text and send to separate leaderboard object
integer generateLeaderboardText() {
    list sortedData = getSortedLeaderboard();
    string SPACES = "                                "; 
    string title = "TOP BATTLE RECORDS";
    string rankCol = "";
    string nameCol = "";
    string statsCol = "";
    
    integer numSorted = llGetListLength(sortedData) / 3;
    integer genI;
    integer base;
    string playerName;
    integer genWins;
    integer genLosses;
    string rank;
    string sWins;
    string sLosses;
    
    // 1. Send Title to Parent Box (Row 0)
    integer titleMargin = (LEADERBOARD_WIDTH - llStringLength(title)) / 2;
    if (titleMargin < 0) titleMargin = 0;
    string titleText = llGetSubString(SPACES, 0, titleMargin - 1) + title;
    llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "FORMATTED_TEXT|" + titleText, NULL_KEY);
    
    // Add actual player data column-by-column
    for (genI = 0; genI < numSorted && genI < MAX_LEADERBOARD_ENTRIES; genI++) {
        base = genI * 3;
        playerName = llList2String(sortedData, base);
        genWins = llList2Integer(sortedData, base + 1);
        genLosses = llList2Integer(sortedData, base + 2);
        
        if (llStringLength(playerName) > 19) playerName = llGetSubString(playerName, 0, 16) + "...";
        
        rank = (string)(genI + 1) + ".";
        if (genI < 9) rank = "0" + rank;
        
        sWins = (string)genWins;
        sLosses = (string)genLosses;
        
        rankCol += rank + "\n";
        nameCol += playerName + "\n";
        statsCol += "W:" + sWins + "/L:" + sLosses + "\n";
    }
    
    // Fill remaining positions with placeholders
    for (genI = numSorted; genI < MAX_LEADERBOARD_ENTRIES; genI++) {
        rank = (string)(genI + 1) + ".";
        if (genI < 9) rank = "0" + rank;
        
        rankCol += rank + "\n";
        nameCol += "----------\n";
        statsCol += "W:0/L:0\n";
    }
    
    // Send 3-column data to bridge
    llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "COLUMNS|" + rankCol + "|" + nameCol + "|" + statsCol, NULL_KEY);
    return 0;
}

// Reset leaderboard data (SECURED for Creator Only)
integer resetLeaderboard() {
    // PROTECT THE GLOBAL DATABASE!
    if (llGetOwner() != llGetCreator()) {
        llOwnerSay("❌ Access Denied: Only the creator of Peril Dice can wipe the Global Scoreboard!");
        return 0;
    }
    
    leaderboardData = [];
    pendingSerialize = "";
    kvpWriteReq = llUpdateKeyValue("Peril_LB_Top50", "", FALSE, "");
    generateLeaderboardText(); // Send empty leaderboard immediately
    return 0;
}

// Clear all current players from the scoreboard
integer clearAllPlayers() {
    activePlayers = [];
    
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
        clearProfilePrimIndex = getProfilePrimLink(clearI);
        clearHeartsPrimIndex = getHeartsPrimLink(clearI);
        clearOverlayPrimIndex = getOverlayPrimLink(clearI);
        
        // SAFETY CHECK - use if block instead of continue for maximum compatibility
        if (clearProfilePrimIndex > 0) {
            // Reset profile prim to default and hide it
            llSetLinkPrimitiveParamsFast(clearProfilePrimIndex, [
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Hidden by default
                PRIM_TEXT, "", <1,1,1>, 0.0,
                PRIM_GLOW, ALL_SIDES, 0.0
            ]);
            
            // Reset hearts prim to 3 hearts and hide it
            llSetLinkPrimitiveParamsFast(clearHeartsPrimIndex, [
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Hidden by default
                PRIM_TEXT, "", <1,1,1>, 0.0,
                PRIM_GLOW, ALL_SIDES, 0.0
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
    integer idx = llListFindList(activePlayers, [playerName]);
    if (idx != -1) {
        activePlayers = llDeleteSubList(activePlayers, idx, idx + 2);
        refreshPlayerDisplay();
        dbg("📈 Player removed: " + playerName);
    }
    return 0;
}

integer refreshPlayerDisplay() {
    integer numActivePlayers = llGetListLength(activePlayers) / 3;
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
        refreshProfilePrimIndex = getProfilePrimLink(refreshI);
        refreshHeartsPrimIndex = getHeartsPrimLink(refreshI);
        refreshOverlayPrimIndex = getOverlayPrimLink(refreshI);
        
        if (refreshProfilePrimIndex > 0) {
            // Unused slots: Reset and HIDE
            llSetLinkPrimitiveParamsFast(refreshProfilePrimIndex, [
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_DEFAULT_PROFILE, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Invisible
                PRIM_TEXT, "", <1,1,1>, 0.0
            ]);
            
            llSetLinkPrimitiveParamsFast(refreshHeartsPrimIndex, [
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_3_HEARTS, <1,1,0>, <0,0,0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 0.0, // Invisible
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
        integer base = refreshI * 3;
        r_name = llList2String(activePlayers, base);
        r_lives = llList2Integer(activePlayers, base + 1);
        r_profileTexture = llList2String(activePlayers, base + 2);
        
        // Calculate prim indices for this position
        r_profileIdx = getProfilePrimLink(refreshI);
        r_heartsIdx = getHeartsPrimLink(refreshI);
        r_overlayIdx = getOverlayPrimLink(refreshI);
        
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
integer getProfilePrimLink(integer playerIndex) { return llList2Integer(gridLinks, playerIndex * 3); }
integer getHeartsPrimLink(integer playerIndex) { return llList2Integer(gridLinks, (playerIndex * 3) + 1); }
integer getOverlayPrimLink(integer playerIndex) { return llList2Integer(gridLinks, (playerIndex * 3) + 2); }

string getHeartTexture(integer lives) {
    if (lives <= 0) return TEXTURE_0_HEARTS;
    else if (lives == 1) return TEXTURE_1_HEARTS;
    else if (lives == 2) return TEXTURE_2_HEARTS;
    else return TEXTURE_3_HEARTS; // 3 or more
}

// Helper to set glow and color on a prim
setGlow(integer link, float glow, vector color) {
    if (link > 0) {
        llSetLinkPrimitiveParamsFast(link, [PRIM_GLOW, ALL_SIDES, glow, PRIM_COLOR, ALL_SIDES, color, 1.0]);
    }
}

// Update all glow effects (peril and winner)
integer updatePlayerGlowEffects() {
    integer numPlayers = llGetListLength(activePlayers) / 3;
    integer glowI;
    for (glowI = 0; glowI < numPlayers; glowI++) {
        setGlow(getProfilePrimLink(glowI), 0.0, <1,1,1>);
        setGlow(getHeartsPrimLink(glowI), 0.0, <1,1,1>);
    }
    
    integer idx = -1;
    vector col = <1,1,1>;
    float glow = 0.0;
    
    if (currentWinner != "" && currentWinner != "NONE") {
        idx = llListFindList(activePlayers, [currentWinner]);
        if (idx != -1) { idx = idx / 3; col = <0,1,0>; glow = 0.3; }
    } else if (currentPerilPlayer != "" && currentPerilPlayer != "NONE") {
        idx = llListFindList(activePlayers, [currentPerilPlayer]);
        if (idx != -1) { idx = idx / 3; col = <1,1,0>; glow = 0.2; }
    }
    
    if (idx != -1) {
        setGlow(getProfilePrimLink(idx), glow, col);
        setGlow(getHeartsPrimLink(idx), glow, col);
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
    integer playerIndex = llListFindList(activePlayers, [playerName]);
    if (playerIndex != -1) playerIndex = playerIndex / 3;
    
    if (playerIndex == -1) {
        playerIndex = llGetListLength(activePlayers) / 3;
        if (playerIndex >= 10) {
            dbg("📈 MAX players reached: " + playerName);
            return 0;
        }
        
        string activeUUID = profileUUID;
        if (isBot(playerName)) activeUUID = TEXTURE_BOT_PROFILE;
        activePlayers += [playerName, lives, activeUUID];
        
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
        activePlayers = llListReplaceList(activePlayers, [lives], (playerIndex * 3) + 1, (playerIndex * 3) + 1);
    }
    
    // Update the physical prims for this player
    integer updateProfilePrimIndex = getProfilePrimLink(playerIndex);
    integer updateHeartsPrimIndex = getHeartsPrimLink(playerIndex);
    integer updateOverlayPrimIndex = getOverlayPrimLink(playerIndex);
    
    if (updateProfilePrimIndex <= 0) return 0;
    
    // Update profile prim texture - show red X if eliminated, otherwise show profile
    string updateProfileTexture;
    
    if (lives <= 0) {
        // Player is eliminated - keep profile picture but show red X on overlay prim
        dbg("📈 [Scoreboard Manager] 💀 Scoreboard: Showing elimination X overlay for " + playerName);
        
        // CRITICAL: Still need to set updateProfileTexture for eliminated players
        if (isBot(playerName)) {
            updateProfileTexture = TEXTURE_BOT_PROFILE;
        } else {
            string updateCachedTexture = llList2String(activePlayers, (playerIndex * 3) + 2);
            if (updateCachedTexture != "" && updateCachedTexture != profileUUID && 
                updateCachedTexture != TEXTURE_DEFAULT_PROFILE && updateCachedTexture != TEXTURE_BOT_PROFILE &&
                updateCachedTexture != TEXTURE_ELIMINATED_X) {
                updateProfileTexture = updateCachedTexture;
            } else {
                updateProfileTexture = TEXTURE_DEFAULT_PROFILE;
            }
        }
    } else {
        // Player is alive - determine profile texture to use
        updateProfileTexture = profileUUID;
        
        // Check if we already have a cached profile texture for this player
        string liveCachedTexture = llList2String(activePlayers, (playerIndex * 3) + 2);
        if (liveCachedTexture != "" && liveCachedTexture != profileUUID && 
            liveCachedTexture != TEXTURE_DEFAULT_PROFILE && liveCachedTexture != TEXTURE_BOT_PROFILE &&
            liveCachedTexture != TEXTURE_ELIMINATED_X) {
            updateProfileTexture = liveCachedTexture;
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
                dbg("Default texture");
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
        REPORT_MEMORY();
        dbg("Ready");
        
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
        
        dbg("Init complete");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        // Handle messages from the game logic and bridges
        
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
                dbg("Update: " + playerName);
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
            
            dbg("Peril: " + currentPerilPlayer);
            
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
            
            dbg("Winner: " + currentWinner);
            
            // Update glow effects - winner glow overrides peril glow
            updatePlayerGlowEffects();
        }
        else if (num == MSG_DISPLAY_LEADERBOARD && str == "REFRESH_STARTUP") {
            // Startup handshake from leaderboard bridge - re-send text now that boxes are ready
            dbg("📋 [Scoreboard] Handshake received! Refreshing virtual columns...");
            generateLeaderboardText();
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        // Handle profile picture HTTP responses
        integer requestIndex = llListFindList(httpRequests, [request_id]);
        if (requestIndex != -1) {
            integer playerIndex = llList2Integer(httpRequests, requestIndex + 1);
            
            // Remove this request from tracking
            httpRequests = llDeleteSubList(httpRequests, requestIndex, requestIndex + 1);
            
            if (status == 200 && playerIndex < llGetListLength(activePlayers) / 3) {
                // Parse the HTML to extract profile image UUID
                string profileUUID = "";
                
                // Try the meta tag method first
                integer metaStart = llSubStringIndex(body, PROFILE_KEY_PREFIX);
                if (metaStart != -1) {
                    metaStart += PROFILE_KEY_PREFIX_LENGTH;
                    string remainingBody = llGetSubString(body, metaStart, -1);
                    integer metaEnd = llSubStringIndex(remainingBody, "\"");
                    if (metaEnd != -1) {
                        profileUUID = llGetSubString(remainingBody, 0, metaEnd - 1);
                    }
                }
                
                // If meta tag failed, try img src method
                if (profileUUID == "") {
                    integer imgStart = llSubStringIndex(body, PROFILE_IMG_PREFIX);
                    if (imgStart != -1) {
                        imgStart += PROFILE_IMG_PREFIX_LENGTH;
                        string remainingBody = llGetSubString(body, imgStart, -1);
                        integer imgEnd = llSubStringIndex(remainingBody, "/");
                        if (imgEnd != -1) {
                            profileUUID = llGetSubString(remainingBody, 0, imgEnd - 1);
                        }
                    }
                }
                
                // If we got a valid UUID, update the profile prim and cache it
                if (profileUUID != "" && profileUUID != "00000000-0000-0000-0000-000000000000") {
                    // Update the cached profile texture in stride
                    activePlayers = llListReplaceList(activePlayers, [profileUUID], (playerIndex * 3) + 2, (playerIndex * 3) + 2);
                    
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
                        
                        string playerName = llList2String(activePlayers, playerIndex * 3);
                        dbg("Profile updated: " + playerName);
                    } else {
                        dbg("Invalid prim: " + (string)profilePrimIndex);
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
                    leaderboardData = [];
                    
                    list entries = llParseString2List(val, ["|"], []);
                    integer i;
                    for (i = 0; i < llGetListLength(entries); i++) {
                        string data_entry = llList2String(entries, i);
                        list parts = llParseString2List(data_entry, [":"], []);
                        if (llGetListLength(parts) >= 3) {
                            leaderboardData += [
                                llList2String(parts, 0),
                                (integer)llList2String(parts, 1),
                                (integer)llList2String(parts, 2)
                            ];
                        }
                    }
                    dbg("LB Loaded");
                } else if (status == "3") { 
                    leaderboardData = [];
                    dbg("LB Empty");
                } else {
                    dbg("LB Error: " + status);
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
                    dbg("LB Saved");
                    pendingSerialize = ""; 
                }
            }
        }
    }
    
    
    timer() {
        dbg("Timer");
        loadLeaderboardData();
    }
    
    listen(integer channel, string name, key id, string message) {
        string msg = llToLower(llStringTrim(message, STRING_TRIM));
        if (msg == "testx") {
            llOwnerSay("🛠️ [Scoreboard] Testing FULL LAYOUT on all 10 slots (Forced Alpha Reveal)...");
            integer i;
            for (i = 0; i < 10; i++) {
                integer pIdx = getProfilePrimLink(i);
                integer hIdx = getHeartsPrimLink(i);
                integer oIdx = getOverlayPrimLink(i);
                
                if (pIdx > 0) {
                    llSetLinkPrimitiveParamsFast(pIdx, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
                    llSetLinkPrimitiveParamsFast(hIdx, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
                    llSetLinkPrimitiveParamsFast(oIdx, [
                        PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0,
                        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0
                    ]);
                }
            }
        }
        else if (msg == "clearx") {
            refreshPlayerDisplay();
        }
    }
}
