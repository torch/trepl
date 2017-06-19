--[============================================================================[
   REPL: A REPL for Lua (with support for Torch objects).

   This REPL is embeddable, and doesn't depend on C libraries.
   If readline.so is built and found at runtime, then tab-completion is enabled.

   Support for SHELL commands:
   > $ ls
   > $ ll
   > $ ls -l
   (prepend any command by $, from the Lua interpreter)

   Copyright: MIT / BSD / Do whatever you want with it.
   Clement Farabet, 2013
--]============================================================================]

-- Require Torch
pcall(require,'torch')
pcall(require,'paths')
pcall(require,'sys')
pcall(require,'xlua')
local dok_loaded_ok = pcall(require,'dok')


-- Colors:
local colors = require 'trepl.colors'
local col = require 'trepl.colorize'

-- Lua 5.2 compatibility
local loadstring = loadstring or load
local unpack = unpack or table.unpack

-- Kill colors:
function noColors()
   for k,v in pairs(colors) do
      colors[k] = ''
   end
end

local cutils = require 'treplutils'

-- best effort isWindows. Not robust
local function isWindows()
   return type(package) == 'table' and
      type(package.config) == 'string' and
      package.config:sub(1,1) == '\\'
end

local hasTPut = true -- default true for non windows
if isWindows() then
  hasTPut = sys.fexecute('where tput'):find('tput')
end

if not hasTPut or not cutils.isatty() then
   noColors()
else
   local outp = os.execute('tput colors >' .. (isWindows() and 'NUL' or '/dev/null'))
   if type(outp) == 'boolean' and not outp then
      noColors()
   elseif type(outp) == 'number' and outp ~= 0 then
      noColors()
   end
end

