// ====================================================================
// Update Receiver - GitHub Integration + External Updater Coordination
// ====================================================================
// VERIFIED LINKSET PLACEMENT: Link 1 (Root Prim) "Peril Dice Controller V2"
// Replaces Update_Checker.lsl with external updater box coordination
// 
// This script:
// 1. Checks GitHub for new releases (same as before)
// 2. Scans for nearby Peril_Dice_Updater boxes
// 3. Coordinates automatic script installation via external updater
// 4. Provides professional one-click update experience
// ====================================================================

string CURRENT_VERSION = "2.8.8";
#define GITHUB_API_URL "https://api.github.com/repos/RebeccaNod1/Peril/releases/latest"

// External updater communication
#define UPDATER_CHANNEL -7723847 // Must match Peril_Dice_Updater.lsl
#define SENSOR_RANGE 96 // meters to scan for updater boxes
list nearbyUpdaters = [];
key selectedUpdater = NULL_KEY;

// Update process state
integer updateInProgress = FALSE;
integer updatePin = 0;
string availableVersion = "";

// HTTP operation tracking  
key currentHttpRequest = NULL_KEY;
string currentOperation = "";

// Message constants - following existing Peril Dice patterns
#define MSG_ADMIN_MENU_RESPONSE 888
#define MSG_UPDATE_CHECK_REQUEST 2100
#define MSG_TOGGLE_VERBOSE_LOGS 9999

// Update dialog constants
#define UPDATE_DIALOG_CHANNEL -77401 // Unique channel for update dialogs
integer updateDialogHandle = -1;
key pendingUpdateUser = NULL_KEY;

// Internal verbose logging
integer VERBOSE_LOGGING = FALSE;

// Memory usage reporting
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

// Manual JSON parsing for LSL 2048-char limit
string extractJsonValue(string json, string keyName) {
    string quote = "\"";
    string searchPattern = quote + keyName + quote + ":" + quote;
    integer start = llSubStringIndex(json, searchPattern);
    if (start == -1) return "";
    
    integer valueStart = start + llStringLength(searchPattern);
    integer valueEnd = llSubStringIndex(llGetSubString(json, valueStart, -1), quote);
    if (valueEnd == -1) return "";
    
    return llGetSubString(json, valueStart, valueStart + valueEnd - 1);
}

// Scan for nearby updater boxes
scanForUpdaters() {
    nearbyUpdaters = [];
    llOwnerSay("🔍 Scanning for GitHub updater boxes within " + (string)SENSOR_RANGE + "m...");
    llSensor("", NULL_KEY, SCRIPTED, SENSOR_RANGE, PI);
}

// Check GitHub for updates
checkForUpdates() {
    currentOperation = "version_check";
    llOwnerSay("🔍 Checking GitHub for Peril Dice updates...");
    if (VERBOSE_LOGGING) {
        llOwnerSay("📊 GitHub API: " + GITHUB_API_URL);
    }
    
    currentHttpRequest = llHTTPRequest(GITHUB_API_URL, [
        HTTP_METHOD, "GET"
    ], "");
}

// Start update installation process
startUpdateInstallation() {
    if (selectedUpdater == NULL_KEY) {
        llOwnerSay("❌ No updater box selected. Please rez a Peril Dice Updater nearby.");
        return;
    }
    
    // Generate unique access pin
    updatePin = (integer)(llFrand(2000000000)) + 1000000000;
    
    // Set remote script access pin
    llSetRemoteScriptAccessPin(updatePin);
    
    updateInProgress = TRUE;
    llOwnerSay("🔄 Starting automatic update installation...");
    llOwnerSay("📊 Requesting " + availableVersion + " from GitHub updater box...");
    
    // Request update from external updater
    llRegionSayTo(selectedUpdater, UPDATER_CHANNEL, 
                  "UPDATE_REQUEST|" + CURRENT_VERSION + "|" + (string)updatePin);
    
    // Set timeout for update process
    llSetTimerEvent(300.0); // 5 minute timeout
}

// Complete update process
completeUpdate(string newVersion) {
    updateInProgress = FALSE;
    llSetRemoteScriptAccessPin(0); // Clear access pin
    llSetTimerEvent(0.0); // Clear timer
    
    llOwnerSay("🎉 Update installation complete!");
    llOwnerSay("✅ Peril Dice is now running version " + newVersion);
    llOwnerSay("💡 You can now delete the updater box");
    
    // Update our version number
    // Note: In practice, this script itself would have been updated
    // CURRENT_VERSION = newVersion;
}

// Handle update failure
handleUpdateFailure(string error) {
    updateInProgress = FALSE;
    llSetRemoteScriptAccessPin(0); // Clear access pin
    llSetTimerEvent(0.0); // Clear timer
    
    llOwnerSay("❌ Update installation failed: " + error);
    llOwnerSay("💡 You can try again or delete the updater box");
}

