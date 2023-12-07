import "Turbine";
import "Turbine.UI";
import "Turbine.UI.Lotro";

import "CubePlugins.OpaqueQuestTracker.HelperFunctions"
import "CubePlugins.OpaqueQuestTracker.VindarPatch"
import "CubePlugins.OpaqueQuestTracker.ColorPicker"
import "CubePlugins.OpaqueQuestTracker.LockControl"

PICKER_JPG_DIR = "CubePlugins/OpaqueQuestTracker/Resources/picker.jpg";

KEY_ACTION_TOGGLE_HUD = 0x100000B3;    -- F12

pluginName = plugin:GetName();
pluginVersion = plugin:GetVersion();
pluginDescription = string.format("'%s' v%s, by Cube", pluginName, pluginVersion);

settingsDataScope = Turbine.DataScope.Character;
settingsFilename = "OpaqueQuestTracker_Settings";
defaultSettingsDataScope = Turbine.DataScope.Account;
defaultSettingsFilename = "OpaqueQuestTracker_DefaultSettings";

opaqueWinMinHeight = 200;
opaqueWinMinWidth = 200;

screenWidth, screenHeight = Turbine.UI.Display:GetSize();

-- Lock location stuff:

UL = "UL";
UR = "UR";
LL = "LL";
LR = "LR";
NONE = "NONE";

LOCATION_BUTTONS = {};

-- End Lock location stuff

-- Language stuff!
clientLanguage = Turbine.Engine:GetLanguage();

EN = Turbine.Language.English;
DE = Turbine.Language.German;
FR = Turbine.Language.French;


_LANG = {
    ["STATUS"] = {
        ["LOADED"] = {
            [EN] = "Loaded " .. pluginDescription;
            [DE] = "Geladen " .. pluginDescription;
        };
        ["UNLOADED"] = {
            [EN] = string.format("'%s' unloaded", pluginName);
        };
    };
    ["OPTIONS"] = {
        ["OPACITY"] = {
            [EN] = "Opacity: %d%%";
            [DE] = "Opazität: %d%%";
            [FR] = "Opacité: %d%%";
        };
        ["LOCKED"] = {
            [EN] = "Lock the window in place";
        };
        ["LOCK_ICON_LOCATION"] = {
            [EN] = "Choose location of lock icon:";
        };
        ["LOCK_ICON_LOCATION_UPPER_LEFT"] = {
            [EN] = "Upper Left";
        };
        ["LOCK_ICON_LOCATION_UPPER_RIGHT"] = {
            [EN] = "Upper Right";
        };
        ["LOCK_ICON_LOCATION_LOWER_LEFT"] = {
            [EN] = "Lower Left";
        };
        ["LOCK_ICON_LOCATION_LOWER_RIGHT"] = {
            [EN] = "Lower Right";
        };
        ["LOCK_ICON_LOCATION_NONE"] = {
            [EN] = "None";
        };
        ["MAKE_DEFAULT"] = {
            [EN] = "Use Current Settings As Default";
        };
        ["COLOR_PICKER"] = {
            [EN] = "Color Picker";
        };
        ["CHANGE_COLOR"] = {
            [EN] = "Change Color";
        };
        ["SAVE_COLOR"] = {
            [EN] = "Save";
        };
        ["REVERT"] = {
            [EN] = "Revert settings to default";
        }
    };
};

function GetString(text)
    -- use clientLanguage, it's always right

    -- If they passed in a non-existant thing, return an empty string
    if (text == nil) then return ""; end

    -- If the text is present in the language, return it
    if (text[clientLanguage] ~= nil) then return text[clientLanguage]; end

    -- Otherwise, fall back to English
    return text[EN];
end

-- this will be true if the number is formatted with a 
-- comma for the decimal place / radix point, false otherwise
isEuroFormat=(tonumber("1,000")==1);

-- create a function to automatcially convert in string format to number:
if (isEuroFormat) then
    function euroNormalize(value)
        if (value == nil) then return 0.0; end
        return tonumber((string.gsub(value, "%.", ",")));
    end
else
    function euroNormalize(value)
        if (value == nil) then return 0.0; end
        return tonumber((string.gsub(value, ",", ".")));
    end
