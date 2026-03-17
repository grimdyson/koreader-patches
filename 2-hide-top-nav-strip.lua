-- Hide top navigation strip in KOReader File Manager (mosaic view)
-- Removes the subtitle row (home icon, folder label, plus icon) from the
-- titlebar, reclaiming vertical space for the cover grid.
-- Runs AFTER 2-custom-titlebar.lua (filename sort order ensures this).
-- Pattern inspired by 2-hide-pagination.lua: hide visible pieces, preserve
-- internal refs, recalculate layout safely.

local FileManager = require("apps/filemanager/filemanager")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local VerticalSpan = require("ui/widget/verticalspan")

-- Capture current methods (already wrapped by the titlebar patch by load order)
local orig_updateStatusBar = FileManager._updateStatusBar
local orig_updateTitleBarPath = FileManager.updateTitleBarPath

local function applyHideTopNavStrip(fm)
    if not fm then return end

    local fc = fm.file_chooser
    if not fc then return end

    local tb = fm.title_bar
    if not tb or not tb.title_group then return end

    local tg = tb.title_group
    if #tg < 4 then return end

    -- Move buttons offscreen; preserve refs for downstream code
    if tb.left_button then
        tb.left_button.overlap_align = nil
        tb.left_button.overlap_offset = {-10000, -10000}
    end
    if tb.right_button then
        tb.right_button.overlap_align = nil
        tb.right_button.overlap_offset = {-10000, -10000}
    end

    -- Collapse spacer [3] and subtitle row [4] to zero height
    tg[3] = VerticalSpan:new{ width = 0 }
    tg[4] = VerticalSpan:new{ width = 0 }
    tg:resetLayout()

    -- Compute reduced titlebar height from visible content + small margin
    local new_h = 0
    for i = 1, #tg do
        new_h = new_h + tg[i]:getSize().h
    end
    new_h = new_h + Size.padding.default

    -- Skip if already applied (idempotent fast path)
    if tb._strip_hidden_h == new_h then return end
    tb._strip_hidden_h = new_h

    -- Update the stored titlebar height
    tb.titlebar_height = new_h

    -- Walk the title bar widget tree and shrink every container's dimen.h
    local c = tb
    for _ = 1, 5 do
        if not c then break end
        if c.dimen then c.dimen.h = new_h end
        c = c[1]
    end

    -- Override getSize() on the title bar instance so that
    -- _recalculateDimen reads the reduced height (belt-and-suspenders).
    if not tb._getSize_patched then
        tb._getSize_patched = true
        function tb:getSize()
            return Geom:new{ w = self.width or 0, h = self.titlebar_height or 0 }
        end
    end

    -- Recalculate file chooser dimensions, then re-render items
    if fc._recalculateDimen then
        fc:_recalculateDimen()
    end
    if fc.updateItems then
        fc:updateItems()
    end
end

-- Wrap _updateStatusBar: titlebar patch runs first, then hide the strip
if orig_updateStatusBar then
    function FileManager:_updateStatusBar(...)
        orig_updateStatusBar(self, ...)
        applyHideTopNavStrip(self)
    end
end

-- Wrap updateTitleBarPath: may restore subtitle content; re-hide afterward
if orig_updateTitleBarPath then
    function FileManager:updateTitleBarPath(path)
        orig_updateTitleBarPath(self, path)
        applyHideTopNavStrip(self)
    end
end
