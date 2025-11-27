## nvim doc server

HTTP server/telegram bot for vimdoc, hosted inside Neovim.

```sh
# kill -9 $(ps -p $(lsof -ti:8080) -o pid,cmd --no-headers | grep nvim | awk '{print $1}')
# http server
lx -v "LUA=./n.lua" --lua-version jit run

# telegram bot
lx -v "LUA=./n.lua" --lua-version jit lua src/bot.lua
```

## api
* `/hello` - Returns "Hello, World!"
* `/echo` - Echoes request info
* `/ex?query` - Executes ex command and returns raw output
* `/ex2?query` - Executes ex command and returns HTML output
* `/doc?query` - Returns Neovim help documentation
* `/version?query` - Returns Neovim help version info

## credits
* https://github.com/hat0uma/prelive.nvim
* https://github.com/nvim-neorocks/lux
* https://github.com/giuseppeM99/tdluaJIT
* https://github.com/giuseppeM99/tdlua
