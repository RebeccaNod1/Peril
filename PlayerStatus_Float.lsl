#include "Peril_Constants.lsl"

// === Player Status Float - Enhanced Display ===

key target;
string displayText;
string myName;
integer listenHandle = -1;


default {
    state_entry() {
        REPORT_MEMORY();
        string currentDesc = llGetObjectDesc();
        
        llSetText("⏳ Waiting...", <1,1,1>, 1.0);
        llSetTimerEvent(1.0);
    }

    on_rez(integer start_param) {
        REPORT_MEMORY();
        if (listenHandle != -1) llListenRemove(listenHandle);
        listenHandle = llListen(start_param, "", NULL_KEY, "");
        myName = "";
        llSetRemoteScriptAccessPin(1337); 
    }

    attach(key id) {
        if (id != NULL_KEY) {
            // HUD MODE: Stop following target in-world
            llSetTimerEvent(0.0);
            
            // HUD Scaling & Rotation (Center 2 focus)
            // Smaller scale, reset rotation to face screen
            llSetLinkPrimitiveParamsFast(LINK_THIS, [
                PRIM_SIZE, <0.05, 0.05, 0.05>,
                PRIM_ROTATION, ZERO_ROTATION,
                PRIM_POSITION, <0.0, 0.0, 0.0> 
            ]);
            
            dbg("📊 [Status Float] HUD Mode Activated for " + llKey2Name(id));
        } else {
            // BACK TO WORLD: Restore size and follow logic
            llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_SIZE, <0.2, 0.2, 0.2>]);
        }
    }

    experience_permissions(key av) {
        // ATTACH_HUD_CENTER_2 = 31
        llAttachToAvatarTemp(31); 
    }

    listen(integer channel, string name, key id, string message) {
        // Universal Floater API - Format: CMD:avKey|T=Text|G=Glow|C=Color|H=HeartTexture
        if (llSubStringIndex(message, "CMD:") == 0) {
            list parts = llParseString2List(message, ["|"], []);
            if (llGetListLength(parts) < 1) return;
            
            string header = llList2String(parts, 0);
            target = (key)llGetSubString(header, 4, -1);
            
            integer i;
            for (i = 1; i < llGetListLength(parts); i++) {
                string pair = llList2String(parts, i);
                integer eqIdx = llSubStringIndex(pair, "=");
                if (eqIdx != -1) {
                    string keyStr = llGetSubString(pair, 0, eqIdx - 1);
                    string valStr = llGetSubString(pair, eqIdx + 1, -1);
                    
                    if (keyStr == "T") {
                        displayText = valStr;
                        llSetText(displayText, <1,1,1>, 1.0);
                    }
                    else if (keyStr == "G") {
                        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_GLOW, ALL_SIDES, (float)valStr]);
                    }
                    else if (keyStr == "C") {
                        llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_COLOR, ALL_SIDES, (vector)valStr, 1.0]);
                    }
                    else if (keyStr == "H") {
                        llSetLinkPrimitiveParamsFast(LINK_THIS, [
                            PRIM_TEXTURE, 1, valStr, <1,1,0>, ZERO_VECTOR, 0.0,
                            PRIM_TEXTURE, 2, valStr, <1,1,0>, ZERO_VECTOR, 0.0,
                            PRIM_TEXTURE, 3, valStr, <1,1,0>, ZERO_VECTOR, 0.0,
                            PRIM_TEXTURE, 4, valStr, <1,1,0>, ZERO_VECTOR, 0.0
                        ]);
                    }
                }
            }
        }
        else if (message == "CLEANUP") {
            llDie();
        }
        else if (llSubStringIndex(message, "ATTACH_TO:") == 0) {
            key avKey = (key)llGetSubString(message, 10, -1);
            if (avKey != NULL_KEY) {
                llRequestExperiencePermissions(avKey, "");
            }
        }
        else if (llSubStringIndex(message, "SET_NAME:") == 0) {
            myName = llGetSubString(message, 9, -1);
            llSetObjectDesc(myName);
        }
    }

    timer() {
        if (target != NULL_KEY) {
            list details = llGetObjectDetails(target, [OBJECT_POS]);
            if (llGetListLength(details) > 0) {
                vector pos = llList2Vector(details, 0) + <1,0,1>;
                llSetRegionPos(pos);
            }
        }
    }
}
