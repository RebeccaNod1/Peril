// ====================================================================
// Peril Dice Updater - External Update Box
// ====================================================================
// This script goes in a standalone object (the "Updater Box")
// It downloads scripts from GitHub and installs them into the game
// ====================================================================

string CURRENT_VERSION = "2.8.8";
string GITHUB_API_URL = "https://api.github.com/repos/RebeccaNod1/Peril/releases/latest";
string GITHUB_RAW_URL = "https://raw.githubusercontent.com/RebeccaNod1/Peril/main/";

// Communication channels
integer UPDATER_CHANNEL = -7723847; // Must match Update_Receiver.lsl

// State tracking
key targetGame = NULL_KEY;
integer targetPin = 0;
list downloadQueue = [];
string currentFile = "";
integer installIndex = 0;
integer isBusy = FALSE;

// HTTP tracking
key currentHttpRequest = NULL_KEY;
string currentOperation = "";

// Script manifest - List of all scripts to update
// Format: "ScriptName.lsl|LinkNumber"
// Note: Link numbers will be verified via UUID request
list SCRIPT_MANIFEST = [
    "Main_Controller_Linkset.lsl|1",
    "Game_Manager.lsl|1",
    "Controller_Memory.lsl|1",
    "Controller_MessageHandler.lsl|1",
    "Player_RegistrationManager.lsl|1",
    "Player_DialogHandler.lsl|1",
    "NumberPicker_DialogHandler.lsl|1",
    "Floater_Manager.lsl|1",
    "Roll_ConfettiModule.lsl|1",
    "Bot_Manager.lsl|1",
    "Game_Calculator.lsl|1",
    "Verbose_Logger.lsl|1",
    "System_Debugger.lsl|1",
    "Update_Receiver.lsl|1", // Updates the receiver itself!
    "Game_Scoreboard_Manager_Linkset.lsl|12",
    "Leaderboard_Communication_Linkset.lsl|35",
    "XyzzyText_Dice_Bridge_Linkset.lsl|83",
    "xyzzy_Master_script.lsl|XYZZY" // Special handling for xyzzy
];

// Map of Link Number -> UUID (populated by game response)
list linkUUIDs = []; // Format: [LinkNum, UUID, LinkNum, UUID...]

// Helper to get UUID for a link number
key getLinkUUID(integer linkNum) {
    integer idx = llListFindList(linkUUIDs, [linkNum]);
    if (idx != -1) {
        return llList2Key(linkUUIDs, idx + 1);
    }
    return NULL_KEY;
}

// Manual JSON parsing (same as receiver)
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

// Start the update process for a specific game
startUpdate(key gameId, string version, integer pin) {
    if (isBusy) {
        llRegionSayTo(gameId, UPDATER_CHANNEL, "UPDATE_BUSY");
        return;
    }
    
    isBusy = TRUE;
    targetGame = gameId;
    targetPin = pin;
    
    llOwnerSay("🚀 Starting update for game " + (string)gameId);
    llRegionSayTo(targetGame, UPDATER_CHANNEL, "UPDATE_STARTING|" + version);
    
    // Step 1: Request Link UUIDs from the game
    // We need these to install scripts to specific links
    llRegionSayTo(targetGame, UPDATER_CHANNEL, "REQUEST_LINK_UUIDS");
    
    // Set timeout for UUID response
    llSetTimerEvent(10.0);
}

// Continue update after getting UUIDs
startDownloadSequence() {
    installIndex = 0;
    downloadNextScript();
}

downloadNextScript() {
    if (installIndex >= llGetListLength(SCRIPT_MANIFEST)) {
        // All done!
        finishUpdate();
        return;
    }
    
    string entry = llList2String(SCRIPT_MANIFEST, installIndex);
    list parts = llParseString2List(entry, ["|"], []);
    currentFile = llList2String(parts, 0);
    string linkTarget = llList2String(parts, 1);
    
    llOwnerSay("📥 Downloading " + currentFile + "...");
    
    string url = GITHUB_RAW_URL + currentFile;
    currentOperation = "download_script";
    currentHttpRequest = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
}

