#include "Peril_Constants.lsl"

debugMsg(string msg) {
    if (DEBUG_LOGS) llMessageLinked(LINK_SET, MSG_DEBUG_TEXT, msg, NULL_KEY);
}

// =============================================================================
// PERIL WORLD RANKING - Leaderboard Manager
// =============================================================================
// Handles sharded KVP storage (up to 10 keys) and sorted ranking.
// Capacity: 500+ Players (Max 10 keys x 50 entries)
// =============================================================================

list leaderboardData = []; // Stride 3: [Name, Wins, Losses]
integer currentLoadPage = 1;
key kvpReadReq;
key kvpWriteReq;
key kvpLockReq;    // Stage 1: Check Lock
key kvpClaimReq;   // Stage 2: Claim Lock
key kvpSentinelReq; // Startup Probe
list writeQueue = []; // Pairs of [KeyName, DataString]
integer isSaving = FALSE;
integer isBusy = FALSE; // Read lock
integer displayOffset = 0; // Current ranking page offset (0, 10, 20...)
integer retryCount = 0; // Track number of timeouts
string currentWriteKey;
string currentWriteVal;

// --- Lock & Sync State ---
list pendingRecords = []; // Stride 2: [Name, Result]
integer isLocking = FALSE;
string myLockVal = "";
integer isClaiming = FALSE; // Track if we are in the middle of a WRITE claim

// Helper: Process the next KVP write in the queue
processWriteQueue() {
    if (llGetListLength(writeQueue) == 0) {
        isSaving = FALSE;
        // Batch Processing: Check if more records are queued before releasing lock
        if (llGetListLength(pendingRecords) > 0) {
            string nextName = llList2String(pendingRecords, 0);
            string nextRes = llList2String(pendingRecords, 1);
            pendingRecords = llDeleteSubList(pendingRecords, 0, 1);
            dbg("🔄 [Leaderboard] Processing next queued record: " + nextName);
            updatePlayerRecord(nextName, nextRes);
        } else {
            releaseLock();
        }
        return;
    }
    isSaving = TRUE;
    currentWriteKey = llList2String(writeQueue, 0);
    currentWriteVal = llList2String(writeQueue, 1);
    writeQueue = llDeleteSubList(writeQueue, 0, 1);
    kvpWriteReq = llUpdateKeyValue(currentWriteKey, currentWriteVal, FALSE, "");
}

// Helper: Release the lock immediately
releaseLock() {
    dbg("🏆 [Leaderboard] Releasing global lock...");
    kvpLockReq = llUpdateKeyValue(LB_LOCK_KEY, "OFF", TRUE, myLockVal);
}

// Convert the whole list into sharded strings and start saving
generateShardedData() {
    integer _shardI;
    integer _totalCount = llGetListLength(leaderboardData) / 3;
    writeQueue = [];
    
    for (_shardI = 0; _shardI < MAX_LB_PAGES; _shardI++) {
        integer _start = _shardI * MAX_ENTRIES_PER_PAGE;
        if (_start >= _totalCount) jump shard_exit;
        
        string _serialized = "";
        integer _j;
        for (_j = 0; _j < MAX_ENTRIES_PER_PAGE && (_start + _j) < _totalCount; _j++) {
            integer _base = (_start + _j) * 3;
            // NEW FORMAT: Wins,Losses,Name (CSV-like within colon segments)
            string _entry = (string)llList2Integer(leaderboardData, _base) + "," + 
                           (string)llList2Integer(leaderboardData, _base + 1) + "," + 
                           llList2String(leaderboardData, _base + 2);
            if (_serialized != "") _serialized += "|";
            _serialized += _entry;
        }
        writeQueue += ["Peril_LB_" + (string)(_shardI + 1), _serialized];
    }
    @shard_exit;
    
    // If no data to write (reset case), release lock now
    if (llGetListLength(writeQueue) == 0) {
        kvpLockReq = llUpdateKeyValue(LB_LOCK_KEY, "", TRUE, myLockVal);
    } else {
        processWriteQueue();
    }
}

