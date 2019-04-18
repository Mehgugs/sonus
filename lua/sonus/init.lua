--imports--
local core = require"sonus.core"
local client = require"novus.client"
local cond = require"cqueues.condition"
local telecom = require"sonus.telecom"
local dispatch = require"novus.client.dispatch"
local util = require"novus.util"
local novus_debug = os.getenv"NOVUS_DEBUG"
--start-module--
local _ENV = {}

local old_create
old_create = client.interpose("create", function(options)
    local cli = old_create(options)
    cli.telecom = telecom.new()
    return cli
end)

dispatch.interpose("VOICE_SERVER_UPDATE",
    function(cli, _, _, event)
        local id = util.uint(event.guild_id)
        cli.telecom.clients[id].handle:set_server_info(event.endpoint, event.token)
        cli.telecom.clients[id].ready:set(true, true)
    end
)

version = core.version

setup_logging = novus_debug and core.setup_logging_debug or core.setup_logging

--end-module--
return _ENV