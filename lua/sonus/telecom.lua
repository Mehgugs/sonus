--imports--
local context = require"novus.client.context"
local enums = require"novus.enums"
local promise = require"cqueues.promise"
local core = require"sonus.core"
local shard = require"novus.shard"
local util = require"novus.util"
local null = require"cjson".null
local setmetatable = setmetatable
local assert = assert
local error = error
--start-module--
local _ENV = {}

context.interpose("shard", function(ctx)
    return ctx.client.shards[ctx.guild.shard_id]
end)

__index = _ENV

function new()
    return setmetatable({clients = {}}, _ENV)
end

function validate(telecom, id)
    if telecom.clients[id] then
        return telecom.clients[id].ready:get()
    else
        return error("You need to join a voice channel!")
    end
end

function join(telecom, ctx, channel)
    assert(channel.type == enums.channeltype.voice, "Cannot join a non-voice channel.")
    local gid, chid, me =
         util.uint.tostring(ctx.guild.id)
        ,util.uint.tostring(channel.id)
        ,util.uint.tostring(ctx.client:me().id)
    shard.send(ctx:shard(), shard.ops.VOICE_STATE_UPDATE, {
         guild_id = gid
        ,channel_id = chid
        ,self_mute = false
        ,self_deaf = false
        ,self_video = false
    })
    local handle = core.new_client(me, gid,  ctx:shard().session_id)
    telecom.clients[ctx.guild.id] = {handle = handle, ready = promise.new()}
    return telecom.clients[ctx.guild.id].ready:get()
end

function play(telecom, ctx, path)
    telecom:validate(ctx.guild.id)
    local playable = core.new_playable(path)
    util.info("%s", playable)
    telecom.clients[ctx.guild.id].handle:play(playable)
end

function leave(telecom, ctx)
    if telecom.clients[ctx.guild.id] then
        telecom.clients[ctx.guild.id].ready:get()
        telecom.clients[ctx.guild.id].handle:destroy()
    end
    telecom.clients[ctx.guild.id] = nil
    local gid = util.uint.tostring(ctx.guild.id)
    shard.send(ctx:shard(), shard.ops.VOICE_STATE_UPDATE, {
        guild_id = gid
       ,channel_id = null
       ,self_mute = false
       ,self_deaf = false
       ,self_video = false
   })
end

--end-module--
return _ENV