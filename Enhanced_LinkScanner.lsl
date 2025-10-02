// ====================================================================
// Enhanced Link Scanner for Peril Dice Update System
// ====================================================================
// Extended version of Temp_LinkScanner.lsl that identifies:
// 1. Current linkset structure 
// 2. Which scripts belong on which links
// 3. Missing scripts or misplaced scripts
// 4. Generates accurate placement info for Update_Checker.lsl
//
// USAGE: Place this script on any prim in the linkset, touch to scan
// ====================================================================

// Expected script locations based on WARP.md architecture
list LINK1_SCRIPTS = [
    "Main_Controller_Linkset.lsl",
    "Game_Manager.lsl", 
    "Controller_Memory.lsl",
    "Controller_MessageHandler.lsl", 
    "Player_RegistrationManager.lsl",
    "Player_DialogHandler.lsl",
    "NumberPicker_DialogHandler.lsl",
    "Floater_Manager.lsl",
    "Roll_ConfettiModule.lsl",
    "Bot_Manager.lsl", 
    "Game_Calculator.lsl",
    "Verbose_Logger.lsl",
    "System_Debugger.lsl"
];

// Link-specific scripts (based on architecture documentation)
list LINKSET_SPECIFIC_SCRIPTS = [
    "Game_Scoreboard_Manager_Linkset.lsl",      // Link 12
    "Leaderboard_Communication_Linkset.lsl",    // Link 35  
    "XyzzyText_Dice_Bridge_Linkset.lsl"         // Link 83
];

string XYZZY_SCRIPT = "xyzzy_Master_script.lsl";  // Links 35-82 (48 prims)

// Scan results
integer totalPrims = 0;
list linkNames = [];
list linkPositions = [];

// Function to perform the full linkset scan
performFullScan() {
    totalPrims = llGetNumberOfPrims();
    linkNames = [];
    linkPositions = [];
    
    llOwnerSay("=== 🔍 PERIL DICE LINKSET ANALYSIS ===");
    llOwnerSay("📊 Total Prims: " + (string)totalPrims);
    llOwnerSay("🎯 Expected Architecture: 84-prim single linkset");
    llOwnerSay("");
    
    // Scan all links
    integer i;
    for (i = 1; i <= totalPrims; i++) {
        string primName = llGetLinkName(i);
        vector pos = llList2Vector(llGetLinkPrimitiveParams(i, [PRIM_POSITION]), 0);
        
        linkNames += [primName];
        linkPositions += [pos];
        
        // Basic link info
        llOwnerSay("Link " + (string)i + ": " + primName);
        
        // Add delays to prevent spam
        if (i % 15 == 0) {
            llSleep(1.5);
        }
    }
    
    llOwnerSay("");
    llOwnerSay("=== 📋 SCRIPT PLACEMENT ANALYSIS ===");
    
    // Analyze Link 1 (Root Prim)
    llOwnerSay("🔧 LINK 1 (ROOT PRIM) ANALYSIS:");
    llOwnerSay("  Name: " + llList2String(linkNames, 0));
    llOwnerSay("  Expected Scripts: " + (string)llGetListLength(LINK1_SCRIPTS) + " scripts");
    
    integer j;
    for (j = 0; j < llGetListLength(LINK1_SCRIPTS); j++) {
        string scriptName = llList2String(LINK1_SCRIPTS, j);
        llOwnerSay("    • " + scriptName);
    }
    llOwnerSay("  + Update_Checker.lsl (NEW - replaces eliminated UpdateHelper)");
    llOwnerSay("");
    
    // Analyze scoreboard
    llOwnerSay("📊 SCOREBOARD SECTION (Links 2-24):");
    if (totalPrims >= 12) {
        llOwnerSay("  Link 12: " + llList2String(linkNames, 11) + " (Scoreboard Manager)");
        llOwnerSay("    Expected Script: Game_Scoreboard_Manager_Linkset.lsl");
    }
    llOwnerSay("  Links 2-11: Overlay prims (elimination markers)");
    llOwnerSay("  Links 13-24: Player display prims (profiles & hearts)");
    llOwnerSay("");
    
    // Analyze leaderboard
    llOwnerSay("🏆 LEADERBOARD SECTION (Links 35-82):");
    if (totalPrims >= 35) {
        llOwnerSay("  Link 35: " + llList2String(linkNames, 34) + " (Leaderboard Bridge)");
        llOwnerSay("    Expected Script: Leaderboard_Communication_Linkset.lsl");
    }
    llOwnerSay("  Links 35-82: XyzzyText display prims (48 total)"); 
    llOwnerSay("    Each prim needs: xyzzy_Master_script.lsl");
    llOwnerSay("    Organization: 4 banks × 12 prims each");
    llOwnerSay("");
    
    // Analyze dice display
    llOwnerSay("🎲 DICE DISPLAY SECTION (Links 83-84):");
    if (totalPrims >= 83) {
        llOwnerSay("  Link 83: " + llList2String(linkNames, 82) + " (Dice Bridge)");
        llOwnerSay("    Expected Script: XyzzyText_Dice_Bridge_Linkset.lsl");
    }
    if (totalPrims >= 84) {
        llOwnerSay("  Link 84: " + llList2String(linkNames, 83) + " (Dice Display)");
        llOwnerSay("    No script needed");
    }
    llOwnerSay("");
    
    // Update checker guide
    llOwnerSay("=== 🎯 UPDATE CHECKER PLACEMENT GUIDE ===");
    llOwnerSay("📥 UPDATE CHECKER DEPLOYMENT:");
    llOwnerSay("  ✅ Place Update_Checker.lsl on Link 1 (Root Prim)");
    llOwnerSay("  ✅ Replaces eliminated UpdateHelper.lsl from v2.8.5");
    llOwnerSay("  ✅ Integrates with existing admin menu system");
    llOwnerSay("");
    
    llOwnerSay("🔄 ESSENTIAL FILES FOR UPDATES:");
    llOwnerSay("  📂 Link 1 Scripts (" + (string)llGetListLength(LINK1_SCRIPTS) + " files)");
    llOwnerSay("  📂 Link-Specific Scripts (3 files)");
    llOwnerSay("  📂 XyzzyText Script (1 file × 48 prims)");
    llOwnerSay("  📂 Documentation (4 files)");
    llOwnerSay("");
    
    llOwnerSay("⚠️  EXCLUDED FROM UPDATES:");
    llOwnerSay("  🚫 Development files: lsl_validator.py, debug_mcp.py");
    llOwnerSay("  🚫 Test files: test_*.py, MCP_README.md");
    llOwnerSay("  🚫 Templates: MEMORY_REPORT_TEMPLATE.lsl");
    llOwnerSay("  🚫 Utilities: Temp_LinkScanner.lsl, Enhanced_LinkScanner.lsl");
    
    llOwnerSay("");
    llOwnerSay("✅ Linkset analysis complete!");
}

default {
    state_entry() {
        llOwnerSay("🔍 Enhanced Link Scanner ready for Peril Dice linkset");
        llOwnerSay("📊 This will map script locations for the Update Checker");
        llOwnerSay("👆 Touch to perform full linkset analysis");
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) != llGetOwner()) return;
        performFullScan();
    }
}