loadLBPage(integer pageNum) {
    if ((isBusy || isSaving || isLocking) && pageNum == 1) {
        dbg("⏳ [Leaderboard] Sync requested while Busy/Saving. Ignoring duplicate reset.");
        return; 
    }
    
    // ANTI-THROTTLE: Add small 0.2s pause for Mono speed compatibility
    if (pageNum == 1) llSleep(0.2);
    else llSleep(1.0); // 1.0s delay for sharded pages
    
    isBusy = TRUE;
    llSetTimerEvent(30.0); // Lag Resistant watchdog
    currentLoadPage = pageNum;
    string keyName = LB_KEY_PREFIX + (string)pageNum;
    
    kvpReadReq = llReadKeyValue(keyName);
    
    if (kvpReadReq == NULL_KEY) {
        dbg("⚠️ [Leaderboard] KVP Request FAILED (Throttle/NULL_KEY). Retrying " + keyName + " in 2s...");
        isBusy = FALSE; // Unlock for retry
        llSetTimerEvent(2.0); // Use timer to trigger the retry
        return;
    }
    
    dbg("📡 [Leaderboard] Loading " + keyName + "...");
}

list getSortedSlice(integer offset) {
    if (llGetListLength(leaderboardData) == 0) return [];
    
    // In LSL, llListSort sorts by the FIRST element of each stride.
    // Our data format is [Wins, Losses, Name].
    // Sort by Wins (descending).
    list sorted = llListSort(leaderboardData, 3, FALSE); 
    
    integer start = offset * 3;
    return llList2List(sorted, start, start + 29);
}

updatePlayerRecord(string pName, string pResult) {
    // Search for Name (index 2 of each 3-stride entry)
    integer _idx = -1;
    integer _it;
    for (_it = 2; _it < llGetListLength(leaderboardData); _it += 3) {
        if (llList2String(leaderboardData, _it) == pName) { _idx = _it; jump found; }
    }
    @found;

    if (_idx == -1) {
        if (llGetListLength(leaderboardData) / 3 >= MAX_WORLD_RANKING) return;
        if (pResult == "WIN") leaderboardData += [1, 0, pName];
        else leaderboardData += [0, 1, pName];
    } else {
        integer _base = _idx - 2;
        integer _v;
        if (pResult == "WIN") {
            _v = llList2Integer(leaderboardData, _base);
            leaderboardData = llListReplaceList(leaderboardData, [_v + 1], _base, _base);
        } else {
            _v = llList2Integer(leaderboardData, _base + 1);
            leaderboardData = llListReplaceList(leaderboardData, [_v + 1], _base+1, _base+1);
        }
    }
    
    // SORT before saving
    leaderboardData = llListSort(leaderboardData, 3, FALSE);
    generateShardedData();
}

startUpdateSequence(string pName, string pResult) {
    llSetTimerEvent(0); // GHOST-BUSTER: Kill any pending retries/syncs
    
    // Check if record already in queue to avoid duplicates
    if (llListFindList(pendingRecords, [pName, pResult]) != -1) return;

    pendingRecords += [pName, pResult]; // Add to Victory Queue
    
    if (isBusy || isLocking || isSaving) {
        dbg("⏳ [Leaderboard] Record for [" + pName + "] added to queue (" + (string)(llGetListLength(pendingRecords)/2) + " pending).");
        return;
    }
    
    isLocking = TRUE;
    dbg("🔐 [Leaderboard] Checking global lock for update...");
    kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
}

