#include "telecom.h"
#include "lua.h"
#include "lauxlib.h"

#define MYNAME "sonus"
#define SVER "1555606938"
#define MYVERSION MYNAME "-" SVER "-" LUA_VERSION
#define sonus_client_type "sonus_client"
#define sonus_playable_type "sonus_playable"
#define CHECKSOBJ(L, c, t) if ((c)->closed == 1) return luaL_error((L), "%s: %p is already closed.", (t), (void*)(c));
#define stack_top -1
#define below_top_by(n) -1 -(n)

typedef struct {
    GoUintptr ref;
    int closed;
} sonus_client;

typedef struct {
    GoUintptr ref;
    int closed;
} sonus_playable;


static sonus_client *Cget(lua_State *L, int i) {
    return luaL_checkudata(L, i, sonus_client_type);
}

static sonus_client *Cnew(lua_State *L) {
    sonus_client *c = lua_newuserdata(L, sizeof(sonus_client));
    luaL_getmetatable(L, sonus_client_type);
    lua_setmetatable(L, -2);
    return c;
}

static sonus_playable *Pget(lua_State *L, int i) {
    return luaL_checkudata(L, i, sonus_playable_type);
}

static sonus_playable *Pnew(lua_State *L) {
    sonus_playable *c = lua_newuserdata(L, sizeof(sonus_playable));
    luaL_getmetatable(L, sonus_playable_type);
    lua_setmetatable(L, -2);
    return c;
}

//setup_logging(enable)
static int Lsetup_logging(lua_State *L) {
    if (lua_isboolean(L, 1)) {
        telecom_setup_logging(1, 0);
    } else {
        telecom_setup_logging(0,0);
    }
    return 0;
}

static int Lsetup_logging_debug(lua_State *L) {
    if (lua_isboolean(L, 1)) {
        telecom_setup_logging(1, 1);
    } else {
        telecom_setup_logging(0,1);
    }
    return 0;
}



static int Lnew_client(lua_State *L) {
    char* userId = luaL_checkstring(L, 1);
    char* guildId = luaL_checkstring(L, 2);
    char* sessionId = luaL_checkstring(L, 3);
    GoUintptr next_client = telecom_create_client(userId, guildId, sessionId);
    sonus_client* lclient = Cnew(L);
    lclient->ref = next_client;
    lclient->closed = 0;
    return 1;
}

static int Lclient_destroy(lua_State *L) {
    sonus_client* lclient = Cget(L, 1);
    if (lclient->closed == 0){
        telecom_client_destroy(lclient->ref);
        lclient->closed = 1;
    }
    return 0;
}

static int Lclient_set_server_info(lua_State *L) {
    sonus_client* lclient = Cget(L, 1);
    CHECKSOBJ(L, lclient, sonus_client_type);
    char* endpoint = luaL_checkstring(L, 2);
    char* token = luaL_checkstring(L, 3);
    telecom_client_set_server_info(lclient->ref, endpoint, token);
    lua_settop(L,1);
    return 1;
}

static int Lclient_play(lua_State *L) {
    sonus_client* lclient = Cget(L, 1);
    CHECKSOBJ(L, lclient, sonus_client_type);
    sonus_playable* lplayable = Pget(L, 2);
    CHECKSOBJ(L, lplayable, sonus_playable_type);
    telecom_client_play(lclient->ref, lplayable->ref);
    lua_settop(L,1);
    return 1;
}

static int Lnew_playable(lua_State *L) {
    char* source = luaL_checkstring(L, 1);
    GoUintptr next_playable = telecom_create_avconv_playable(source);
    sonus_playable* lplayable = Pnew(L);
    lplayable->ref = next_playable;
    lplayable->closed = 0;
    return 1;
}

static int Lplayable_destroy(lua_State *L) {
    sonus_playable* lplayable = Pget(L, 1);
    if (lplayable->closed == 0){
        telecom_playable_destroy(lplayable->ref);
        lplayable->closed = 1;
    }
    return 0;
}

static int Lclient_tostring(lua_State *L)
{
    sonus_client* c=Cget(L,1);
    lua_pushfstring(L,"%s: %p <%s>",sonus_client_type,(void*)c, c->closed? "closed" : "open");
    return 1;
}

static int Lplayable_tostring(lua_State *L)
{
    sonus_playable* c=Pget(L,1);
    lua_pushfstring(L,"%s: %p <%s>",sonus_playable_type,(void*)c,  c->closed? "closed" : "open");
    return 1;
}

static const luaL_Reg ClientFuncs[] = {
    {"__tostring", Lclient_tostring},
    {"__gc", Lclient_destroy},
    {"destroy", Lclient_destroy},
    {"set_server_info", Lclient_set_server_info},
    {"play", Lclient_play},
    {NULL, NULL}
};

static const luaL_Reg PlayableFuncs[] = {
    {"__tostring", Lplayable_tostring},
    {"__gc", Lplayable_destroy},
    {"destroy", Lplayable_destroy},
    {NULL, NULL}
};

static const luaL_Reg LibFuncs[] = {
    {"new_client", Lnew_client},
    {"new_playable", Lnew_playable},
    {"setup_logging", Lsetup_logging},
    {"setup_debug_logging", Lsetup_logging_debug},
    {NULL, NULL}
};

LUALIB_API int luaopen_sonus_core(lua_State *L) {
    luaL_newmetatable(L, sonus_client_type); //[table1]
    luaL_setfuncs(L, ClientFuncs, 0); //[table1]
    lua_pushliteral(L,"__index"); //["__index", table1]
    lua_pushvalue(L, -2); //[table1, "__index", table1]
    lua_settable(L,-3); //[table1]

    luaL_newmetatable(L, sonus_playable_type); //[table2, table1]
    luaL_setfuncs(L, PlayableFuncs, 0); //[table2, table1]
    lua_pushliteral(L,"__index"); //["__index", table2, table1]
    lua_pushvalue(L, -2); //[table2, "__index", table2, table1]
    lua_settable(L,-3); //[table2, table1]

    luaL_newlib(L, LibFuncs); //[table3, table2, table1]
    lua_pushliteral(L, "__clientmt"); //["__clientmt", table3, table2, table1]
    lua_pushvalue(L, -4); //[table1, "__clientmt", table3, table2, table1]
    lua_settable(L,-3); //[table3, table2, table1]
    lua_pushliteral(L, "__playablemt"); //["__playablemt", table3, table2, table1]
    lua_pushvalue(L, -3); //[table2, "__clientmt", table3, table2, table1]
    lua_settable(L,-3); //[table3, table2, table1]
    lua_pushliteral(L, "version");
    lua_pushliteral(L, MYVERSION);
    lua_settable(L,-3);
    lua_remove(L, 1);
    lua_remove(L, 1);
    return 1;
}