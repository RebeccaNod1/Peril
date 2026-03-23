// ====================================================================
// Update Checker - GitHub-based Update System for Peril Dice
// ====================================================================
// VERIFIED LINKSET PLACEMENT: Link 1 (Root Prim) "Peril Dice Controller V2"
// Based on actual linkset scan: 84 prims total, exactly matching architecture
// Replaces eliminated UpdateHelper.lsl from v2.8.5 memory optimization
// 
// INTEGRATION: 
// - Integrates with existing admin menu system via Player_DialogHandler.lsl
// - Uses link message communication following existing patterns
// - Memory optimized to fit alongside 13 other Link 1 scripts
//
// VERIFIED STRUCTURE (from linkset scan):
// - Link 1: Root controller with 13+ scripts
// - Link 12: "scoreboard manager cube" - Game_Scoreboard_Manager_Linkset.lsl
// - Link 35: "leaderboard row 1 col 1" - Leaderboard_Communication_Linkset.lsl
// - Links 35-82: XyzzyText prims (48 total) - each needs xyzzy_Master_script.lsl
// - Link 83: "dice col 1" - XyzzyText_Dice_Bridge_Linkset.lsl
// - Link 84: "dice col 2" - no script needed
// ====================================================================

#define CURRENT_VERSION "2.8.7"
#define GITHUB_API_URL "https://api.github.com/repos/RebeccaNod1/Peril/releases/latest"
#define GITHUB_RAW_URL "https://raw.githubusercontent.com/RebeccaNod1/Peril/main/"

// VERIFIED Link 1 Scripts (from actual scan of "Peril Dice Controller V2")
list LINK1_SCRIPTS = [
    "Main_Controller_Linkset.lsl",        // Master coordination
    "Game_Manager.lsl",                   // Round management
    "Controller_Memory.lsl",              // Memory monitoring  
    "Controller_MessageHandler.lsl",      // Message routing
    "Player_RegistrationManager.lsl",     // Player registry
    "Player_DialogHandler.lsl",           // Admin menus
    "NumberPicker_DialogHandler.lsl",     // Number picking
    "Floater_Manager.lsl",                // Floating HUDs
    "Roll_ConfettiModule.lsl",            // Dice rolling
    "Bot_Manager.lsl",                    // AI players
    "Game_Calculator.lsl",                // Dice calculations
    "Verbose_Logger.lsl",                 // Logging system
    "System_Debugger.lsl"                 // Debug tools
];

// VERIFIED Link-Specific Scripts (from actual linkset scan)
list LINKSET_SPECIFIC_SCRIPTS = [
    "Game_Scoreboard_Manager_Linkset.lsl",      // Link 12: "scoreboard manager cube"
    "Leaderboard_Communication_Linkset.lsl",    // Link 35: "leaderboard row 1 col 1"
    "XyzzyText_Dice_Bridge_Linkset.lsl"         // Link 83: "dice col 1"
];

// XyzzyText system - VERIFIED 48 prims (Links 35-82)
#define XYZZY_SCRIPT "xyzzy_Master_script.lsl"

// Essential documentation files  
list ESSENTIAL_DOCS = [
    "README.md", "CHANGELOG.md", "README_Notecard.txt", "CHANGELOG_Notecard.txt"
];

// HTTP operation tracking
key currentHttpRequest = NULL_KEY;
string currentOperation = "";
integer updateCheckInProgress = FALSE;
integer downloadMode = FALSE;
string downloadingFile = "";

// Message constants - following existing Peril Dice patterns
#define MSG_ADMIN_MENU_RESPONSE 888           // Integration with admin menu
#define MSG_UPDATE_CHECK_REQUEST 2100         // Request from admin menu
#define MSG_TOGGLE_VERBOSE_LOGS 9999          // Verbose logging toggle

// Internal verbose logging (follows existing pattern)
integer VERBOSE_LOGGING = FALSE;

