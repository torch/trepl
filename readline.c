// Bindings to readline
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#ifndef WinEditLine
#include <readline/readline.h>
#include <readline/history.h>
#else
#include <editline/readline.h>
#endif
#include <ctype.h>

#if LUA_VERSION_NUM == 501
# define lua_pushglobaltable(L) lua_pushvalue(L, LUA_GLOBALSINDEX)
# define luaL_setfuncs(L, libs, _) luaL_register(L, NULL, libs)
#else
# define lua_strlen lua_rawlen
#endif

/*
** Lua 5.1.4 advanced readline support for the GNU readline and history
** libraries or compatible replacements.
**
** Author: Mike Pall.
** Maintainer: Sean Bolton (sean at smbolton dot com).
**
** Copyright (C) 2004-2006, 2011 Mike Pall. Same license as Lua. See lua.h.
**
** Advanced features:
** - Completion of keywords and global variable names.
** - Recursive and metatable-aware completion of variable names.
** - Context sensitive delimiter completion.
** - Save/restore of the history to/from a file (LUA_HISTORY env variable).
** - Setting a limit for the size of the history (LUA_HISTSIZE env variable).
** - Setting the app name to allow for $if lua ... $endif in ~/.inputrc.
**
** Start lua and try these (replace ~ with the TAB key):
**
** ~~
** fu~foo() ret~fa~end<CR>
** io~~~s~~~o~~~w~"foo\n")<CR>
**
** The ~~ are just for demonstration purposes (io~s~o~w~ suffices, of course).
**
** If you are used to zsh/tcsh-style completion support, try adding
** 'TAB: menu-complete' and 'C-d: possible-completions' to your ~/.inputrc.
**
** The patch has been successfully tested with:
**
** GNU    readline 2.2.1  (1998-07-17)
** GNU    readline 4.0    (1999-02-18) [harmless compiler warning]
** GNU    readline 4.3    (2002-07-16)
** GNU    readline 5.0    (2004-07-27)
** GNU    readline 5.1    (2005-12-07)
** GNU    readline 5.2    (2006-10-11)
** GNU    readline 6.0    (2009-02-20)
** GNU    readline 6.2    (2011-02-13)
** MacOSX libedit  2.11   (2008-07-12)
** NETBSD libedit  2.6.5  (2002-03-25)
** NETBSD libedit  2.6.9  (2004-05-01)
**
** Change Log:
** 2004-2006  Mike Pall   - original patch
** 2009/08/24 Sean Bolton - updated for GNU readline version 6
** 2011/12/14 Sean Bolton - fixed segfault when using Mac OS X libedit 2.11
*/

static char *lua_rl_hist;
static int lua_rl_histsize;

static lua_State *lua_rl_L;  /* User data is not passed to rl callbacks. */

/* Reserved keywords. */
static const char *const lua_rl_keywords[] = {
  "and", "break", "do", "else", "elseif", "end", "false",
  "for", "function", "if", "in", "local", "nil", "not", "or",
  "repeat", "return", "then", "true", "until", "while", NULL
};

static int valididentifier(const char *s)
{
  if (!(isalpha(*s) || *s == '_')) return 0;
  for (s++; *s; s++) if (!(isalpha(*s) || isdigit(*s) || *s == '_')) return 0;
  return 1;
}

/* Dynamically resizable match list. */
typedef struct {
  char **list;
  size_t idx, allocated, matchlen;
} dmlist;

/* Add prefix + string + suffix to list and compute common prefix. */
static int lua_rl_dmadd(dmlist *ml, const char *p, size_t pn, const char *s,
      int suf)
{
  char *t = NULL;

  if (ml->idx+1 >= ml->allocated &&
      !(ml->list = realloc(ml->list, sizeof(char *)*(ml->allocated += 32))))
    return -1;

  if (s) {
    size_t n = strlen(s);
    if (!(t = (char *)malloc(sizeof(char)*(pn+n+(suf?2:1))))) return 1;
    memcpy(t, p, pn);
    memcpy(t+pn, s, n);
    n += pn;
    t[n] = suf;
    if (suf) t[++n] = '\0';

    if (ml->idx == 0) {
      ml->matchlen = n;
    } else {
      size_t i;
      for (i = 0; i < ml->matchlen && i < n && ml->list[1][i] == t[i]; i++) ;
      ml->matchlen = i;  /* Set matchlen to common prefix. */
    }
  }

  ml->list[++ml->idx] = t;
  return 0;
}

/* Get __index field of metatable of object on top of stack. */
static int lua_rl_getmetaindex(lua_State *L)
{
  if (!lua_getmetatable(L, -1)) { lua_pop(L, 1); return 0; }

  /* prefer __metatable if it exists */
  lua_pushstring(L, "__metatable");
  lua_rawget(L, -2);
  if(lua_istable(L, -1))
  {
    lua_remove(L, -2);
    return 1;
  }
  else
    lua_pop(L, 1);

  lua_pushstring(L, "__index");
  lua_rawget(L, -2);
  lua_replace(L, -2);
  if (lua_isnil(L, -1) || lua_rawequal(L, -1, -2)) { lua_pop(L, 2); return 0; }
  lua_replace(L, -2);
  return 1;
}  /* 1: obj -- val, 0: obj -- */

/* Get field from object on top of stack. Avoid calling metamethods. */
static int lua_rl_getfield(lua_State *L, const char *s, size_t n)
{
  int i = 20;  /* Avoid infinite metatable loops. */
  do {
    if (lua_istable(L, -1)) {
      lua_pushlstring(L, s, n);
      lua_rawget(L, -2);
      if (!lua_isnil(L, -1)) { lua_replace(L, -2); return 1; }
      lua_pop(L, 1);
    }
  } while (--i > 0 && lua_rl_getmetaindex(L));
  lua_pop(L, 1);
  return 0;
}  /* 1: obj -- val, 0: obj -- */

