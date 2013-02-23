package = "trepl"
version = "scm-1"

source = {
   url = "git://github.com/clementfarabet/trepl",
   tag = "master",
}

description = {
   summary = "An embedabble, Lua-only REPL for Torch.",
   detailed = [[
An embedabble, Lua-only REPL for Torch.
   ]],
   homepage = "https://github.com/clementfarabet/trepl",
   license = "BSD"
}

dependencies = {
   "torch >= 7.0",
   "linenoise >= 0.4"
}

build = {
   type = "builtin",
   modules = {
      ['trepl.init'] = 'init.lua',
   }
}
