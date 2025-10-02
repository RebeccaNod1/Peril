// ====================================================================
// Peril Dice GitHub Updater - External Updater Box
// ====================================================================
// This script goes in a separate updater box object that users rez temporarily.
// Downloads scripts directly from GitHub and installs them automatically
// in target Peril Dice games via llRemoteLoadScriptPin().
//
// USAGE:
// 1. User rezzes this updater box near their Peril Dice game
// 2. User touches their game -> "Check for Updates" -> "Install Update"
// 3. Game communicates with this updater box for automatic installation
// 4. User deletes updater box when finished
// ====================================================================

string GITHUB_MANIFEST_URL = "https://raw.githubusercontent.com/RebeccaNod1/Peril/main/peril-dice-manifest.json";
string UPDATER_VERSION = "2.8.8";

// Communication channels
integer UPDATER_CHANNEL = -7723847; // Unique channel for updater communication
integer RESPONSE_TIMEOUT = 30; // seconds

// Current operation state
string currentOperation = "";
key targetGameKey = NULL_KEY;
integer updatePin = 0;
list scriptQueue = [];
integer currentScriptIndex = 0;
string manifestData = "";

// HTTP tracking
key currentHttpRequest = NULL_KEY;
string downloadingScript = "";

// UI and status
integer isListening = FALSE;

// Memory usage reporting
reportMemoryUsage(string scriptName) {
    integer memory = llGetUsedMemory();
    integer freeMemory = llGetFreeMemory();
    float memoryPercent = (float)memory / (memory + freeMemory) * 100.0;
    llOwnerSay("📊 " + scriptName + ": " + (string)memory + " bytes used (" + 
               llGetSubString((string)memoryPercent, 0, 4) + "% memory)");
}

// Extract JSON value manually (works around LSL 2048-char limit)
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

// Parse script list from manifest (simplified for LSL limitations)
list parseScriptList(string manifest) {
    list scripts = [];
    // This is a simplified parser - in production might need more robust parsing
    // For now, we'll use the script URLs directly
    
    // Add all essential scripts in priority order (URLs keep .lsl, but script names don't)
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Main_Controller_Linkset.lsl|1|Main_Controller_Linkset"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Game_Manager.lsl|1|Game_Manager"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Controller_Memory.lsl|1|Controller_Memory"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Controller_MessageHandler.lsl|1|Controller_MessageHandler"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Player_RegistrationManager.lsl|1|Player_RegistrationManager"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Player_DialogHandler.lsl|1|Player_DialogHandler"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/NumberPicker_DialogHandler.lsl|1|NumberPicker_DialogHandler"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Floater_Manager.lsl|1|Floater_Manager"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Roll_ConfettiModule.lsl|1|Roll_ConfettiModule"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Bot_Manager.lsl|1|Bot_Manager"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Game_Calculator.lsl|1|Game_Calculator"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Verbose_Logger.lsl|1|Verbose_Logger"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/System_Debugger.lsl|1|System_Debugger"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Update_Receiver.lsl|1|Update_Receiver"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Game_Scoreboard_Manager_Linkset.lsl|12|Game_Scoreboard_Manager_Linkset"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/Leaderboard_Communication_Linkset.lsl|35|Leaderboard_Communication_Linkset"];
    scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/XyzzyText_Dice_Bridge_Linkset.lsl|83|XyzzyText_Dice_Bridge_Linkset"];
    
    // Add XyzzyText script for links 35-82 (48 prims)
    integer i;
    for (i = 35; i <= 82; i++) {
        scripts += ["https://raw.githubusercontent.com/RebeccaNod1/Peril/main/xyzzy_Master_script.lsl|" + (string)i + "|xyzzy_Master_script"];
    }
    
    return scripts;
}

// Start update process
startUpdate(key gameKey, integer pin) {
    targetGameKey = gameKey;
    updatePin = pin;
    currentOperation = "updating";
    currentScriptIndex = 0;
    
    // Get script list (simplified - using hardcoded list for now)
    scriptQueue = parseScriptList("");
    
    llOwnerSay("🔄 Starting update process...");
    llOwnerSay("📊 Installing " + (string)llGetListLength(scriptQueue) + " scripts");
    
    // Start with first script
    downloadNextScript();
}

// Download next script in queue
downloadNextScript() {
    if (currentScriptIndex >= llGetListLength(scriptQueue)) {
        // Update complete!
        completeUpdate();
        return;
    }
    
    string scriptEntry = llList2String(scriptQueue, currentScriptIndex);
    list parts = llParseString2List(scriptEntry, ["|"], []);
    string url = llList2String(parts, 0);
    string linkNum = llList2String(parts, 1);
    string scriptName = llList2String(parts, 2);  // Now using explicit script name
    
    downloadingScript = scriptName;
    
    llOwnerSay("📥 Downloading " + scriptName + " for link " + linkNum + 
               " (" + (string)(currentScriptIndex + 1) + "/" + (string)llGetListLength(scriptQueue) + ")");
    
    currentHttpRequest = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
}