static int lua_rl_isglobaltable(lua_State *L, int idx)
{
#if LUA_VERSION_NUM == 501
  return lua_rawequal(L, idx, LUA_GLOBALSINDEX);
#else
  idx = lua_absindex(L, idx);
  lua_pushglobaltable(L);
  int same = lua_rawequal(L, idx, -1);
  lua_pop(L, 1);
  return same;
#endif
}

/* Completion callback. */
static char **lua_rl_complete(const char *text, int start, int end)
{
  lua_State *L = lua_rl_L;
  dmlist ml;
  const char *s;
  size_t i, n, dot, loop;
  int savetop;

  if (!(text[0] == '\0' || isalpha(text[0]) || text[0] == '_')) return NULL;

  ml.list = NULL;
  ml.idx = ml.allocated = ml.matchlen = 0;

  savetop = lua_gettop(L);
  lua_pushglobaltable(L);
  for (n = (size_t)(end-start), i = dot = 0; i < n; i++)
    if (text[i] == '.' || text[i] == ':') {
      if (!lua_rl_getfield(L, text+dot, i-dot))
  goto error;  /* Invalid prefix. */
      dot = i+1;  /* Points to first char after dot/colon. */
    }

  /* Add all matches against keywords if there is no dot/colon. */
  if (dot == 0)
    for (i = 0; (s = lua_rl_keywords[i]) != NULL; i++)
      if (!strncmp(s, text, n) && lua_rl_dmadd(&ml, NULL, 0, s, ' '))
  goto error;

  /* Add all valid matches from all tables/metatables. */
  loop = 0;  /* Avoid infinite metatable loops. */
  do {
    if (lua_istable(L, -1) &&
  (loop == 0 || !lua_rl_isglobaltable(L, -1)))
      for (lua_pushnil(L); lua_next(L, -2); lua_pop(L, 1))
  if (lua_type(L, -2) == LUA_TSTRING) {
    s = lua_tostring(L, -2);
    /* Only match names starting with '_' if explicitly requested. */
    if (!strncmp(s, text+dot, n-dot) && valididentifier(s) &&
        (*s != '_' || text[dot] == '_')) {
      int suf = ' ';  /* Default suffix is a space. */
      switch (lua_type(L, -1)) {
      case LUA_TTABLE:  suf = '.'; break;  /* No way to guess ':'. */
      case LUA_TFUNCTION: suf = '('; break;
      case LUA_TUSERDATA:
        if (lua_getmetatable(L, -1)) { lua_pop(L, 1); suf = ':'; }
        break;
      }
      if (lua_rl_dmadd(&ml, text, dot, s, suf)) goto error;
    }
  }
  } while (++loop < 20 && lua_rl_getmetaindex(L));

  if (ml.idx == 0) {
error:
    lua_settop(L, savetop);
    return NULL;
  } else {
    /* list[0] holds the common prefix of all matches (may be ""). */
    /* If there is only one match, list[0] and list[1] will be the same. */
    if (!(ml.list[0] = (char *)malloc(sizeof(char)*(ml.matchlen+1))))
      goto error;
    memcpy(ml.list[0], ml.list[1], ml.matchlen);
    ml.list[0][ml.matchlen] = '\0';
    /* Add the NULL list terminator. */
    if (lua_rl_dmadd(&ml, NULL, 0, NULL, 0)) goto error;
  }

  lua_settop(L, savetop);
#if RL_READLINE_VERSION >= 0x0600
  rl_completion_suppress_append = 1;
#endif
  return ml.list;
}

/* Initialize readline library. */
static int f_setup(lua_State *L)
{
  char *s;

  lua_rl_L = L;

  /* This allows for $if lua ... $endif in ~/.inputrc. */
  rl_readline_name = "lua";
  /* Break words at every non-identifier character except '.' and ':'. */
  rl_completer_word_break_characters =
    "\t\r\n !\"#$%&'()*+,-/;<=>?@[\\]^`{|}~";
#ifndef WinEditLine
  rl_completer_quote_characters = "\"'";
#endif
/* #if RL_READLINE_VERSION < 0x0600 */
  rl_completion_append_character = '\0';
/* #endif */
  rl_attempted_completion_function = lua_rl_complete;
#ifndef WinEditLine
  rl_initialize();
#endif

  return 0;
}

static int f_readline(lua_State* L)
{
  const char* prompt = lua_tostring(L,1);
  const char* line = readline(prompt);
  lua_pushstring(L,line);
  free((void *)line); // Lua makes a copy...
  return 1;
}

static int f_add_history(lua_State* L)
{
  if (lua_strlen(L,1) > 0)
    add_history(lua_tostring(L, 1));
  return 0;
}

static int f_write_history(lua_State* L)
{
  if (lua_strlen(L,1) > 0)
    write_history(lua_tostring(L, 1));
  return 0;
}

static int f_read_history(lua_State* L)
{
  if (lua_strlen(L,1) > 0)
    read_history(lua_tostring(L, 1));
  return 0;
}

static const struct luaL_Reg lib[] = {
  {"readline", f_readline},
  {"add_history",f_add_history},
  {"write_history",f_write_history},
  {"read_history",f_read_history},
  {"setup",f_setup},
  {NULL, NULL},
};

int luaopen_readline (lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, lib, 0);
  return 1;
}
