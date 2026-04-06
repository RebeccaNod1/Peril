#include "Peril_Constants.lsl"

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
key kvpLockReq;    // Request for claiming leaderboard lock
list writeQueue = []; // Pairs of [KeyName, DataString]
integer isSaving = FALSE;
integer isBusy = FALSE; // Read lock
integer displayOffset = 0; // Current ranking page offset (0, 10, 20...)
integer retryCount = 0; // Track number of timeouts
string currentWriteKey;
string currentWriteVal;

// --- Lock & Sync State ---
string pendingPlayer = "";
string pendingResult = "";
integer isLocking = FALSE;
string myLockVal = "";

// Helper: Process the next KVP write in the queue
processWriteQueue() {
    if (llGetListLength(writeQueue) == 0) {
        isSaving = FALSE;
        dbg("🏆 [Leaderboard] Save sequence complete. Releasing lock...");
        // releaseLock();
        kvpLockReq = llUpdateKeyValue(LB_LOCK_KEY, "", TRUE, myLockVal);
        return;
    }
    isSaving = TRUE;
    currentWriteKey = llList2String(writeQueue, 0);
    currentWriteVal = llList2String(writeQueue, 1);
    writeQueue = llDeleteSubList(writeQueue, 0, 1);
    kvpWriteReq = llUpdateKeyValue(currentWriteKey, currentWriteVal, FALSE, "");
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
    if (isBusy && pageNum == 1) return; // Prevent double loads on reset
    if (pageNum > 1) llSleep(1.0); // Anti-Throttle Delay
    
    isBusy = TRUE;
    llSetTimerEvent(30.0); // 30 second watchdog (Lag Resistant)
    currentLoadPage = pageNum;
    string keyName = LB_KEY_PREFIX + (string)pageNum;
    kvpReadReq = llReadKeyValue(keyName);
    if (kvpReadReq == NULL_KEY) {
        dbg("❌ [Leaderboard] KVP Read FAILED: Not authorized for " + keyName);
        llSetTimerEvent(0.0);
    } else {
        dbg("📡 [Leaderboard] Loading " + keyName + "...");
    }
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
    if (isLocking || isSaving) {
        dbg("⚠️ [Leaderboard] Update already in progress. Retrying in 2s...");
        llSleep(2.0);
    }
    
    pendingPlayer = pName;
    pendingResult = pResult;
    isLocking = TRUE;
    
    dbg("🔐 [Leaderboard] Checking global lock for update...");
    kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
}