// Install downloaded script - commercial updater approach
installScript(string scriptContent, string scriptName, integer linkNumber) {
    llOwnerSay("📥 Installing " + scriptName + " (" + (string)llStringLength(scriptContent) + " chars)");
    llOwnerSay("🎯 Target: " + (string)targetGameKey + " | PIN: " + (string)updatePin);
    
    // Step 1: Tell target to remove old script (if it exists)
    llRegionSayTo(targetGameKey, UPDATER_CHANNEL, "REMOVE_SCRIPT|" + scriptName);
    
    // Step 2: Install new script content with llRemoteLoadScriptPin
    // The script will be created with an auto-generated name like "New Script"
    llRemoteLoadScriptPin(targetGameKey, scriptContent, updatePin, TRUE, 0);
    
    // Step 3: Tell target to rename the new script to correct name
    llRegionSayTo(targetGameKey, UPDATER_CHANNEL, "RENAME_SCRIPT|" + scriptName);
    
    llOwnerSay("✅ Sent " + scriptName + " to target game");
    
    // Move to next script
    currentScriptIndex++;
    llSetTimerEvent(3.0); // Longer pause for script processing
}

// Complete the update process
completeUpdate() {
    llOwnerSay("🎉 Update installation complete!");
    llOwnerSay("📊 Installed " + (string)llGetListLength(scriptQueue) + " scripts successfully");
    
    // Notify target game
    if (targetGameKey != NULL_KEY) {
        llRegionSayTo(targetGameKey, UPDATER_CHANNEL, "UPDATE_COMPLETE|" + UPDATER_VERSION);
    }
    
    // Reset state
    currentOperation = "";
    targetGameKey = NULL_KEY;
    updatePin = 0;
    scriptQueue = [];
    currentScriptIndex = 0;
    
    llOwnerSay("💡 Update complete! You can now delete this updater box.");
}

// Handle update errors
handleUpdateError(string error) {
    llOwnerSay("❌ Update failed: " + error);
    
    // Notify target game of failure
    if (targetGameKey != NULL_KEY) {
        llRegionSayTo(targetGameKey, UPDATER_CHANNEL, "UPDATE_FAILED|" + error);
    }
    
    // Reset state
    currentOperation = "";
    targetGameKey = NULL_KEY;
    updatePin = 0;
    scriptQueue = [];
    currentScriptIndex = 0;
}

default {
    state_entry() {
        reportMemoryUsage("Peril Dice GitHub Updater");
        llOwnerSay("🔄 Peril Dice GitHub Updater v" + UPDATER_VERSION);
        llOwnerSay("📍 Ready to update nearby Peril Dice games");
        llOwnerSay("👆 Touch your Peril Dice game and select 'Check for Updates'");
        
        // Listen for update requests from games
        if (!isListening) {
            llListen(UPDATER_CHANNEL, "", NULL_KEY, "");
            isListening = TRUE;
        }
        
        // Set text to show status
        llSetText("🔄 Peril Dice GitHub Updater v" + UPDATER_VERSION + "\\n" +
                  "Ready to install updates from GitHub\\n" +
                  "Touch your game to begin", <0.2, 1.0, 0.2>, 1.0);
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel != UPDATER_CHANNEL) return;
        
        list parts = llParseString2List(message, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (command == "UPDATE_REQUEST") {
            string version = llList2String(parts, 1);
            integer pin = (integer)llList2String(parts, 2);
            
            llOwnerSay("📨 Update request from " + name + " (current: " + version + ")");
            
            if (currentOperation != "") {
                llRegionSayTo(id, UPDATER_CHANNEL, "UPDATE_BUSY|Another update in progress");
                return;
            }
            
            // Start the update process
            startUpdate(id, pin);
            llRegionSayTo(id, UPDATER_CHANNEL, "UPDATE_STARTING|" + UPDATER_VERSION);
        }
        else if (command == "PING_UPDATER") {
            // Respond to updater detection pings
            llRegionSayTo(id, UPDATER_CHANNEL, "UPDATER_AVAILABLE|" + UPDATER_VERSION);
        }
    }
    
    timer() {
        // Continue with next script installation
        if (currentOperation == "updating") {
            downloadNextScript();
        }
        llSetTimerEvent(0.0);
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id != currentHttpRequest) return;
        
        currentHttpRequest = NULL_KEY;
        
        if (status == 200) {
            // Successfully downloaded script
            string scriptEntry = llList2String(scriptQueue, currentScriptIndex);
            list parts = llParseString2List(scriptEntry, ["|"], []);
            integer linkNum = (integer)llList2String(parts, 1);
            
            // Install the script
            installScript(body, downloadingScript, linkNum);
        } else {
            handleUpdateError("Failed to download " + downloadingScript + " (HTTP " + (string)status + ")");
        }
    }
    
    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        
        if (currentOperation == "updating") {
            llOwnerSay("⏳ Update in progress - please wait...");
            llOwnerSay("📊 Installing script " + (string)(currentScriptIndex + 1) + 
                       " of " + (string)llGetListLength(scriptQueue));
        } else {
            llOwnerSay("🔄 Peril Dice GitHub Updater v" + UPDATER_VERSION);
            llOwnerSay("📍 Ready to update Peril Dice games from GitHub");
            llOwnerSay("👆 Touch your Peril Dice game (not this updater) and select 'Check for Updates'");
            llOwnerSay("💡 This updater will automatically download and install scripts");
        }
    }
}