end

-- end Language stuff!

DEFAULT_SETTINGS = {
    ["OPAQUE_WIN"] = {
        ["LEFT"] = 0.75;
        ["TOP"] = 0.35;
        ["WIDTH"] = 0.25;
        ["HEIGHT"] = 0.35;
        ["OPACITY"] = 0.5;
        ["RED"] = 0.0;
        ["GREEN"] = 0.0;
        ["BLUE"] = 0.0;
        ["LOCKED"] = false;
        ["LOCK_ICON_POSITION"] = UL;
    };
};

SETTINGS = {};

function ConvertSavedPixelsToPercentages()
    -- Fix Width, Height, Left, and Top if they are pixels instead of percentages.
    local displayWidth, displayHeight = Turbine.UI.Display:GetSize();

    -- Basic logic: 
    --  For Width and Height:
    --      Try to rescale, use if > 50 pixels and < screen width/height

    if (SETTINGS.OPAQUE_WIN.WIDTH >= opaqueWinMinWidth and 
        SETTINGS.OPAQUE_WIN.WIDTH <= displayWidth) then
        -- try to rescale, e.g. ["WIDTH"] = "447"
        -- 447 / 1920 ~ 0.233
        SETTINGS.OPAQUE_WIN.WIDTH = SETTINGS.OPAQUE_WIN.WIDTH / displayWidth;
    end

    if (SETTINGS.OPAQUE_WIN.HEIGHT >= opaqueWinMinHeight and 
        SETTINGS.OPAQUE_WIN.HEIGHT <= displayHeight) then
        -- try to rescale, e.g. ["HEIGHT"] = "343"
        -- 343 / 1080 ~ 0.318
        SETTINGS.OPAQUE_WIN.HEIGHT = SETTINGS.OPAQUE_WIN.HEIGHT / displayHeight;
    end    

    --  For Left and Top:
    --      Try to rescale, use if > 0 and < screen width/height

    if (SETTINGS.OPAQUE_WIN.LEFT > 1 and 
        SETTINGS.OPAQUE_WIN.LEFT <= displayWidth) then
        -- try to resale, e.g. ["LEFT"] = "1473"
        -- 1473 / 1920 ~ 0.767
        SETTINGS.OPAQUE_WIN.LEFT = SETTINGS.OPAQUE_WIN.LEFT / displayWidth;
    end

    if (SETTINGS.OPAQUE_WIN.TOP > 1 and 
        SETTINGS.OPAQUE_WIN.TOP <= displayHeight) then
        -- try to resale, e.g. ["TOP"] = "287"
        -- 287 / 1080 ~ 0.266
        SETTINGS.OPAQUE_WIN.TOP = SETTINGS.OPAQUE_WIN.TOP / displayHeight;
    end
end

function ConstrainWindowSizeToDisplaySize()
    if (SETTINGS.OPAQUE_WIN.WIDTH > 1) then SETTINGS.OPAQUE_WIN.WIDTH = 1; end
    if (SETTINGS.OPAQUE_WIN.HEIGHT > 1) then SETTINGS.OPAQUE_WIN.HEIGHT = 1; end
end

function LoadSettings()
    local loadedSettings = PatchDataLoad(
        settingsDataScope,
        settingsFilename);

    -- if we didn't find character settings, look for custom default values:
    if (type(loadedSettings) ~= 'table') then
        loadedSettings = PatchDataLoad(
            defaultSettingsDataScope,
            defaultSettingsFilename);
    end

    -- did we load something good?
    if (type(loadedSettings) == 'table') then
        -- Yes, use what we loaded
        SETTINGS = loadedSettings;

        SETTINGS.OPAQUE_WIN.LEFT = euroNormalize(SETTINGS.OPAQUE_WIN.LEFT);
        SETTINGS.OPAQUE_WIN.TOP = euroNormalize(SETTINGS.OPAQUE_WIN.TOP);
        SETTINGS.OPAQUE_WIN.WIDTH = euroNormalize(SETTINGS.OPAQUE_WIN.WIDTH);
        SETTINGS.OPAQUE_WIN.HEIGHT = euroNormalize(SETTINGS.OPAQUE_WIN.HEIGHT);
        SETTINGS.OPAQUE_WIN.OPACITY = euroNormalize(SETTINGS.OPAQUE_WIN.OPACITY);
        SETTINGS.OPAQUE_WIN.RED = euroNormalize(SETTINGS.OPAQUE_WIN.RED);
        SETTINGS.OPAQUE_WIN.GREEN = euroNormalize(SETTINGS.OPAQUE_WIN.GREEN);
        SETTINGS.OPAQUE_WIN.BLUE = euroNormalize(SETTINGS.OPAQUE_WIN.BLUE);

        ConvertSavedPixelsToPercentages();
        ConstrainWindowSizeToDisplaySize();
    else
        -- No, start with the default values, they're OK.
        SETTINGS = deepcopy(DEFAULT_SETTINGS);
    end
