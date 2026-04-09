#include "Peril_Constants.lsl"

// =============================================================================
// PERIL SCOREBOARD - GRID DISPLAY MANAGER (v3.2.7 Final)
// =============================================================================
// Shows current game players in grid layout (Profile Pic, Hearts, Overlay)
// Delegates persistent Leaderboard storage to Game_Leaderboard_Manager.lsl
// =============================================================================

// --- DYNAMIC LINK DISCOVERY ---
integer BACKGROUND_PRIM = -1;
integer ACTIONS_PRIM = -1;
list gridLinks = [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0];

discoverLinks() {
    integer _dl_i;
    integer _dl_total = llGetNumberOfPrims();
    gridLinks = [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0];
    
    for (_dl_i = 1; _dl_i <= _dl_total; _dl_i++) {
        string _name = llGetLinkName(_dl_i);
        if (_name == "backboard:0:0") BACKGROUND_PRIM = _dl_i;
        else if (_name == "TitleAction:0:0") ACTIONS_PRIM = _dl_i;
        else if (_name == "Scoreboard:0:0") LINK_SCOREBOARD = _dl_i;
        else {
            list _p = llParseString2List(_name, [":"], []);
            if (llGetListLength(_p) == 3) {
                string _type = llList2String(_p, 0);
                integer _idx = (((integer)llList2String(_p, 1)) * 2) + ((integer)llList2String(_p, 2));
                if (_idx >= 0 && _idx < 10) {
                    integer _gb = _idx * 3;
                    if (_type == "profile") gridLinks = llListReplaceList(gridLinks, [_dl_i], _gb, _gb);
                    else if (_type == "life") gridLinks = llListReplaceList(gridLinks, [_dl_i], _gb + 1, _gb + 1);
                    else if (_type == "overlay") gridLinks = llListReplaceList(gridLinks, [_dl_i], _gb + 2, _gb + 2);
                }
            }
        }
    }
    dbg("Discovery done");
    if (LINK_SCOREBOARD == -1) LINK_SCOREBOARD = 1;
}

// --- Textures ---
#define LEADERBOARD_WIDTH 32    
#define TEXTURE_0_HEARTS "7d8ae121-e171-12ae-f5b6-7cc3c0395c7b"
#define TEXTURE_1_HEARTS "6605d25f-8e2d-2870-eb87-77c58cd47fa9"
#define TEXTURE_2_HEARTS "7ba6cb1e-f384-25a5-8e88-a90bbd7cc041"
#define TEXTURE_3_HEARTS "a5d16715-4648-6526-5582-e8068293f792"
#define TEXTURE_DEFAULT_PROFILE "1ce89375-6c3c-3845-26b1-1dc666bc9169"
#define TEXTURE_BOT_PROFILE "62f31722-04c1-8c29-c236-398543f2a6ae"
#define BLANK_TEXTURE "5748decc-f629-461c-9a36-a35a221fe21f"
#define TEXTURE_BACKGROUND "5748decc-f629-461c-9a36-a35a221fe21f"
#define TEXTURE_TITLE "624bb7a7-e856-965c-bae8-94d75226c1bc"
#define TEXTURE_ELIMINATED_X "90524092-03b0-1b3c-bcea-3ea5118c6dba"

// Status textures
#define TEXTURE_PERIL "c5676fec-0c85-5567-3dd8-f939234e21d9"
#define TEXTURE_PERIL_SELECTED "a53ff601-3c8a-e312-9e0e-f6fa76f6773a"
#define TEXTURE_VICTORY "ec5bf10e-4970-fb63-e7bf-751e1dc27a8d"
#define TEXTURE_PUNISHMENT "acfabed0-84ad-bfd1-cdfc-2ada0aeeaa2f"
#define TEXTURE_DIRECT_HIT "ecd2dba2-3969-6c39-ad59-319747307f55"
#define TEXTURE_NO_SHIELD "2440174f-e385-44e2-8016-ac34934f11f5"
#define TEXTURE_PLOT_TWIST "ec533379-4f7f-8183-e877-e68af703dcce"

list activePlayers = []; // Stride 3: Name, Lives, UUID/Texture
string currentPerilPlayer = "";
string currentWinner = "";
list httpRequests = [];

#define PROFILE_KEY_PREFIX "<meta name=\"imageid\" content=\""
#define PROFILE_IMG_PREFIX "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/\""
#define PROFILE_KEY_PREFIX_LENGTH 30
#define PROFILE_IMG_PREFIX_LENGTH 59

resetBackgroundPrim() {
    if (BACKGROUND_PRIM != -1) {
        llSetLinkPrimitiveParamsFast(BACKGROUND_PRIM, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_BACKGROUND, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, PRIM_TEXT, "", <0,0,0>, 0.0]);
    }
}

