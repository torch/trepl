#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#if LUA_VERSION_NUM == 501
# define lua_pushglobaltable(L) lua_pushvalue(L, LUA_GLOBALSINDEX)
# define luaL_setfuncs(L, libs, _) luaL_register(L, NULL, libs)
#else
# define lua_strlen lua_rawlen
#endif

#if defined(_WIN32) || defined(LUA_WIN)

int treplutils_isatty(lua_State *L)
{
  lua_pushboolean(L, _isatty(1));
  return 1;
}

#else

#include <unistd.h>

int treplutils_isatty(lua_State *L)
{
  lua_pushboolean(L, isatty(1));
  return 1;
}

#endif

static const struct luaL_Reg utils[] = {
  {"isatty", treplutils_isatty},
  {NULL, NULL}
};

int luaopen_treplutils(lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, utils, 0);
  return 1;
}