// Show update installation dialog
showInstallUpdateDialog(key userId) {
    if (availableVersion == "") {
        llOwnerSay("❌ No update available to install");
        return;
    }
    
    if (llGetListLength(nearbyUpdaters) == 0) {
        llOwnerSay("📦 No updater boxes found. Scanning...");
        scanForUpdaters();
        return;
    }
    
    pendingUpdateUser = userId;
    
    // Close previous dialog listener
    if (updateDialogHandle != -1) {
        llListenRemove(updateDialogHandle);
    }
    
    // Start new dialog listener
    updateDialogHandle = llListen(UPDATE_DIALOG_CHANNEL, "", userId, "");
    
    string dialogText = "🆕 NEW VERSION AVAILABLE!\n\n";
    dialogText += "📊 Current Version: v" + CURRENT_VERSION + "\n";
    dialogText += "✨ Available Version: " + availableVersion + "\n\n";
    dialogText += "🔄 Ready to install " + availableVersion + " automatically?\n";
    dialogText += "📦 Found " + (string)llGetListLength(nearbyUpdaters) + " updater box(es) nearby";
    
    list options = ["🚀 Install Update", "❌ Cancel", "📦 Scan Again"];
    llDialog(userId, dialogText, options, UPDATE_DIALOG_CHANNEL);
}

// Show help commands
showUpdateCommands() {
    llOwnerSay("=== 🔄 PERIL DICE UPDATE SYSTEM ===");
    llOwnerSay("📱 Current Version: v" + CURRENT_VERSION);
    llOwnerSay("🌐 Repository: github.com/RebeccaNod1/Peril");
    llOwnerSay("📍 Location: Link 1 (Root Prim) - VERIFIED 84-prim structure");
    llOwnerSay("");
    llOwnerSay("🔄 NEW: Automatic Update System!");
    llOwnerSay("1️⃣ Rez a 'Peril Dice Updater' box nearby");
    llOwnerSay("2️⃣ Touch this game → Admin Menu → 'Check for Updates'");
    llOwnerSay("3️⃣ Click 'Install Update' for one-click installation");
    llOwnerSay("4️⃣ Delete updater box when complete");
    llOwnerSay("");
    llOwnerSay("💬 Manual commands still available:");
    llOwnerSay("  /1 check     - Check GitHub for updates");
    llOwnerSay("  /1 scan      - Scan for nearby updater boxes");
    llOwnerSay("  /1 test      - Test llRemoteLoadScriptPin with tiny script");
    llOwnerSay("  /1 help      - Show these commands");
}