resetManagerCube() {
    llSetLinkPrimitiveParamsFast(LINK_SCOREBOARD, [PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <0.0, 0.0, 0.0>, 1.0, PRIM_TEXT, "", <0,0,0>, 0.0]);
}

updateActionsPrim(string status) {
    string _uap_tex = "";
    if (status == "Elimination") _uap_tex = TEXTURE_PERIL;
    else if (status == "Victory") _uap_tex = TEXTURE_VICTORY;
    else if (status == "Punishment") _uap_tex = TEXTURE_PUNISHMENT;
    else if (status == "Direct Hit") _uap_tex = TEXTURE_DIRECT_HIT;
    else if (status == "No Shield") _uap_tex = TEXTURE_NO_SHIELD;
    else if (status == "Peril Selected") _uap_tex = TEXTURE_PERIL_SELECTED;
    else if (status == "Plot Twist") _uap_tex = TEXTURE_PLOT_TWIST;
    else if (status == "Title") _uap_tex = TEXTURE_TITLE;
    
    if (ACTIONS_PRIM != -1 && _uap_tex != "") {
        llSetLinkPrimitiveParamsFast(ACTIONS_PRIM, [PRIM_TEXTURE, ALL_SIDES, _uap_tex, <1,1,0>, <0,0,0>, 0.0, PRIM_TEXT, "", <0,0,0>, 0.0]);
    }
}