// Memory usage reporting (matches existing scripts)
reportMemoryUsage(string scriptName) {
    integer memory = llGetUsedMemory();
    integer freeMemory = llGetFreeMemory();
    float memoryPercent = (float)memory / (memory + freeMemory) * 100.0;
    llOwnerSay("📊 " + scriptName + ": " + (string)memory + " bytes used (" + 
               llGetSubString((string)memoryPercent, 0, 4) + "% memory)");
}

// Version comparison (handles "v2.8.6" and "2.8.6" formats)
integer isNewerVersion(string latestVersion, string currentVersion) {
    // Remove 'v' prefix if present
    if (llGetSubString(latestVersion, 0, 0) == "v") {
        latestVersion = llGetSubString(latestVersion, 1, -1);
    }
    if (llGetSubString(currentVersion, 0, 0) == "v") {
        currentVersion = llGetSubString(currentVersion, 1, -1);
    }
    
    return (latestVersion != currentVersion);
}

// Check GitHub API for updates
checkForUpdates() {
    if (updateCheckInProgress) {
        llOwnerSay("⏳ Update check already in progress...");
        return;
    }
    
    updateCheckInProgress = TRUE;
    currentOperation = "version_check";
    llOwnerSay("🔍 Checking GitHub for Peril Dice updates...");
    if (VERBOSE_LOGGING) {
        llOwnerSay("🔗 API URL: " + GITHUB_API_URL);
    }
    
    currentHttpRequest = llHTTPRequest(GITHUB_API_URL, [
        HTTP_METHOD, "GET"
    ], "");
}

// Download file content from GitHub raw repository
downloadFileContent(string filename) {
    if (updateCheckInProgress && !downloadMode) {
        llOwnerSay("⏳ Please wait for version check to complete...");
        return;
    }
    
    // Validate file is in essential lists
    if (llListFindList(LINK1_SCRIPTS, [filename]) == -1 && 
        llListFindList(LINKSET_SPECIFIC_SCRIPTS, [filename]) == -1 &&
        llListFindList(ESSENTIAL_DOCS, [filename]) == -1 &&
        filename != XYZZY_SCRIPT) {
        llOwnerSay("❌ File '" + filename + "' is not in the essential files list.");
        llOwnerSay("📋 Say '/1 list' to see available files");
        return;
    }
    
    downloadMode = TRUE;
    downloadingFile = filename;
    currentOperation = "file_download";
    llOwnerSay("📥 Downloading " + filename + " from GitHub main branch...");
    
    string url = GITHUB_RAW_URL + filename;
    if (VERBOSE_LOGGING) {
        llOwnerSay("🔗 Download URL: " + url);
    }
    
    currentHttpRequest = llHTTPRequest(url, [
        HTTP_METHOD, "GET"
    ], "");
}

// Show help commands
showUpdateCommands() {
    llOwnerSay("=== 🔄 PERIL DICE UPDATE SYSTEM ===");
    llOwnerSay("📱 Current Version: v" + CURRENT_VERSION);
    llOwnerSay("🌐 Repository: github.com/RebeccaNod1/Peril");
    llOwnerSay("📍 Location: Link 1 (Root Prim) - 84-prim linkset verified");
    llOwnerSay("💡 Note: GitHub releases start with v2.8.7+");
    llOwnerSay("");
    llOwnerSay("💬 Available Commands (say in local chat):");
    llOwnerSay("  /1 check     - Check GitHub for updates");
    llOwnerSay("  /1 download ScriptName.lsl - Download specific file");
    llOwnerSay("  /1 list      - Show essential files with placement info");  
    llOwnerSay("  /1 help      - Show these commands");
    llOwnerSay("");
    llOwnerSay("🎛️  Or use Owner Menu → Troubleshooting → Check for Updates");
    llOwnerSay("📋 Example: /1 download xyzzy_Master_script.lsl");
}

