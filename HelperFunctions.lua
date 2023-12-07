function OnScreen(control)
    -- How big is the screen?
    local displayWidth, displayHeight = Turbine.UI.Display.GetSize();

    -- Where is the control?
    local controlLeft, controlTop = control:GetPosition();

    -- How big is the control?
    local controlWidth, controlHeight = control:GetSize();

    local controlRight = controlLeft + controlWidth;
    local controlBottom = controlTop + controlHeight;

    -- if it's too far right, bring it back:
    if (controlRight > displayWidth) then
        controlLeft = displayWidth - controlWidth;
    end

    -- if it's too far left, bring it back:
    if (controlLeft < 0) then
        controlLeft = 0;
    end

    -- if it's too far down, bring it back:
    if (controlBottom > displayHeight) then
        controlTop = displayHeight - controlHeight;
    end

    -- if it's too far up, bring it back:
    if (controlTop < 0) then
        controlTop = 0;
    end

    control:SetPosition(controlLeft, controlTop);
end

-- Basic debug function to look at a table:
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--This function returns a deep copy of a given table ---------------
function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end
