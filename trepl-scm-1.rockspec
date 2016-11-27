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
   "penlight >= 1.1.0",
}

build = {
   type = "builtin",
   modules = {
      ['trepl.init'] = 'init.lua',
      ['trepl.colors'] = 'colors.lua',
      ['trepl.colorize'] = 'colorize.lua',
      ['readline'] = {
         sources = {'readline.c'},
         libraries = {'readline'}
      },
      ['treplutils'] = {
         sources = {'utils.c'},
      }
   },
   platforms = {
      freebsd = {
             modules = {
                  ['readline'] = {
                    incdirs = {'/usr/local/include'},
                    libdirs = {'/usr/local/lib'}
                  }
             }
      },
      windows = {
	     modules = {
		    ['readline'] = {
               sources = {'readline.c'},
               libraries = {'readline'},
               defines = {"WinEditLine"},
               incdirs = {"..\\..\\win-files\\3rd\\wineditline-2.201\\include"},
               libdirs = {"..\\..\\win-files\\3rd\\wineditline-2.201\\lib64"},
               libraries = {'edit_static', 'user32'}
			}
		 }
	  }
   },
   install = {
      bin = {
         'th'
      }
   }
}
