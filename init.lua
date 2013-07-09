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
local function colorize(object)
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
      return apply('yellow', object)
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
      return apply('black', tostring(object))
   end
end

-- This is a new recursive, colored print.
function print(...)
   local objs = {...}
   local function printrecursive(obj,tab)
      local tab = tab or 0
      local line = function(s) for i=1,tab do io.write(' ') end print_old(s) end
      line('{')
      tab = tab+2
      for k,v in pairs(obj) do
         if type(v) == 'table' then
            if tab > 16 or next(v) == nil then
               line(k .. ' : ' .. colorize(v))
            else
               line(k .. ' : ') printrecursive(v,tab+4)
            end
         else
            line(k .. ' : ' .. colorize(v))
         end
      end
      tab = tab-2
      line('}')
   end
   for i = 1,select('#',...) do
      local obj = select(i,...)
      if type(obj) ~= 'table' then
         if type(obj) == 'userdata' or type(obj) == 'cdata' then
            print_old(obj)
         else
            io.write(colorize(obj) .. '\t')
            if i == select('#',...) then
               print_old()
            end
         end
      elseif getmetatable(obj) and getmetatable(obj).__tostring then
         print_old(obj)
         printrecursive(obj)
      else
         printrecursive(obj) 
      end
   end
end

-- Tracekback (error printout)
local function traceback(message)
   local tp = type(message)
   if tp ~= "string" and tp ~= "number" then return message end
   local debug = _G.debug
   if type(debug) ~= "table" then return message end
   local tb = debug.traceback
   if type(tb) ~= "function" then return message end
   return tb(message, 2)
end

-- Prompt:
local counter = 1
local function prompt()
   local s = '> '
   return s
end

-- Read line:
local function readline()
   io.write(prompt()) io.flush()
   return io.read('*line')
end

-- LineNoise?
local ok,L = pcall(require,'linenoise')
if ok then
   -- History:
   local history = os.getenv('HOME') .. '/.luahistory'
   L.historyload(history)

   -- Completion:
   L.setcompletion(function(c,s)
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
   readline = function()
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

-- Aliases:
local aliases = [[
   alias ls='ls -GF';
   alias ll='ls -lhF';
   alias la='ls -ahF';
   alias lla='ls -lahF';
]]

-- Paths:
local cpath = package.cpath .. ';'
for cpath in cpath:gmatch('(.-);') do
   if cpath:find('%.so') then
      package.cpath = package.cpath .. ';' .. cpath:gsub('%.so','.dylib')
   end
end

-- Try to load env (Torch):
pcall(require,'torch')

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

-- The REPL:
function repl()
   -- Reults:
   _RESULTS = {}

   -- REPL:
   while true do
      -- READ:
      local line = readline()

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
         line = 'local res = ' .. line:gsub('^%s-=','') .. ' print(res) table.insert(_RESULTS,res)'
      end

      -- EVAL:
      if line then
         timer_start()
         local ok,err
         if line:find(';%s-$') or line:find('^%s-print') then
            ok = false
         else
            ok,err = xpcall(loadstring('local res = '..line..' print(res) table.insert(_RESULTS,res)'), traceback)
         end
         if not ok then
            local ok,err = xpcall(loadstring(line), traceback)
            if not ok then
               print(err)
            end
         end
         counter = counter + 1
         timer_stop()
      end

      -- Last result:
      _LAST = _RESULTS[#_RESULTS]
   end
end

-- return repl, just call it to start it!
return repl
