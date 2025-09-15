// === MEMORY REPORTING TEMPLATE ===
// Add this to the state_entry() of every script to track memory usage

// Add this function to every script:
reportMemoryUsage(string scriptName) {
    integer used = llGetUsedMemory();
    integer free = llGetFreeMemory();
    integer total = used + free;
    float percentUsed = ((float)used / (float)total) * 100.0;
    
    llOwnerSay("🧠 [" + scriptName + "] Memory: " + 
               (string)used + " used, " + 
               (string)free + " free (" + 
               llGetSubString((string)percentUsed, 0, 4) + "% used)");
}

// Add this to state_entry() in every script:
state_entry() {
    // Replace "SCRIPT_NAME" with the actual script name
    reportMemoryUsage("SCRIPT_NAME");
    
    // ... rest of existing state_entry() code ...
}

// Add this to on_rez() in every script:
on_rez(integer start_param) {
    // Replace "SCRIPT_NAME" with the actual script name  
    reportMemoryUsage("SCRIPT_NAME");
    
    // ... rest of existing on_rez() code ...
}