# TREPL: A REPL for Torch

```
  ______             __   |  Torch7
 /_  __/__  ________/ /   |  Scientific computing for LuaJIT.
  / / / _ \/ __/ __/ _ \  |
 /_/  \___/_/  \__/_//_/  |  https://github.com/torch
                          |  http://torch.ch

th>
```

A pure Lua [REPL](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop) 
for LuaJIT, with heavy support for Torch types. 

Uses Readline for tab completion, with code borrowed from
[iluajit](https://github.com/jdesgats/ILuaJIT).

If Readline is not found, it defaults to using
[Linenoise](https://github.com/hoelzro/lua-linenoise),
which is significantly more simplistic.

This package installs a new binary named `th`, which
comes packed with all these features:

Features:

  * Tab-completion on nested namespaces
  * Tab-completion on disk files (when opening a string)
  * History
  * Pretty print (table introspection and coloring)
  * Auto-print after eval (can be stopped with ;)
  * Each command is profiled, timing is reported
  * No need for '=' to print
  * Easy help with: `? funcname`
  * Self help: `?`
  * Shell commands with: $ cmd (example: `$ ls`)
  * Print all user globals with `who()`
  * Import a package's symbols globally with `import(package)`
  * Require is overloaded to provide relative search paths: `require('./mylocallib/')`
  * Optional strict global namespace monitoring
  * Optional async repl (based on [async](https://github.com/clementfarabet/async))

Install
-------

Via luarocks:

```
luarocks install trepl
```

Launch
------

We install a binary, simple to remember:

```
th
> -- amazing repl!
```

Alternatively, you can always bring up the repl by loading it as a lib,
from anywhere:

```
luajit
> repl = require 'trepl'
> repl()
```

Use
---

Completion:

```lua
> cor+TAB   ...  completes to: coroutine
```

History:

```lua
> ARROW_UP | ARROW_DOWN
```

Help (shortcut to Torch's help method):

```lua
> ? torch.FloatTensor
prints help...
```

Shell commands:

```lua
> $ ls
README.md
init.lua
trepl-scm-1.rockspec

[Lua # 2] > $ ll
...

> $ ls
...
```

History / last results. Two variables are used:

```
_RESULTS: contains the history of results:

> a = 1
> a
1
> 'test'
test
> _RESULTS
{
   1 : 1
   2 : test
}

_LAST: contains the last result
> _LAST
test

Convenient to get output from shell commands:
> $ ls -l
> _LAST
contains the results from ls -l, in a string.
```

Hide output. By default, TREPL always tries to dump
the content of what's evaluated. Use ; to stop it.

```lua
> a = torch.Tensor(3)
> a:zero()
0
0
0
[torch.DoubleTensor of dimension 3]

> a:zero();
> 
```

Helpers
-------

Colors libraries can be loaded independently:

```lua
> c = require 'trepl.colorize'
> print(c.red('a red string') .. c.Blue('a bold blue string'))
```

Globals
-------

Global variables are a well known issue with Lua. `th` can be run
with a flag `-g` that will monitor global variables creation and access.

Creation of a variable will generate a warning message, while access
will generate an error.

```sh
th -g
> require 'sys';
created global variable: sys @ [c-module]
> a = 1
created global variable: a @ a = 1
> b
error: attempt to read undeclared variable b
```

Async repl [BETA]
-----------------

An asynchronous repl can be started with `-a`. Based on [async](https://github.com/clementfarabet/async), 
this repl is non-blocking, and can be used to spawn/schedule asyncrhonous jobs. It is still beta, 
and does not yet have readline support:

```sh
th -a
> idx = 1
> async.setInterval(1000, function() print('will be printed every second - step #' .. idx) idx = idx + 1 end)
will be printed every second - step #1
will be printed every second - step #2
will be printed every second - step #3
> idx = 20
will be printed every second - step #20
will be printed every second - step #21
```
