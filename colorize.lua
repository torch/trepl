local colors = require 'trepl.colors'

local f = {}

for name,color in pairs(colors) do
   f[name] = function(txt)
      return color .. txt .. colors.none
   end
end

return f
