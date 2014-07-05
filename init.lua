--[============================================================================[
   REPL: A REPL for Lua (with support for Torch objects).

   This REPL is embeddable, and doesn't depend on C libraries.
   It's usable with Torch, and with MOAI.

   For full completion support, and history, install lua-linenoise:
   $ luarocks install linenoise

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

-- Colors:
local colors = {
   none = '\27[0m',
   black = '\27[0;30m',
   red = '\27[0;31m',
   green = '\27[0;32m',
   yellow = '\27[0;33m',
   blue = '\27[0;34m',
   magenta = '\27[0;35m',
   cyan = '\27[0;36m',
   white = '\27[0;37m',
   Black = '\27[1;30m',
   Red = '\27[1;31m',
   Green = '\27[1;32m',
   Yellow = '\27[1;33m',
   Blue = '\27[1;34m',
   Magenta = '\27[1;35m',
   Cyan = '\27[1;36m',
   White = '\27[1;37m',
   _black = '\27[40m',
   _red = '\27[41m',
   _green = '\27[42m',
   _yellow = '\27[43m',
   _blue = '\27[44m',
   _magenta = '\27[45m',
   _cyan = '\27[46m',
   _white = '\27[47m'
}

-- Apply:
local c
if true then
   c = function(color, txt)
      return colors[color] .. txt .. colors.none
   end
else
   c = function(color,txt) return txt end
end

-- If no Torch:
if not torch then
   torch = {
      typename = function() return '' end
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
      tp = tp .. ' - size: ' .. #val
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
   local apply = c
   
   -- Type?
   if object == nil then
      return apply('Black', 'nil')
   elseif type(object) == 'number' then
      return apply('cyan', tostring(object))
   elseif type(object) == 'boolean' then
      return apply('blue', tostring(object))
   elseif type(object) == 'string' then
      if nested then
         return apply('Black','"')..apply('green', object)..apply('Black','"')
      else
         return apply('none', object)
      end
   elseif type(object) == 'function' then
      return apply('magenta', tostring(object))
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
         return apply('red', tp)
      else
         return apply('red', tostring(object))
      end
   elseif type(object) == 'table' then
      return apply('green', tostring(object))
   else
      return apply('_black', tostring(object))
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
      line('{')
      tab = tab+2
      for k,v in pairs(obj) do
         if type(v) == 'table' then
            if depth >= (ndepth-1) or next(v) == nil then
               line(tostring(k) .. ' : ' .. colorize(v,true))
            else
               line(tostring(k) .. ' : ') printrecursive(v,depth+1)
            end
         else
            line(tostring(k) .. ' : ' .. colorize(v,true))
         end
      end
      tab = tab-2
      line('}')
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
         --printrecursive(obj)
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
      if path.exists(file) then
         dir = path.dirname(file)
      end
      local pkgpath = path.join(dir,name)
      if path.isfile(pkgpath..'.lua') then
         return dofile(pkgpath..'.lua')
      elseif path.isfile(pkgpath) then
         return dofile(pkgpath)
      elseif path.isfile(pkgpath..'.so') then
         return package.loadlib(pkgpath..'.so', 'luaopen_'..path.basename(name))()
      elseif path.isfile(pkgpath..'.dylib') then
         return package.loadlib(pkgpath..'.dylib', 'luaopen_'..path.basename(name))()
      else
         local initpath = path.join(pkgpath,'init.lua')
         return dofile(initpath)
      end
   else
      return drequire(name)
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
               cb(key)
            else
               local file = debug.getinfo(2).source:gsub('^@','')
               local line = debug.getinfo(2).currentline
               if line > 0 then
                  print(colors.red .. 'created global variable: ' 
                     .. colors.blue .. key .. colors.none
                     .. ' @ ' .. colors.magenta .. file .. colors.none 
                     .. ':' .. colors.green .. line .. colors.none
                  )
               else
                  print(colors.red .. 'created global variable: ' 
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
         error(colors.red .. "attempt to read undeclared variable " .. colors.blue .. key .. colors.none, 2)
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
      s = '> '
   else
      s = '>> '
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

-- Penlight
pcall(require,'pl')

-- Reults:
_RESULTS = {}
_LAST = ''

-- Readline:
local readline_ok,readline = pcall(require,"trepl.readline")

-- REPL:
function repl_readline()
   -- Completer:
   local completer = require 'trepl.completer'
   completer.final_char_setter = readline.completion_append_character

   local inputrc = paths.concat(os.getenv('HOME'),'.inputrc')
   if not paths.filep(inputrc) then
      local finputrc = io.open(inputrc,'w')
      local trepl =
[[
$if TREPL
   # filter up and down arrows using characters typed so far
   "\e[A":history-search-backward
   "\e[B":history-search-forward
$endif
]]
      finputrc:write(trepl)
      finputrc:close()
   end

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
         print(c('Black',string.format('[%0.04fs]', step)))
      end
   else
      timer_start = function() end
      timer_stop = function() end
   end
   
   -- History:
   local history = os.getenv('HOME') .. '/.luahistory'

   -- Readline callback:
   readline.shell{
      -- History:
      history = history,

      -- Completer:
      complete = completer.complete,

      -- Chars:
      word_break_characters = " \t\n\"\\'><=;:+-*/%^~#{}()[].,",

      -- Get command:
      getcommand = function()
         -- get the first line
         local line = coroutine.yield(prompt())
         local cmd = line .. '\n'

         -- = (lua supports that)
         if cmd:sub(1,1) == "=" then
            cmd = "return "..cmd:sub(2)
         end
      
         -- Interupt?
         if line == 'exit' then
            io.stdout:write('Do you really want to exit ([y]/n)? ') io.flush()
            local line = io.read('*l')
            if line == '' or line:lower() == 'y' then
               os.exit()
            end
         end
      
         -- OS Commands:
         if line and line:find('^%s-%$') then
            local cline = line:gsub('^%s-%$','')
            if io.popen then
               local f = io.popen(aliases .. ' ' .. cline)
               local res = f:read('*a')
               f:close()
               io.write(c('none',res)) io.flush()
               table.insert(_RESULTS, res)
               _LAST = _RESULTS[#_RESULTS]
            else
               os.execute(aliases .. ' ' .. cline)
            end
            timer_stop()
            return line
         end
         
         -- Shortcut to get help:
         if line and line:find('^%s-?') then
            local ok = pcall(require,'dok')
            if ok then
               line = 'help(' .. line:gsub('^%s-?','') .. ')'
            else
               print('error: could not load help backend')
               return line
            end
         end

         -- try to return first:
         timer_start()
         local pok,ok,err
         if line:find(';%s-$') or line:find('^%s-print') then
            ok = false
         elseif line:match('^%s*$') then
            return nil
         else
            local func, perr = loadstring('local f = function() return '..line..' end local res = {f()} print(unpack(res)) table.insert(_RESULTS,res[1])')
            if func then
               pok = true
               ok,err = xpcall(func, traceback)
            end
         end

         -- run ok:
         if ok then 
            _LAST = _RESULTS[#_RESULTS]
            timer_stop()
            return line 
         end

         -- parsed ok, but failed to run (code error):
         if pok then
            print(err)
            return cmd:sub(1, -2)
         end

         -- continue to get lines until get a complete chunk
         local func, err
         while true do
            -- if not go ahead:
            func, err = loadstring(cmd)
            if func or err:sub(-7) ~= "'<eof>'" then break end

            -- concat:
            cmd = cmd .. coroutine.yield(prompt(true)) .. '\n'
         end

         -- exec chunk:
         if not cmd:match("^%s*$") then
            local ff,err=loadstring(cmd)
            if not ff then
               print(err)
               return cmd:sub(1, -2)
            end
            local res = {xpcall(ff, traceback)}
            local ok,err = res[1], res[2]
            if not ok then
               print(err)
            else
               if err ~= nil then
                  table.remove(res,1)
                  print(unpack(res))
               end
            end
            timer_stop()
            return cmd:sub(1, -2) -- remove last \n for history
         end
      end,
   }
   io.stderr:write"\n"
end

-- No readline -> LineNoise?
local nextline
if not readline_ok then
   -- Load linenoise:
   local ok,L = pcall(require,'linenoise')
   if not ok then
      -- No readline, no linenoise... default to plain io:
      nextline = function()
         io.write(prompt()) io.flush()
         return io.read('*line')
      end
   else
      -- History:
      local history = os.getenv('HOME') .. '/.luahistory'
      L.historyload(history)

      -- Completion:
      L.setcompletion(function(c,s)
         -- Check if we're in a string
         local ignore,str = s:gfind('(.-)"([a-zA-Z%._]*)$')()
         local quote = '"'
         if not str then
            ignore,str = s:gfind('(.-)\'([a-zA-Z%._]*)$')()
            quote = "'"
         end

         -- String?
         if str then
            -- Complete from disk:
            local f = io.popen('ls ' .. str..'* 2> /dev/null')
            local res = f:read('*all')
            f:close()
            res = res:gsub('(%s*)$','')
            local elts = stringx.split(res,'\n')
            for _,elt in ipairs(elts) do
               L.addcompletion(c,ignore .. quote .. elt)
            end
            return
         end

         -- Get symbol of interest
         local ignore,str = s:gfind('(.-)([a-zA-Z%._]*)$')()

         -- Lookup globals:
         if not str:find('%.') then
            for k,v in pairs(_G) do
               if k:find('^'..str) then
                  L.addcompletion(c,ignore .. k)
               end
            end
         end

         -- Lookup packages:
         local base,sub = str:gfind('(.*)%.(.*)')()
         if base then
            local ok,res = pcall(loadstring('return ' .. base))
            for k,v in pairs(res) do
               if k:find('^'..sub) then
                  L.addcompletion(c,ignore .. base .. '.' .. k)
               end
            end
         end
      end)

      -- read line:
      nextline = function()
         -- Get line:
         local line = L.linenoise(prompt())

         -- Save:
         if line and not line:find('^%s-$') then
            L.historyadd(line)
            L.historysave(history)
         end

         -- Return line:
         return line
      end
   end
end

-- The default repl
function repl_linenoise()
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
         print(c('Black',string.format('[%0.04fs]', step)))
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
         if line == '' or line:lower() == 'y' then
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
            io.write(c('_black',res)) io.flush()
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
         local ok = pcall(require,'dok')
         if ok then
            line = 'help(' .. line:gsub('^%s-?','') .. ')'
         else
            print('error: could not load help backend')
            line = nil
         end
      end

      -- EVAL:
      if line then
         timer_start()
         local ok,err
         if line:find(';%s-$') or line:find('^%s-print') then
            ok = false
         else
            ok,err = xpcall(loadstring('local f = function() return '..line..' end local res = {f()} print(unpack(res)) table.insert(_RESULTS,res[1])'), traceback)
         end
         if not ok then
            local ok,err = xpcall(loadstring(line), traceback)
            if not ok then
               print(err)
            end
         end
         timer_stop()
      end

      -- Last result:
      _LAST = _RESULTS[#_RESULTS]
   end
end

-- Store preloaded symbols, for who()
_G._preloaded_ = {}
for k,v in pairs(_G) do
   _G._preloaded_[k] = true
end

-- return repl, just call it to start it!
return (readline_ok and repl_readline) or repl_linenoise