default {
    on_rez(integer _p) { llResetScript(); }
    
    state_entry() {
        REPORT_MEMORY();
        pendingRecords = []; 
        dbg("⏳ [Leaderboard] v1.55 (Atomic Endurance) - Handshake link active. Probing Experience...");
        
        // SENTINEL CHECK: Use a dedicated ID to prevent shard-read collisions
        kvpSentinelReq = llReadKeyValue(LB_KEY_PREFIX + "1");
        llSetTimerEvent(10.0); // 10s watchdog for sentinel
    }

    dataserver(key _qid, string _qd) {
        integer _c = llSubStringIndex(_qd, ",");
        string _st = _qd; string _vl = ""; string _rawVal = ""; 
        if (_c != -1) {
            _st = llGetSubString(_qd, 0, _c - 1);
            _rawVal = llGetSubString(_qd, _c + 1, -1);
            _vl = llStringTrim(_rawVal, STRING_TRIM);
        }

        if (_qid == kvpSentinelReq) {
            llSetTimerEvent(0.0); // Reset watchdog
            kvpSentinelReq = NULL_KEY; // Kill it once used
            
            if (_st == "1" || _st == "3") { // Success (1) or Not Found (3) prove access
                dbg("✅ [Leaderboard] Experience Sentinel: KVP Access Confirmed. Starting Auto-Sync...");
                loadLBPage(1);
            } else if (_st == "0") {
                string sentinelErr = _vl;
                if (_vl == "1") sentinelErr = "Experience Throttled (Error 1)";
                else if (_vl == "3") sentinelErr = "Invalid Parameters (Error 3)";
                else if (_vl == "17") sentinelErr = "Experience Disabled/Not Permitted (Error 17)";
                else sentinelErr = "KVP Error Status: " + _vl;
                
                dbg("🚫 [Leaderboard] Experience Sentinel: FATAL " + sentinelErr);
                llOwnerSay("🚫 [Leaderboard] WORLD RANKING DISABLED: " + sentinelErr);
            }
            return;
        }

        if (_qid == kvpReadReq) {
            if (isBusy == FALSE && isLocking == FALSE) return; // Ignore stale reads

            if (_st == "1") { // SUCCESS: Data found
                if (_vl != "" && llSubStringIndex(_vl, "Error") == -1) {
                    list _ent = llParseString2List(_vl, ["|"], []);
                    integer _ei;
                    for (_ei = 0; _ei < llGetListLength(_ent); _ei++) {
                        string _rawEntry = llList2String(_ent, _ei);
                        if (llSubStringIndex(_rawEntry, ",") != -1) {
                            // NEW FORMAT: Wins,Losses,Name
                            list _it = llParseString2List(_rawEntry, [","], []);
                            if (llGetListLength(_it) >= 3) {
                                leaderboardData += [(integer)llList2String(_it, 0), (integer)llList2String(_it, 1), llList2String(_it, 2)];
                            }
                        } else {
                            // OLD LEGACY FORMAT: Name:Wins:Losses
                            list _it = llParseString2List(_rawEntry, [":"], []);
                            if (llGetListLength(_it) >= 3) {
                                // Translate to new stride structure in memory
                                leaderboardData += [(integer)llList2String(_it, 1), (integer)llList2String(_it, 2), llList2String(_it, 0)];
                            }
                        }
                    }
                }
                
                if (isBusy && currentLoadPage < 10) {
                    retryCount = 0; // Reset retries for next page
                    loadLBPage(currentLoadPage + 1);
                } else {
                    if (isBusy) {
                        isBusy = FALSE;
                        llSetTimerEvent(0);
                        dbg("🏆 [Leaderboard] SYNC COMPLETE - " + (string)(llGetListLength(leaderboardData)/3) + " players.");
                        llMessageLinked(LINK_SET, MSG_LB_LOAD_COMPLETE, "", NULL_KEY);
                        llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "0", NULL_KEY); // Show page 1
                    }
                    
                    // IF WE WERE SYNCING FOR AN UPDATE, APPLY IT NOW
                    if (isSaving && llGetListLength(pendingRecords) > 0) {
                        isSaving = FALSE;
                        string nextName = llList2String(pendingRecords, 0);
                        string nextRes = llList2String(pendingRecords, 1);
                        pendingRecords = llDeleteSubList(pendingRecords, 0, 1);
                        updatePlayerRecord(nextName, nextRes);
                    }
                }
            } else if (_st == "0") {
                if (_vl == "1") { // XP_ERROR_THROTTLED
                    dbg("⚠️ [Leaderboard] Read throttled. Retrying Shard " + (string)currentLoadPage + " in 2s...");
                    llSleep(2.0);
                    isBusy = FALSE;
                    loadLBPage(currentLoadPage);
                } else if (_vl == "14") { // XP_ERROR_KEY_NOT_FOUND (Value is empty)
                    isBusy = FALSE;
                    llSetTimerEvent(0);
                    dbg("🏆 [Leaderboard] Shard " + (string)currentLoadPage + " is empty (New).");
                    
                    if (currentLoadPage < 10) {
                        loadLBPage(currentLoadPage + 1);
                    } else if (isBusy) {
                        dbg("🏆 [Leaderboard] SYNC COMPLETE - " + (string)(llGetListLength(leaderboardData)/3) + " players total.");
                        llMessageLinked(LINK_SET, MSG_LB_LOAD_COMPLETE, "", NULL_KEY);
                        llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "0", NULL_KEY);
                    }
                } else {
                    dbg("❌ [Leaderboard] Read Error (Code " + _vl + ") on Shard " + (string)currentLoadPage);
                    isBusy = FALSE;
                    llSetTimerEvent(0);
                }
            } else if (_st == "3") { // Not Found
                 isBusy = FALSE;
                 llSetTimerEvent(0);
                 dbg("🏆 [Leaderboard] Shard " + (string)currentLoadPage + " not found.");
                 if (currentLoadPage < 10) loadLBPage(currentLoadPage + 1);
            }
        }
        else if (_qid == kvpWriteReq) {
            integer _c = llSubStringIndex(_qd, ",");
            string _st = _qd; string _vl = "";
            if (_c != -1) {
                _st = llGetSubString(_qd, 0, _c - 1);
                _vl = llGetSubString(_qd, _c + 1, -1);
            }
            
            if (_st == "1") {
                dbg("✅ [Leaderboard] Write success to " + currentWriteKey);
                processWriteQueue();
            } else if (_st == "0" && _vl == "1") {
                // XP_ERROR_THROTTLED
                dbg("⚠️ [Leaderboard] Write throttled. Retrying " + currentWriteKey + " in 2s...");
                llSleep(2.0);
                kvpWriteReq = llUpdateKeyValue(currentWriteKey, currentWriteVal, FALSE, "");
            } else {
                dbg("❌ [Leaderboard] Write Error (" + _st + ":" + _vl + ") on " + currentWriteKey);
                processWriteQueue();
            }
        }
        else if (_qid == kvpClaimReq) {
            kvpClaimReq = NULL_KEY; // DUPLICATE DEFENSE: Prevent zombie processing
            if (_st == "1") { 
                dbg("🔐 [Leaderboard] LOCK ACQUIRED. Starting fresh sync...");
                isClaiming = FALSE;
                isLocking = FALSE; 
                isSaving = TRUE;   
                leaderboardData = []; 
                loadLBPage(1);
            } else if (_vl == "15") { // ATOMIC CHECK FAILED
                dbg("⏳ [Leaderboard] Race conflict (Loss). Yielding and retrying in 5s...");
                isClaiming = FALSE;
                isLocking = TRUE; // Stay in locking mode for retry
                llSetTimerEvent(5.0);
            } else {
                dbg("❌ [Leaderboard] Lock claim failed. Status: " + _st + ":" + _vl);
                isClaiming = FALSE;
                isLocking = FALSE;
            }
        }
        else if (_qid == kvpLockReq) {
            kvpLockReq = NULL_KEY; // DUPLICATE DEFENSE: Prevent zombie processing
            // --- STAGE 1: Check Result (Success Pulse = 1) ---
            if (isLocking) {
                if (_st == "1" && _c != -1) { 
                    string _curVal = _rawVal; // USE RAW DATA FOR ATOMIC CHECK
                    integer _isStale = FALSE;
                    list _p = [];
                    integer _ts = 0;
                    
                    if (_curVal != "") {
                        _p = llParseString2List(_curVal, [":"], []);
                        _ts = (integer)llList2String(_p, 1);
                        if (llGetUnixTime() - _ts > LB_LOCK_TIMEOUT) _isStale = TRUE;
                    }
                    
                    if (llList2String(_p, 0) == (string)llGetKey()) {
                        dbg("🔐 [Leaderboard] Lock already held by this board (Self-Sync). Proceeding...");
                        myLockVal = _curVal; // CRITICAL: Sync timestamp to allow future release
                        isLocking = FALSE; 
                        isSaving = TRUE;   // MARK THAT WE ARE SYNCING FOR A SAVE
                        leaderboardData = []; // PURGE STALE MEMORY
                        loadLBPage(1);
                        return; // Done
                    }
                    
                    if (_curVal == "" || _curVal == "OFF" || _isStale) {
                        dbg("🔐 [Leaderboard] Lock available (or stale). Claiming...");
                        myLockVal = (string)llGetKey() + ":" + (string)llGetUnixTime();
                        dbg("🔓 [Leaderboard] CLAIMING WITH: [" + myLockVal + "] (Len: " + (string)llStringLength(myLockVal) + ")");
                        isClaiming = TRUE;
                        kvpClaimReq = llUpdateKeyValue(LB_LOCK_KEY, myLockVal, TRUE, _curVal);
                    } else {
                        dbg("⏳ [Leaderboard] Lock held by board [" + llList2String(_p, 0) + "] for " + (string)(llGetUnixTime() - _ts) + "s. Retrying in 5s...");
                        llSetTimerEvent(5.0);
                    }
                } else if (_st == "0" && _vl == "14") { // KEY_NOT_FOUND (Lock key doesn't exist)
                    dbg("🔐 [Leaderboard] Lock doesn't exist. Creating initial lock...");
                    myLockVal = (string)llGetKey() + ":" + (string)llGetUnixTime();
                    dbg("🔓 [Leaderboard] CLAIMING WITH: [" + myLockVal + "] (Len: " + (string)llStringLength(myLockVal) + ")");
                    isClaiming = TRUE;
                    // INITIAL CREATION: Use kvpClaimReq to match Stage 2 handler
                    kvpClaimReq = llUpdateKeyValue(LB_LOCK_KEY, myLockVal, FALSE, "");
                } else if (_st == "0" && _vl == "1") { // Throttled
                    dbg("⚠️ [Leaderboard] Lock check throttled. Retrying...");
                    llSleep(2.0);
                    kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
                } else {
                    dbg("❌ [Leaderboard] Lock logic failed (Code " + _st + ":" + _vl + ")");
                    isLocking = FALSE;
                }
            } else {
                // RELEASE RESULT: Check for Status 1 (Success)
                if (_st == "1") { dbg("🔓 [Leaderboard] Lock released."); }
                else { dbg("⚠️ [Leaderboard] Lock release report: " + _st + ":" + _vl); }
            }
        }
    }

    timer() {
        if (isLocking) {
            llSetTimerEvent(0);
            kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
            return;
        }
        
        if (isBusy || (kvpReadReq == NULL_KEY && currentLoadPage > 0)) {
            if (retryCount < 3) {
                retryCount++;
                dbg("⏳ [Leaderboard] Retrying Shard " + (string)currentLoadPage + " (" + (string)retryCount + "/3)...");
                isBusy = FALSE; // Unlock so loadLBPage can run
                loadLBPage(currentLoadPage);
            } else {
                isBusy = FALSE;
                llSetTimerEvent(0);
                dbg("🏆 [Leaderboard] SYNC GAVE UP (Persistent issues on Shard " + (string)currentLoadPage + ")");
                llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "0", NULL_KEY);
            }
        } else {
            llSetTimerEvent(0);
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_LB_RECORD_PLAYER) {
            // str is "Name|Result" (e.g. "Bot1|WIN")
            list _p = llParseString2List(str, ["|"], []);
            startUpdateSequence(llList2String(_p, 0), llList2String(_p, 1));
        }
        else if (num == MSG_DISPLAY_LEADERBOARD) {
            if (str == "REFRESH_STARTUP") loadLBPage(1);
        }
        else if (num == MSG_LB_REQUEST_DISPLAY) {
            integer _offset = (integer)str;
            displayOffset = _offset; // SYNC GLOBAL VARIABLE
            list _sorted = getSortedSlice(_offset);
            string _rankCol = ""; string _nameCol = ""; string _statsCol = "";
            integer _i; integer _total = llGetListLength(_sorted) / 3;
            integer _globalTotal = llGetListLength(leaderboardData) / 3;

            for (_i = 0; _i < 10; _i++) {
                integer _rn = _offset + _i + 1;
                string _rank = (string)_rn + "."; if (_rn < 10) _rank = "0" + _rank;
                _rankCol += _rank + "\n";
                if (_i < _total) {
                    integer _b = _i * 3;
                    _statsCol += "W:" + (string)llList2Integer(_sorted, _b) + "/L:" + (string)llList2Integer(_sorted, _b+1) + "\n";
                    string _n = llList2String(_sorted, _b+2);
                    if (llStringLength(_n) > 16) _n = llGetSubString(_n, 0, 13) + "...";
                    _nameCol += _n + "\n";
                } else {
                    _nameCol += "----------\n"; _statsCol += "W:0/L:0\n";
                }
            }
            string _p = " "; if (_offset > 0) _p = "[ < PREV ]";
            string _n = " "; if (_offset + 10 < _globalTotal) _n = "[ NEXT > ]";
            llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "COLUMNS|" + _rankCol + "|" + _nameCol + "|" + _statsCol + "|" + _p + "|" + _n + "|" + (string)_offset, NULL_KEY);
        }
        else if (num == MSG_LB_PAGE_NEXT) {
            integer _maxEntries = llGetListLength(leaderboardData) / 3;
            if (displayOffset + 10 < _maxEntries) {
                displayOffset += 10;
                llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, (string)displayOffset, NULL_KEY);
            }
        }
        else if (num == MSG_LB_PAGE_PREV) {
            if (displayOffset >= 10) {
                displayOffset -= 10;
                llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, (string)displayOffset, NULL_KEY);
            }
        }
        else if (num == MSG_RESET_LEADERBOARD) {
            leaderboardData = [];
            currentLoadPage = 1;
            isBusy = FALSE;
            displayOffset = 0;
            
            if (str == "START_SYNC") {
                loadLBPage(1);
            }
            else if (str == "WIPE" || str == "HARD_RESET") {
                if (id != (key)GLOBAL_ADMIN) {
                    llOwnerSay("🚫 [Security] Unauthorized WIPE attempt blocked from: " + (string)id);
                    return;
                }
                // Soft Wipe: Clear all shards to empty in world datastore
                integer _i;
                for (_i = 1; _i <= MAX_LB_PAGES; _i++) {
                    llUpdateKeyValue(LB_KEY_PREFIX + (string)_i, "", FALSE, "");
                }
                dbg("🚫 [Leaderboard Manager] GLOBAL WIPE: All 10 datastore shards have been set to empty.");
            }
            else if (str == "DEBUG_GENERATE" && llGetOwner() == llGetCreator()) {
                generateShardedData();
            }
        }
        else if (num == MSG_RESET_ALL) { 
            if (str == "FULL_RESET" || str == "HARD_RESET") llResetScript(); 
        }
    }
}