end

function SaveSettings()
    PatchDataSave(
        settingsDataScope,
        settingsFilename,
        SETTINGS);
end

function SaveSettingsAsDefault()
    PatchDataSave(
        defaultSettingsDataScope,
        defaultSettingsFilename,
        SETTINGS);
end

function RevertSettings()
    SETTINGS = deepcopy(DEFAULT_SETTINGS);
    SetWindowSizePosition();
    UpdateWindowBackColor();
end

function RegisterForUnload()
    Turbine.Plugin.Unload = function(sender, args)
        SaveSettings();

        Turbine.Shell.WriteLine(GetString(_LANG.STATUS.UNLOADED));
    end
end

function UpdateWindowBackColor()
    local opacity = SETTINGS.OPAQUE_WIN.OPACITY;
    local red = SETTINGS.OPAQUE_WIN.RED;
    local green = SETTINGS.OPAQUE_WIN.GREEN;
    local blue = SETTINGS.OPAQUE_WIN.BLUE;
    window:SetBackColor(Turbine.UI.Color(opacity, red, green, blue));
end

function SetWindowSizePosition()
    window:SetPosition(SETTINGS.OPAQUE_WIN.LEFT * screenWidth, SETTINGS.OPAQUE_WIN.TOP * screenHeight);
    window:SetSize(SETTINGS.OPAQUE_WIN.WIDTH * screenWidth, SETTINGS.OPAQUE_WIN.HEIGHT * screenHeight);
end

