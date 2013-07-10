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
   "torch >= 7.1.alpha",
   "linenoise >= 0.4",
   "penlight >= 1.1.0"
}

build = {
   type = "builtin",
   modules = {
      ['trepl.init'] = 'init.lua',
   },
   install = {
      bin = {
         'th'
      }
   }
}
