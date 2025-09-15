// Temporary Link Scanner - Find overlay prim link numbers
// Put this in any prim in the linkset and touch it to get a full link report

default {
    state_entry() {
        llOwnerSay("🔍 Link Scanner ready - touch to scan all links in the linkset");
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) != llGetOwner()) return;
        
        integer totalLinks = llGetNumberOfPrims();
        llOwnerSay("📊 LINKSET SCAN - Total prims: " + (string)totalLinks);
        llOwnerSay("==========================================");
        
        integer i;
        for (i = 1; i <= totalLinks; i++) {
            string primName = llGetLinkName(i);
            vector pos = llList2Vector(llGetLinkPrimitiveParams(i, [PRIM_POSITION]), 0);
            
            llOwnerSay("Link " + (string)i + ": " + primName + " at " + (string)pos);
            
            // Small delay to prevent message spam
            if (i % 10 == 0) {
                llSleep(1.0);
            }
        }
        
        llOwnerSay("==========================================");
        llOwnerSay("✅ Scan complete! Look for the new overlay prims you added");
        llOwnerSay("💡 The overlay prims should be the highest link numbers");
    }
}