function CreateMainWindow()
    window = Turbine.UI.Window();
    SetWindowSizePosition();
    UpdateWindowBackColor();
    window:SetVisible(true);
    window:SetMouseVisible(not SETTINGS.OPAQUE_WIN.LOCKED);
    window:SetZOrder(-1);

    lockControl = CreateLockControl();
    lockControl:SetParent(window);
    MoveLockButton(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION)

    -- Save off where the mouse and window were when the button was pressed.
    window.MouseDown = function(sender, args)
        window.mouseDown_MousePosition = { Turbine.UI.Display.GetMousePosition(); }
        window.mouseDown_WindowPosition = { window:GetPosition(); }
        window.mouseDown_WindowSize = { window:GetSize(); }
        window.isMouseDown = true;

        local borderWidth, borderHeight = 10, 10;
        local windowWidth, windowHeight = window:GetSize();
        local relativeMouseX, relativeMouseY = window:GetMousePosition();

        window.isMouseOverLeftBorder = relativeMouseX < borderWidth;
        window.isMouseOverTopBorder = relativeMouseY < borderHeight;
        window.isMouseOverRightBorder = relativeMouseX > (windowWidth - borderWidth);
        window.isMouseOverBottomBorder = relativeMouseY > (windowHeight - borderHeight);

        window.isMouseOverBorder = 
            window.isMouseOverLeftBorder or
            window.isMouseOverTopBorder or
            window.isMouseOverRightBorder or
            window.isMouseOverBottomBorder
    end

    window.MouseUp = function(sender, args)
        window.isMouseDown = false;
    end

    -- If the mouse button is down, drag / resize the window
    window.MouseMove = function(sender, args)
        if (window.isMouseDown) then
            local mouseDownX, mouseDownY = unpack(window.mouseDown_MousePosition);
            local mouseCurrentX, mouseCurrentY = Turbine.UI.Display.GetMousePosition();
            local windowLeft, windowTop = unpack(window.mouseDown_WindowPosition);

            local displayWidth, displayHeight = Turbine.UI.Display:GetSize();
            if (mouseCurrentX > displayWidth) then mouseCurrentX = displayWidth; end
            if (mouseCurrentY > displayHeight) then mouseCurrentY = displayHeight; end          

            if (window.isMouseOverBorder) then
                -- Resize the window!
                local mouseDown_WindowWidth, mouseDown_WindowHeight = unpack(window.mouseDown_WindowSize);

                -- how much will the width and height change?
                local deltaWidth = 0;
                local deltaHeight = 0;

                -- where will the window be?
                local left = windowLeft;
                local top = windowTop

                -- check for each of the borders:

                if (window.isMouseOverLeftBorder) then
                    -- make wider / narrower, adjust width to match:
                    -- left is bigger, right is smaller:
                    deltaWidth = mouseDownX - mouseCurrentX;
                    left = windowLeft - deltaWidth;
                end

                if (window.isMouseOverRightBorder) then
                    -- make wider / narrower, adjust width to match:
                    -- left is smaller, right is bigger:
                    deltaWidth = mouseCurrentX - mouseDownX;
                end

                if (window.isMouseOverTopBorder) then
                    -- make taller / shorter, adjust height to match:
                    -- up is bigger, down is smaller:
                    deltaHeight = mouseDownY - mouseCurrentY;
                    top = windowTop - deltaHeight;
                end

                if (window.isMouseOverBottomBorder) then
                    -- make taller / shorter, adjust height to match:
                    -- down is bigger, up is smaller:
                    deltaHeight = mouseCurrentY - mouseDownY;
                end

                -- Adjust the width and height based on which borders were moved:
                local width = mouseDown_WindowWidth + deltaWidth;
                local height = mouseDown_WindowHeight + deltaHeight;

                -- Don't let the window get too small:
                if (width < opaqueWinMinWidth) then width = opaqueWinMinWidth; end
                if (height < opaqueWinMinHeight) then height = opaqueWinMinHeight; end

                -- Update the window size (and if necessary position):
                window:SetSize(width, height);
                window:SetPosition(left, top);

                MoveLockButton(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION);
            else
                -- Move the window!

                -- calculate how much the cursor has moved
                local deltaX = mouseCurrentX - mouseDownX;
                local deltaY = mouseCurrentY - mouseDownY;

                -- move the window the same distance that the mouse has moved:
                window:SetPosition(windowLeft + deltaX, windowTop + deltaY);

            end
            OnScreen(window);

            local screenWidth, screenHeight = Turbine.UI.Display:GetSize();
            SETTINGS.OPAQUE_WIN.LEFT = window:GetLeft() / screenWidth;
            SETTINGS.OPAQUE_WIN.TOP = window:GetTop() / screenHeight;
            SETTINGS.OPAQUE_WIN.WIDTH = window:GetWidth() / screenWidth;
            SETTINGS.OPAQUE_WIN.HEIGHT = window:GetHeight() / screenHeight;
        end
    end

    window:SetWantsKeyEvents(true);
    window.KeyDown = function(sender, args)
        if (args.Action == KEY_ACTION_TOGGLE_HUD) then
            window:SetVisible(not window:IsVisible());
        end
    end

    OnScreen(window);
end

