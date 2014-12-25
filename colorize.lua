local colors = require 'trepl.colors'

local f = {}

for name in pairs(colors) do
   f[name] = function(txt)
      return colors[name] .. txt .. colors.none
   end
end

return f
