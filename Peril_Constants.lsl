// =============================================================================
// PERIL DICE - CENTRAL CONSTANTS (Preprocessor Version)
// =============================================================================

// --- Linkset Layout (Dynamic Discovery) ---
integer LINK_CONTROLLER = 1;         // Usually Root (link 1)
integer LINK_SCOREBOARD = -1;       // "Scoreboard:0:0"
integer LINK_DICE_BRIDGE = -1;      // "FURWARE text mesh:Dice:0:0"
integer LINK_LEADERBOARD_BRIDGE = -1; // "FURWARE text mesh:Leaderboard:0:0"
integer LINK_STATUS_BRIDGE = -1;      // "FURWARE text mesh:Status:0:0"
key EXPERIENCE_ID = "06926390-26e6-11f1-a452-0242ac110003"; // Final Girlz I.N.C.
#define PARCEL_DETAILS_EXPERIENCE_LIST 18

// Macro to discover core links by name
#define DISCOVER_CORE_LINKS() { \
    integer _i; \
    integer _total = llGetNumberOfPrims(); \
    for (_i = 1; _i <= _total; _i++) { \
        string _name = llGetLinkName(_i); \
        if (_name == "Scoreboard:0:0") LINK_SCOREBOARD = _i; \
        else if (_name == "FURWARE text mesh:Dice:0:0") LINK_DICE_BRIDGE = _i; \
        else if (_name == "FURWARE text mesh:Leaderboard:0:0") LINK_LEADERBOARD_BRIDGE = _i; \
        else if (_name == "FURWARE text mesh:Status:0:0") LINK_STATUS_BRIDGE = _i; \
        else if (LINK_CONTROLLER == 1 && _i == 1) { ; /* Default to root if not found */ } \
    } \
    /* Safety Fallback: Use Root if Scoreboard prim is missing */ \
    if (LINK_SCOREBOARD == -1) LINK_SCOREBOARD = 1; \
}

// --- FURWARE Text Commands ---
#define FW_DATA "fw_data"
#define FW_CONF "fw_conf"
#define FW_READY "fw_ready"
#define FW_DONE "fw_done"

// --- System/Debug (9000-9999) ---
#define DEBUG_LOGS 0           // GLOBAL MASTER SWITCH - Set to 1 for dev feedback, 0 to STRIP from memory
#if DEBUG_LOGS
#define dbg(msg) llOwnerSay(msg)
#else
#define dbg(msg) ;
#endif

#define MSG_RESET_ALL -99999
#define MSG_EMERGENCY_RESET -99998
#define MSG_DEBUG_PICKS_ON 7001
#define MSG_DEBUG_PICKS_OFF 7002
#define MSG_UPDATE_MAIN_LISTS 9040

// --- Game Flow (3000-3099) ---
#define MSG_GAME_STATUS 3001
#define MSG_UPDATE_LIFE 80    // Unified damage reporting
#define MSG_PLAYER_UPDATE 3002
#define MSG_CLEAR_GAME 3003
#define MSG_REMOVE_PLAYER 3004
#define MSG_UPDATE_PERIL_PLAYER 3005
#define MSG_UPDATE_WINNER 3006
#define MSG_GAME_WON 3010
#define MSG_GAME_LOST 3011
#define MSG_RESET_LEADERBOARD 3012
#define MSG_DISPLAY_LEADERBOARD 3013
#define MSG_STATUS_TEXT 3007
#define MSG_DICE_ROLL 3020
#define MSG_CLEAR_DICE 3021
#define MSG_DICE_CLEAR 3021 // Alias for consistency in dice bridge
#define MSG_ROLL_RESULT 102
#define MSG_PLAYER_WON 551
#define MSG_ELIMINATE_PLAYER 999
#define MSG_CONTINUE_GAME 998
#define MSG_CONTINUE_ROUND 998 // Alias for consistency across scripts
#define MSG_EFFECT_CONFETTI 995
#define MSG_GET_DICE_TYPE 1001
#define MSG_DICE_TYPE_RESULT 1005