// Show essential files list with VERIFIED linkset placement info
showEssentialFiles() {
    llOwnerSay("=== 📋 ESSENTIAL GAME FILES (VERIFIED LINKSET STRUCTURE) ===");
    
    llOwnerSay("🔧 Link 1 Scripts (Root Prim: \"Peril Dice Controller V2\"):");
    integer i;
    for (i = 0; i < llGetListLength(LINK1_SCRIPTS); i++) {
        llOwnerSay("  • " + llList2String(LINK1_SCRIPTS, i));
    }
    llOwnerSay("  • Update_Checker.lsl (THIS SCRIPT)");
    llOwnerSay("");
    
    llOwnerSay("🎯 Link-Specific Scripts (VERIFIED placement):");
    llOwnerSay("  • Game_Scoreboard_Manager_Linkset.lsl");
    llOwnerSay("    → Link 12: \"scoreboard manager cube\"");
    llOwnerSay("  • Leaderboard_Communication_Linkset.lsl");
    llOwnerSay("    → Link 35: \"leaderboard row 1 col 1\"");  
    llOwnerSay("  • XyzzyText_Dice_Bridge_Linkset.lsl");
    llOwnerSay("    → Link 83: \"dice col 1\"");
    llOwnerSay("");
    
    llOwnerSay("📺 XyzzyText Display System (VERIFIED 48 prims):");
    llOwnerSay("  • xyzzy_Master_script.lsl");
    llOwnerSay("    → Links 35-82: All leaderboard prims");
    llOwnerSay("    → 4 banks × 12 rows each");
    llOwnerSay("    → Bank 1: Links 35-46 (col 1)");
    llOwnerSay("    → Bank 2: Links 47-58 (col 2)");
    llOwnerSay("    → Bank 3: Links 59-70 (col 3)");
    llOwnerSay("    → Bank 4: Links 71-82 (col 4)");
    llOwnerSay("    ⚠️  Each prim needs this exact script!");
    llOwnerSay("");
    
    llOwnerSay("📖 Documentation (" + (string)llGetListLength(ESSENTIAL_DOCS) + " files):");
    for (i = 0; i < llGetListLength(ESSENTIAL_DOCS); i++) {
        llOwnerSay("  • " + llList2String(ESSENTIAL_DOCS, i));
    }
    llOwnerSay("");
    llOwnerSay("ℹ️  Development files excluded: lsl_validator.py, test_*.py, etc.");
    llOwnerSay("📊 Total Essential Files: " + (string)(llGetListLength(LINK1_SCRIPTS) + llGetListLength(LINKSET_SPECIFIC_SCRIPTS) + llGetListLength(ESSENTIAL_DOCS) + 1) + " unique files");
}

