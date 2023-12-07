import "Turbine.UI";

lockWidth = 16;
lockHeight = 16;

invlock_locked = 0x411523A7;
invlock_locked_rollover = 0x411523A8;
invlock_unlocked = 0x411523A9;
invlock_unlocked_pressed = 0x411523A5;
invlock_unlocked_rollover = 0x411523AB;

function CreateLockControl()
    local lockControl = Turbine.UI.Control();
    lockControl.isLocked = SETTINGS.OPAQUE_WIN.LOCKED;
    lockControl.isHover = false;

    lockControl:SetSize(lockWidth, lockHeight);
    lockControl:SetStretchMode(1);

    lockControl.UpdateBackground = function()
        local newBackground = GetBackground(lockControl);
        lockControl:SetBackground(newBackground);

        local opacity = GetOpacity(lockControl);
        lockControl:SetOpacity(opacity);
    end

    lockControl.UpdateBackground();
    lockControl:SetMouseVisible(true);

    lockControl.LockedChanged = function(isLocked)
        lockControl.isLocked = isLocked;
        lockControl.UpdateBackground();
    end

    lockControl.MouseEnter = function(sender, args)
        lockControl.isHover = true;
        lockControl.UpdateBackground();
    end

    lockControl.MouseLeave = function(sender, args)
        lockControl.isHover = false;
        lockControl.UpdateBackground();
    end

    lockControl.MouseDown = function(sender, args)
        lockControl.isMouseDown = true;
        lockControl.UpdateBackground();
    end

    lockControl.MouseUp = function(sender, args)
        lockControl.isMouseDown = false;
        lockControl.UpdateBackground();

        if (lockControl.isHover) then
            -- Tell options to toggle, which will then call LockedChanged
            lockControl.lockedCheckbox:SetChecked(not lockControl.isLocked);
        end
    end

    return lockControl;
end

function GetOpacity(lockControl)
    if (lockControl.isHover) then
        return 1;
    else
        return 0.25;
    end
end

function GetBackground(lockControl)
    local isLocked = lockControl.isLocked;
    local isHover = lockControl.isHover;
    local isMouseDown = lockControl.isMouseDown;

    if (isLocked) then
        if (isHover) then
            return invlock_locked_rollover;
        else
            return invlock_locked;
        end
    else
        if (isHover) then
            if (isMouseDown) then
                return invlock_unlocked_pressed;
            else
                return invlock_unlocked_rollover;
            end
        else
            if (isMouseDown) then
                return invlock_unlocked_pressed;
            else
                return invlock_unlocked;
            end
        end
    end
end