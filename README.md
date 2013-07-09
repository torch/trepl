TREPL: A REPL for Torch
=======================

A pure Lua REPL for Torch. Uses [Linenoise](https://github.com/hoelzro/lua-linenoise) 
for completion/history.

Features:

* Tab-completion
* History
* Pretty print (table introspection and coloring)
* No need for '=' to print

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
[Lua # 1] > cor+TAB   ...  completes to: coroutine
```

History:

```lua
[Lua # 1] > ARROW_UP | ARROW_DOWN
```

Shell commands:

```lua
[Lua # 1] > $ ls
README.md
init.lua
trepl-scm-1.rockspec

[Lua # 2] > $ ll
...

[Lua # 3] > $ ls
...
```

History / last results. Two variables are used:

```
_RESULTS: contains the history of results:

[Lua # 1] > a = 1
[Lua # 2] > a
1
[Lua # 3] > 'test'
test
[Lua # 4] > _RESULTS
{
   1 : 1
   2 : test
}

_LAST: contains the last result
[Lua # 5] > _LAST
test
```

Hide output. By default, TREPL always tries to dump
the content of what's evaluated. Use ; to stop it.

```lua
[Lua # 1] > a = torch.Tensor(3)
[Lua # 1] > a:zero()
0
0
0
[torch.DoubleTensor of dimension 3]

[Lua # 3] > a:zero();
[Lua # 4] > 
```