clearAllPlayers() {
    activePlayers = [];
    httpRequests = [];
    integer _ca_i;
    for (_ca_i = 0; _ca_i < 10; _ca_i++) {
        integer _pL = getProfilePrimLink(_ca_i);
        integer _hL = getHeartsPrimLink(_ca_i);
        integer _oL = getOverlayPrimLink(_ca_i);
        if (_pL > 0) {
            // Explicitly reset textures to blank to prevent profile persistence
            llSetLinkPrimitiveParamsFast(_pL, [PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
            llSetLinkPrimitiveParamsFast(_hL, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_0_HEARTS, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
            llSetLinkPrimitiveParamsFast(_oL, [PRIM_TEXTURE, ALL_SIDES, BLANK_TEXTURE, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
        }
    }
}

removePlayer(string pName) {
    integer _rem_idx = llListFindList(activePlayers, [pName]);
    if (_rem_idx != -1) {
        activePlayers = llDeleteSubList(activePlayers, _rem_idx, _rem_idx + 2);
        refreshPlayerDisplay();
    }
}

refreshPlayerDisplay() {
    integer _rpd_num = llGetListLength(activePlayers) / 3;
    integer _rpd_ri;
    for (_rpd_ri = 0; _rpd_ri < 10; _rpd_ri++) {
        integer _rpd_pL = getProfilePrimLink(_rpd_ri);
        integer _rpd_hL = getHeartsPrimLink(_rpd_ri);
        integer _rpd_oL = getOverlayPrimLink(_rpd_ri);
        if (_rpd_pL > 0) {
            if (_rpd_ri >= _rpd_num) {
                llSetLinkPrimitiveParamsFast(_rpd_pL, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
                llSetLinkPrimitiveParamsFast(_rpd_hL, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
                llSetLinkPrimitiveParamsFast(_rpd_oL, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
            } else {
                integer _rpd_b = _rpd_ri * 3;
                string _rpd_nm = llList2String(activePlayers, _rpd_b);
                integer _rpd_lv = llList2Integer(activePlayers, _rpd_b + 1);
                string _rpd_tx = llList2String(activePlayers, _rpd_b + 2);
                if (isBot(_rpd_nm)) _rpd_tx = TEXTURE_BOT_PROFILE;
                else if (_rpd_tx == "" || _rpd_tx == NULL_KEY) _rpd_tx = TEXTURE_DEFAULT_PROFILE;
                
                llSetLinkPrimitiveParamsFast(_rpd_pL, [PRIM_TEXTURE, ALL_SIDES, _rpd_tx, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
                llSetLinkPrimitiveParamsFast(_rpd_hL, [PRIM_TEXTURE, ALL_SIDES, getHeartTexture(_rpd_lv), <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
                if (_rpd_lv <= 0) llSetLinkPrimitiveParamsFast(_rpd_oL, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
                else llSetLinkPrimitiveParamsFast(_rpd_oL, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
            }
        }
    }
    updatePlayerGlowEffects();
}

integer isBot(string pName) { return (llSubStringIndex(pName, "Bot") == 0); }
integer getProfilePrimLink(integer pI) { return llList2Integer(gridLinks, pI * 3); }
integer getHeartsPrimLink(integer pI) { return llList2Integer(gridLinks, (pI * 3) + 1); }
integer getOverlayPrimLink(integer pI) { return llList2Integer(gridLinks, (pI * 3) + 2); }

string getHeartTexture(integer lives) {
    if (lives <= 0) return TEXTURE_0_HEARTS;
    if (lives == 1) return TEXTURE_1_HEARTS;
    if (lives == 2) return TEXTURE_2_HEARTS;
    return TEXTURE_3_HEARTS;
}

setGlow(integer link, float glow, vector color) {
    if (link > 0) llSetLinkPrimitiveParamsFast(link, [PRIM_GLOW, ALL_SIDES, glow, PRIM_COLOR, ALL_SIDES, color, 1.0]);
}

updatePlayerGlowEffects() {
    integer _uge_num = llGetListLength(activePlayers) / 3;
    integer _uge_gi;
    for (_uge_gi = 0; _uge_gi < _uge_num; _uge_gi++) {
        setGlow(getProfilePrimLink(_uge_gi), 0.0, <1,1,1>);
        setGlow(getHeartsPrimLink(_uge_gi), 0.0, <1,1,1>);
    }
    integer _uge_idx = -1; vector _uge_col = <1,1,1>; float _uge_glow = 0.0;
    if (currentWinner != "" && currentWinner != "NONE") {
        _uge_idx = llListFindList(activePlayers, [currentWinner]);
        if (_uge_idx != -1) { _uge_idx = _uge_idx / 3; _uge_col = <0,1,0>; _uge_glow = 0.3; }
    } else if (currentPerilPlayer != "" && currentPerilPlayer != "NONE") {
        _uge_idx = llListFindList(activePlayers, [currentPerilPlayer]);
        if (_uge_idx != -1) { _uge_idx = _uge_idx / 3; _uge_col = <1,1,0>; _uge_glow = 0.2; }
    }
    if (_uge_idx != -1) {
        setGlow(getProfilePrimLink(_uge_idx), _uge_glow, _uge_col);
        setGlow(getHeartsPrimLink(_uge_idx), _uge_glow, _uge_col);
    }
}

updatePlayerDisplay(string pName, integer pLives, string pUUID) {
    integer _upd_pIdx = llListFindList(activePlayers, [pName]);
    if (_upd_pIdx != -1) _upd_pIdx = _upd_pIdx / 3;
    
    if (_upd_pIdx == -1) {
        _upd_pIdx = llGetListLength(activePlayers) / 3;
        if (_upd_pIdx >= 10) return;
        string _upd_activeUUID = pUUID;
        if (isBot(pName)) _upd_activeUUID = TEXTURE_BOT_PROFILE;
        activePlayers += [pName, pLives, _upd_activeUUID];
    } else {
        activePlayers = llListReplaceList(activePlayers, [pLives], (_upd_pIdx * 3) + 1, (_upd_pIdx * 3) + 1);
    }
    
    integer _upd_upP = getProfilePrimLink(_upd_pIdx);
    integer _upd_upH = getHeartsPrimLink(_upd_pIdx);
    integer _upd_upO = getOverlayPrimLink(_upd_pIdx);
    if (_upd_upP <= 0) return;
    
    string _upd_uT; vector _upd_pC = <1,1,1>;
    if (pLives <= 0) _upd_pC = <1.0, 0.3, 0.3>;
    
    if (isBot(pName)) _upd_uT = TEXTURE_BOT_PROFILE;
    else {
        _upd_uT = llList2String(activePlayers, (_upd_pIdx * 3) + 2);
        if (_upd_uT == "" || _upd_uT == pUUID || _upd_uT == TEXTURE_DEFAULT_PROFILE) {
            _upd_uT = TEXTURE_DEFAULT_PROFILE;
            key _upd_rID = llHTTPRequest("https://world.secondlife.com/resident/" + pUUID, [HTTP_METHOD, "GET"], "");
            httpRequests += [_upd_rID, _upd_pIdx];
        }
    }
    
    llSetLinkPrimitiveParamsFast(_upd_upP, [PRIM_TEXTURE, ALL_SIDES, _upd_uT, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, _upd_pC, 1.0, PRIM_GLOW, ALL_SIDES, 0.01]);
    llSleep(DELAY_SCOREBOARD_REFRESH);
    llSetLinkPrimitiveParamsFast(_upd_upP, [PRIM_GLOW, ALL_SIDES, 0.0]);
    llSetLinkPrimitiveParamsFast(_upd_upH, [PRIM_TEXTURE, ALL_SIDES, getHeartTexture(pLives), <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
    if (pLives <= 0) llSetLinkPrimitiveParamsFast(_upd_upO, [PRIM_TEXTURE, ALL_SIDES, TEXTURE_ELIMINATED_X, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0]);
    else llSetLinkPrimitiveParamsFast(_upd_upO, [PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0]);
    
    updatePlayerGlowEffects();
}

default {
    on_rez(integer _sp) { discoverLinks(); clearAllPlayers(); llResetScript(); }
    state_entry() {
        discoverLinks();
        llListen(1, "", llGetOwner(), ""); 
        REPORT_MEMORY();
        clearAllPlayers(); // Ensure board is clean on initialization
        resetBackgroundPrim();
        resetManagerCube();
        updateActionsPrim("Title");
        updatePlayerGlowEffects();
        dbg("Ready");
    }
    
    link_message(integer _s, integer _n, string _st, key _i) {
        if (_n == MSG_GAME_STATUS) updateActionsPrim(_st);
        else if (_n == MSG_PLAYER_UPDATE) {
            list _parts = llParseString2List(_st, ["|"], []);
            if (llGetListLength(_parts) >= 3) {
                updatePlayerDisplay(llList2String(_parts, 0), (integer)llList2String(_parts, 1), llList2String(_parts, 2));
            }
        }
        else if (_n == MSG_CLEAR_GAME) {
            resetBackgroundPrim(); resetManagerCube(); clearAllPlayers(); updateActionsPrim("Title");
            currentPerilPlayer = ""; currentWinner = ""; updatePlayerGlowEffects();
            llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "", NULL_KEY);
        }
        else if (_n == MSG_GAME_WON || _n == MSG_GAME_LOST) {
            // Visual winning/losing logic is already handled by specific update messages
            // Record keeping is now centralized in Main Controller
        }
        else if (_n == MSG_LB_DISPLAY_DATA) {
            string _tl = "WORLD RANKING RECORD"; string _sp = "                                "; 
            integer _m = (LEADERBOARD_WIDTH - llStringLength(_tl)) / 2;
            string _tt = llGetSubString(_sp, 0, _m - 1) + _tl;
            llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "FORMATTED_TEXT|" + _tt, NULL_KEY);
            llMessageLinked(LINK_SET, MSG_DISPLAY_LEADERBOARD, "COLUMNS|" + _st, NULL_KEY);
        }
        else if (_n == MSG_LB_LOAD_COMPLETE) llMessageLinked(LINK_SET, MSG_LB_REQUEST_DISPLAY, "", NULL_KEY);
        else if (_n == MSG_REMOVE_PLAYER) removePlayer(_st);
        else if (_n == MSG_UPDATE_PERIL_PLAYER) { 
            if (_st == "NONE") currentPerilPlayer = "";
            else currentPerilPlayer = _st;
            updatePlayerGlowEffects();
        }
        else if (_n == MSG_UPDATE_WINNER) { 
            if (_st == "NONE") currentWinner = "";
            else currentWinner = _st;
            updatePlayerGlowEffects();
        }
        else if (_n == MSG_RESET_ALL) llResetScript();
    }
    
    http_response(key _rid, integer _status, list _meta, string _body) {
        integer _rIdx = llListFindList(httpRequests, [_rid]);
        if (_rIdx != -1) {
            integer _pIdx = llList2Integer(httpRequests, _rIdx + 1);
            httpRequests = llDeleteSubList(httpRequests, _rIdx, _rIdx + 1);
            if (_status == 200 && _pIdx < llGetListLength(activePlayers) / 3) {
                string _pU = "";
                integer _mS = llSubStringIndex(_body, PROFILE_KEY_PREFIX);
                if (_mS != -1) {
                    _mS += PROFILE_KEY_PREFIX_LENGTH;
                    string _rem = llGetSubString(_body, _mS, -1);
                    integer _mE = llSubStringIndex(_rem, "\"");
                    if (_mE != -1) _pU = llGetSubString(_rem, 0, _mE - 1);
                }
                if (_pU == "" || _pU == NULL_KEY) {
                    integer _iS = llSubStringIndex(_body, PROFILE_IMG_PREFIX);
                    if (_iS != -1) {
                        _iS += PROFILE_IMG_PREFIX_LENGTH;
                        string _rem = llGetSubString(_body, _iS, -1);
                        integer _iE = llSubStringIndex(_rem, "/");
                        if (_iE != -1) _pU = llGetSubString(_rem, 0, _iE - 1);
                    }
                }
                if (_pU != "" && _pU != NULL_KEY) {
                    activePlayers = llListReplaceList(activePlayers, [_pU], (_pIdx * 3) + 2, (_pIdx * 3) + 2);
                    integer _pL = getProfilePrimLink(_pIdx);
                    if (_pL > 0) {
                        llSetLinkPrimitiveParamsFast(_pL, [PRIM_TEXTURE, ALL_SIDES, _pU, <1,1,0>, <0,0,0>, 0.0, PRIM_COLOR, ALL_SIDES, <1,1,1>, 1.0, PRIM_GLOW, ALL_SIDES, 0.01]);
                        llSleep(DELAY_SCOREBOARD_REFRESH);
                        llSetLinkPrimitiveParamsFast(_pL, [PRIM_GLOW, ALL_SIDES, 0.0]);
                    }
                }
            }
        }
    }
}
