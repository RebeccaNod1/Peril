// ====================================================================
// Traditional Peril Dice Updater - Inventory-Based Script Copying
// ====================================================================
// This script goes in an updater box that contains all the updated scripts
// in its inventory. It copies scripts from its inventory to the target game.
//
// SETUP:
// 1. Copy all updated LSL scripts into this updater box's inventory
// 2. User rezzes updater box near their Peril Dice game
// 3. User touches their game -> "Check for Updates" -> "Install Update"
// 4. Updater copies scripts from its inventory to their game
// 5. User deletes updater box when finished
// ====================================================================

string UPDATER_VERSION = "2.8.8";
integer UPDATER_CHANNEL = -7723847;

// Update state
key targetGameKey = NULL_KEY;
integer updatePin = 0;
list scriptList = [];
integer currentScriptIndex = 0;
string currentOperation = "";

// Script to link mapping - each script knows where it belongs
list SCRIPT_LINK_MAP = [
    // Root prim scripts (Link 1)
    "Main_Controller_Linkset", "1",
    "Game_Manager", "1",
    "Controller_Memory", "1",
    "Controller_MessageHandler", "1",
    "Player_RegistrationManager", "1",
    "Player_DialogHandler", "1",
    "NumberPicker_DialogHandler", "1",
    "Floater_Manager", "1",
    "Roll_ConfettiModule", "1",
    "Bot_Manager", "1",
    "Game_Calculator", "1",
    "Verbose_Logger", "1",
    "System_Debugger", "1",
    "Update_Receiver", "1",
    // Other link scripts
    "Game_Scoreboard_Manager_Linkset", "12",
    "Leaderboard_Communication_Linkset", "35",
    "XyzzyText_Dice_Bridge_Linkset", "83",
    "xyzzy_Master_script", "35-82"  // Special case - multiple links
];

// Extract unique script names for inventory checking
list REQUIRED_SCRIPTS = [
    "Main_Controller_Linkset",
    "Game_Manager", 
    "Controller_Memory",
    "Controller_MessageHandler",
    "Player_RegistrationManager",
    "Player_DialogHandler",
    "NumberPicker_DialogHandler",
    "Floater_Manager",
    "Roll_ConfettiModule",
    "Bot_Manager",
    "Game_Calculator",
    "Verbose_Logger",
    "System_Debugger",
    "Update_Receiver",
    "Game_Scoreboard_Manager_Linkset",
    "Leaderboard_Communication_Linkset",
    "XyzzyText_Dice_Bridge_Linkset",
    "xyzzy_Master_script"
];

// Memory reporting
reportMemoryUsage(string scriptName) {
    integer memory = llGetUsedMemory();
    integer freeMemory = llGetFreeMemory(); 
    float memoryPercent = (float)memory / (memory + freeMemory) * 100.0;
    llOwnerSay("📊 " + scriptName + ": " + (string)memory + " bytes used (" + 
               llGetSubString((string)memoryPercent, 0, 4) + "% memory)");
}

// Get target link number for a script
string getTargetLink(string scriptName) {
    integer i;
    for (i = 0; i < llGetListLength(SCRIPT_LINK_MAP); i += 2) {
        if (llList2String(SCRIPT_LINK_MAP, i) == scriptName) {
            return llList2String(SCRIPT_LINK_MAP, i + 1);
        }
    }
    return "1"; // Default to root prim if not found
}

// Install script to specific link using llRemoteLoadScriptPin
installScriptToLink(string scriptName, string targetLink) {
    if (targetLink == "35-82") {
        // Special case: install xyzzy_Master_script to multiple links
        llOwnerSay("🔄 Installing " + scriptName + " to links 35-82 (48 copies)...");
        integer i;
        for (i = 35; i <= 82; i++) {
            // Use link number as start_param to target specific link
            llRemoteLoadScriptPin(targetGameKey, scriptName, updatePin, TRUE, i);
            llOwnerSay("✅ Installed " + scriptName + " to link " + (string)i);
            llSleep(0.1); // Brief pause between installations
        }
    } else {
        // Regular installation to single link
        integer linkNum = (integer)targetLink;
        llOwnerSay("📝 Installing " + scriptName + " to link " + targetLink);
        llRemoteLoadScriptPin(targetGameKey, scriptName, updatePin, TRUE, linkNum);
        llOwnerSay("✅ Installed " + scriptName + " to link " + targetLink);
    }
}

