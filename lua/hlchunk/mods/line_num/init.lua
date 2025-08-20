local BaseMod = require("hlchunk.mods.base_mod")
local LineNumConf = require("hlchunk.mods.line_num.line_num_conf")
local chunkHelper = require("hlchunk.utils.chunkHelper")
local class = require("hlchunk.utils.class")
local debounce = require("hlchunk.utils.timer").debounce
local debounce_throttle = require("hlchunk.utils.timer").debounce_throttle

local api = vim.api
local CHUNK_RANGE_RET = chunkHelper.CHUNK_RANGE_RET

---@class HlChunk.LineNumMetaInfo : HlChunk.MetaInfo

local constructor = function(self, conf, meta)
    local default_meta = {
        name = "line_num",
        augroup_name = "hlchunk_line_num",
        hl_base_name = "HLLineNum",
        ns_id = api.nvim_create_namespace("line_num"),
    }
    
    BaseMod.init(self, conf, meta)
    self.meta = vim.tbl_deep_extend("force", default_meta, meta or {})
    self.conf = LineNumConf(conf)
end

---@class HlChunk.LineNumMod : HlChunk.BaseMod
---@field conf HlChunk.LineNumConf
---@field meta HlChunk.LineNumMetaInfo
---@field render fun(self: HlChunk.LineNumMod, range: HlChunk.Scope, opts?: {error: boolean})
---@overload fun(conf?: HlChunk.UserLineNumConf, meta?: HlChunk.MetaInfo): HlChunk.LineNumMod
local LineNumMod = class(BaseMod, constructor)

function LineNumMod:render(range)
    if not self:shouldRender(range.bufnr) then
        return
    end

    local beg_row = range.start
    local end_row = range.finish
    local row_opts = {
        number_hl_group = self.meta.hl_name_list[1],
        priority = self.conf.priority,
    }
    for i = beg_row, end_row do
        api.nvim_buf_set_extmark(0, self.meta.ns_id, i, 0, row_opts)
    end
end

function LineNumMod:createAutocmd()
    BaseMod.createAutocmd(self)

    local render_cb = function(event)
        local bufnr = event.buf
        if not api.nvim_buf_is_valid(bufnr) then
            return
        end
        local winnr = api.nvim_get_current_win()
        local pos = api.nvim_win_get_cursor(winnr)
        local retcode, cur_chunk_range = chunkHelper.get_chunk_range({
            pos = { bufnr = bufnr, row = pos[1] - 1, col = pos[2] },
            use_treesitter = self.conf.use_treesitter,
        })
        self:clear({ bufnr = bufnr, start = 0, finish = api.nvim_buf_line_count(bufnr) })
        if retcode ~= CHUNK_RANGE_RET.OK then
            return
        end
        self:render(cur_chunk_range)
    end
    local db_render_cb = debounce(render_cb, self.conf.delay, false)
    local render_callback
    if self.conf.delay == 0 then
      render_callback = render_cb
    else
      render_callback = db_render_cb
    end
    api.nvim_create_autocmd({ "CursorMovedI", "CursorMoved" }, {
        group = self.meta.augroup_name,
        callback = render_callback,
    })
end

return LineNumMod
