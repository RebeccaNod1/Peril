// ====================================================================
// Test Updater - Debug llRemoteLoadScriptPin
// ====================================================================
// Simple test to see if llRemoteLoadScriptPin works at all

#define TEST_VERSION "1.0.0"
#define UPDATER_CHANNEL -7723847

// Test state
key targetGameKey = NULL_KEY;
integer testPin = 0;
integer testStep = 0;

// Simple test script content
#define TEST_SCRIPT "default {
    state_entry() {
        llOwnerSay(\"✅ Test script installed successfully!\")\n        llOwnerSay(\"📝 This proves llRemoteLoadScriptPin is working.\");\n    }\n}";

default {
    state_entry() {
        llOwnerSay("🧪 Test Updater v" + TEST_VERSION + " ready");
        llOwnerSay("📍 This will test llRemoteLoadScriptPin with a tiny script");
        llOwnerSay("👆 Touch your Peril Dice game, then touch this updater");
        
        llListen(UPDATER_CHANNEL, "", NULL_KEY, "");
        
        llSetText("🧪 Test Updater\nReady to test llRemoteLoadScriptPin\nTouch your game first, then me", 
                  <1.0, 0.8, 0.2>, 1.0);
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel != UPDATER_CHANNEL) return;
        
        list parts = llParseString2List(message, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (command == "TEST_REQUEST") {
            string version = llList2String(parts, 1);
            integer pin = (integer)llList2String(parts, 2);
            
            llOwnerSay("📨 Test request from " + name + " (PIN: " + (string)pin + ")");
            
            // Store the test info
            targetGameKey = id;
            testPin = pin;
            testStep = 1;
            
            // Start the test
            llOwnerSay("🚀 Step 1: Testing tiny script installation...");
            llOwnerSay("📊 Script size: " + (string)llStringLength(TEST_SCRIPT) + " characters");
            llOwnerSay("🎯 Target: " + (string)targetGameKey);
            llOwnerSay("🔑 PIN: " + (string)testPin);
            
            // Try to install the test script
            llRemoteLoadScriptPin(targetGameKey, TEST_SCRIPT, testPin, TRUE, 0);
            
            llOwnerSay("✅ llRemoteLoadScriptPin called - check your game for new script");
            llOwnerSay("💡 If successful, you'll see a 'Test script installed' message");
        }
        else if (command == "PING_UPDATER") {
            llRegionSayTo(id, UPDATER_CHANNEL, "TEST_UPDATER_AVAILABLE|" + TEST_VERSION);
        }
    }
    
    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        
        if (testStep == 0) {
            llOwnerSay("🔍 Touch your Peril Dice game first to set up the PIN");
            llOwnerSay("📝 The game needs to call llSetRemoteScriptAccessPin()");
        } else {
            llOwnerSay("🧪 Test Status:");
            llOwnerSay("📍 Target: " + (string)targetGameKey);
            llOwnerSay("🔑 PIN: " + (string)testPin);
            llOwnerSay("📊 Test script size: " + (string)llStringLength(TEST_SCRIPT) + " chars");
            llOwnerSay("❓ Did you see 'Test script installed successfully' message?");
        }
    }
}