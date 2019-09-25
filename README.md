# Archive Notice
This project is no longer being maintained; I've decided to stop the development of [novus][novus].

## Sonus
Adds voice support to [novus][novus], powered by [telecom][telecom].

### Installation
- You need to have [novus][novus] installed.
- Install Go and [`$ go get github.com/b1naryth1ef/telecom`][telecom].
- Build the telecom-native app. (You may want to install it afterwards to make building easier!)
- Install ffmpeg.
- To install from github:
  - `$ git clone https://github.com/Mehgugs/sonus.git`,
  - `$ cd sonus && luarocks make`.

### Example Usage

```lua
local util = require"novus.util"
local sonus = require"sonus"
local client = require"novus.client".new{token = os.getenv"TOKEN"}
client.events.MESSAGE_CREATE:listen(function(ctx)
    local parts = util.lpeg.split(ctx.msg.content, " ")
    if parts[1] == "!play" then
        local ch = ctx.guild.channels[util.uint(parts[2])]
        client.telecom:join(ctx, ch)
        client.telecom:play(ctx, "allstar.mp3")
    end
end)
client:run()
```

[novus]: https://github.com/Mehgugs/novus
[telecom]: https://github.com/b1naryth1ef/telecom