default {
    state_entry() {
        REPORT_MEMORY();
        dbg("⏳ [Leaderboard] Startup: Handshake link active.");
    }

    dataserver(key _qid, string _qd) {
        if (_qid == kvpReadReq) {
            llSetTimerEvent(0.0); // Reset watchdog
            integer _c = llSubStringIndex(_qd, ",");
            string _st = _qd; string _vl = "";
            if (_c != -1) {
                _st = llGetSubString(_qd, 0, _c - 1);
                _vl = llGetSubString(_qd, _c + 1, -1);
            }

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
                
                if (currentLoadPage < 10) {
                    retryCount = 0; // Reset retries for next page
                    loadLBPage(currentLoadPage + 1);
                } else {
                    isBusy = FALSE;
                    llSetTimerEvent(0);
                    dbg("🏆 [Leaderboard] SYNC COMPLETE - " + (string)(llGetListLength(leaderboardData)/3) + " players.");
                    llMessageLinked(LINK_SET, MSG_LB_LOAD_COMPLETE, "", NULL_KEY);
                    llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "0", NULL_KEY); // Show page 1
                    
                    // IF WE WERE SYNCING FOR AN UPDATE, APPLY IT NOW
                    if (isLocking) {
                        isLocking = FALSE;
                        updatePlayerRecord(pendingPlayer, pendingResult);
                    }
                }
            } else if (_st == "0" && _vl == "1") {
                // XP_ERROR_THROTTLED
                dbg("⚠️ [Leaderboard] Read throttled. Retrying Shard " + (string)currentLoadPage + " in 2s...");
                llSleep(2.0);
                isBusy = FALSE;
                loadLBPage(currentLoadPage);
            } else { // Empty or Error
                isBusy = FALSE;
                llSetTimerEvent(0);
                if (_st == "0") { dbg("❌ [Leaderboard] KVP Error on Shard " + (string)currentLoadPage + ": " + _vl); }
                dbg("🏆 [Leaderboard] SYNC COMPLETE - " + (string)(llGetListLength(leaderboardData)/3) + " players total.");
                llMessageLinked(LINK_SET, MSG_LB_LOAD_COMPLETE, "", NULL_KEY);
                llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "0", NULL_KEY);
            }
        }
        else if (_qid == kvpWriteReq) {
            integer _c = llSubStringIndex(_qd, ",");
            string _st = _qd; string _vl = "";
            if (_c != -1) {
                _st = llGetSubString(_qd, 0, _c - 1);
                _vl = llGetSubString(_qd, _c + 1, -1);
            }
            
            if (_st == "0" && _vl == "1") {
                // XP_ERROR_THROTTLED
                dbg("⚠️ [Leaderboard] Write throttled. Retrying " + currentWriteKey + " in 2s...");
                llSleep(2.0);
                kvpWriteReq = llUpdateKeyValue(currentWriteKey, currentWriteVal, FALSE, "");
            } else {
                if (_st == "0") { dbg("❌ [Leaderboard] Write Error (" + _vl + ") on " + currentWriteKey); }
                processWriteQueue();
            }
        }
        else if (_qid == kvpLockReq) {
            integer _c = llSubStringIndex(_qd, ",");
            string _st = _qd; string _vl = "";
            if (_c != -1) {
                _st = llGetSubString(_qd, 0, _c - 1);
                _vl = llGetSubString(_qd, _c + 1, -1);
            }
            
            if (isLocking) {
                // STAGE 1: Current Lock Read Result
                if (_st == "1") { // Success read
                    string _curVal = _vl;
                    integer _isStale = FALSE;
                    if (_curVal != "") {
                        list _p = llParseString2List(_curVal, [":"], []);
                        integer _ts = (integer)llList2String(_p, 1);
                        if (llGetUnixTime() - _ts > LB_LOCK_TIMEOUT) _isStale = TRUE;
                    }
                    
                    if (_curVal == "" || _isStale) {
                        dbg("🔐 [Leaderboard] Lock available. Claiming...");
                        myLockVal = (string)llGetKey() + ":" + (string)llGetUnixTime();
                        // ATOMIC UPDATE: Only write if value is still what we just read
                        kvpLockReq = llUpdateKeyValue(LB_LOCK_KEY, myLockVal, TRUE, _curVal);
                    } else {
                        dbg("⏳ [Leaderboard] Lock held by another board. Retrying in 5s...");
                        llSetTimerEvent(5.0);
                    }
                } else if (_st == "0" && _vl == "1") { // Throttled
                    dbg("⚠️ [Leaderboard] Lock check throttled. Retrying...");
                    llSleep(2.0);
                    kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
                } else if (_st == "14") { // SUCCESSFUL CLAIM (Atomic check passed)
                    dbg("🔐 [Leaderboard] LOCK ACQUIRED. Starting fresh sync...");
                    leaderboardData = []; // PURGE STALE MEMORY
                    loadLBPage(1);
                } else if (_st == "0" && _vl == "15") { // ATOMIC CHECK FAILED (Someone else grabbed it)
                    dbg("⏳ [Leaderboard] Lock race lost. Retrying...");
                    llSleep(1.0);
                    kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
                } else {
                    dbg("❌ [Leaderboard] Lock Error: (" + _st + ") " + _vl);
                    isLocking = FALSE;
                }
            } else {
                // RELEASE RESULT
                if (_st == "14") { dbg("🔓 [Leaderboard] Lock released."); }
                else { dbg("⚠️ [Leaderboard] Lock release issues: " + _vl); }
            }
        }
    }

    timer() {
        if (isLocking) {
            llSetTimerEvent(0);
            kvpLockReq = llReadKeyValue(LB_LOCK_KEY);
            return;
        }
        
        if (isBusy) {
            if (retryCount < 3) {
                retryCount++;
                dbg("⚠️ [Leaderboard] Shard " + (string)currentLoadPage + " timed out. Retrying (" + (string)retryCount + "/3)...");
                isBusy = FALSE; // Unlock so loadLBPage can run
                loadLBPage(currentLoadPage);
            } else {
                isBusy = FALSE;
                llSetTimerEvent(0);
                dbg("🏆 [Leaderboard] SYNC GAVE UP (Persistent timeout on Shard " + (string)currentLoadPage + ")");
                llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "0", NULL_KEY);
            }
        } else {
            llSetTimerEvent(0);
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MSG_LB_RECORD_PLAYER) {
            startUpdateSequence(str, (string)id);
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
            llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "COLUMNS|" + _rankCol + "|" + _nameCol + "|" + _statsCol + "|" + _p + "|" + _n, NULL_KEY);
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
            else if (str == "DEBUG_GENERATE" && llGetOwner() == llGetCreator()) {
                generateShardedData();
            }
        }
        else if (num == MSG_RESET_ALL) { llResetScript(); }
    }
}
