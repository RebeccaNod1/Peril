// =============================================================================
// PERIL DICE - CENTRAL CONSTANTS (Preprocessor Version)
// =============================================================================

// --- Linkset Layout (Dynamic Discovery) ---
integer LINK_CONTROLLER = 1;         // Usually Root (link 1)
integer LINK_SCOREBOARD = -1;       // "Scoreboard:0:0"
integer LINK_DICE_BRIDGE = -1;      // "FURWARE text mesh:Dice:0:0"
integer LINK_LEADERBOARD_BRIDGE = -1; // "FURWARE text mesh:Leaderboard:0:0"
integer LINK_STATUS_BRIDGE = -1;      // "FURWARE text mesh:Status:0:0"
integer LINK_BACKBOARD = -1;          // "backboard:0:0"
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
        else if (_name == "backboard:0:0") LINK_BACKBOARD = _i; \
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

#define MSG_DEBUG_TEXT 7000

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

// --- World Ranking Leaderboard (4000-4099) ---
#define MSG_LB_LOAD_COMPLETE 4001
#define MSG_LB_RECORD_PLAYER 4002
#define MSG_LB_REQUEST_DISPLAY 4003
#define MSG_LB_DISPLAY_DATA 4004
#define MSG_LB_PAGE_NEXT 4005
#define MSG_LB_PAGE_PREV 4006
#define MAX_LB_PAGES 10                  // 10 keys (Peril_LB_1 to Peril_LB_10)
#define LB_KEY_PREFIX "Peril_LB_"        // Base name for sharded keys
#define LB_LOCK_KEY "Peril_LB_LOCK"       // KVP lock for multi-board synchronization
#define LB_LOCK_TIMEOUT 60               // Lock expiry in seconds
#define MAX_ENTRIES_PER_PAGE 50          // 50 players per key
#define MAX_WORLD_RANKING 500            // Total capacity (Pages * Entries)
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
#define MSG_TOUCH_EVENT 215
#define MSG_PROCESS_ELIMINATION 3015


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
#define SHOW_MEMORY 0           // Toggle this to 1 to see memory usage on rez/reset

#define REPORT_MEMORY() { \
    integer used = llGetUsedMemory(); \
    integer free = llGetFreeMemory(); \
    integer total = used + free; \
    float percent = ((float)used / (float)total) * 100.0; \
    dbg("🧠 [" + llGetScriptName() + "] Memory: " + (string)used + " used, " + (string)free + " free (" + llGetSubString((string)percent, 0, 4) + "% used)."); \
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

// --- Timing & Delays ---
#define DELAY_SCAN_LINKSET 1.5           // Link scanner delay
#define DELAY_DIALOG_REFRESH 0.2         // Brief delay before refreshing/showing dialog (0.2s)
#define DELAY_BRIDGE_READY 1.0           // Delay for bridge initialization (1.0s)
#define DELAY_LEADERBOARD_SYNC 1.0       // Delay for leaderboard synchronization (1.0s)
#define DELAY_LEADERBOARD_READY 0.5      // Delay for leaderboard system readiness (0.5s)
#define DELAY_FLOATER_REZ 0.2            // Delay between floater rezzing (0.2s)
#define DELAY_FLOATER_UPDATE 0.05        // Very brief delay for floater updates (0.05s)
#define DELAY_SCOREBOARD_REFRESH 0.1     // Scoreboard refresh delay (0.1s)
#define DELAY_STATE_TRANSITION 0.5       // Generic state transition sleep (0.5s)
#define DELAY_ELIMINATION_NOTICE 2.0     // Time given to show eliminated status (2.0s)
#define DELAY_VICTORY_NOTICE 1.5         // Additional time for victory scenarios (1.5s)
#define DELAY_SYNC_PROPAGATION 0.5       // Time for linked messages to propagate (0.5s)
#define DELAY_GAME_RESET 2.0             // Delay during full system reset (2.0s)
#define DELAY_GENERIC_TICK 0.3           // Generic tick delay (0.3s)
#define DELAY_LONG_SYNC 4.0              // Long dramatic pause or heavy sync (4.0s)
#define DELAY_SHORT_SYNC 0.1             // Very short sync buffer (0.1s)
#define DELAY_MEDIUM_SYNC 1.0            // Medium sync buffer (1.0s)
#define DELAY_ANTI_SPAM 0.5              // Delay to prevent message loops/spam (0.5s)
#define DELAY_CONFETTI_START 2.0         // Delay before confetti effects (2.0s)
#define DELAY_CONFETTI_DURATION 4.0      // Duration confetti stays active (4.0s)
#define DELAY_CONFETTI_TICK 0.2          // Confetti particle interval (0.2s)
#define DELAY_CONFETTI_PREP 0.5          // Confetti preparation delay (0.5s)
#define DELAY_FLOAT_UPDATE 0.1           // Floater status update delay (0.1s)
// --- Game Timing Settings (Originals relocated here) ---
#define BOT_PICK_DELAY 2.0               // Bot picking decision time (2.0s)
#define HUMAN_PICK_DELAY 1.0             // Human picking buffer (1.0s)
#define DIALOG_DELAY 1.5                 // Base dialog presentation delay (1.5s)
#define STATUS_DISPLAY_TIME 8.0          // How long status text stays on display (8.0s)
#define BOT_RESPONSE_DELAY 1.5           // Bot response timing (1.5s)

// --- Security ---
#define GLOBAL_ADMIN "3e01527d-a9ff-4776-b2b8-918ab622f70f"
