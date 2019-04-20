--imports--
local util = require"novus.util"
local interposable = require"novus.client.interposable"
local errno = require"cqueues.errno"
local hutil = require"http.util"
local request = require"http.request"
local formats = require"sonus.extractors.youtube.formats"

local json = require"cjson"
local tostring = tostring
local assert = assert
local tonumber = tonumber
local time = os.time
local list = util.list
local re = util.relabel
local lpeg = util.lpeg
--start-module--
local _ENV = interposable{}

VIDEO_URL  = 'https://www.youtube.com/watch?v=%s&%s'
EMBED_URL  = 'https://www.youtube.com/embed/%s?%s'
VIDEO_EURL = 'https://youtube.googleapis.com/v/'
INFO_URL  = 'https://www.youtube.com/get_video_info?%s'

KEYS_TO_SPLIT = {
  'fmt_list',
  'fexp',
  'watermark'
}



local P, C, Cp = lpeg.P, lpeg.C, lpeg.Cp
local anywhere = lpeg.anywhere
local function between(start, finish)
    start = P(start)
    finish = P(finish or start)
    return start * C((1 - finish)^0) * finish
end

local unavailable_check = anywhere(between('<div id="player-unavailable"', '>'))
local class_check = anywhere(between('class="', '"'))
local grep_err = anywhere(between('<h1 id="unavailable-message" class="message">', '</h1>'))
local json_str = anywhere(between('ytplayer.config = ', '</script>'))
local embed_grep = anywhere(between("t.setConfig({'PLAYER_CONFIG': ", re.compile[[ "}" (",'" / "});") ]]))

function get_basic_info(id, options)
    local params = hutil.dict_to_query{
        hl = options.lang or 'en'
       ,bpctr = tostring(time())
    }
    local uri = VIDEO_URL % {
         id
        ,params
    }
    local req = request.new_from_uri(uri)
    req.headers:upsert("user-agent", "")
    req.headers:upsert(":method", "GET")
    if options.apply then options.apply(req) end

    local headers, stream, eno = req:go(options.timeout)
    if not headers then
        return nil, errno.strerror(eno)
    else
        local body = stream:get_body_as_string()
        local unavailable_err = unavailable_check:match(body)
        if unavailable_err and (class_check:match(body) or ""):find("%f[%w]hid%f[%W]") then
            if not body:find('<div id="watch7-player-age-gate-content', 1, true) then
                return nil, grep_err:match(body)
            end
        end

        --TODO: parse addition metadata

        local raw = json_str:match(body)
        if raw then

            local config = raw:sub(1, raw:find(';ytplayer%.load.-$')-1)
            return process_config(id, options, config)
        else
            local embed_uri = EMBED_URL % {id, params}
            local embed_req = request.new_from_uri(embed_uri)
            embed_req.headers:upsert("user-agent", "")
            embed_req.headers:upsert(":method", "GET")
            local headers, stream, eno = embed_req:go(options.timeout)
            if not headers then
                return nil, errno.strerror(eno)
            else
                local embed_body = stream:get_body_as_string()
                local config = embed_grep:match(embed_body)
                return process_config(id, options, config, true)
            end
        end
    end
end

function query_of(s)
    local out = {}
    for name, value in hutil.query_args(s) do
        out[name] = value
    end
    return out
end

local tags = re.compile[[
    tag <- (ltag / rtag)
    ltag <- lopen content lclose
        lopen <-  "<"->""
        lclose <- ">"->""
    rtag <- ropen content rclose
        ropen <- "</"->""
        rclose <- ">"->""
    content <- (!">".)*
]]

local function strip_tags(s)
    return re.gsub(s, tags, "")
end

local function make_format(f)
    local obj = query_of(f)
    obj.container = formats[obj.itag].container
    return obj
end

local function parse_formats(info)
    local formats
    if info.url_encoded_fmt_stream_map then
        formats = lpeg.split(info.url_encoded_fmt_stream_map, ",")
    else formats = {}
    end
    if info.adaptive_fmts then
        list.cat(formats, lpeg.split(info.adaptive_fmts, ","))
    end
    formats = list.map(make_format, formats)
    info.url_encoded_fmt_stream_map = nil
    info.adaptive_fmts = nil
    return formats
end

function process_config(id, options, config, from_embed)
    if not config then
        return nil, 'Unable to retrieve config from document.'
    end
    config = json.decode(from_embed and config.."}" or config)
    local uri = INFO_URL % hutil.dict_to_query{
         video_id = id
        ,eurl = VIDEO_EURL .. id
        ,ps = 'default'
        ,gl = 'US'
        ,hl = options.lang or 'en'
        ,sts = tostring(config.sts)
    }
    local req = request.new_from_uri(uri)
    req.headers:upsert("user-agent", "")
    req.headers:upsert(":method", "GET")
    if options.apply then options.apply(req) end
    local headers, stream, eno = req:go(options.timeout)
    if not headers then
        return nil, errno.strerror(eno)
    else
        local body = stream:get_body_as_string()
        local info = query_of(body)

        if info.status == "fail" then
            if config.args
            and (config.args.fmt_list or config.args.url_encoded_fmt_stream_map or config.args.adaptive_fmts)
            then
                info = config.args
                info.no_embed_allowed = true
            else
                return nil, "%s : %s" % {info.errorcode, strip_tags(info.reason)}
            end
        end
        local player_response = config.args.player_response or info.player_response

        if player_response then
            info.player_response = json.decode(player_response)
        end
        local playability = info.player_response.playabilityStatus
        if playability and playability.status == 'UNPLAYABLE' then
            return nil, playability.reason
        end

        list.each(function(key)
            if not info[key] then return end
            info[key] = list.filter(
                function(i) return i ~= "" end,
                lpeg.split(info[key], ",")
            )
        end, KEYS_TO_SPLIT)
        info.fmt_list = info.fmt_list and
            list.map(function(i) return lpeg.split(i, '/') end, info.fmt_list)
        or {}

        info.ageRestricted = from_embed
        info.formats = parse_formats(info)
        info.html5player = config.assets.js
        return info
    end
end

local function simple_metadata(info)
    return {
        title = info.player_response.videoDetails.title
        ,artist = info.player_response.videoDetails.author
        ,views = tonumber(info.player_response.videoDetails.viewCount)
        ,id = info.player_response.videoDetails.videoId
        ,thumbnail = info.player_response.videoDetails.thumbnail.thumbnails[1]
        ,description = info.player_response.videoDetails.shortDescription
        ,length = tonumber(info.player_response.videoDetails.lengthSeconds)
    }
end

function resolve_simply(id)
    local info = assert(get_basic_info(id, {}))
    local format = info.formats[1]
    return format.url, format, simple_metadata(info)
end

--end-module--
return _ENV