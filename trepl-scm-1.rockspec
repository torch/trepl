package = "trepl"
version = "scm-1"

source = {
   url = "git://github.com/torch/trepl",
   branch = "master",
}

description = {
   summary = "An embedabble, Lua-only REPL for Torch.",
   detailed = [[
An embedabble, Lua-only REPL for Torch.
   ]],
   homepage = "https://github.com/torch/trepl",
   license = "BSD"
}

dependencies = {
   "torch >= 7.0",
   "linenoise >= 0.4",
   "penlight >= 1.1.0",
   "luafilesystem >= 1.6.2"
}

build = {
   type = "builtin",
   modules = {
      ['trepl.init'] = 'init.lua',
      ['trepl.colors'] = 'colors.lua',
      ['trepl.colorize'] = 'colorize.lua',
      ['trepl.readline'] = 'readline.lua',
      ['trepl.completer'] = 'completer.lua',
   },
   install = {
      bin = {
         'th'
      }
   }
}
