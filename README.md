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

Via Luarocks:

```
luarocks install trepl
```

Launch
------

With pure Lua:

```
lua -ltrepl
luajit -ltrepl
```

With Torch7:

```
torch-lua -ltrepl -ltorch
```

With Torch9 (coming soon):

```
luajit -ltrepl -ltorch
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

_LAST: contains the last result, _ is a shortcut,
that's only used if not already defined:
[Lua # 5] > _
test
```

