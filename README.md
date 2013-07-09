TREPL: A REPL for Torch
=======================

A pure Lua REPL for Torch. Uses [Linenoise](https://github.com/hoelzro/lua-linenoise) 
for completion/history. Installs a new binary named "th".

Features:

* Tab-completion on nested namespaces
* Tab-completion on disk files (when opening a string)
* History
* Pretty print (table introspection and coloring)
* Auto-print after eval (can be stopped with ;)
* Each command is profiled, timing is reported
* No need for '=' to print
* Easy help with: ? funcname
* Shell commands with: $ cmd (example: $ ls)

Install
-------

Via torch-rocks:

```
torch-rocks install trepl
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
torch
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