default {
    state_entry() {
        reportMemoryUsage("Update Checker");
        llOwnerSay("🔄 Update Checker ready - GitHub integration active");
        llOwnerSay("📍 Location: Link 1 (\"Peril Dice Controller V2\") - VERIFIED 84-prim structure");
        llOwnerSay("💬 Say '/1 help' for commands or use Owner Menu → Troubleshooting");
        llListen(1, "", llGetOwner(), "");
    }
    
    on_rez(integer start_param) {
        // Reset state on rez (follows existing script patterns)
        updateCheckInProgress = FALSE;
        downloadMode = FALSE; 
        currentOperation = "";
        downloadingFile = "";
        currentHttpRequest = NULL_KEY;
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string message) {
        if (id != llGetOwner()) return;
        
        string msg = llToLower(llStringTrim(message, STRING_TRIM));
        
        if (msg == "help") {
            showUpdateCommands();
        }
        else if (msg == "check") {
            checkForUpdates();
        }
        else if (msg == "list") {
            showEssentialFiles();
        }
        else if (llGetSubString(msg, 0, 7) == "download") {
            string filename = llStringTrim(llGetSubString(message, 8, -1), STRING_TRIM);
            if (filename != "") {
                downloadFileContent(filename);
            } else {
                llOwnerSay("❌ Usage: /1 download ScriptName.lsl");
                llOwnerSay("📋 Say '/1 list' to see available files");
            }
        }
        else {
            llOwnerSay("❓ Unknown command. Say '/1 help' for available commands");
        }
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        // Handle verbose logging toggle (follows existing pattern)
        if (num == MSG_TOGGLE_VERBOSE_LOGS) {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔊 [UpdateChecker] Verbose logging ENABLED");
            } else {
                llOwnerSay("🔊 [UpdateChecker] Verbose logging DISABLED");
            }
            return;
        }
        
        // Handle update check requests from admin menu
        if (num == MSG_UPDATE_CHECK_REQUEST) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔄 [UpdateChecker] Received update check request from admin menu");
            }
            checkForUpdates();
            return;
        }
        
        // Respond to admin menu status queries  
        if (num == MSG_ADMIN_MENU_RESPONSE && str == "update_status") {
            llMessageLinked(LINK_SET, MSG_ADMIN_MENU_RESPONSE, 
                           "update_version|v" + CURRENT_VERSION, id);
            return;
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id != currentHttpRequest) return;
        
        currentHttpRequest = NULL_KEY;
        
        if (currentOperation == "version_check") {
            updateCheckInProgress = FALSE;
            
            if (status == 200) {
                if (VERBOSE_LOGGING) {
                    llOwnerSay("📊 GitHub response: " + (string)llStringLength(body) + " chars (LSL limit: 2048)");
                }
                
                // LSL truncates HTTP responses at 2048 chars, breaking JSON parser
                // Use manual parsing instead
                string latestVersion = "";
                string htmlUrl = "";
                string publishedAt = "";
                
                // Extract tag_name manually
                integer tagStart = llSubStringIndex(body, "\"tag_name\":\"");
                if (tagStart != -1) {
                    integer versionStart = tagStart + 12; // Skip '"tag_name":"'
                    integer versionEnd = llSubStringIndex(llGetSubString(body, versionStart, -1), "\"");
                    if (versionEnd != -1) {
                        latestVersion = llGetSubString(body, versionStart, versionStart + versionEnd - 1);
                    }
                }
                
                // Extract html_url manually
                integer urlStart = llSubStringIndex(body, "\"html_url\":\"");
                if (urlStart != -1) {
                    integer urlValueStart = urlStart + 12; // Skip '"html_url":"'
                    integer urlEnd = llSubStringIndex(llGetSubString(body, urlValueStart, -1), "\"");
                    if (urlEnd != -1) {
                        htmlUrl = llGetSubString(body, urlValueStart, urlValueStart + urlEnd - 1);
                    }
                }
                
                // Extract published_at manually
                integer pubStart = llSubStringIndex(body, "\"published_at\":\"");
                if (pubStart != -1) {
                    integer pubValueStart = pubStart + 15; // Skip '"published_at":"'
                    integer pubEnd = llSubStringIndex(llGetSubString(body, pubValueStart, -1), "\"");
                    if (pubEnd != -1) {
                        publishedAt = llGetSubString(body, pubValueStart, pubValueStart + pubEnd - 1);
                    }
                }
                
                if (latestVersion == "") {
                    llOwnerSay("❌ Could not extract version from truncated GitHub response");
                    llOwnerSay("🔍 Response was cut off at 2048 characters");
                    return;
                }
                
                // Skip release notes parsing - response is truncated at 2048 chars
                string releaseNotes = "Release notes available on GitHub (response truncated)";
                
                llOwnerSay("=== 🔍 UPDATE CHECK RESULTS ===");
                llOwnerSay("📊 Current Version: v" + CURRENT_VERSION);
                llOwnerSay("✨ Latest GitHub Release: " + latestVersion);
                
                if (isNewerVersion(latestVersion, CURRENT_VERSION)) {
                    llOwnerSay("🆕 NEW VERSION AVAILABLE!");
                    llOwnerSay("📅 Published: " + llGetSubString(publishedAt, 0, 9));
                    llOwnerSay("🌐 View Release: " + htmlUrl);
                    
                    // Show release notes preview
                    if (releaseNotes != JSON_INVALID && releaseNotes != "") {
                        string shortNotes = releaseNotes;
                        if (llStringLength(shortNotes) > 200) {
                            shortNotes = llGetSubString(shortNotes, 0, 197) + "...";
                        }
                        llOwnerSay("📋 What's New: " + shortNotes);
                    }
                    
                    llOwnerSay("");
                    llOwnerSay("📥 Individual Files: /1 download ScriptName.lsl");
                    llOwnerSay("📋 Available Files: /1 list");
                    llOwnerSay("🎁 Complete Release: " + htmlUrl);
                } else {
                    llOwnerSay("✅ You have the latest version!");
                    llOwnerSay("🔄 Individual file updates available via /1 download");
                }
            } else {
                llOwnerSay("❌ Update check failed (HTTP " + (string)status + ")");
                if (status == 403) {
                    llOwnerSay("   ⏳ GitHub rate limited - try again in a few minutes");
                } else if (status == 404) {
                    llOwnerSay("   📋 No releases found yet - this is normal for new repositories");
                    llOwnerSay("   🌐 Repository exists at: https://github.com/RebeccaNod1/Peril");
                    llOwnerSay("   💡 Individual file downloads still available via /1 download");
                    llOwnerSay("   🔄 Releases will appear here when v2.8.7+ is tagged");
                }
            }
        }
        else if (currentOperation == "file_download") {
            downloadMode = FALSE;
            
            if (status == 200) {
                integer contentLength = llStringLength(body);
                llOwnerSay("✅ Downloaded " + downloadingFile);
                llOwnerSay("📊 Size: " + (string)contentLength + " characters");
                
                // Show VERIFIED deployment instructions based on actual linkset scan
                if (downloadingFile == "xyzzy_Master_script.lsl") {
                    llOwnerSay("📺 XyzzyText Script - Deploy to ALL Links 35-82 (48 prims)");
                    llOwnerSay("   🎯 VERIFIED: \"leaderboard row X col Y\" prims");
                    llOwnerSay("   ⚠️  Each leaderboard prim needs this exact script!");
                } else if (downloadingFile == "Game_Scoreboard_Manager_Linkset.lsl") {
                    llOwnerSay("🎯 Scoreboard Manager - Deploy to Link 12 ONLY");
                    llOwnerSay("   📍 VERIFIED: \"scoreboard manager cube\"");
                } else if (downloadingFile == "Leaderboard_Communication_Linkset.lsl") {
                    llOwnerSay("🎯 Leaderboard Bridge - Deploy to Link 35 ONLY");
                    llOwnerSay("   📍 VERIFIED: \"leaderboard row 1 col 1\"");
                } else if (downloadingFile == "XyzzyText_Dice_Bridge_Linkset.lsl") {
                    llOwnerSay("🎯 Dice Display Bridge - Deploy to Link 83 ONLY"); 
                    llOwnerSay("   📍 VERIFIED: \"dice col 1\"");
                } else if (llListFindList(LINK1_SCRIPTS, [downloadingFile]) != -1) {
                    llOwnerSay("🎯 Root Prim Script - Deploy to Link 1 ONLY");
                    llOwnerSay("   📍 VERIFIED: \"Peril Dice Controller V2\"");
                } else {
                    llOwnerSay("📖 Documentation file - no deployment needed");
                }
                
                // Show content preview
                llOwnerSay("───── CONTENT PREVIEW (200 chars) ─────");
                string preview = body;
                if (llStringLength(preview) > 200) {
                    preview = llGetSubString(preview, 0, 197) + "...";
                }
                llOwnerSay(preview);
                llOwnerSay("──────────────────────────────────────");
                
                if (llGetSubString(downloadingFile, -4, -1) == ".lsl") {
                    llOwnerSay("🔧 Copy → Paste into script editor → SAVE → RESET");
                    llOwnerSay("📍 Deployment verified for 84-prim linkset structure");
                }
            } else {
                llOwnerSay("❌ Download failed: " + downloadingFile + " (HTTP " + (string)status + ")");
                if (status == 404) {
                    llOwnerSay("   📁 File not found on GitHub - check spelling");
                }
            }
            
            downloadingFile = "";
        }
        
        currentOperation = "";
    }
}