// Check which scripts are available in inventory
checkInventory() {
    integer totalScripts = 0;
    integer availableScripts = 0;
    
    llOwnerSay("📋 Checking updater inventory with link mapping...");
    
    integer i;
    for (i = 0; i < llGetListLength(REQUIRED_SCRIPTS); i++) {
        string scriptName = llList2String(REQUIRED_SCRIPTS, i);
        string targetLink = getTargetLink(scriptName);
        totalScripts++;
        
        if (llGetInventoryType(scriptName) == INVENTORY_SCRIPT) {
            availableScripts++;
            llOwnerSay("✅ " + scriptName + " → Link " + targetLink + " - Ready");
        } else {
            llOwnerSay("❌ " + scriptName + " → Link " + targetLink + " - MISSING");
        }
    }
    
    llOwnerSay("📊 Inventory Status: " + (string)availableScripts + "/" + (string)totalScripts + " scripts available");
    
    if (availableScripts == totalScripts) {
        llOwnerSay("✅ All required scripts present - updater ready!");
        llOwnerSay("🔗 Scripts will be installed to their correct links automatically");
    } else {
        llOwnerSay("⚠️ Missing scripts - please add them to updater inventory");
    }
}

// Start the update process
startUpdate(key gameKey, integer pin) {
    targetGameKey = gameKey;
    updatePin = pin;
    currentOperation = "updating";
    currentScriptIndex = 0;
    
    // Build script list for this specific update
    scriptList = [];
    
    // Add all available scripts
    integer i;
    for (i = 0; i < llGetListLength(REQUIRED_SCRIPTS); i++) {
        string scriptName = llList2String(REQUIRED_SCRIPTS, i);
        if (llGetInventoryType(scriptName) == INVENTORY_SCRIPT) {
            scriptList += [scriptName];
        }
    }
    
    llOwnerSay("🔄 Starting update process...");
    llOwnerSay("📊 Installing " + (string)llGetListLength(scriptList) + " scripts");
    
    // Start with first script
    installNextScript();
}

// Install next script in the queue
installNextScript() {
    if (currentScriptIndex >= llGetListLength(scriptList)) {
        // Update complete!
        completeUpdate();
        return;
    }
    
    string scriptName = llList2String(scriptList, currentScriptIndex);
    string targetLink = getTargetLink(scriptName);
    
    llOwnerSay("🚀 Progress: " + (string)(currentScriptIndex + 1) + "/" + (string)llGetListLength(scriptList));
    
    // Install script to correct link(s)
    installScriptToLink(scriptName, targetLink);
    
    // Move to next script
    currentScriptIndex++;
    
    // Longer pause for xyzzy_Master_script (48 installations)
    if (targetLink == "35-82") {
        llSetTimerEvent(10.0); // Extra time for multiple installations
    } else {
        llSetTimerEvent(2.0); // Normal pause
    }
}

// Complete the update process
completeUpdate() {
    llOwnerSay("🎉 Update installation complete!");
    llOwnerSay("📊 Successfully installed " + (string)llGetListLength(scriptList) + " scripts");
    
    // Notify target game
    if (targetGameKey != NULL_KEY) {
        llRegionSayTo(targetGameKey, UPDATER_CHANNEL, "UPDATE_COMPLETE|" + UPDATER_VERSION);
    }
    
    // Reset state
    currentOperation = "";
    targetGameKey = NULL_KEY;
    updatePin = 0;
    scriptList = [];
    currentScriptIndex = 0;
    
    llOwnerSay("💡 Update complete! You can now delete this updater box.");
    llSetText("🎉 Update Complete!\nYou can delete this updater box\nThank you for updating!", 
              <0.2, 1.0, 0.2>, 1.0);
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
    scriptList = [];
    currentScriptIndex = 0;
}

default {
    state_entry() {
        reportMemoryUsage("Traditional Peril Dice Updater");
        llOwnerSay("🔄 Traditional Peril Dice Updater v" + UPDATER_VERSION);
        llOwnerSay("📦 Inventory-based script copying system");
        llOwnerSay("👆 Touch your Peril Dice game and select 'Check for Updates'");
        
        // Check our inventory
        checkInventory();
        
        // Listen for update requests
        llListen(UPDATER_CHANNEL, "", NULL_KEY, "");
        
        // Set helpful text
        llSetText("🔄 Peril Dice Updater v" + UPDATER_VERSION + "\n" +
                  "Traditional inventory-based system\n" +
                  "Touch your game, not this updater", <0.2, 1.0, 0.2>, 1.0);
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
            
            llOwnerSay("📨 Update request from " + name + " (current: " + version + ", PIN: " + (string)pin + ")");
            
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
            installNextScript();
        }
        llSetTimerEvent(0.0);
    }
    
    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        
        if (currentOperation == "updating") {
            llOwnerSay("⏳ Update in progress for " + llKey2Name(targetGameKey));
            llOwnerSay("📊 Installing script " + (string)(currentScriptIndex + 1) + 
                       " of " + (string)llGetListLength(scriptList));
        } else {
            llOwnerSay("🔄 Traditional Peril Dice Updater v" + UPDATER_VERSION);
            llOwnerSay("📦 Ready to update Peril Dice games using inventory scripts");
            llOwnerSay("👆 Touch your Peril Dice game (not this updater) and select 'Check for Updates'");
            llOwnerSay("📋 Checking inventory...");
            checkInventory();
        }
    }
}