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

// Script names that should be in this updater's inventory
list REQUIRED_SCRIPTS = [
    // Root prim scripts (Link 1)
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
    // Other link scripts
    "Game_Scoreboard_Manager_Linkset",    // Link 12
    "Leaderboard_Communication_Linkset",  // Link 35
    "XyzzyText_Dice_Bridge_Linkset",      // Link 83
    "xyzzy_Master_script"                 // Links 35-82 (we'll copy this multiple times)
];

// Memory reporting
reportMemoryUsage(string scriptName) {
    integer memory = llGetUsedMemory();
    integer freeMemory = llGetFreeMemory(); 
    float memoryPercent = (float)memory / (memory + freeMemory) * 100.0;
    llOwnerSay("📊 " + scriptName + ": " + (string)memory + " bytes used (" + 
               llGetSubString((string)memoryPercent, 0, 4) + "% memory)");
}

// Check which scripts are available in inventory
checkInventory() {
    integer totalScripts = 0;
    integer availableScripts = 0;
    
    llOwnerSay("📋 Checking updater inventory...");
    
    integer i;
    for (i = 0; i < llGetListLength(REQUIRED_SCRIPTS); i++) {
        string scriptName = llList2String(REQUIRED_SCRIPTS, i);
        totalScripts++;
        
        if (llGetInventoryType(scriptName) == INVENTORY_SCRIPT) {
            availableScripts++;
            llOwnerSay("✅ " + scriptName + " - Ready");
        } else {
            llOwnerSay("❌ " + scriptName + " - MISSING");
        }
    }
    
    llOwnerSay("📊 Inventory Status: " + (string)availableScripts + "/" + (string)totalScripts + " scripts available");
    
    if (availableScripts == totalScripts) {
        llOwnerSay("✅ All required scripts present - updater ready!");
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
    
    llOwnerSay("📝 Installing " + scriptName + " (" + (string)(currentScriptIndex + 1) + 
               "/" + (string)llGetListLength(scriptList) + ")");
    
    // Use llRemoteLoadScriptPin to copy script from our inventory to target
    llRemoteLoadScriptPin(targetGameKey, scriptName, updatePin, TRUE, 0);
    
    llOwnerSay("✅ Copied " + scriptName + " to target game");
    
    // Move to next script
    currentScriptIndex++;
    llSetTimerEvent(2.0); // Brief pause between installations
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