function CreateColorPickerWindow()
    -- the color picker window
    ColorPickerWindow = Turbine.UI.Lotro.Window();
    ColorPickerWindow:SetSize(300,180);
    ColorPickerWindow:SetPosition(100,100);
    ColorPickerWindow:SetText(GetString(_LANG.OPTIONS.COLOR_PICKER));

    -- slightly not-black background to see the edges more easily:
    local background = Turbine.UI.Control();
    background:SetParent(ColorPickerWindow);
    background:SetSize(284, 145 - 38);
    background:SetPosition(8, 38);
    background:SetBackColor(Turbine.UI.Color(0.1, 0.1, 0.1));

    -- the color picker
    local colorPicker = ColorPicker.Create();
    colorPicker:SetParent(ColorPickerWindow);
    colorPicker:SetSize(280, 70);
    colorPicker:SetPosition(10, 40);

    -- Get the current color values:
    local red = SETTINGS.OPAQUE_WIN.RED;        -- 0 to 1
    local green = SETTINGS.OPAQUE_WIN.GREEN;    -- 0 to 1
    local blue = SETTINGS.OPAQUE_WIN.BLUE;      -- 0 to 1

    local redNum = math.floor((red * 255) + 0.5);       -- 0 to 255
    local greenNum = math.floor((green * 255) + 0.5);   -- 0 to 255
    local blueNum = math.floor((blue * 255 + 0.5));     -- 0 to 255

    -- selected color preview
    local colorPreview = Turbine.UI.Control();
    colorPreview:SetParent(ColorPickerWindow);
    colorPreview:SetSize(23,23);
    colorPreview:SetPosition(95,120);
    colorPreview:SetBackColor(Turbine.UI.Color(red, green, blue));

    colorLabelFont = Turbine.UI.Lotro.Font.TrajanPro14;
    colorLabelColor = Turbine.UI.Color((229/255),(209/255),(136/255));

    -- selected color hex value
    local colorLabel = Turbine.UI.Label();
    colorLabel = Turbine.UI.Label();
    colorLabel:SetParent(ColorPickerWindow);
    colorLabel:SetPosition(125,120);
    colorLabel:SetSize(220,23);
    colorLabel:SetForeColor(colorLabelColor);
    colorLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
    colorLabel:SetFont(colorLabelFont);
    colorLabel:SetText(string.format("Hex: #%02x%02x%02x", redNum, greenNum, blueNum));

    -- respond to clicks:
    colorPicker.LeftClick = function ()
        colorPreview:SetBackColor(colorPicker:GetTurbineColor());
        colorLabel:SetText("Hex: #" .. colorPicker:GetHexColor());
    end

    -- button which updates the SETTINGS and recolours the window.
    local saveButton = Turbine.UI.Lotro.Button();
    saveButton:SetParent(ColorPickerWindow);
    saveButton:SetText(GetString(_LANG.OPTIONS.SAVE_COLOR));
    saveButton:SetPosition(100, 150);
    saveButton:SetWidth(100);
    saveButton.Click = function(sender, args)
        local red, green, blue = colorPicker:GetRGBColor();
        SETTINGS.OPAQUE_WIN.RED = red / 255;
        SETTINGS.OPAQUE_WIN.GREEN = green / 255;
        SETTINGS.OPAQUE_WIN.BLUE = blue / 255;
        UpdateWindowBackColor();
    end
end

-- Pass UL, UR, LL, LR, or NONE
function MoveLockButton(newLocation)

    if (newLocation == NONE) then
        lockControl:SetVisible(false);
    else
        lockControl:SetVisible(true);
        local left = 0;
        local top = 0;

        if (newLocation == UR) then
            -- top is 0
            left = window:GetWidth() - lockControl:GetWidth();
        elseif (newLocation == LL) then
            top = window:GetHeight() - lockControl:GetHeight();
            -- left = 0
        elseif (newLocation == LR) then
            left = window:GetWidth() - lockControl:GetWidth();
            top = window:GetHeight() - lockControl:GetHeight();
        else
            -- Default behavior is UL
            -- top is 0
            -- left is 0
        end
        lockControl:SetPosition(left, top);
    end

end

function ChangeLockIconLocation(newLocation)
    MoveLockButton(newLocation);
    SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION = newLocation;

    -- enable all buttons
    LOCATION_BUTTONS[UL]:SetEnabled(true);
    LOCATION_BUTTONS[UR]:SetEnabled(true);
    LOCATION_BUTTONS[LL]:SetEnabled(true);
    LOCATION_BUTTONS[LR]:SetEnabled(true);
    LOCATION_BUTTONS[NONE]:SetEnabled(true);

    -- disable the clicked button
    LOCATION_BUTTONS[newLocation]:SetEnabled(false);
end