// --- Player/Registration (9000-9099) ---
#define MSG_REGISTER_PLAYER 106            // Legacy Registration ID (Backward Compatibility)
#define MSG_REGISTER_PLAYER_REQUEST 9050   // New Standard Registration ID
#define MSG_OWNER_MESSAGE 9030
#define MSG_PUBLIC_MESSAGE 9031
#define MSG_REGION_MESSAGE 9032
#define MSG_DIALOG_REQUEST 9033
#define MSG_DIALOG_FORWARD_REQUEST 9060
#define MSG_SYNC_GAME_STATE 107
#define MSG_SYNC_PICKQUEUE 2001
#define MSG_SYNC_LIGHTWEIGHT 9070
#define MSG_SYNC_LEGACY 9071
#define MSG_SERIALIZE_GAME_STATE 9072
#define MSG_LEAVE_GAME_REQUEST 8006
#define MSG_LEAVE_GAME 8007
#define MSG_REQUEST_PLAYER_LIST_KICK 8009
#define MSG_LOCK_GAME 9001
#define MSG_UNLOCK_GAME 9002

// --- Dialogs & Menus (100-399) ---
#define MSG_SHOW_MENU 201
#define MSG_SHOW_DIALOG 101
#define MSG_GET_CURRENT_DIALOG 302
#define MSG_SHOW_ROLL_DIALOG 301
#define MSG_CLOSE_ALL_DIALOGS -9999
#define MSG_TOGGLE_READY 202
#define MSG_QUERY_READY_STATE 210
#define MSG_READY_STATE_RESULT 211
#define MSG_QUERY_OWNER_STATUS 213
#define MSG_OWNER_STATUS_RESULT 214

// --- Float Management (100-199) ---
#define MSG_REZ_FLOAT 105
#define MSG_REZ_FLOATER 105    // Alias for consistency
#define MSG_UPDATE_FLOAT 103
#define MSG_CLEANUP_FLOAT 104
#define MSG_CLEANUP_ALL_FLOATERS 212

// --- Data Requests (200-299) ---
#define MSG_REQUEST_PLAYER_LIST_PICK 202
#define MSG_PLAYER_LIST_PICK_RESULT 203
#define MSG_PLAYER_LIST_RESULT 203 // Alias for consistency across scripts
#define MSG_PICK_ACTION 204
#define MSG_PICK_LIST_RESULT 205
#define MSG_OWNER_PICK_MANAGER 206
#define MSG_LIFE_LOOKUP_REQUEST 207
#define MSG_LIFE_LOOKUP_RESULT 208
#define MSG_QUERY_OWNER_STATUS 213

// --- Memory Management (6000-6099) ---
#define SHOW_MEMORY 1           // Toggle this to 1 to see memory usage on rez/reset

#define REPORT_MEMORY() { \
    if (SHOW_MEMORY) { \
        integer used = llGetUsedMemory(); \
        integer free = llGetFreeMemory(); \
        float percent = ((float)used / (float)(used + free)) * 100.0; \
        llOwnerSay("🧠 [" + llGetScriptName() + "] Memory: " + (string)used + " used, " + (string)free + " free (" + llGetSubString((string)percent, 0, 4) + "% used)."); \
    } \
}

#define MSG_MEMORY_CHECK 6001
#define MSG_MEMORY_STATS 6002
#define MSG_MEMORY_CLEANUP 6003
#define MSG_MEMORY_REPORT 6004
#define MSG_EMERGENCY_CLEANUP 6005
#define MSG_MEMORY_STATS_REQUEST 6006
#define MSG_MEMORY_STATS_RESULT 6007

// --- Bot Management ---
#define MSG_BOT_PICKED -9997
#define MSG_HUMAN_PICKED -9998
#define MSG_BOT_COMMAND -9999

// --- Helper Functions Support ---
#define MSG_GET_PICKS_REQUIRED 1002
#define MSG_GET_PICKER_INDEX 1003