-- Help string:
local selfhelp =  [[
  ______             __
 /_  __/__  ________/ /
  / / / _ \/ __/ __/ _ \
 /_/  \___/_/  \__/_//_/

]]..col.red('th')..[[ is an enhanced interpreter (repl) for Torch7/Lua.

]]..col.blue('Features:')..[[ 

   Tab-completion on nested namespaces
   Tab-completion on disk files (when opening a string)
   History stored in:

      ]]..col.magenta("_RESULTS")..[[ 
      ]]..col.magenta("_LAST")..[[ 

   Pretty print (table introspection and coloring)
   Auto-print after eval (no need for '='), can be stopped with ]]..col.magenta(";")..[[ 
   Each command is profiled, timing is reported
   Easy help on functions/packages:

      ]]..col.magenta("? torch.randn")..[[ 

   Documentation browsable with:

      ]]..col.magenta("browse()")..[[ 
      ]]..col.magenta("browse(package)")..[[ 

   Shell commands with:

      ]]..col.magenta("$ ls -l")..[[ 

   and the string result can be retrieved with:

      ]]..col.magenta("_LAST")..[[ 

   Print all user globals with:

      ]]..col.magenta("who()")..[[ 

   Clear screen with:

      ]]..col.magenta("<Ctrl> L")..[[ 

   Quit Torch7 with:

      ]]..col.magenta("<Ctrl> D")..[[ 

   Import a package's symbols globally with:

      ]]..col.magenta("import 'torch'")..[[ 

   Require is overloaded to provide relative (form within a file) search paths:

      ]]..col.magenta("require './local/lib' ")..[[ 

   Optional strict global namespace monitoring:

      ]]..col.magenta('th -g')..[[ 

   Optional async repl (based on https://github.com/clementfarabet/async):

      ]]..col.magenta('th -a')..[[ 

   Using colors:

      ]]..col.magenta("c = require 'trepl.colorize'")..[[ 
      print(c.red(]]..col.red("'a red string'")..[[) .. c.blue(]]..col.blue("'a blue string'")..[[))
]]

-- If no Torch:
if not torch then
   torch = {
      typename = function() return '' end,
      setheaptracking = function() end
   }
end

-- helper
local function sizestr(x)
   local strt = {}
   if _G.torch.typename(x):find('torch.*Storage') then
      return _G.torch.typename(x):match('torch%.(.+)') .. ' - size: ' .. x:size()
   end
   if x:nDimension() == 0 then
      table.insert(strt, _G.torch.typename(x):match('torch%.(.+)') .. ' - empty')
   else
      table.insert(strt, _G.torch.typename(x):match('torch%.(.+)') .. ' - size: ')
      for i=1,x:nDimension() do
         table.insert(strt, x:size(i))
         if i ~= x:nDimension() then
            table.insert(strt, 'x')
         end
      end
   end
   return table.concat(strt)
end

-- k : name of variable
-- m : max length
local function printvar(key,val,m)
   local name = '[' .. tostring(key) .. ']'
   --io.write(name)
   name = name .. string.rep(' ',m-name:len()+2)
   local tp = type(val)
   if tp == 'userdata' then
      tp = torch.typename(val) or ''
      if tp:find('torch.*Tensor') then
         tp = sizestr(val)
      elseif tp:find('torch.*Storage') then
         tp = sizestr(val)
      else
         tp = tostring(val)
      end
   elseif tp == 'table' then
      if torch.type(val) == 'table' then
	 tp = tp .. ' - size: ' .. #val
      else
	 tp = torch.type(val)
      end
   elseif tp == 'string' then
      local tostr = val:gsub('\n','\\n')
      if #tostr>40 then
         tostr = tostr:sub(1,40) .. '...'
      end
      tp = tp .. ' : "' .. tostr .. '"'
   else
      tp = tostring(val)
   end
   return name .. ' = ' .. tp
end

-- helper
local function getmaxlen(vars)
   local m = 0
   if type(vars) ~= 'table' then return tostring(vars):len() end
   for k,v in pairs(vars) do
      local s = tostring(k)
      if s:len() > m then
         m = s:len()
      end
   end
   return m
end

-- overload print:
if not print_old then
   print_old=print
end

-- a function to colorize output:
local function colorize(object,nested)
   -- Apply:
   local apply = col

   -- Type?
   if object == nil then
      return apply['Black']('nil')
   elseif type(object) == 'number' then
      return apply['cyan'](tostring(object))
   elseif type(object) == 'boolean' then
      return apply['blue'](tostring(object))
   elseif type(object) == 'string' then
      if nested then
         return apply['Black']('"')..apply['green'](object)..apply['Black']('"')
      else
         return apply['none'](object)
      end
   elseif type(object) == 'function' then
      return apply['magenta'](tostring(object))
   elseif type(object) == 'userdata' or type(object) == 'cdata' then
      local tp = torch.typename(object) or ''
      if tp:find('torch.*Tensor') then
         tp = sizestr(object)
      elseif tp:find('torch.*Storage') then
         tp = sizestr(object)
      else
         tp = tostring(object)
      end
      if tp ~= '' then
         return apply['red'](tp)
      else
         return apply['red'](tostring(object))
      end
   elseif type(object) == 'table' then
      return apply['green'](tostring(object))
   else
      return apply['_black'](tostring(object))
   end
end

-- This is a new recursive, colored print.
local ndepth = 4
function print_new(...)
   local function rawprint(o)
      io.write(tostring(o or '') .. '\n')
      io.flush()
   end
   local objs = {...}
   local function printrecursive(obj,depth)
      local depth = depth or 0
      local tab = depth*4
      local line = function(s) for i=1,tab do io.write(' ') end rawprint(s) end
      if next(obj) then
         line('{')
         tab = tab+2
         for k,v in pairs(obj) do
            if type(v) == 'table' then
               if depth >= (ndepth-1) or next(v) == nil then
                  line(tostring(k) .. ' : {...}')
               else
                  line(tostring(k) .. ' : ') printrecursive(v,depth+1)
               end
            else
               line(tostring(k) .. ' : ' .. colorize(v,true))
            end
         end
         tab = tab-2
         line('}')
      else
         line('{}')
      end
   end
   for i = 1,select('#',...) do
      local obj = select(i,...)
      if type(obj) ~= 'table' then
         if type(obj) == 'userdata' or type(obj) == 'cdata' then
            rawprint(obj)
         else
            io.write(colorize(obj) .. '\t')
            if i == select('#',...) then
               rawprint()
            end
         end
      elseif getmetatable(obj) and getmetatable(obj).__tostring then
         rawprint(obj)
      else
         printrecursive(obj)
      end
   end
end


function setprintlevel(n)
  if n == nil or n < 0 then
    error('expected number [0,+)')
  end
  n = math.floor(n)
  ndepth = n
  if ndepth == 0 then
    print = print_old
  else
    print = print_new
  end
end
setprintlevel(5)

-- Import, ala Python
function import(package, forced)
   local ret = require(package)
   local symbols = {}
   if _G[package] then
      _G._torchimport = _G._torchimport or {}
      _G._torchimport[package] = _G[package]
      symbols = _G[package]
   elseif ret and type(ret) == 'table' then
      _G._torchimport = _G._torchimport or {}
      _G._torchimport[package] = ret
      symbols = ret
   end
   for k,v in pairs(symbols) do
      if not _G[k] or forced then
         _G[k] = v
      end
   end
end

-- Smarter require (ala Node.js)
local drequire = require
function require(name)
   if name:find('^%.') then
      local file = debug.getinfo(2).source:gsub('^@','')
      local dir = '.'
      if paths.filep(file) then
         dir = paths.dirname(file)
      end
      local pkgpath = paths.concat(dir,name)
      if paths.filep(pkgpath..'.lua') then
         return dofile(pkgpath..'.lua')
      elseif pkgpath:find('%.th$') and paths.filep(pkgpath) then
         return torch.load(pkgpath)
      elseif pkgpath:find('%.net$') and paths.filep(pkgpath) then
         require 'nn'
         return torch.load(pkgpath)
      elseif pkgpath:find('%.json$') and paths.filep(pkgpath) then
         return require('cjson').decode(io.open(pkgpath):read('*all'))
      elseif pkgpath:find('%.csv$') and paths.filep(pkgpath) then
         return require('csv').load(pkgpath)
      elseif paths.filep(pkgpath) then
         return dofile(pkgpath)
      elseif paths.filep(pkgpath..'.th') then
         return torch.load(pkgpath..'.th')
      elseif paths.filep(pkgpath..'.net') then
         require 'nn'
         return torch.load(pkgpath..'.net')
      elseif paths.filep(pkgpath..'.json') then
         return require('cjson').decode(io.open(pkgpath..'.json'):read('*all'))
      elseif paths.filep(pkgpath..'.csv') then
         return require('csv').load(pkgpath..'.csv')
      elseif paths.filep(pkgpath..'.so') then
         return package.loadlib(pkgpath..'.so', 'luaopen_'..path.basename(name))()
      elseif paths.filep(pkgpath..'.dylib') then
         return package.loadlib(pkgpath..'.dylib', 'luaopen_'..path.basename(name))()
      else
         local initpath = paths.concat(pkgpath,'init.lua')
         return dofile(initpath)
      end
   else
      local ok,res = pcall(drequire,name)
      if not ok then
         local ok2,res2 = pcall(require,'./'..name)
         if not ok2 then
            error(res)
         end
         return res2
      end
      return res
   end
end

-- Who
-- a simple function that prints all the symbols defined by the user
-- very much like Matlab's who function
function who(system)
   local m = getmaxlen(_G)
   local p = _G._preloaded_
   local function printsymb(sys)
      for k,v in pairs(_G) do
         if (sys and p[k]) or (not sys and not p[k]) then
            print(printvar(k,_G[k],m))
         end
      end
   end
   if system then
      print('== System Variables ==')
      printsymb(true)
   end
   print('== User Variables ==')
   printsymb(false)
   print('==')
end

-- Monitor Globals
function monitor_G(cb)
   -- user CB or strict mode
   local strict
   if type(cb) == 'boolean' then
      strict = true
      cb = nil
   end

   -- Force load of penlight packages:
   stringx = require 'pl.stringx'
   tablex = require 'pl.tablex'
   path = require 'pl.path'
   dir = require 'pl.dir'
   text = require 'pl.text'

   -- Store current globals:
   local evercreated = {}
   for k in pairs(_G) do
      evercreated[k] = true
   end

   -- Overwrite global namespace meta tables to monitor it:
   setmetatable(_G, {
      __newindex = function(G,key,val)
         if not evercreated[key] then
            if cb then
               cb(key,'newindex')
            else
               local file = debug.getinfo(2).source:gsub('^@','')
               local line = debug.getinfo(2).currentline
               local report = print
               if strict then
                  report = error
               end
               if line > 0 then
                  report(colors.red .. 'created global variable: '
                     .. colors.blue .. key .. colors.none
                     .. ' @ ' .. colors.magenta .. file .. colors.none
                     .. ':' .. colors.green .. line .. colors.none
                  )
               else
                  report(colors.red .. 'created global variable: '
                     .. colors.blue .. key .. colors.none
                     .. ' @ ' .. colors.yellow .. '[C-module]' .. colors.none
                  )
               end
            end
         end
         evercreated[key] = true
         rawset(G,key,val)
      end,
      __index = function (table, key)
         if cb then
            cb(key,'index')
         else
            local file = debug.getinfo(2).source:gsub('^@','')
            local line = debug.getinfo(2).currentline
            local report = print
            if strict then
               report = error
            end
            if line > 0 then
               report(colors.red .. 'attempt to read undeclared variable: '
                  .. colors.blue .. key .. colors.none
                  .. ' @ ' .. colors.magenta .. file .. colors.none
                  .. ':' .. colors.green .. line .. colors.none
               )
            else
               report(colors.red .. 'attempt to read undeclared variable: '
                  .. colors.blue .. key .. colors.none
                  .. ' @ ' .. colors.yellow .. '[C-module]' .. colors.none
               )
            end
         end
      end,
   })
end

-- Tracekback (error printout)
local function traceback(message)
   local tp = type(message)
   if tp ~= "string" and tp ~= "number" then return message end
   local debug = _G.debug
   if type(debug) ~= "table" then return message end
   local tb = debug.traceback
   if type(tb) ~= "function" then return message end
   return tb(message)
end

-- Prompt:
local function prompt(aux)
   local s
   if not aux then
      s = 'th> '
   else
      s = '..> '
   end
   return s
end

-- Aliases:
local aliases = [[
   alias ls='ls -GF';
   alias ll='ls -lhF';
   alias la='ls -ahF';
   alias lla='ls -lahF';
]]

if isWindows() then
   aliases = ""
end

-- Penlight
pcall(require,'pl')

-- Useful globally, from penlight
if text then
   text.format_operator()
end

-- Reults:
_RESULTS = {}
_LAST = ''

-- Readline:
local readline_ok,readline = pcall(require,'readline')
local nextline,saveline
if readline_ok and (os.getenv('TREPL_HISTORY') or os.getenv('HOME') or os.getenv('USERPROFILE')) ~= nil then
   -- Readline found:
   local history = os.getenv('TREPL_HISTORY') or ((os.getenv('HOME') or os.getenv('USERPROFILE')) .. '/.luahistory')
   readline.setup()
   readline.read_history(history)
   nextline = function(aux)
      return readline.readline(prompt(aux))
   end
   saveline = function(line)
      readline.add_history(line)
      readline.write_history(history)
   end
else
   -- No readline... default to plain io:
   nextline = function(aux)
      io.write(prompt(aux)) io.flush()
      return io.read('*line')
   end
   saveline = function() end
end

-- The repl
function repl()
   -- Timer
   local timer_start, timer_stop
   if torch and torch.Timer then
      local t = torch.Timer()
      local start = 0
      timer_start = function()
         start = t:time().real
      end
      timer_stop = function()
         local step = t:time().real - start
         for i = 1,70 do io.write(' ') end
         print(col.Black(string.format('[%0.04fs]', step)))
      end
   else
      timer_start = function() end
      timer_stop = function() end
   end

   -- REPL:
   while true do
      -- READ:
      local line = nextline()

      -- Interupt?
      if not line or line == 'exit' then
         io.write('Do you really want to exit ([y]/n)? ') io.flush()
         local line = io.read('*l')
         if not line or line == '' or line:lower() == 'y' then
            if not line then print('') end
            os.exit()
         end
      end
      if line == 'break' then
         break
      end

      -- OS Commands:
      if line and line:find('^%s-%$') then
         line = line:gsub('^%s-%$','')
         if io.popen then
            local f = io.popen(aliases .. ' ' .. line)
            local res = f:read('*a')
            f:close()
            io.write(col._black(res)) io.flush()
            table.insert(_RESULTS, res)
         else
            os.execute(aliases .. ' ' .. line)
         end
         line = nil
      end

      -- Support the crappy '=', as Lua does:
      if line and line:find('^%s-=') then
         line = line:gsub('^%s-=','')
      end

      -- Shortcut to get help:
      if line and line:find('^%s-?') then
	 if line:gsub('^%s-?','') == '' then
	    print(selfhelp)
	    line = nil
	 elseif dok_loaded_ok then
            line = 'help(' .. line:gsub('^%s-?','') .. ')'
         else
            print('error: could not load help backend')
            line = nil
         end
      end

      -- EVAL:
      if line then
         -- Try to load line first, for multiline support:
         local valid = loadstring('return ' .. line) or loadstring(line)
         while not valid do
            local nline = nextline(true)
            if nline == '' or not nline then
               break
            end
            line = line .. '\n' .. nline
            valid = loadstring(line)
         end

         -- Execute, first by trying to auto return result:
         timer_start()
         local done = false
         local err
         if not (line:find(';%s-$') or line:find('^%s-print')) then
            -- Try to compile statement with "return", to auto-print
            local parsed = loadstring('local f = function() return '..line..' end')
            if parsed then
               local parsed = loadstring('_RESULT={'..line..'}')
               local ok,err=xpcall(parsed, traceback)
               if ok then
                  print(unpack(_RESULT))
                  table.insert(_RESULTS,_RESULT[1])
               else
                  print(err)
               end
               done = true
            end
         end

         -- If not done executing, execute normally:
         if not done then
            -- We only get here if statement could not be printed/returned
            local parsed,perr = loadstring(line)
            if not parsed then
               print('syntax error: ' .. perr)
            else
               local ok,err = xpcall(parsed, traceback)
               if not ok then
                  print(err)
               end
            end
         end
         timer_stop()
      end

      -- Last result:
      _LAST = _RESULTS[#_RESULTS]

      -- Save:
      saveline(line)
   end
end

-- Store preloaded symbols, for who()
_G._preloaded_ = {}
for k,v in pairs(_G) do
   _G._preloaded_[k] = true
end

-- Enable heap tracking
torch.setheaptracking(true)

-- return repl, just call it to start it!
return repl