function DrawOptionsControl()
    options = Turbine.UI.Control();
    plugin.GetOptionsPanel = function(self) return options; end

    options:SetBackColor(Turbine.UI.Color(0.1, 0.1, 0.1)); -- RGB, 0 = 0, 1 = 255.
    options:SetSize(250, 300);

    local leftMargin = 10;
    local controlTop = 10;

    -- add a label for the scrollbar
    local opacityLabel = Turbine.UI.Label();
    opacityLabel:SetParent(options);
    opacityLabel:SetSize(200, 25);
    opacityLabel:SetText(string.format(GetString(_LANG.OPTIONS.OPACITY), SETTINGS.OPAQUE_WIN.OPACITY * 100));
    opacityLabel:SetPosition(leftMargin, controlTop);
    controlTop = controlTop + 20;

    -- add a scrollbar to control opacity
    local opacityScrollBar = Turbine.UI.Lotro.ScrollBar();
    opacityScrollBar:SetParent(options);
    opacityScrollBar:SetSize(200, 10);
    opacityScrollBar:SetOrientation(Turbine.UI.Orientation.Horizontal);
    opacityScrollBar:SetPosition(leftMargin, controlTop);
    opacityScrollBar:SetValue(SETTINGS.OPAQUE_WIN.OPACITY * 100);
    opacityScrollBar.ValueChanged = function(sender, args)
        local value = opacityScrollBar:GetValue(); -- [0, 100]
        local scaledOpacity = value / 100;
        SETTINGS.OPAQUE_WIN.OPACITY = scaledOpacity;
        UpdateWindowBackColor();
        opacityLabel:SetText(string.format(GetString(_LANG.OPTIONS.OPACITY), value));
    end
    controlTop = controlTop + 20;

    -- add a button to open the color picker to choose the background color
    local changeColorButton = Turbine.UI.Lotro.Button();
    changeColorButton:SetParent(options);
    changeColorButton:SetText(GetString(_LANG.OPTIONS.CHANGE_COLOR));
    changeColorButton:SetPosition(leftMargin, controlTop);
    changeColorButton:SetWidth(150);
    changeColorButton.Click = function(sender, args)
        ColorPickerWindow:SetVisible(true);

        -- Make sure the Color Picker window is on top:
        ColorPickerWindow:SetZOrder(1);
        ColorPickerWindow:SetZOrder(0);
    end
    controlTop = controlTop + 40;

    -- add a checkbox to "lock" the window
    local lockedCheckbox = Turbine.UI.Lotro.CheckBox();
    lockedCheckbox:SetParent(options);
    lockedCheckbox:SetPosition(leftMargin, controlTop);
    lockedCheckbox:SetSize(250, 25);
    lockedCheckbox:SetText(GetString(_LANG.OPTIONS.LOCKED));
    lockedCheckbox:SetChecked(SETTINGS.OPAQUE_WIN.LOCKED);
    lockControl.lockedCheckbox = lockedCheckbox;
    lockedCheckbox.CheckedChanged = function(sender, args)
        local isLocked = lockedCheckbox:IsChecked();
        local mouseVisible = not isLocked;
        window:SetMouseVisible(mouseVisible);
        lockControl.LockedChanged(isLocked);
        SETTINGS.OPAQUE_WIN.LOCKED = isLocked;
    end
    controlTop = controlTop + 30;

    -- Add controls to determine lock icon location:
    local lockedPositionLabel = Turbine.UI.Label();
    lockedPositionLabel:SetParent(options);
    lockedPositionLabel:SetPosition(leftMargin, controlTop);
    lockedPositionLabel:SetWidth(250);
    lockedPositionLabel:SetText(GetString(_LANG.OPTIONS.LOCK_ICON_LOCATION));

    controlTop = controlTop + 20;

    local upperLeftButton = Turbine.UI.Lotro.Button();
    upperLeftButton:SetParent(options);
    upperLeftButton:SetPosition(leftMargin, controlTop);
    upperLeftButton:SetWidth(85);
    upperLeftButton:SetText(GetString(_LANG.OPTIONS.LOCK_ICON_LOCATION_UPPER_LEFT));
    upperLeftButton.Click = function(sender, args)
        ChangeLockIconLocation(UL);
    end
    upperLeftButton:SetEnabled(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION ~= UL);
    LOCATION_BUTTONS[UL] = upperLeftButton;

    local upperRightButton = Turbine.UI.Lotro.Button();
    upperRightButton:SetParent(options);
    upperRightButton:SetPosition(leftMargin + 100, controlTop);
    upperRightButton:SetWidth(85);
    upperRightButton:SetText(GetString(_LANG.OPTIONS.LOCK_ICON_LOCATION_UPPER_RIGHT));
    upperRightButton.Click = function(sender, args)
        ChangeLockIconLocation(UR);
    end
    upperRightButton:SetEnabled(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION ~= UR);
    LOCATION_BUTTONS[UR] = upperRightButton;

    local lowerLeftButton = Turbine.UI.Lotro.Button();
    lowerLeftButton:SetParent(options);
    lowerLeftButton:SetPosition(leftMargin, controlTop + 50);
    lowerLeftButton:SetWidth(85);
    lowerLeftButton:SetText(GetString(_LANG.OPTIONS.LOCK_ICON_LOCATION_LOWER_LEFT));
    lowerLeftButton.Click = function(sender, args)
        ChangeLockIconLocation(LL);
    end
    lowerLeftButton:SetEnabled(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION ~= LL);
    LOCATION_BUTTONS[LL] = lowerLeftButton;

    local lowerRightButton = Turbine.UI.Lotro.Button();
    lowerRightButton:SetParent(options);
    lowerRightButton:SetPosition(leftMargin + 100, controlTop + 50);
    lowerRightButton:SetWidth(85);
    lowerRightButton:SetText(GetString(_LANG.OPTIONS.LOCK_ICON_LOCATION_LOWER_RIGHT));
    lowerRightButton.Click = function(sender, args)
        ChangeLockIconLocation(LR);
    end
    lowerRightButton:SetEnabled(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION ~= LR);
    LOCATION_BUTTONS[LR] = lowerRightButton;

    local noneButton = Turbine.UI.Lotro.Button();
    noneButton:SetParent(options);
    noneButton:SetPosition(leftMargin + 50, controlTop + 25);
    noneButton:SetWidth(85);
    noneButton:SetText(GetString(_LANG.OPTIONS.LOCK_ICON_LOCATION_NONE));
    noneButton.Click = function(sender, args)
        ChangeLockIconLocation(NONE);
    end
    noneButton:SetEnabled(SETTINGS.OPAQUE_WIN.LOCK_ICON_POSITION ~= NONE);
    LOCATION_BUTTONS[NONE] = noneButton;
    controlTop = controlTop + 30 + 50;

    options.SizeChanged = function(sender, args)
        local width, height = options:GetSize();
        local margin = lockedCheckbox:GetLeft();
        lockedCheckbox:SetWidth(width - margin * 2);
    end

    controlTop = controlTop + 20;
    -- add a button to make the current settings the default settings 
    -- for other characters that don't already have a save file.
    local makeDefaultButton = Turbine.UI.Lotro.Button();
    makeDefaultButton:SetParent(options);
    makeDefaultButton:SetText(GetString(_LANG.OPTIONS.MAKE_DEFAULT));
    makeDefaultButton:SetPosition(leftMargin, controlTop);
    makeDefaultButton:SetWidth(250);
    makeDefaultButton.Click = function(sender, args)
        SaveSettingsAsDefault();
    end
    controlTop = controlTop + 30;

    -- add a button to reset the settings
    local revertSettingsButton = Turbine.UI.Lotro.Button();
    revertSettingsButton:SetParent(options);
    revertSettingsButton:SetText(GetString(_LANG.OPTIONS.REVERT));
    revertSettingsButton:SetPosition(leftMargin, controlTop);
    revertSettingsButton:SetWidth(250);
    revertSettingsButton.Click = function(sender, args)
        RevertSettings();
    end
    controlTop = controlTop + 30;
end

function Main()
    LoadSettings();
    RegisterForUnload();
    CreateMainWindow();
    CreateColorPickerWindow();
    DrawOptionsControl();

    Turbine.Shell.WriteLine(GetString(_LANG.STATUS.LOADED));
end

Main();
