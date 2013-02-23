TREPL: A REPL for Torch
=======================

A pure Lua REPL for Torch. Uses [Linenoise](https://github.com/hoelzro/lua-linenoise) 
for completion/history.

Install
-------

Via Luarocks:

```
luarocks install trepl
```

Use
---

With pure Lua:

```
lua -ltrepl
luajit -ltrepl
```

With Torch7:

```
torch-lua -ltrepl
```

With Torch9 (coming soon):

```
luajit -ltrepl -ltorch
```