default {
    state_entry() {
        reportMemoryUsage("Update Receiver");
        llOwnerSay("🔄 Update Receiver ready - GitHub + External Updater integration");
        llOwnerSay("📍 Location: Link 1 (\"Peril Dice Controller V2\") - VERIFIED structure");
        llOwnerSay("💬 Say '/1 help' for commands or use Owner Menu → Troubleshooting");
        llListen(1, "", llGetOwner(), "");
        llListen(UPDATER_CHANNEL, "", NULL_KEY, "");
    }
    
    on_rez(integer start_param) {
        // Reset state on rez
        updateInProgress = FALSE;
        updatePin = 0;
        availableVersion = "";
        nearbyUpdaters = [];
        selectedUpdater = NULL_KEY;
        currentOperation = "";
        currentHttpRequest = NULL_KEY;
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == 1 && id == llGetOwner()) {
            // Owner chat commands
            string msg = llToLower(llStringTrim(message, STRING_TRIM));
            
            if (msg == "help") {
                showUpdateCommands();
            }
            else if (msg == "check") {
                checkForUpdates();
            }
            else if (msg == "scan") {
                scanForUpdaters();
            }
            else if (msg == "test") {
                // Test llRemoteLoadScriptPin with tiny script
                llOwnerSay("🧪 DEBUG: Testing llRemoteLoadScriptPin...");
                
                // Generate test PIN
                integer testPin = (integer)(llFrand(1000000)) + 100000;
                llSetRemoteScriptAccessPin(testPin);
                
                llOwnerSay("🔑 Test PIN set: " + (string)testPin);
                llOwnerSay("📡 Broadcasting test request on channel " + (string)UPDATER_CHANNEL);
                
                // Broadcast test request to any test updaters
                llRegionSay(UPDATER_CHANNEL, "TEST_REQUEST|" + CURRENT_VERSION + "|" + (string)testPin);
                
                llOwnerSay("🏷️ If you have a Test_Updater nearby, it should respond now");
            }
            else {
                llOwnerSay("❓ Unknown command. Say '/1 help' for available commands");
            }
        }
        else if (channel == UPDATE_DIALOG_CHANNEL) {
            // Handle update dialog responses
            if (id != pendingUpdateUser) return; // Only respond to the user who triggered the dialog
            
            if (message == "🚀 Install Update") {
                llOwnerSay("🚀 Starting automatic update installation...");
                startUpdateInstallation();
            }
            else if (message == "📦 Scan Again") {
                llOwnerSay("🔍 Scanning for GitHub updater boxes...");
                scanForUpdaters();
                // Dialog will be shown again when scan finds updaters
            }
            else if (message == "❌ Cancel") {
                llOwnerSay("❌ Update installation cancelled");
            }
            
            // Clean up dialog listener and pending user
            if (updateDialogHandle != -1) {
                llListenRemove(updateDialogHandle);
                updateDialogHandle = -1;
            }
            pendingUpdateUser = NULL_KEY;
        }
        else if (channel == UPDATER_CHANNEL) {
            // Communication with updater boxes
            list parts = llParseString2List(message, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "UPDATER_AVAILABLE") {
                string updaterVersion = llList2String(parts, 1);
                llOwnerSay("📦 Found GitHub updater: " + name + " v" + updaterVersion);
                
                // Add to list if not already there
                if (llListFindList(nearbyUpdaters, [id]) == -1) {
                    nearbyUpdaters += [id];
                }
                
                // Auto-select if we don't have one selected
                if (selectedUpdater == NULL_KEY) {
                    selectedUpdater = id;
                    llOwnerSay("✅ Selected updater: " + name);
                }
            }
            else if (command == "UPDATE_STARTING") {
                string version = llList2String(parts, 1);
                llOwnerSay("🚀 Updater is installing " + version + " from GitHub...");
            }
            else if (command == "UPDATE_COMPLETE") {
                string version = llList2String(parts, 1);
                completeUpdate(version);
            }
            else if (command == "UPDATE_FAILED") {
                string error = llList2String(parts, 1);
                handleUpdateFailure(error);
            }
            else if (command == "UPDATE_BUSY") {
                llOwnerSay("⏳ Updater is busy with another installation");
            }
            else if (command == "REQUEST_LINK_UUIDS") {
                // Updater is requesting our link UUIDs for proper script installation
                llOwnerSay("📡 Updater requesting link UUIDs for linkset script installation...");
                
                integer linkCount = llGetNumberOfPrims();
                
                // Send critical links first
                list criticalLinks = [12, 35, 83]; // Scoreboard, Leaderboard, Dice Bridge
                string criticalPayload = "";
                
                integer i;
                for (i = 0; i < llGetListLength(criticalLinks); i++) {
                    integer linkNum = llList2Integer(criticalLinks, i);
                    if (linkNum <= linkCount) {
                        key linkUUID = llGetLinkKey(linkNum);
                        if (criticalPayload != "") criticalPayload += ",";
                        criticalPayload += (string)linkNum + ":" + (string)linkUUID;
                    }
                }
                llRegionSayTo(id, UPDATER_CHANNEL, "LINK_UUIDS_RESPONSE|" + criticalPayload);
                llOwnerSay("✅ Sent critical link UUIDs (" + (string)llGetListLength(criticalLinks) + " links)");
                if (VERBOSE_LOGGING) llOwnerSay("📊 Critical UUID Data: " + criticalPayload);
                
                // Now send all xyzzy links (35-82) in safe-sized chunks as additional LINK_UUIDS_RESPONSE messages
                if (linkCount >= 82) {
                    string chunk = "";
                    integer countInChunk = 0;
                    integer j;
                    for (j = 35; j <= 82; j++) {
                        key luuid = llGetLinkKey(j);
                        string piece = (string)j + ":" + (string)luuid;
                        // Flush if adding would exceed ~900 chars or ~20 entries
                        if ((llStringLength(chunk) + 1 + llStringLength(piece)) > 900 || countInChunk >= 20) {
                            llRegionSayTo(id, UPDATER_CHANNEL, "LINK_UUIDS_RESPONSE|" + chunk);
                            chunk = "";
                            countInChunk = 0;
                        }
                        if (chunk != "") chunk += ",";
                        chunk += piece;
                        countInChunk++;
                    }
                    if (chunk != "") {
                        llRegionSayTo(id, UPDATER_CHANNEL, "LINK_UUIDS_RESPONSE|" + chunk);
                    }
                    llOwnerSay("✅ Sent xyzzy UUIDs (links 35-82) in chunks");
                }
            }
        }
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        // Handle verbose logging toggle
        if (num == MSG_TOGGLE_VERBOSE_LOGS) {
            VERBOSE_LOGGING = !VERBOSE_LOGGING;
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔊 [UpdateReceiver] Verbose logging ENABLED");
            } else {
                llOwnerSay("🔊 [UpdateReceiver] Verbose logging DISABLED");
            }
            return;
        }
        
        // Handle update check requests from admin menu
        if (num == MSG_UPDATE_CHECK_REQUEST) {
            if (VERBOSE_LOGGING) {
                llOwnerSay("🔄 [UpdateReceiver] Received update check request from admin menu");
            }
            
            // Store the requesting user for potential dialog
            if (availableVersion != "") {
                // We already know there's an update - show install dialog immediately
                showInstallUpdateDialog(id);
            } else {
                // Check for updates first
                checkForUpdates();
                // We'll show the dialog in the HTTP response if an update is found
                pendingUpdateUser = id;
            }
            return;
        }
        
        // Respond to admin menu status queries  
        if (num == MSG_ADMIN_MENU_RESPONSE && str == "update_status") {
            llMessageLinked(LINK_SET, MSG_ADMIN_MENU_RESPONSE, 
                           "update_version|v" + CURRENT_VERSION, id);
            return;
        }
    }
    
    sensor(integer num_detected) {
        // Found scripted objects - check if any are updater boxes
        nearbyUpdaters = [];
        integer i;
        for (i = 0; i < num_detected; i++) {
            key detected = llDetectedKey(i);
            string detectedName = llDetectedName(i);
            
            // Ping to see if it's an updater box
            llRegionSayTo(detected, UPDATER_CHANNEL, "PING_UPDATER");
        }
        
        // Wait for responses
        llSetTimerEvent(3.0);
    }
    
    no_sensor() {
        llOwnerSay("📭 No GitHub updater boxes found within " + (string)SENSOR_RANGE + "m");
        llOwnerSay("💡 Please rez a 'Peril Dice Updater' box nearby to enable automatic updates");
    }
    
    timer() {
        if (updateInProgress) {
            // Update timeout
            llOwnerSay("⏰ Update installation timed out");
            handleUpdateFailure("Installation timeout - updater may have failed");
        } else {
            // Sensor response timeout
            if (llGetListLength(nearbyUpdaters) == 0) {
                llOwnerSay("📭 No GitHub updater boxes responded");
                llOwnerSay("💡 Please rez a 'Peril Dice Updater' box nearby");
            } else {
                llOwnerSay("✅ Found " + (string)llGetListLength(nearbyUpdaters) + " GitHub updater box(es)");
            }
        }
        llSetTimerEvent(0.0);
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id != currentHttpRequest) return;
        
        currentHttpRequest = NULL_KEY;
        
        if (currentOperation == "version_check") {
            if (status == 200) {
                if (VERBOSE_LOGGING) {
                    llOwnerSay("📊 GitHub response: " + (string)llStringLength(body) + " chars (LSL limit: 2048)");
                }
                
                // Extract version using manual parsing
                string latestVersion = extractJsonValue(body, "tag_name");
                string htmlUrl = extractJsonValue(body, "html_url");
                string publishedAt = extractJsonValue(body, "published_at");
                
                if (latestVersion == "") {
                    llOwnerSay("❌ Could not extract version from GitHub response");
                    return;
                }
                
                llOwnerSay("=== 🔍 UPDATE CHECK RESULTS ===");
                llOwnerSay("📊 Current Version: v" + CURRENT_VERSION);
                llOwnerSay("✨ Latest GitHub Release: " + latestVersion);
                
                if (isNewerVersion(latestVersion, CURRENT_VERSION)) {
                    availableVersion = latestVersion;
                    llOwnerSay("🆕 NEW VERSION AVAILABLE!");
                    llOwnerSay("📅 Published: " + llGetSubString(publishedAt, 0, 9));
                    llOwnerSay("🌐 View Release: " + htmlUrl);
                    llOwnerSay("");
                    
                    // Check for updater boxes
                    if (llGetListLength(nearbyUpdaters) == 0) {
                        llOwnerSay("📦 Scanning for GitHub updater boxes...");
                        scanForUpdaters();
                    } else {
                        llOwnerSay("✅ GitHub updater box ready!");
                        llOwnerSay("🚀 Click 'Install Update' to automatically install " + latestVersion);
                    }
                    
                    // Show install dialog if request came from admin menu
                    if (pendingUpdateUser != NULL_KEY) {
                        showInstallUpdateDialog(pendingUpdateUser);
                        pendingUpdateUser = NULL_KEY;
                    }
                } else {
                    llOwnerSay("✅ You have the latest version!");
                    llOwnerSay("📦 GitHub updater system is ready for future updates");
                    pendingUpdateUser = NULL_KEY; // Clear pending user
                }
            } else {
                llOwnerSay("❌ Update check failed (HTTP " + (string)status + ")");
                if (status == 403) {
                    llOwnerSay("   ⏳ GitHub rate limited - try again in a few minutes");
                }
            }
        }
        
        currentOperation = "";
    }
}