installScript(string content) {
    string scriptEntry = llList2String(SCRIPT_MANIFEST, installIndex);
    list scriptParts = llParseString2List(scriptEntry, ["|"], []);
    string filename = llList2String(scriptParts, 0);
    string linkTargetStr = llList2String(scriptParts, 1);
    
    llOwnerSay("💾 Installing " + filename + "...");
    
    // Determine target UUIDs
    list targets = [];
    key targetUUID;
    
    if (linkTargetStr == "XYZZY") {
        // Install to all xyzzy prims (links 35-82)
        integer i;
        for (i = 35; i <= 82; i++) {
            targetUUID = getLinkUUID(i);
            if (targetUUID != NULL_KEY) targets += [targetUUID];
        }
    } else {
        integer linkNum = (integer)linkTargetStr;
        if (linkNum == 1) {
            targets = [targetGame]; // Root prim is the game object itself
        } else {
            targetUUID = getLinkUUID(linkNum);
            if (targetUUID != NULL_KEY) targets += [targetUUID];
        }
    }
    
    if (llGetListLength(targets) == 0) {
        llOwnerSay("⚠️ No valid targets found for " + filename + " (Target: " + linkTargetStr + ")");
        // Skip but continue
        installIndex++;
        downloadNextScript();
        return;
    }
    
    // Install to all targets
    integer t;
    for (t = 0; t < llGetListLength(targets); t++) {
        key target = llList2Key(targets, t);
        llRemoteLoadScriptPin(target, filename, targetPin, TRUE, 0);
    }
    
    // Move to next
    installIndex++;
    downloadNextScript();
}

finishUpdate() {
    llOwnerSay("✅ Update sequence complete!");
    llRegionSayTo(targetGame, UPDATER_CHANNEL, "UPDATE_COMPLETE|" + CURRENT_VERSION);
    
    isBusy = FALSE;
    targetGame = NULL_KEY;
    targetPin = 0;
    linkUUIDs = [];
}

default {
    state_entry() {
        llSetText("📦 Peril Dice Updater\nv" + CURRENT_VERSION + "\nTouch to check version", <0,1,0>, 1.0);
        llListen(UPDATER_CHANNEL, "", NULL_KEY, "");
    }
    
    touch_start(integer num) {
        llOwnerSay("🔍 Checking GitHub for latest version...");
        currentOperation = "version_check";
        currentHttpRequest = llHTTPRequest(GITHUB_API_URL, [HTTP_METHOD, "GET"], "");
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == UPDATER_CHANNEL) {
            list parts = llParseString2List(message, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "PING_UPDATER") {
                llRegionSayTo(id, UPDATER_CHANNEL, "UPDATER_AVAILABLE|" + CURRENT_VERSION);
            }
            else if (command == "UPDATE_REQUEST") {
                string version = llList2String(parts, 1); // Version requested (not used currently, we install latest)
                integer pin = (integer)llList2String(parts, 2);
                startUpdate(id, version, pin);
            }
            else if (command == "LINK_UUIDS_RESPONSE") {
                if (id != targetGame) return;
                
                // Parse UUIDs: "12:uuid,35:uuid,..."
                string payload = llList2String(parts, 1);
                list pairs = llParseString2List(payload, [","], []);
                
                integer i;
                for (i = 0; i < llGetListLength(pairs); i++) {
                    string pair = llList2String(pairs, i);
                    list kv = llParseString2List(pair, [":"], []);
                    if (llGetListLength(kv) == 2) {
                        integer ln = (integer)llList2String(kv, 0);
                        key uid = (key)llList2String(kv, 1);
                        
                        // Update or add
                        integer idx = llListFindList(linkUUIDs, [ln]);
                        if (idx != -1) {
                            linkUUIDs = llListReplaceList(linkUUIDs, [uid], idx+1, idx+1);
                        } else {
                            linkUUIDs += [ln, uid];
                        }
                    }
                }
                
                // Reset timer as we got data
                llSetTimerEvent(5.0); // Wait a bit more for other chunks if any
                
                // If we have enough critical data, we can start
                // For now, let's just wait for the timer to trigger the start
                // This allows multiple chunks to arrive
            }
        }
    }
    
    timer() {
        llSetTimerEvent(0.0);
        
        if (isBusy && installIndex == 0) {
            // Timer fired while waiting for UUIDs
            if (llGetListLength(linkUUIDs) > 0) {
                llOwnerSay("✅ Received link data. Starting installation...");
                startDownloadSequence();
            } else {
                llOwnerSay("❌ Timed out waiting for Link UUIDs.");
                llRegionSayTo(targetGame, UPDATER_CHANNEL, "UPDATE_FAILED|Timeout waiting for link data");
                isBusy = FALSE;
            }
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id != currentHttpRequest) return;
        
        if (currentOperation == "version_check") {
            if (status == 200) {
                string latestVersion = extractJsonValue(body, "tag_name");
                llOwnerSay("📊 Latest GitHub Version: " + latestVersion);
                llOwnerSay("📦 Updater Version: v" + CURRENT_VERSION);
            } else {
                llOwnerSay("❌ GitHub check failed: " + (string)status);
            }
        }
        else if (currentOperation == "download_script") {
            if (status == 200) {
                installScript(body);
            } else {
                llOwnerSay("❌ Failed to download " + currentFile + ": " + (string)status);
                llRegionSayTo(targetGame, UPDATER_CHANNEL, "UPDATE_FAILED|Download failed for " + currentFile);
                isBusy = FALSE;
            }
        }
    }
}