// ============================================================================
// Experience Admin HUD
// ============================================================================
// Instructions:
// 1. Create a new box, put this script inside.
// 2. DO NOT FORGET to check "Use Experience" and select Final Girlz I.N.C!
// 3. Attach it to your HUD or click it if it's rezzed.
//
// Commands (type in local chat):
// /99 keys       - Lists all keys currently in the entire database
// /99 get [Key]  - Reads and displays the data inside a specific key
// /99 del [Key]  - Deletes a specific key from the database
// ============================================================================

key requestKeys;
key requestRead;
key requestDelete;
key requestWrite;
key lastUser;
string pendingSetKey;
string pendingSetValue;

default {
    state_entry() {
        lastUser = llGetOwner();
        llRegionSayTo(lastUser, 0, "🔧 Experience Admin Terminal Ready.");
        llRegionSayTo(lastUser, 0, "💬 Type commands in local chat:");
        llRegionSayTo(lastUser, 0, "  /99 keys");
        llRegionSayTo(lastUser, 0, "  /99 get key_name");
        llRegionSayTo(lastUser, 0, "  /99 set key_name=Hello World");
        llRegionSayTo(lastUser, 0, "  /99 del key_name");
        llListen(99, "", NULL_KEY, "");
    }
    
    listen(integer channel, string name, key id, string msg) {
        // SECURITY CHECK: Strictly whitelist authorized Admin usernames!
        string uname = llStringTrim(llToLower(llGetUsername(id)), STRING_TRIM);
        if (id != llGetOwner() && uname != "djmusica28" && uname != "finalgirlzbot") {
            llRegionSayTo(id, 0, "❌ Access Denied: You are not on the authorized Administrator whitelist for this database.");
            return;
        }
        lastUser = id;
        msg = llStringTrim(msg, STRING_TRIM);
        
        if (msg == "keys") {
            llRegionSayTo(lastUser, 0, "🔍 Requesting list of database keys (up to 100)...");
            requestKeys = llKeysKeyValue(0, 100); 
        } 
        else if (llGetSubString(msg, 0, 3) == "get ") {
            string targetKey = llStringTrim(llGetSubString(msg, 4, -1), STRING_TRIM);
            llRegionSayTo(lastUser, 0, "🔍 Reading key: " + targetKey + "...");
            requestRead = llReadKeyValue(targetKey);
        }
        else if (llGetSubString(msg, 0, 3) == "set ") {
            string payload = llStringTrim(llGetSubString(msg, 4, -1), STRING_TRIM);
            integer equalSign = llSubStringIndex(payload, "=");
            if (equalSign != -1) {
                pendingSetKey = llStringTrim(llGetSubString(payload, 0, equalSign - 1), STRING_TRIM);
                pendingSetValue = llStringTrim(llGetSubString(payload, equalSign + 1, -1), STRING_TRIM);
                llRegionSayTo(lastUser, 0, "💾 Writing key: " + pendingSetKey + "...");
                requestWrite = llUpdateKeyValue(pendingSetKey, pendingSetValue, FALSE, "");
            } else {
                llRegionSayTo(lastUser, 0, "❌ Format: /99 set key=value");
            }
        }
        else if (llGetSubString(msg, 0, 3) == "del ") {
            string targetKey = llStringTrim(llGetSubString(msg, 4, -1), STRING_TRIM);
            llRegionSayTo(lastUser, 0, "🗑️ Deleting key: " + targetKey + "...");
            requestDelete = llDeleteKeyValue(targetKey);
        }
    }
    
    dataserver(key queryid, string data) {
        // llKeysKeyValue returns data as CSV:
        // Success: 1,keyname1,keyname2...
        // Failure: 0,error_code
        if (queryid == requestKeys) {
            list result = llCSV2List(data);
            if (llList2Integer(result, 0) == 1) {
                // Success
                integer numKeys = llGetListLength(result) - 1;
                llRegionSayTo(lastUser, 0, "✅ Found " + (string)numKeys + " keys in database:");
                
                integer i;
                for(i = 1; i < llGetListLength(result); i++) {
                    llRegionSayTo(lastUser, 0, "  🔑 " + llList2String(result, i));
                }
            } else if (llList2Integer(result, 1) == 3) { 
                llRegionSayTo(lastUser, 0, "📭 The database is completely empty! No keys exist.");
            } else {
                llRegionSayTo(lastUser, 0, "❌ Failed to read keys (Error " + llList2String(result, 1) + ")");
            }
        } 
        
        // llReadKeyValue returns data as: status,value
        else if (queryid == requestRead) {
            integer comma = llSubStringIndex(data, ",");
            string status = llGetSubString(data, 0, comma - 1);
            string val = llGetSubString(data, comma + 1, -1);
            
            if (status == "1") {
                llRegionSayTo(lastUser, 0, "📄 Content:\n" + val);
            } else if (status == "3") {
                llRegionSayTo(lastUser, 0, "❌ That key doesn't exist!");
            } else {
                llRegionSayTo(lastUser, 0, "❌ Read failed (Status: " + status + ")");
            }
        }
        
        // llDeleteKeyValue dataserver logic
        else if (queryid == requestDelete) {
            integer comma = llSubStringIndex(data, ",");
            string status = llGetSubString(data, 0, comma - 1);
            
            if (status == "1") {
                llRegionSayTo(lastUser, 0, "✅ Key successfully deleted!");
            } else if (status == "3") {
                llRegionSayTo(lastUser, 0, "❌ Key didn't exist to delete.");
            } else {
                llRegionSayTo(lastUser, 0, "❌ Delete failed (Status: " + status + ")");
            }
        }
        
        // Write logic
        else if (queryid == requestWrite) {
            integer comma = llSubStringIndex(data, ",");
            string status = llGetSubString(data, 0, comma - 1);
            if (status == "1") {
                llRegionSayTo(lastUser, 0, "✅ Key saved successfully!");
            } else if (status == "3") {
                // Key didn't exist to update, manually create it!
                requestWrite = llCreateKeyValue(pendingSetKey, pendingSetValue);
            } else {
                llRegionSayTo(lastUser, 0, "❌ Write failed (Status: " + status + ")");
            }
        }
    }
}
