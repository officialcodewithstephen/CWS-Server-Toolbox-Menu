#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

/*
    CWS Admin Menu actions.
    Implements moderation requests, remote IW4MAdmin and Dragnet views, server
    controls, player utilities, spectator telemetry, ESP, and self tools.
    Layout and HUD navigation remain in menu.gsc.
*/

/* Adds a themed notification to the top of this player's active stack. */
menuShowNotification(title, caption, kind)
{
    self thread menuPushNotification(title, caption, kind, 3.5);
}

menuShowNotificationTimed(title, caption, kind, duration)
{
    self thread menuPushNotification(title, caption, kind, duration);
}

/* Sends the same custom notification to every connected player. */
menuNotifyAll(title, caption, kind)
{
    for(i = 0; i < level.players.size; i++)
    {
        if(isDefined(level.players[i]))
        {
            level.players[i] menuShowNotification(title, caption, kind);
        }
    }
}

menuNotifyAllTimed(title, caption, kind, duration)
{
    for(i = 0; i < level.players.size; i++)
    {
        if(isDefined(level.players[i]))
        {
            level.players[i] menuShowNotificationTimed(title, caption, kind, duration);
        }
    }
}

menuPushNotification(title, caption, kind, duration)
{
    self endon("disconnect");
    if(!isDefined(duration) || duration < 1)
    {
        duration = 1;
    }
    else if(duration > 8)
    {
        duration = 8;
    }

    if(!isDefined(self.menuNotifications))
    {
        self.menuNotifications = [];
        self.menuNotificationCount = 0;
        self.menuNotificationId = 0;
    }

    safeCaption = self maps\mp\gametypes\menu::menuGetStaticMenuText(caption, 48);
    for(i = 0; i < self.menuNotificationCount; i++)
    {
        active = self.menuNotifications[i];
        if(isDefined(active) && active.captionText == safeCaption)
        {
            return;
        }
    }

    if(self.menuNotificationCount >= 2)
    {
        expiredNotification = self.menuNotifications[1];
        self.menuNotifications[1] = undefined;
        self.menuNotificationCount = 1;
        self thread menuSlideOutAndDestroyNotification(expiredNotification);
    }

    for(i = self.menuNotificationCount; i > 0; i--)
    {
        self.menuNotifications[i] = self.menuNotifications[i - 1];
    }

    self.menuNotificationId++;
    notification = self menuCreateNotification(self.menuNotificationId, title, caption, kind);
    self.menuNotifications[0] = notification;
    self.menuNotificationCount++;
    self menuReflowNotificationStack();
    self thread menuNotificationLifetime(notification.id, duration);
}

menuCreateNotification(id, title, caption, kind)
{
    notification = spawnStruct();
    notification.id = id;
    notification.slot = 0;
    notification.captionText = self maps\mp\gametypes\menu::menuGetStaticMenuText(caption, 48);
    notification.width = menuGetNotificationWidth(notification.captionText);
    notification.height = 32;
    notification.targetX = 320;
    notification.targetY = notification.height / 2;
    notification.offscreenY = 0 - (notification.height / 2) - 3;
    notification.textXOffset = 0 - (notification.width / 2) + 8;
    notification.borderYOffset = 0 - (notification.height / 2) + 1;
    notification.captionYOffset = 0;
    notification.elements = [];

    backgroundColor = self maps\mp\gametypes\menu::menuGetBackgroundColor();
    borderColor = self maps\mp\gametypes\menu::getMenuAccentColor();
    fallbackCaption = "Information updated.";
    if(kind == "success")
    {
        borderColor = (.08, .8, .28);
        fallbackCaption = "Action completed successfully.";
    }
    else if(kind == "error")
    {
        borderColor = (1, .16, .16);
        fallbackCaption = "The action could not be completed.";
    }
    else if(kind == "warning")
    {
        borderColor = (1, .78, .08);
        fallbackCaption = "Review this action.";
    }

    notification.background = self menuCreateNotificationRectangle(notification.targetX, notification.offscreenY, notification.width, notification.height, backgroundColor, self maps\mp\gametypes\menu::menuGetPanelOpacity(), 150);
    notification.border = self menuCreateNotificationRectangle(notification.targetX, notification.offscreenY + notification.borderYOffset, notification.width, 2, borderColor, 1, 152);
    notification.caption = self menuCreateNotificationText(notification.targetX + notification.textXOffset, notification.offscreenY + notification.captionYOffset, .9, self maps\mp\gametypes\menu::menuGetFontColor(), notification.captionText, fallbackCaption);
    notification.elements[0] = notification.background;
    notification.elements[1] = notification.border;
    notification.elements[2] = notification.caption;
    return notification;
}

/* Approximates content width and clamps it to the menu's normal panel width. */
menuGetNotificationWidth(caption)
{
    width = (caption.size * 5) + 16;
    if(width < 140)
    {
        width = 140;
    }
    menuWidth = maps\mp\gametypes\menu::getMenuPanelWidth();
    if(width > menuWidth)
    {
        width = menuWidth;
    }
    return width;
}

menuCreateNotificationRectangle(x, y, width, height, color, alpha, sort)
{
    elem = newClientHudElem(self);
    elem.elemType = "bar";
    elem.horzAlign = "fullscreen";
    elem.vertAlign = "fullscreen";
    elem.alignX = "center";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = alpha;
    elem.sort = sort;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    elem setShader("white", width, height);
    return elem;
}

menuCreateNotificationText(x, y, scale, color, text, fallback)
{
    elem = self createFontString(self maps\mp\gametypes\menu::menuGetFontName(), scale);
    elem.horzAlign = "fullscreen";
    elem.vertAlign = "fullscreen";
    elem.alignX = "left";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = 1;
    elem.sort = 153;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    elem setText(menuGetStableNotificationText(text, fallback));
    return elem;
}

/*
    Limits unique notification strings per map. IW4 stores HUD strings in a
    511-entry configstring table, so unlimited dynamic captions eventually
    cause G_FindConfigstringIndex overflow on long-running maps.
*/
menuGetStableNotificationText(text, fallback)
{
    if(!isDefined(level.menuNotificationTextCache))
    {
        level.menuNotificationTextCache = [];
        level.menuNotificationTextCount = 0;
    }

    for(i = 0; i < level.menuNotificationTextCount; i++)
    {
        if(level.menuNotificationTextCache[i] == text)
        {
            return text;
        }
    }

    if(level.menuNotificationTextCount >= 32)
    {
        return fallback;
    }

    level.menuNotificationTextCache[level.menuNotificationTextCount] = text;
    level.menuNotificationTextCount++;
    return text;
}

/* Places every panel directly after the previous panel with a five-pixel gap. */
menuReflowNotificationStack()
{
    if(!isDefined(self.menuNotifications) || !isDefined(self.menuNotificationCount))
    {
        return;
    }

    nextTop = 10;
    for(i = 0; i < self.menuNotificationCount; i++)
    {
        notification = self.menuNotifications[i];
        if(!isDefined(notification))
        {
            continue;
        }
        notification.slot = i;
        notification.targetY = nextTop + (notification.height / 2);
        self menuMoveNotificationElements(notification, notification.targetX, notification.targetY, .18);
        nextTop += notification.height + 5;
    }
}

menuMoveNotificationElements(notification, centerX, centerY, duration)
{
    if(!isDefined(notification) || !isDefined(notification.elements))
    {
        return;
    }
    targetXs = [];
    targetYs = [];
    targetXs[0] = centerX;
    targetYs[0] = centerY;
    targetXs[1] = centerX;
    targetYs[1] = centerY + notification.borderYOffset;
    targetXs[2] = centerX + notification.textXOffset;
    targetYs[2] = centerY + notification.captionYOffset;
    for(i = 0; i < notification.elements.size; i++)
    {
        if(isDefined(notification.elements[i]))
        {
            notification.elements[i] moveOverTime(duration);
            notification.elements[i].x = targetXs[i];
            notification.elements[i].y = targetYs[i];
        }
    }
}

menuNotificationLifetime(id, duration)
{
    self endon("disconnect");
    wait duration;
    self menuRemoveNotification(id);
}

menuRemoveNotification(id)
{
    if(!isDefined(self.menuNotifications) || !isDefined(self.menuNotificationCount))
    {
        return;
    }
    found = -1;
    for(i = 0; i < self.menuNotificationCount; i++)
    {
        if(isDefined(self.menuNotifications[i]) && self.menuNotifications[i].id == id)
        {
            found = i;
            break;
        }
    }
    if(found < 0)
    {
        return;
    }

    notification = self.menuNotifications[found];
    for(i = found + 1; i < self.menuNotificationCount; i++)
    {
        self.menuNotifications[i - 1] = self.menuNotifications[i];
    }
    self.menuNotifications[self.menuNotificationCount - 1] = undefined;
    self.menuNotificationCount--;
    self menuReflowNotificationStack();
    self menuSlideOutAndDestroyNotification(notification);
}

/* Slides a detached notification above the viewport, then frees every HUD element. */
menuSlideOutAndDestroyNotification(notification)
{
    if(!isDefined(notification))
    {
        return;
    }

    self menuMoveNotificationElements(notification, notification.targetX, notification.offscreenY, .2);
    wait .2;
    self menuDestroyNotification(notification);
}

menuDestroyNotification(notification)
{
    if(!isDefined(notification) || !isDefined(notification.elements))
    {
        return;
    }
    for(i = 0; i < notification.elements.size; i++)
    {
        if(isDefined(notification.elements[i]))
        {
            notification.elements[i] destroy();
            notification.elements[i] = undefined;
        }
    }
    notification.elements = [];
}

menuResetNotificationState()
{
    if(isDefined(self.menuNotifications))
    {
        for(i = 0; i < self.menuNotifications.size; i++)
        {
            if(isDefined(self.menuNotifications[i]))
            {
                self menuDestroyNotification(self.menuNotifications[i]);
            }
        }
    }

    self.menuNotifications = [];
    self.menuNotificationCount = 0;
    if(!isDefined(self.menuNotificationId))
    {
        self.menuNotificationId = 0;
    }
}

/*
    Opens a persistent, menu-styled confirmation notification. Destructive
    actions use Confirm/Abort; question-style actions use Yes/No. The normal
    menu remains closed until one of the two choices is made.
*/
menuOpenConfirmation(title, style, acceptFunction, acceptInput, parent)
{
    if(isDefined(self.menuConfirmationOpen) && self.menuConfirmationOpen)
    {
        return;
    }

    self menuResetNotificationState();
    self.menuConfirmation = spawnStruct();
    self.menuConfirmation.title = title;
    self.menuConfirmation.style = style;
    self.menuConfirmation.acceptFunction = acceptFunction;
    self.menuConfirmation.acceptInput = acceptInput;
    self.menuConfirmation.parent = parent;
    self.menuConfirmation.selected = 0;
    self.menuConfirmationOpen = true;
    self maps\mp\gametypes\menu::closeBaseMenu();
    self thread menuRunConfirmation();
}

menuRunConfirmation()
{
    self endon("disconnect");
    wait .32;

    if(!isDefined(self.menuConfirmationOpen) || !self.menuConfirmationOpen)
    {
        return;
    }

    self menuCreateConfirmationHud();
    self freezeControls(true);

    for(;;)
    {
        if(!isDefined(self.menuConfirmationOpen) || !self.menuConfirmationOpen)
        {
            return;
        }

        upPressed = self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["up"]);
        downPressed = self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["down"]);

        if(upPressed || downPressed)
        {
            self.menuConfirmation.selected = 1 - self.menuConfirmation.selected;
            self menuUpdateConfirmationSelection();
            activeBind = self.menuControlBinds["up"];
            if(downPressed)
            {
                activeBind = self.menuControlBinds["down"];
            }

            self maps\mp\gametypes\menu::waitMenuBindRelease(activeBind);
            wait .08;
        }
        else if(self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["select"]))
        {
            accepted = self.menuConfirmation.selected == 0;
            self menuResolveConfirmation(accepted);
            return;
        }
        else if(self maps\mp\gametypes\menu::menuCloseButtonPressed() || self MeleeButtonPressed())
        {
            self menuResolveConfirmation(false);
            return;
        }

        wait .05;
    }
}

menuCreateConfirmationHud()
{
    self menuDestroyConfirmationHud();
    self.menuConfirmationHud = [];
    viewportX = 320;
    viewportY = 240;
    slideOffset = -400;
    panelWidth = maps\mp\gametypes\menu::getMenuPanelWidth();
    panelTop = -58;
    headerSeparatorY = panelTop + 42;
    optionStartY = headerSeparatorY + 17;
    optionDistance = maps\mp\gametypes\menu::getMenuOptionDistance();
    lastOptionY = optionStartY + optionDistance;
    contentBottomY = lastOptionY + 11;
    footerSeparatorY = contentBottomY + maps\mp\gametypes\menu::getMenuContentEdgeGap() + 1;
    panelBottom = footerSeparatorY + 6;
    panelHeight = panelBottom - panelTop;
    panelCenterY = panelTop + (panelHeight / 2);
    textLeft = viewportX - (panelWidth / 2) + 10;
    optionLeft = viewportX - (panelWidth / 2) + 14;
    backgroundColor = self maps\mp\gametypes\menu::menuGetBackgroundColor();
    accentColor = self maps\mp\gametypes\menu::getMenuAccentColor();
    fontColor = self maps\mp\gametypes\menu::menuGetFontColor();
    selectionColor = self maps\mp\gametypes\menu::menuGetSelectionColor();
    yesLabel = "Confirm";
    noLabel = "Abort";

    if(self.menuConfirmation.style == "yesno")
    {
        yesLabel = "Yes";
        noLabel = "No";
    }

    targetYs = [];
    targetYs[0] = viewportY + panelCenterY;
    targetYs[1] = viewportY + panelTop + 1;
    targetYs[2] = viewportY + headerSeparatorY;
    targetYs[3] = viewportY + footerSeparatorY;
    targetYs[4] = viewportY + optionStartY;
    targetYs[5] = viewportY + panelTop + 20;
    targetYs[6] = viewportY + optionStartY;
    targetYs[7] = viewportY + lastOptionY;

    background = self menuCreateConfirmationRectangle(viewportX, targetYs[0] + slideOffset, panelWidth, panelHeight, backgroundColor, self maps\mp\gametypes\menu::menuGetPanelOpacity(), 170);
    topBorder = self menuCreateConfirmationRectangle(viewportX, targetYs[1] + slideOffset, panelWidth, 3, accentColor, 1, 172);
    headerBorder = self menuCreateConfirmationRectangle(viewportX, targetYs[2] + slideOffset, panelWidth, 2, accentColor, 1, 172);
    bottomBorder = self menuCreateConfirmationRectangle(viewportX, targetYs[3] + slideOffset, panelWidth, 2, accentColor, 1, 172);
    selector = self menuCreateConfirmationRectangle(viewportX, targetYs[4] + slideOffset, panelWidth, maps\mp\gametypes\menu::getMenuSelectionHeight(""), selectionColor, .95, 171);
    title = self menuCreateConfirmationText(textLeft, targetYs[5] + slideOffset, 1.2, fontColor, self.menuConfirmation.title, "CONFIRM ACTION");
    optionYes = self menuCreateConfirmationText(optionLeft, targetYs[6] + slideOffset, maps\mp\gametypes\menu::getMenuSelectedFontScale(), fontColor, yesLabel, yesLabel);
    optionNo = self menuCreateConfirmationText(optionLeft, targetYs[7] + slideOffset, maps\mp\gametypes\menu::getMenuDefaultFontScale(), fontColor, noLabel, noLabel);

    self.menuConfirmationHud[0] = background;
    self.menuConfirmationHud[1] = topBorder;
    self.menuConfirmationHud[2] = headerBorder;
    self.menuConfirmationHud[3] = bottomBorder;
    self.menuConfirmationHud[4] = selector;
    self.menuConfirmationHud[5] = title;
    self.menuConfirmationHud[6] = optionYes;
    self.menuConfirmationHud[7] = optionNo;
    self.menuConfirmationHud[7].alpha = .65;
    self.menuConfirmation.optionStartY = viewportY + optionStartY;
    self.menuConfirmation.optionDistance = optionDistance;

    for(i = 0; i < self.menuConfirmationHud.size; i++)
    {
        self.menuConfirmationHud[i] moveOverTime(.2);
        self.menuConfirmationHud[i].y = targetYs[i];
    }
}

menuCreateConfirmationRectangle(x, y, width, height, color, alpha, sort)
{
    elem = newClientHudElem(self);
    elem.elemType = "bar";
    elem.horzAlign = "fullscreen";
    elem.vertAlign = "fullscreen";
    elem.alignX = "center";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = alpha;
    elem.sort = sort;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    elem setShader("white", width, height);
    return elem;
}

menuCreateConfirmationText(x, y, scale, color, text, fallback)
{
    elem = self createFontString(self maps\mp\gametypes\menu::menuGetFontName(), scale);
    elem.horzAlign = "fullscreen";
    elem.vertAlign = "fullscreen";
    elem.alignX = "left";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = 1;
    elem.sort = 173;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    stableText = self maps\mp\gametypes\menu::menuGetStaticMenuText(text, 42);
    elem setText(menuGetStableNotificationText(stableText, fallback));
    return elem;
}

menuUpdateConfirmationSelection()
{
    if(!isDefined(self.menuConfirmationHud))
    {
        return;
    }

    selectionY = self.menuConfirmation.optionStartY + (self.menuConfirmation.selected * self.menuConfirmation.optionDistance);
    self.menuConfirmationHud[4] moveOverTime(.12);
    self.menuConfirmationHud[4].y = selectionY;
    self.menuConfirmationHud[6].alpha = .65;
    self.menuConfirmationHud[7].alpha = .65;
    self.menuConfirmationHud[6] changeFontScaleOverTime(.12);
    self.menuConfirmationHud[7] changeFontScaleOverTime(.12);
    self.menuConfirmationHud[6].fontscale = maps\mp\gametypes\menu::getMenuDefaultFontScale();
    self.menuConfirmationHud[7].fontscale = maps\mp\gametypes\menu::getMenuDefaultFontScale();
    self.menuConfirmationHud[6 + self.menuConfirmation.selected].alpha = 1;
    self.menuConfirmationHud[6 + self.menuConfirmation.selected] changeFontScaleOverTime(.12);
    self.menuConfirmationHud[6 + self.menuConfirmation.selected].fontscale = maps\mp\gametypes\menu::getMenuSelectedFontScale();
}

menuResolveConfirmation(accepted)
{
    if(!isDefined(self.menuConfirmation))
    {
        return;
    }

    acceptFunction = self.menuConfirmation.acceptFunction;
    acceptInput = self.menuConfirmation.acceptInput;
    parent = self.menuConfirmation.parent;
    self menuDestroyConfirmationHud();
    self freezeControls(false);

    while(self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["select"]) || self maps\mp\gametypes\menu::menuCloseButtonPressed() || self MeleeButtonPressed())
    {
        wait .05;
    }

    self.menuConfirmationOpen = false;
    self.menuConfirmation = undefined;

    if(accepted && isDefined(acceptFunction))
    {
        self [[acceptFunction]](acceptInput);
        return;
    }

    self maps\mp\gametypes\menu::openBaseMenu();
    if(isDefined(parent) && parent != "")
    {
        self maps\mp\gametypes\menu::loadBaseMenu(parent);
    }
}

menuDestroyConfirmationHud()
{
    if(!isDefined(self.menuConfirmationHud))
    {
        return;
    }

    for(i = 0; i < self.menuConfirmationHud.size; i++)
    {
        if(isDefined(self.menuConfirmationHud[i]))
        {
            self.menuConfirmationHud[i] destroy();
        }
    }

    self.menuConfirmationHud = undefined;
}

/* Clears modal state without reopening the menu during respawn/reinitialization. */
menuResetConfirmationState()
{
    self.menuConfirmationOpen = false;
    self menuDestroyConfirmationHud();
    self.menuConfirmation = undefined;
    self freezeControls(false);
}

/* Releases every auxiliary HUD and monitor when menu access is revoked. */
menuCleanupPlayerRuntime()
{
    if(isDefined(self.menuWatching) && self.menuWatching)
    {
        self menuStopWatching();
    }
    if(isDefined(self.menuKeepEyeActive) && self.menuKeepEyeActive)
    {
        self menuKeepEyeDisable();
    }
    if(isDefined(self.menuUfo) && self.menuUfo)
    {
        self menuExitUfo();
    }
    if(isDefined(self.menuHidden) && self.menuHidden)
    {
        self menuDisableHide();
    }

    self.menuServerStatusOpen = false;
    if(isDefined(self.menuRemoteRequestId))
    {
        self.menuRemoteRequestId++;
    }
    self notify("menu_server_status_stop");
    self notify("menu_remote_loading_restart");
    self menuDestroyServerStatusHud();
    self menuWatchEspDisable();
    self menuWatchTelemetryDisable();
    self menuKeepEyeHudDisable();
    self menuResetConfirmationState();
    self menuResetNotificationState();
}

/* Starts spectator tracking for the currently selected connected player. */
menuWatchSelectedPlayer(input)
{
    if(!isDefined(self.menu) || !isDefined(self.menu.selectedPlayer))
    {
        self menuShowNotification("PLAYER", "No player selected.", "error");
        return;
    }

    target = self.menu.selectedPlayer;

    if(!isDefined(target))
    {
        self menuShowNotification("PLAYER", "That player is no longer connected.", "error");
        return;
    }

    if(target == self)
    {
        self menuShowNotification("WATCH", "You cannot watch yourself.", "error");
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    self notify("menu_watch_stop");
    self thread menuWatchPlayer(target);
}

menuSendKickRequest(target, reason)
{
    self menuSendModerationRequest("kick", target, reason, "");
}

/* Sends an allow-listed self-service command to the IW4MAdmin plugin. */
menuSubmitSelfIw4mCommand(command)
{
    if(command != "mask")
    {
        return;
    }

    slot = self getEntityNumber();
    logPrint("[CWSADMIN] action=selfcommand origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + command + "\n");
    self maps\mp\gametypes\menu::closeBaseMenu();
}

/* Validates preset moderation choices and requests confirmation when required. */
menuSubmitPresetModeration(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    if(parts[0] == "kick" || parts[0] == "ban")
    {
        self menuOpenModerationConfirmation(input);
        return;
    }

    self menuSendModerationRequest(parts[0], target, parts[1], "");
}

menuOpenModerationConfirmation(input)
{
    parent = self.menu.current;
    self menuOpenConfirmation("CONFIRM MODERATION", "confirm", ::menuConfirmPresetModeration, input, parent);
}

menuConfirmPresetModeration(input)
{
    parts = strTok(input, "|");
    target = self menuGetSelectedPlayerForAction();
    if(parts.size < 2 || !isDefined(target))
    {
        return;
    }

    self menuSendModerationRequest(parts[0], target, parts[1], "");
}

menuSubmitSetLevel(levelName)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    self menuSendModerationRequest("setlevel", target, levelName, "");
}

menuSubmitCustomModeration(action)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    reason = menuGetCustomReason();

    if(reason == "")
    {
        self menuShowNotification("CUSTOM REASON", "Set cws_menu_custom_reason before continuing.", "warning");
        return;
    }

    if(action == "kick" || action == "ban")
    {
        self menuOpenModerationConfirmation(action + "|" + reason);
        return;
    }

    self menuSendModerationRequest(action, target, reason, "");
}

menuSetTempBanCustomReason(menu)
{
    reason = menuGetCustomReason();

    if(reason == "")
    {
        self menuShowNotification("CUSTOM REASON", "Set cws_menu_custom_reason before continuing.", "warning");
        return;
    }

    self.menuTempBanReason = reason;
    self.menu.text[menu][0] = "Reason: Custom";
    self menuShowNotification("CUSTOM REASON", "Reason updated: " + reason, "success");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuGetCustomReason()
{
    reason = getDvar("cws_menu_custom_reason");

    if(!isDefined(reason))
    {
        return "";
    }

    if(reason == "" || reason == "0")
    {
        return "";
    }

    return reason;
}

/* Builds temporary punishment settings for reason and duration selection. */
menuOpenTempBanSettings(menu)
{
    self.menuTempBanReason = "Cheating";
    self.menuTempBanDuration = "1h";
    self.menu.text[menu][0] = "Reason: Cheating";
    self.menu.text[menu][1] = "Duration: 1 Hour";
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSetTempBanReason(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    menu = parts[0];
    self.menuTempBanReason = parts[1];
    self.menu.text[menu][0] = "Reason: " + parts[1];
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSetTempBanDuration(input)
{
    parts = strTok(input, "|");

    if(parts.size < 3)
    {
        return;
    }

    menu = parts[0];
    self.menuTempBanDuration = parts[1];
    self.menu.text[menu][1] = "Duration: " + parts[2];
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSubmitTempBan(menu)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    if(!isDefined(self.menuTempBanReason))
    {
        self.menuTempBanReason = "Cheating";
    }

    if(!isDefined(self.menuTempBanDuration))
    {
        self.menuTempBanDuration = "1h";
    }

    parent = self.menu.current;
    self.menuPendingTempBanParent = parent;
    self menuOpenConfirmation("CONFIRM TEMP BAN", "confirm", ::menuConfirmTempBan, "", parent);
}

menuConfirmTempBan(input)
{
    target = self menuGetSelectedPlayerForAction();
    if(!isDefined(target) || !isDefined(self.menuTempBanReason) || !isDefined(self.menuTempBanDuration))
    {
        return;
    }

    self menuSendModerationRequest("tempban", target, self.menuTempBanReason, self.menuTempBanDuration);
}

menuOpenTempMuteSettings(menu)
{
    self.menuTempMuteReason = "Toxic Behavior";
    self.menuTempMuteDuration = "1h";
    self.menu.text[menu][0] = "Reason: Toxic Behavior";
    self.menu.text[menu][1] = "Duration: 1 Hour";
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSetTempMuteReason(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    menu = parts[0];
    self.menuTempMuteReason = parts[1];
    self.menu.text[menu][0] = "Reason: " + parts[1];
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSetTempMuteDuration(input)
{
    parts = strTok(input, "|");

    if(parts.size < 3)
    {
        return;
    }

    menu = parts[0];
    self.menuTempMuteDuration = parts[1];
    self.menu.text[menu][1] = "Duration: " + parts[2];
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSubmitTempMute(menu)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    if(!isDefined(self.menuTempMuteReason))
    {
        self.menuTempMuteReason = "Toxic Behavior";
    }

    if(!isDefined(self.menuTempMuteDuration))
    {
        self.menuTempMuteDuration = "1h";
    }

    self menuSendModerationRequest("tempmute", target, self.menuTempMuteReason, self.menuTempMuteDuration);
}

/* Serializes a moderation request into the server log for C# processing. */
menuSendModerationRequest(action, target, reason, duration)
{
    if(!isDefined(target))
    {
        self menuShowNotification("MODERATION", "That player disconnected.", "error");
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    logPrint("[CWSADMIN] action=" + action + " origin=" + menuActionPlayerGuid(self) + " origin_slot=" + self getEntityNumber() + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + " duration=" + duration + " reason=\"" + reason + "\"\n");
    self menuShowNotification("MODERATION", "Request sent to IW4MAdmin.", "success");
}

menuActionPlayerGuid(player)
{
    if(isDefined(player.guid))
    {
        return "" + player.guid;
    }

    return "unknown";
}

menuSetHudTextIfChanged(hud, text, fallback)
{
    if(!isDefined(hud))
    {
        return;
    }

    text = menuGetStableTelemetryText(text, fallback);

    if(!isDefined(hud.menuLastText) || hud.menuLastText != text)
    {
        hud setText(text);
        hud.menuLastText = text;
    }
}

/* Bounds dynamic spectator labels so changing player names cannot exhaust HUD strings. */
menuGetStableTelemetryText(text, fallback)
{
    if(!isDefined(text))
    {
        return "";
    }

    if(!isDefined(fallback) || fallback == "")
    {
        fallback = "Player information updated.";
    }

    if(!isDefined(level.menuTelemetryTextCache))
    {
        level.menuTelemetryTextCache = [];
        level.menuTelemetryTextCount = 0;
    }

    for(i = 0; i < level.menuTelemetryTextCount; i++)
    {
        if(level.menuTelemetryTextCache[i] == text)
        {
            return text;
        }
    }

    if(level.menuTelemetryTextCount >= 32)
    {
        return fallback;
    }

    level.menuTelemetryTextCache[level.menuTelemetryTextCount] = text;
    level.menuTelemetryTextCount++;
    return text;
}

/* Executes an allow-listed command selected from the Server menu. */
menuRunServerCommand(command)
{
    self maps\mp\gametypes\menu::closeBaseMenu();
    Exec(command);
}

menuOpenDragnetView(input)
{
    self thread menuFetchRemoteRows("dragnet", input);
}

menuOpenBanManagement(input)
{
    self thread menuFetchRemoteRows("bans", "banlist|bans|0");
}

menuOpenServerHealth(input)
{
    self thread menuFetchRemoteRows("health", "health|health|0");
}

menuOpenSelectedPlayerHistory(input)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    self thread menuFetchRemoteRows("history", "history|history|0");
}

menuOpenSelectedPlayerTotals(input)
{
    target = self menuGetSelectedPlayerForAction();
    if(!isDefined(target))
    {
        return;
    }
    self thread menuFetchRemoteRows("totals", "totals|totals|0");
}

/* Loads the selected player's known aliases and addresses into a generated menu. */
menuOpenSelectedPlayerKnown(input)
{
    target = self menuGetSelectedPlayerForAction();
    if(!isDefined(target))
    {
        return;
    }
    self thread menuFetchRemoteRows("known", "playerknown|known|0");
}

/* Loads the selected player's ban state and recent ban records into a menu. */
menuOpenSelectedPlayerBanInfo(input)
{
    target = self menuGetSelectedPlayerForAction();
    if(!isDefined(target))
    {
        return;
    }
    self thread menuFetchRemoteRows("baninfo", "playerbaninfo|baninfo|0");
}

menuOpenAuditLog(input)
{
    self thread menuFetchRemoteRows("audit", "audit|audit|0");
}

menuOpenReportsInbox(input)
{
    self thread menuFetchRemoteRows("reports", "reports|reports|0");
}

menuOpenServerList(input)
{
    self thread menuFetchRemoteRows("servers", "servers|servers|0");
}

menuOpenMapRotation(input)
{
    self thread menuFetchRemoteRows("rotation", "rotation|rotation|0");
}

/* Requests remote data and displays loading feedback until rows arrive. */
menuFetchRemoteRows(kind, input)
{
    self endon("disconnect");
    parts = strTok(input, "|");

    if(parts.size < 3)
    {
        return;
    }

    command = parts[0];
    view = parts[1];
    page = parts[2];
    slot = self getEntityNumber();
    self.menuRemoteParent = self.menu.current;
    requestParent = self.menuRemoteParent;

    if(!isDefined(self.menuRemoteRequestId))
    {
        self.menuRemoteRequestId = 0;
    }
    self.menuRemoteRequestId++;
    requestId = self.menuRemoteRequestId;

    target = undefined;
    if(kind == "history" || kind == "totals" || kind == "known" || kind == "baninfo")
    {
        target = self menuGetSelectedPlayerForAction();
        if(!isDefined(target))
        {
            self menuShowNotification("PLAYER UNAVAILABLE", "That player disconnected.", "error");
            return;
        }
    }

    self menuShowRemoteLoading(kind);
    revisionDvar = "cws_dragnet_revision_" + slot;
    oldRevision = getDvar(revisionDvar);

    if(kind == "bans")
    {
        logPrint("[CWSADMIN] action=banlist origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + "\n");
    }
    else if(kind == "health")
    {
        logPrint("[CWSADMIN] action=serverhealth origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + "\n");
    }
    else if(kind == "history")
    {
        logPrint("[CWSADMIN] action=playerhistory origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + "\n");
    }
    else if(kind == "totals")
    {
        logPrint("[CWSADMIN] action=playertotals origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + "\n");
    }
    else if(kind == "known" || kind == "baninfo")
    {
        logPrint("[CWSADMIN] action=" + command + " origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + "\n");
    }
    else if(kind == "audit")
    {
        logPrint("[CWSADMIN] action=auditlog origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + "\n");
    }
    else if(kind == "reports")
    {
        logPrint("[CWSADMIN] action=reports origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + "\n");
    }
    else if(kind == "servers")
    {
        logPrint("[CWSADMIN] action=serverlist origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + "\n");
    }
    else if(kind == "rotation")
    {
        logPrint("[CWSADMIN] action=rotation origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + "\n");
    }
    else
    {
        logPrint("[CWSADMIN] action=dragnet origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + command + " view=" + view + " page=" + page + "\n");
    }

    for(i = 0; i < 80; i++)
    {
        if(!isDefined(self.menuRemoteRequestId) || self.menuRemoteRequestId != requestId)
        {
            return;
        }

        if(getDvar(revisionDvar) != oldRevision)
        {
            break;
        }

        wait .05;
    }

    if(!isDefined(self.menuRemoteRequestId) || self.menuRemoteRequestId != requestId)
    {
        return;
    }

    if(!self maps\mp\gametypes\menu::isMenuOpen() || !isDefined(self.menu.current) || self.menu.current != "remote_data_loading")
    {
        return;
    }

    if(getDvar(revisionDvar) == oldRevision)
    {
        parent = "iw4madmin_menu";
        if(isDefined(requestParent) && requestParent != "")
        {
            parent = requestParent;
        }
        self menuHandleRemoteTimeout(parent);
        return;
    }

    if(kind == "bans")
    {
        self menuBuildBanResults();
    }
    else if(kind == "reports")
    {
        self menuBuildReportsResults();
    }
    else if(kind == "health" || kind == "history" || kind == "totals" || kind == "known" || kind == "baninfo" || kind == "audit" || kind == "servers" || kind == "rotation")
    {
        self menuBuildRemoteInfoResults(kind);
    }
    else
    {
        self menuBuildDragnetResults();
    }
}

menuShowRemoteLoading(kind)
{
    self notify("menu_remote_loading_restart");
    menu = "remote_data_loading";
    title = "Dragnet";
    parent = "dragnet_menu";
    description = "Fetching Dragnet records from IW4MAdmin.";

    if(kind == "bans")
    {
        title = "Ban Management";
        parent = "iw4madmin_menu";
        description = "Fetching active bans from IW4MAdmin.";
    }
    else if(kind == "health")
    {
        title = "Server Health";
        parent = "iw4madmin_menu";
        description = "Fetching live IW4MAdmin server state.";
    }
    else if(kind == "history")
    {
        title = "Moderation History";
        parent = self.menuRemoteParent;
        description = "Fetching this player's moderation history.";
    }
    else if(kind == "totals")
    {
        title = "Warnings & Penalties";
        parent = self.menuRemoteParent;
        description = "Counting this player's IW4MAdmin records.";
    }
    else if(kind == "known")
    {
        title = "Known Aliases";
        parent = self.menuRemoteParent;
        description = "Fetching this player's known names and addresses.";
    }
    else if(kind == "baninfo")
    {
        title = "Ban Info";
        parent = self.menuRemoteParent;
        description = "Fetching this player's IW4MAdmin ban records.";
    }
    else if(kind == "audit")
    {
        title = "Moderation Audit";
        parent = "iw4madmin_menu";
        description = "Fetching recent moderation activity.";
    }
    else if(kind == "reports")
    {
        title = "Reports Inbox";
        parent = "iw4madmin_menu";
        description = "Fetching unresolved player reports.";
    }
    else if(kind == "servers")
    {
        title = "Managed Servers";
        parent = "iw4madmin_menu";
        description = "Fetching live server player counts.";
    }
    else if(kind == "rotation")
    {
        title = "Map Rotation";
        parent = "iw4m_rotation_menu";
        description = "Fetching the active map rotation.";
    }
    else if(kind == "action")
    {
        title = "Dragnet Action";
        parent = "dragnet_menu";
        description = "Waiting for Dragnet to complete the confirmed action.";
    }

    self maps\mp\gametypes\menu::menuCreateMenu(menu, title, parent);
    self maps\mp\gametypes\menu::menuAddOption(menu, 0, "Fetching records [|]", ::menuNoRemoteAction, "", description);
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
    self thread menuAnimateRemoteLoading(menu);
}

menuAnimateRemoteLoading(menu)
{
    self endon("disconnect");
    self endon("menu_remote_loading_restart");
    frames = [];
    frames[0] = "[|]";
    frames[1] = "[/]";
    frames[2] = "[-]";
    frames[3] = "[\\]";
    frame = 0;

    while(isDefined(self.menu) && isDefined(self.menu.current) && self.menu.current == menu)
    {
        loadingText = "Fetching records " + frames[frame];
        self.menu.text[menu][0] = loadingText;

        if(isDefined(self.menuHud) && isDefined(self.menuHud.text) && self.menuHud.text.size > 0 && isDefined(self.menuHud.text[0]))
        {
            self maps\mp\gametypes\menu::menuSetTextIfChanged(self.menuHud.text[0], loadingText);
        }

        frame++;
        if(frame >= frames.size)
        {
            frame = 0;
        }

        wait .15;
    }
}

/* Converts Dragnet rows into peer, event, identity, and action menus. */
menuBuildDragnetResults()
{
    slot = self getEntityNumber();
    title = getDvar("cws_dragnet_title_" + slot);
    view = getDvar("cws_dragnet_view_" + slot);
    page = getDvarInt("cws_dragnet_page_" + slot);
    pages = getDvarInt("cws_dragnet_pages_" + slot);
    menu = "dragnet_results";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, title, "dragnet_menu");
    option = 0;

    for(i = 0; i < 10; i++)
    {
        row = getDvar("cws_dragnet_row_" + slot + "_" + i);

        if(row == "")
        {
            continue;
        }

        rowParts = strTok(row, "~");
        label = rowParts[0];
        description = row;

        if(rowParts.size > 1)
        {
            description = rowParts[1];
        }

        if(view == "peers" && rowParts.size > 1)
        {
            self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, label, ::menuNoRemoteAction, "", description);
        }
        else if((view == "pending" || view == "lifts") && rowParts.size > 1)
        {
            self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, label, ::menuOpenDragnetEventDetails, row, description);
        }
        else
        {
            self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, label, ::menuNoRemoteAction, "", description);
        }
        option++;
    }

    if(page > 0)
    {
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Previous Page", ::menuOpenDragnetView, "prev|" + view + "|" + page, "Load the previous page.");
        option++;
    }

    if(page + 1 < pages)
    {
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Next Page", ::menuOpenDragnetView, "next|" + view + "|" + page, "Load the next page.");
        option++;
    }

    self maps\mp\gametypes\menu::menuAddOption(menu, option, "Refresh", ::menuOpenDragnetView, "refresh|" + view + "|" + page, "Refresh this Dragnet view.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuOpenDragnetEventDetails(input)
{
    rowParts = strTok(input, "~");
    if(rowParts.size < 2)
    {
        return;
    }

    menu = "dragnet_event_details";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, rowParts[0], "dragnet_results");
    details = strTok(rowParts[1], "|");
    eventId = "";
    isPending = false;
    option = 0;

    for(i = 0; i < details.size; i++)
    {
        self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, details[i], ::menuNoRemoteAction, "", details[i]);
        option++;

        if(details[i].size > 10 && getSubStr(details[i], 0, 9) == "Event ID:")
        {
            eventId = getSubStr(details[i], 10, details[i].size);
        }

        if(details[i] == "Review state: PendingBan" || details[i] == "Review state: PendingLift")
        {
            isPending = true;
        }
    }

    if(eventId != "" && isPending)
    {
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Approve", ::menuOpenDragnetConfirmation, "approve|" + eventId, "Approve and import this pending Dragnet event.");
        option++;
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Reject", ::menuOpenDragnetConfirmation, "reject|" + eventId, "Reject this pending Dragnet event.");
    }

    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuOpenDragnetConfirmation(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }

    self.menuPendingDragnetAction = input;
    self.menuPendingDragnetParent = self.menu.current;
    self menuOpenConfirmation("CONFIRM ACTION", "confirm", ::menuSubmitDragnetAction, input, self.menuPendingDragnetParent);
}

menuSubmitDragnetAction(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }

    slot = self getEntityNumber();
    oldRevision = getDvar("cws_dragnet_revision_" + slot);
    logPrint("[CWSADMIN] action=dragnetaction origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + parts[0] + " id=" + parts[1] + "\n");
    self thread menuWaitForRemoteAction(oldRevision, parts[0]);
}

menuWaitForRemoteAction(oldRevision, action)
{
    self endon("disconnect");
    slot = self getEntityNumber();

    for(i = 0; i < 120; i++)
    {
        if(getDvar("cws_dragnet_revision_" + slot) != oldRevision)
        {
            result = getDvar("cws_dragnet_row_" + slot + "_0");
            if(result == "")
            {
                result = "Dragnet action completed.";
            }
            kind = "success";
            if(menuDragnetResultIsError(result))
            {
                kind = "error";
            }
            self menuShowNotification("DRAGNET", result, kind);
            return;
        }

        wait .05;
    }

    parent = "dragnet_menu";
    if(isDefined(self.menuPendingDragnetParent) && self.menuPendingDragnetParent != "")
    {
        parent = self.menuPendingDragnetParent;
    }
    self menuHandleRemoteTimeout(parent);
}

menuDragnetResultIsError(result)
{
    if(result == "Dragnet peer was not found." || result == "That Dragnet menu action is not supported." || result == "Dragnet is still starting. Try again shortly.")
    {
        return true;
    }
    if(result.size >= 5 && getSubStr(result, 0, 5) == "Could")
    {
        return true;
    }
    if(result.size >= 14 && getSubStr(result, 0, 14) == "Dragnet action")
    {
        return true;
    }
    return false;
}

menuBuildRemoteInfoResults(kind)
{
    slot = self getEntityNumber();
    title = getDvar("cws_dragnet_title_" + slot);
    menu = "remote_info_results";
    parent = "iw4madmin_menu";

    if((kind == "history" || kind == "totals" || kind == "known" || kind == "baninfo") && isDefined(self.menuRemoteParent))
    {
        parent = self.menuRemoteParent;
    }
    else if(kind == "action")
    {
        parent = "dragnet_menu";
    }
    else if(kind == "rotation")
    {
        parent = "iw4m_rotation_menu";
    }

    self maps\mp\gametypes\menu::menuCreateMenu(menu, title, parent);
    option = 0;
    for(i = 0; i < 10; i++)
    {
        row = getDvar("cws_dragnet_row_" + slot + "_" + i);
        if(row == "")
        {
            continue;
        }

        rowParts = strTok(row, "~");
        description = row;
        if(rowParts.size > 1)
        {
            description = rowParts[1];
        }
        self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, rowParts[0], ::menuNoRemoteAction, "", description);
        option++;
    }
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

/* Builds the reports inbox and its resolve or dismiss actions. */
menuBuildReportsResults()
{
    slot = self getEntityNumber();
    menu = "reports_inbox_results";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Reports Inbox", "iw4madmin_menu");
    option = 0;

    for(i = 0; i < 10; i++)
    {
        row = getDvar("cws_dragnet_row_" + slot + "_" + i);
        if(row == "")
        {
            continue;
        }

        parts = strTok(row, "~");
        if(parts.size < 3)
        {
            self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, parts[0], ::menuNoRemoteAction, "", row);
            option++;
            continue;
        }

        reportId = parts[0];
        targetName = parts[1];
        reporter = parts[2];
        reason = "No reason supplied";
        created = "";
        if(parts.size > 3)
        {
            reason = parts[3];
        }
        if(parts.size > 4)
        {
            created = parts[4];
        }

        detailMenu = "report_detail_" + i;
        self maps\mp\gametypes\menu::menuCreateMenu(detailMenu, targetName, menu);
        self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, targetName, ::menuOpenGeneratedMenu, detailMenu, reason);
        self maps\mp\gametypes\menu::menuAddDetailedOption(detailMenu, 0, "Reporter", ::menuNoRemoteAction, "", reporter);
        self maps\mp\gametypes\menu::menuAddDetailedOption(detailMenu, 1, "Reason", ::menuNoRemoteAction, "", reason);
        self maps\mp\gametypes\menu::menuAddDetailedOption(detailMenu, 2, "Created", ::menuNoRemoteAction, "", created);

        if(reportId != "0")
        {
            self maps\mp\gametypes\menu::menuAddOption(detailMenu, 3, "Resolve", ::menuOpenReportConfirmation, "resolved|" + reportId, "Mark this report resolved after staff action.");
            self maps\mp\gametypes\menu::menuAddOption(detailMenu, 4, "Dismiss", ::menuOpenReportConfirmation, "dismissed|" + reportId, "Dismiss this report without further action.");
        }
        option++;
    }

    self maps\mp\gametypes\menu::menuAddOption(menu, option, "Refresh", ::menuOpenReportsInbox, "", "Refresh unresolved reports.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuOpenReportConfirmation(input)
{
    parent = self.menu.current;
    self menuOpenConfirmation("REPORT ACTION", "yesno", ::menuSubmitReportAction, input, parent);
}

menuSubmitReportAction(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }
    slot = self getEntityNumber();
    oldRevision = getDvar("cws_dragnet_revision_" + slot);
    logPrint("[CWSADMIN] action=reportaction origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + parts[0] + " id=" + parts[1] + "\n");
    self thread menuWaitForIw4mRefresh(oldRevision, "reports", parts[0]);
}

menuOpenRotationConfirmation(command)
{
    parent = self.menu.current;
    self menuOpenConfirmation("CONFIRM ROTATION", "confirm", ::menuSubmitRotationAction, command, parent);
}

menuSubmitRotationAction(command)
{
    slot = self getEntityNumber();
    oldRevision = getDvar("cws_dragnet_revision_" + slot);
    logPrint("[CWSADMIN] action=rotationaction origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + command + "\n");
    self thread menuWaitForIw4mRefresh(oldRevision, "rotation", command);
}

menuWaitForIw4mRefresh(oldRevision, kind, action)
{
    self endon("disconnect");
    slot = self getEntityNumber();
    for(i = 0; i < 120; i++)
    {
        if(getDvar("cws_dragnet_revision_" + slot) != oldRevision)
        {
            if(kind == "reports")
            {
                result = "Report updated.";
                if(action == "resolved")
                {
                    result = "Report marked as resolved.";
                }
                else if(action == "dismissed")
                {
                    result = "Report dismissed.";
                }
                self menuShowNotification("REPORT", result, "success");
            }
            else
            {
                result = "Map rotation updated.";
                if(action == "rotate")
                {
                    result = "Map rotation requested.";
                }
                self menuShowNotification("ROTATION", result, "success");
            }
            return;
        }
        wait .05;
    }

    parent = "iw4madmin_menu";
    if(kind == "rotation")
    {
        parent = "iw4m_rotation_menu";
    }
    self menuHandleRemoteTimeout(parent);
}

/* Builds ban-management rows and unban confirmation screens. */
menuBuildBanResults()
{
    slot = self getEntityNumber();
    menu = "ban_management_results";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Ban Management", "iw4madmin_menu");
    option = 0;

    for(i = 0; i < 10; i++)
    {
        row = getDvar("cws_dragnet_row_" + slot + "_" + i);

        if(row == "")
        {
            continue;
        }

        rowParts = strTok(row, "~");

        if(rowParts.size < 3)
        {
            continue;
        }

        offenderId = rowParts[0];
        playerName = rowParts[1];
        reason = rowParts[2];
        expiry = "";

        if(rowParts.size > 3)
        {
            expiry = rowParts[3];
        }

        detailMenu = "ban_management_" + i;
        self maps\mp\gametypes\menu::menuCreateMenu(detailMenu, playerName, menu);
        self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, playerName, ::menuOpenGeneratedMenu, detailMenu, reason);
        self maps\mp\gametypes\menu::menuAddDetailedOption(detailMenu, 0, "Reason", ::menuNoRemoteAction, "", reason);
        self maps\mp\gametypes\menu::menuAddDetailedOption(detailMenu, 1, "Expiry", ::menuNoRemoteAction, "", expiry);

        if(offenderId != "0")
        {
            self maps\mp\gametypes\menu::menuAddOption(detailMenu, 2, "Unban", ::menuOpenUnbanConfirmation, offenderId, "Remove this active ban.");
        }

        option++;
    }

    self maps\mp\gametypes\menu::menuAddOption(menu, option, "Refresh", ::menuOpenBanManagement, "", "Refresh active bans.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuOpenGeneratedMenu(menu)
{
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSubmitUnbanId(offenderId)
{
    slot = self getEntityNumber();
    oldRevision = getDvar("cws_dragnet_revision_" + slot);
    logPrint("[CWSADMIN] action=unbanid origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " offender_id=" + offenderId + "\n");
    self thread menuWaitForBanRefresh(oldRevision);
}

menuOpenUnbanConfirmation(offenderId)
{
    parent = self.menu.current;
    self menuOpenConfirmation("CONFIRM UNBAN", "yesno", ::menuSubmitUnbanId, offenderId, parent);
}

menuWaitForBanRefresh(oldRevision)
{
    self endon("disconnect");
    slot = self getEntityNumber();

    for(i = 0; i < 80; i++)
    {
        if(getDvar("cws_dragnet_revision_" + slot) != oldRevision)
        {
            self menuShowNotification("BAN MANAGEMENT", "Player unbanned.", "success");
            return;
        }

        wait .05;
    }

    self menuHandleRemoteTimeout("iw4madmin_menu");
}

menuHandleRemoteTimeout(parent)
{
    self menuShowNotification("REQUEST TIMEOUT", "IW4MAdmin did not respond. Try again.", "error");

    if(self maps\mp\gametypes\menu::isMenuOpen() && isDefined(parent) && parent != "")
    {
        self maps\mp\gametypes\menu::loadBaseMenu(parent);
    }
}

menuNoRemoteAction(input)
{
}

/* Applies the map selected from the server controls. */
menuChangeMap(mapName)
{
    self maps\mp\gametypes\menu::closeBaseMenu();
    Exec("map " + mapName);
}

menuChangeGametype(gametype)
{
    self maps\mp\gametypes\menu::closeBaseMenu();
    Exec("g_gametype " + gametype + "; map_restart");
}

menuShowServerStatus(input)
{
    if(isDefined(self.menuServerStatusOpen) && self.menuServerStatusOpen)
    {
        self.menuServerStatusOpen = false;
        self notify("menu_server_status_stop");
        self menuDestroyServerStatusHud();
        self menuShowNotification("SERVER INFO", "Server details hidden.", "info");
        return;
    }

    self notify("menu_server_status_stop");
    self.menuServerStatusOpen = true;
    self thread menuServerStatusHudLoop();
    self menuShowNotification("SERVER INFO", "Server details shown.", "success");
}

menuServerStatusHudLoop()
{
    self endon("disconnect");
    self endon("menu_server_status_stop");

    self menuDestroyServerStatusHud();
    self.menuServerStatusHud = [];
    self.menuServerStatusDecor = [];

    self.menuServerStatusDecor[self.menuServerStatusDecor.size] = self menuCreateServerStatusRectangle(0, 0, 1, 1, (0, 0, 0), .82, 20);
    self.menuServerStatusDecor[self.menuServerStatusDecor.size] = self menuCreateServerStatusRectangle(0, 0, 1, 1, (.01, .05, .025), .9, 21);
    self.menuServerStatusDecor[self.menuServerStatusDecor.size] = self menuCreateServerStatusRectangle(0, 0, 1, 1, (.15, .65, 1), 1, 22);

    title = self createFontString("objective", 1.35);
    title.horzAlign = "fullscreen";
    title.vertAlign = "fullscreen";
    title.alignX = "center";
    title.alignY = "middle";
    title.foreground = true;
    title.sort = 23;
    title.alpha = .95;
    title.color = (1, 1, 1);
    title setText("SERVER INFO");
    self.menuServerStatusHud[self.menuServerStatusHud.size] = title;

    body = self createFontString("default", 1);
    body.horzAlign = "fullscreen";
    body.vertAlign = "fullscreen";
    body.alignX = "left";
    body.alignY = "top";
    body.foreground = true;
    body.sort = 23;
    body.alpha = .9;
    body.color = (.85, .9, .85);
    self.menuServerStatusHud[self.menuServerStatusHud.size] = body;

    while(isDefined(self.menuServerStatusOpen) && self.menuServerStatusOpen)
    {
        players = 0;

        if(isDefined(level.players))
        {
            players = level.players.size;
        }

        maxClients = getDvar("sv_maxclients");

        if(maxClients == "")
        {
            maxClients = getDvar("com_maxclients");
        }

        host = getDvar("sv_hostname");

        if(host == "")
        {
            host = "Unknown";
        }

        rows = [];
        rows[0] = host;
        rows[1] = "Players: " + players + "/" + maxClients + " | Private: " + getDvar("sv_privateclients");
        rows[2] = "Map: " + getDvar("mapname") + " | " + getDvar("g_gametype");
        rows[3] = "Mod: " + getDvar("fs_game");
        rows[4] = "Time: " + menuGetCurrentGametypeDvar("timelimit") + " | Score: " + menuGetCurrentGametypeDvar("scorelimit");
        rows[5] = "Rounds: " + getDvar("scr_game_roundlimit") + " | Wins: " + getDvar("scr_game_winlimit");
        rows[6] = "Hardcore: " + getDvar("g_hardcore") + " | Killcam: " + getDvar("scr_game_allowkillcam");
        rows[7] = "Friendly Fire: " + getDvar("scr_team_fftype") + " | XP: " + getDvar("scr_xpscale");
        rows[8] = "Gravity: " + getDvar("g_gravity") + " | Speed: " + getDvar("g_speed");
        rows[9] = "Jump Height: " + getDvar("jump_height");
        rotationState = "Not configured";

        if(getDvar("sv_maprotationcurrent") != "")
        {
            rotationState = "Configured";
        }

        rows[10] = "Rotation: " + rotationState;
        rows[11] = "Select Server Status to hide";

        longest = "SERVER INFO".size;

        for(i = 0; i < rows.size; i++)
        {
            if(rows[i].size > longest)
            {
                longest = rows[i].size;
            }
        }

        panelWidth = 12 + (longest * 3);

        if(panelWidth < 96)
        {
            panelWidth = 96;
        }

        lineSpacing = 13;
        panelHeight = 42 + (rows.size * lineSpacing);
        panelLeftX = 5;
        panelCenterX = panelLeftX + (panelWidth / 2);
        panelTop = 105;
        panelCenterY = panelTop + (panelHeight / 2);
        textLeft = panelLeftX + 6;

        self.menuServerStatusDecor[0].x = panelLeftX;
        self.menuServerStatusDecor[0].y = panelCenterY;
        self.menuServerStatusDecor[0] setShader("white", panelWidth, panelHeight);
        self.menuServerStatusDecor[1].x = panelLeftX;
        self.menuServerStatusDecor[1].y = panelTop + 16;
        self.menuServerStatusDecor[1] setShader("white", panelWidth, 32);
        self.menuServerStatusDecor[2].x = panelLeftX;
        self.menuServerStatusDecor[2].y = panelTop + 1;
        self.menuServerStatusDecor[2] setShader("white", panelWidth, 3);

        title.x = panelCenterX;
        title.y = panelTop + 18;
        bodyText = rows[0];

        for(i = 1; i < rows.size; i++)
        {
            bodyText += "\n" + rows[i];
        }

        self.menuServerStatusHud[1].x = textLeft;
        self.menuServerStatusHud[1].y = panelTop + 42;

        stableBodyText = menuGetStableServerStatusText(bodyText);
        if(!isDefined(self.menuServerStatusBodyText) || self.menuServerStatusBodyText != stableBodyText)
        {
            self.menuServerStatusHud[1] setText(stableBodyText);
            self.menuServerStatusBodyText = stableBodyText;
        }

        wait .5;
    }

    self menuDestroyServerStatusHud();
}

/* Caps live server-panel combinations on long-running maps. */
menuGetStableServerStatusText(text)
{
    if(!isDefined(level.menuServerStatusTextCache))
    {
        level.menuServerStatusTextCache = [];
        level.menuServerStatusTextCount = 0;
    }

    for(i = 0; i < level.menuServerStatusTextCount; i++)
    {
        if(level.menuServerStatusTextCache[i] == text)
        {
            return text;
        }
    }

    if(level.menuServerStatusTextCount >= 24)
    {
        return "Server information changed. Reopen this panel after the next map.";
    }

    level.menuServerStatusTextCache[level.menuServerStatusTextCount] = text;
    level.menuServerStatusTextCount++;
    return text;
}

menuCreateServerStatusRectangle(x, y, width, height, color, alpha, sort)
{
    elem = newClientHudElem(self);
    elem.elemType = "bar";
    elem.horzAlign = "fullscreen";
    elem.vertAlign = "fullscreen";
    elem.alignX = "left";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = alpha;
    elem.sort = sort;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    elem setShader("white", width, height);
    return elem;
}

menuDestroyServerStatusHud()
{
    if(isDefined(self.menuServerStatusHud))
    {
        for(i = 0; i < self.menuServerStatusHud.size; i++)
        {
            if(isDefined(self.menuServerStatusHud[i]))
            {
                self.menuServerStatusHud[i] destroy();
            }
        }
    }

    self.menuServerStatusHud = undefined;
    self.menuServerStatusBodyText = undefined;

    if(isDefined(self.menuServerStatusDecor))
    {
        for(i = 0; i < self.menuServerStatusDecor.size; i++)
        {
            if(isDefined(self.menuServerStatusDecor[i]))
            {
                self.menuServerStatusDecor[i] destroy();
            }
        }
    }

    self.menuServerStatusDecor = undefined;
}

menuGetCurrentGametypeDvar(setting)
{
    value = getDvar("scr_" + getDvar("g_gametype") + "_" + setting);

    if(value == "")
    {
        return "default";
    }

    return value;
}

menuToggleServerKillcam(input)
{
    value = 1;

    if(getDvarInt("scr_game_allowkillcam") > 0)
    {
        value = 0;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    Exec("scr_game_allowkillcam " + value);
}

menuToggleServerHardcore(input)
{
    value = 1;

    if(getDvarInt("g_hardcore") > 0)
    {
        value = 0;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    Exec("g_hardcore " + value);
}

menuCycleFriendlyFire(input)
{
    value = getDvarInt("scr_team_fftype") + 1;

    if(value > 3)
    {
        value = 0;
    }

    Exec("scr_team_fftype " + value);
    self menuShowNotification("SERVER SETTING", "Friendly fire mode: " + value, "info");
}

menuSetServerGravity(value)
{
    Exec("g_gravity " + value);
    self menuShowNotification("SERVER SETTING", "Gravity set to " + value, "success");
}

menuSetServerDvar(input)
{
    parts = strTok(input, "|");

    if(parts.size < 3)
    {
        return;
    }

    Exec(parts[0] + " " + parts[1]);
    self menuShowNotification("SERVER SETTING", parts[2] + " set to " + parts[1], "success");
}


menuToggleServerDvar(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    value = 1;

    if(getDvarInt(parts[0]) > 0)
    {
        value = 0;
    }

    Exec(parts[0] + " " + value);

    if(value > 0)
    {
        self menuShowNotification("SERVER SETTING", parts[1] + " toggled ON", "success");
    }
    else
    {
        self menuShowNotification("SERVER SETTING", parts[1] + " toggled OFF", "warning");
    }
}

menuSetGametypeLimit(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    gametype = getDvar("g_gametype");
    dvar = "scr_" + gametype + "_" + parts[0];
    Exec(dvar + " " + parts[1]);
    self menuShowNotification("MATCH LIMIT", parts[0] + " set to " + parts[1] + " for " + gametype, "success");
}

/* Adds an amount to the current gametype-specific time or score limit. */
menuAdjustGametypeLimit(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }
    gametype = getDvar("g_gametype");
    dvar = "scr_" + gametype + "_" + parts[0];
    value = getDvarInt(dvar) + int(parts[1]);
    Exec(dvar + " " + value);
    menuNotifyAll("OVERTIME", parts[0] + " is now " + value, "warning");
}

menuBroadcastServerMessage(message)
{
    menuNotifyAll("SERVER", message, "info");
}

/* Applies personal third-person display state without granting god mode. */
menuToggleThirdPerson(input)
{
    if(!isDefined(self.menuThirdPerson))
    {
        self.menuThirdPerson = false;
    }

    self.menuThirdPerson = !self.menuThirdPerson;

    if(self.menuThirdPerson)
    {
        self setClientDvar("cg_thirdPerson", "1");
        self menuShowNotification("THIRD PERSON", "Enabled.", "success");
    }
    else
    {
        self setClientDvar("cg_thirdPerson", "0");
        self menuShowNotification("THIRD PERSON", "Disabled.", "info");
    }
}

menuToggleFullbright(input)
{
    if(!isDefined(self.menuFullbright))
    {
        self.menuFullbright = false;
    }

    self.menuFullbright = !self.menuFullbright;

    if(self.menuFullbright)
    {
        self setClientDvar("r_fullbright", "1");
        self menuShowNotification("FULLBRIGHT", "Enabled.", "success");
    }
    else
    {
        self setClientDvar("r_fullbright", "0");
        self menuShowNotification("FULLBRIGHT", "Disabled.", "info");
    }
}

menuRefillSelfAmmo(input)
{
    menuRefillPlayerCurrentAmmo(self);
    self menuShowNotification("AMMUNITION", "Current weapon ammo refilled.", "success");
}

menuSetControlBind(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    self maps\mp\gametypes\menu::menuApplyControlBind(parts[0], parts[1]);
    self menuShowNotification("CONTROLS", parts[0] + " bind set to " + parts[1] + ".", "success");
}

menuToggleAccessHint(input)
{
    enabled = self maps\mp\gametypes\menu::menuAccessHintEnabled();
    dvarName = self maps\mp\gametypes\menu::menuGetAccessHintDvarName();

    if(enabled)
    {
        setDvar(dvarName, "0");
        self maps\mp\gametypes\menu::destroyMenuAccessHint();
        self.menu.text["self_display"][3] = "Show Open Hint";
        self menuShowNotification("OPEN HINT", "Hidden.", "info");
    }
    else
    {
        setDvar(dvarName, "1");
        self maps\mp\gametypes\menu::startMenuAccessHint();
        self.menu.text["self_display"][3] = "Hide Open Hint";
        self menuShowNotification("OPEN HINT", "Shown.", "success");
    }

    self maps\mp\gametypes\menu::loadBaseMenu("self_display");
}

menuSetSelfFov(value)
{
    self setClientDvar("cg_fov", value);
    self menuShowNotification("FIELD OF VIEW", "Set to " + value + ".", "success");
}

/* Applies one allow-listed client DVAR from a menu option. */
menuSetClientDvar(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }
    self setClientDvar(parts[0], parts[1]);
    if(parts.size > 2)
    {
        self menuShowNotification("CLIENT SETTING", parts[2] + ".", "success");
    }
}

/* Applies a personal rendering preset without changing other players. */
menuApplyVisionPreset(preset)
{
    self setClientDvar("r_fullbright", "0");
    self setClientDvar("r_picmip", "0");
    self setClientDvar("r_contrast", "1");

    if(preset == "fullbright")
    {
        self setClientDvar("r_fullbright", "1");
    }
    else if(preset == "contrast")
    {
        self setClientDvar("r_contrast", "1.35");
    }
    else if(preset == "lowdetail")
    {
        self setClientDvar("r_picmip", "3");
    }
    self menuShowNotification("VISION", "Preset applied: " + preset, "success");
}

/* Displays a synchronized countdown to every connected player. */
menuStartCountdown(value)
{
    count = int(value);
    if(count < 1 || count > 10)
    {
        return;
    }
    self maps\mp\gametypes\menu::closeBaseMenu();
    for(i = count; i > 0; i--)
    {
        menuNotifyAllTimed("COUNTDOWN", "" + i, "warning", .9);
        wait 1;
    }
    menuNotifyAllTimed("COUNTDOWN", "GO!", "success", 1.5);
}

/* Toggles password-based join lockdown while preserving the prior password. */
menuToggleServerLockdown(input)
{
    actor = menuGetPlayerName(self);
    enabled = getDvarInt("cws_server_lockdown") <= 0;
    menuSetServerLockdownState(enabled, actor);
    self maps\mp\gametypes\menu::loadBaseMenu("server_events");
}

menuSetServerLockdownState(enabled, actor)
{
    if(enabled)
    {
        if(getDvarInt("cws_server_lockdown") > 0)
        {
            return;
        }
        setDvar("cws_lockdown_old_password", getDvar("g_password"));
        setDvar("g_password", "CWS_LOCKED_" + randomInt(999999));
        setDvar("cws_server_lockdown", "1");
        menuNotifyAll("SERVER LOCKDOWN", "Enabled - new joins are blocked.", "error");
        menuAddAdminActivity(actor, "enabled server lockdown");
        return;
    }

    if(getDvarInt("cws_server_lockdown") <= 0)
    {
        return;
    }
    setDvar("g_password", getDvar("cws_lockdown_old_password"));
    setDvar("cws_lockdown_old_password", "");
    setDvar("cws_server_lockdown", "0");
    menuNotifyAll("SERVER LOCKDOWN", "Disabled - joining is open.", "success");
    menuAddAdminActivity(actor, "disabled server lockdown");
}

/* Creates one cancellable delayed restart, rotation, or announcement. */
menuPrepareScheduledEvent(actor)
{
    if(!isDefined(level.cwsScheduledEventActive) || !level.cwsScheduledEventActive)
    {
        return;
    }

    previousType = level.cwsScheduledEventType;
    wasMaintenance = isDefined(level.cwsScheduledEventMaintenance) && level.cwsScheduledEventMaintenance;

    if(!isDefined(level.cwsScheduledEventId))
    {
        level.cwsScheduledEventId = 0;
    }

    level.cwsScheduledEventId++;
    level.cwsScheduledEventActive = false;
    level.cwsScheduledEventMaintenance = false;

    if(wasMaintenance)
    {
        menuSetServerLockdownState(false, actor);
    }

    menuAddAdminActivity(actor, "replaced pending " + previousType);
}

/* Creates one cancellable delayed restart, rotation, or announcement. */
menuScheduleServerEvent(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }
    eventType = parts[0];
    delay = int(parts[1]);
    payload = "";
    if(parts.size > 2)
    {
        payload = parts[2];
    }
    if(delay < 1 || (eventType != "restart" && eventType != "rotate" && eventType != "announce"))
    {
        return;
    }

    actor = menuGetPlayerName(self);
    menuPrepareScheduledEvent(actor);

    if(!isDefined(level.cwsScheduledEventId))
    {
        level.cwsScheduledEventId = 0;
    }
    level.cwsScheduledEventId++;
    eventId = level.cwsScheduledEventId;
    level.cwsScheduledEventActive = true;
    level.cwsScheduledEventType = eventType;
    level.cwsScheduledEventMaintenance = false;
    menuAddAdminActivity(actor, "scheduled " + eventType + " in " + delay + " seconds");
    self maps\mp\gametypes\menu::closeBaseMenu();
    menuNotifyAll("EVENT SCHEDULED", eventType + " in " + delay + " seconds.", "warning");
    level thread menuRunScheduledServerEvent(eventId, eventType, delay, payload, actor);
}

menuRunScheduledServerEvent(eventId, eventType, delay, payload, actor)
{
    for(remaining = delay; remaining > 0; remaining--)
    {
        if(!isDefined(level.cwsScheduledEventId) || level.cwsScheduledEventId != eventId)
        {
            return;
        }
        if(remaining == 10)
        {
            menuNotifyAll("EVENT REMINDER", eventType + " in 10 seconds.", "warning");
        }
        wait 1;
    }
    if(level.cwsScheduledEventId != eventId)
    {
        return;
    }
    level.cwsScheduledEventActive = false;
    menuAddAdminActivity(actor, "completed scheduled " + eventType);
    if(eventType == "restart")
    {
        Exec("map_restart");
    }
    else if(eventType == "rotate")
    {
        Exec("map_rotate");
    }
    else if(eventType == "announce")
    {
        menuNotifyAll("SERVER", payload, "info");
    }
}

/* Locks joining, broadcasts warnings, then restarts or rotates the server. */
menuStartMaintenance(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2)
    {
        return;
    }
    action = parts[0];
    delay = int(parts[1]);
    if(delay < 1 || (action != "restart" && action != "rotate"))
    {
        return;
    }

    actor = menuGetPlayerName(self);
    menuPrepareScheduledEvent(actor);

    if(!isDefined(level.cwsScheduledEventId))
    {
        level.cwsScheduledEventId = 0;
    }
    level.cwsScheduledEventId++;
    eventId = level.cwsScheduledEventId;
    level.cwsScheduledEventActive = true;
    level.cwsScheduledEventType = "maintenance " + action;
    level.cwsScheduledEventMaintenance = true;
    menuSetServerLockdownState(true, actor);
    menuAddAdminActivity(actor, "started maintenance " + action + " countdown at " + delay + " seconds");
    self maps\mp\gametypes\menu::closeBaseMenu();
    level thread menuRunMaintenance(eventId, action, delay, actor);
}

menuRunMaintenance(eventId, action, delay, actor)
{
    for(remaining = delay; remaining > 0; remaining--)
    {
        if(!isDefined(level.cwsScheduledEventId) || level.cwsScheduledEventId != eventId)
        {
            return;
        }
        if(remaining <= 10 || remaining == 30 || remaining == 60 || remaining == 120 || remaining == 300)
        {
            menuNotifyAll("MAINTENANCE", "Server " + action + " in " + remaining + " seconds.", "warning");
        }
        wait 1;
    }
    if(level.cwsScheduledEventId != eventId)
    {
        return;
    }
    level.cwsScheduledEventActive = false;
    level.cwsScheduledEventMaintenance = false;
    menuSetServerLockdownState(false, actor);
    menuAddAdminActivity(actor, "completed maintenance " + action);
    if(action == "restart")
    {
        Exec("map_restart");
    }
    else
    {
        Exec("map_rotate");
    }
}

/* Cancels the active event and reopens joining when maintenance was pending. */
menuCancelScheduledEvent(input)
{
    if(!isDefined(level.cwsScheduledEventActive) || !level.cwsScheduledEventActive)
    {
        return;
    }
    eventType = level.cwsScheduledEventType;
    wasMaintenance = isDefined(level.cwsScheduledEventMaintenance) && level.cwsScheduledEventMaintenance;
    level.cwsScheduledEventId++;
    level.cwsScheduledEventActive = false;
    level.cwsScheduledEventMaintenance = false;
    actor = menuGetPlayerName(self);
    if(wasMaintenance)
    {
        menuSetServerLockdownState(false, actor);
    }
    menuAddAdminActivity(actor, "cancelled pending " + eventType);
    self maps\mp\gametypes\menu::loadBaseMenu("server_events");
}

/* Stores a ten-entry event administration log for the current map. */
menuAddAdminActivity(actor, action)
{
    if(!isDefined(level.cwsAdminActivity))
    {
        level.cwsAdminActivity = [];
    }
    line = int(getTime() / 1000) + "s~" + actor + " - " + action;
    if(level.cwsAdminActivity.size < 10)
    {
        level.cwsAdminActivity[level.cwsAdminActivity.size] = line;
        return;
    }
    for(i = 1; i < level.cwsAdminActivity.size; i++)
    {
        level.cwsAdminActivity[i - 1] = level.cwsAdminActivity[i];
    }
    level.cwsAdminActivity[level.cwsAdminActivity.size - 1] = line;
}

/* Builds an in-menu view of recent scheduler and lockdown activity. */
menuOpenAdminActivityLog(input)
{
    menu = "server_admin_activity";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Admin Activity Log", "server_events");
    if(!isDefined(level.cwsAdminActivity) || level.cwsAdminActivity.size <= 0)
    {
        self maps\mp\gametypes\menu::menuAddOption(menu, 0, "No event activity", ::menuNoRemoteAction, "", "");
        self maps\mp\gametypes\menu::loadBaseMenu(menu);
        return;
    }
    option = 0;
    for(i = level.cwsAdminActivity.size - 1; i >= 0; i--)
    {
        parts = strTok(level.cwsAdminActivity[i], "~");
        description = "";
        if(parts.size > 1)
        {
            description = parts[1];
        }
        self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, parts[0], ::menuNoRemoteAction, "", description);
        option++;
    }
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

/* Applies a grouped set of common server DVARs. */
menuApplyServerPreset(preset)
{
    if(preset == "standard")
    {
        Exec("g_gravity 800");
        Exec("g_speed 190");
        Exec("jump_height 39");
        Exec("timescale 1");
    }
    else if(preset == "fast")
    {
        Exec("g_gravity 800");
        Exec("g_speed 260");
        Exec("jump_height 45");
        Exec("timescale 1.1");
    }
    else if(preset == "lowgravity")
    {
        Exec("g_gravity 300");
        Exec("g_speed 210");
        Exec("jump_height 90");
        Exec("timescale 1");
    }
    else if(preset == "hardcore")
    {
        gametype = getDvar("g_gametype");
        Exec("scr_" + gametype + "_hardcore 1");
        Exec("scr_game_allowkillcam 0");
    }
    else
    {
        return;
    }
    self menuShowNotification("SERVER PRESET", "Applied: " + preset, "success");
}

/* Balances or shuffles active players between Allies and Axis. */
menuBalanceTeams(mode)
{
    players = level.players;
    nextTeam = randomInt(2);
    moved = 0;
    for(i = 0; i < players.size; i++)
    {
        player = players[i];
        if(!isDefined(player) || (player.team != "allies" && player.team != "axis"))
        {
            continue;
        }
        if(mode == "shuffle")
        {
            team = "allies";
            if(randomInt(2) == 1)
            {
                team = "axis";
            }
        }
        else
        {
            team = "allies";
            if(nextTeam == 1)
            {
                team = "axis";
            }
            nextTeam = 1 - nextTeam;
        }
        player.team = team;
        player.sessionteam = team;
        moved++;
    }
    menuNotifyAll("TEAM MANAGEMENT", "Teams updated: " + moved + " players.", "info");
}

/* Shows active team sizes and current team scores. */
menuShowTeamOverview(input)
{
    allies = 0;
    axis = 0;
    spectators = 0;
    for(i = 0; i < level.players.size; i++)
    {
        if(level.players[i].team == "allies")
        {
            allies++;
        }
        else if(level.players[i].team == "axis")
        {
            axis++;
        }
        else
        {
            spectators++;
        }
    }
    self menuShowNotification("TEAM OVERVIEW", "Allies: " + allies + " | Axis: " + axis + " | Spectators: " + spectators, "info");
    if(isDefined(game["teamScores"]) && isDefined(game["teamScores"]["allies"]) && isDefined(game["teamScores"]["axis"]))
    {
        self menuShowNotification("TEAM SCORES", "Allies: " + game["teamScores"]["allies"] + " | Axis: " + game["teamScores"]["axis"], "info");
    }
}

/* Prints live menu and server state to the requesting administrator. */
menuShowGscDiagnostics(input)
{
    self menuShowNotification("MENU DIAGNOSTICS", "Loaded | Role: " + self maps\mp\gametypes\menu::menuGetAccessName(), "success");
    self menuShowNotification("SERVER DIAGNOSTICS", "Map: " + getDvar("mapname") + " | Mode: " + getDvar("g_gametype") + " | Players: " + level.players.size, "info");
    self menuShowNotification("SERVER DVARs", "Gravity: " + getDvar("g_gravity") + " | Speed: " + getDvar("g_speed") + " | Time: " + getDvar("timescale"), "info");
}

menuSuicideSelf(input)
{
    self maps\mp\gametypes\menu::closeBaseMenu();
    self suicide();
}

/* Displays administrative information for the currently selected player. */
menuShowSelectedPlayerInfo(input)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    guid = "unknown";
    team = "unknown";
    state = "unknown";

    if(isDefined(target.guid))
    {
        guid = "" + target.guid;
    }

    if(isDefined(target.team))
    {
        team = target.team;
    }

    if(isDefined(target.sessionstate))
    {
        state = target.sessionstate;
    }

    self menuShowNotification("PLAYER INFO", menuGetPlayerName(target) + " | Slot: " + target getEntityNumber(), "info");
    self menuShowNotification("PLAYER GUID", guid, "info");
    self menuShowNotification("PLAYER STATE", "Team: " + team + " | State: " + state, "info");
}

menuTeleportToSelectedPlayer(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    self setOrigin(target.origin + (0, 0, 40));
}

menuBringSelectedPlayer(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    destination = self.origin + (anglesToForward(self getPlayerAngles()) * 60) + (0, 0, 12);
    target setOrigin(destination);
    self menuShowNotification("PLAYER MOVEMENT", "Player brought to you.", "success");
}

menuToggleFreezeSelectedPlayer(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    if(!isDefined(target.menuAdminFrozen))
    {
        target.menuAdminFrozen = false;
    }

    target.menuAdminFrozen = !target.menuAdminFrozen;
    target freezeControls(target.menuAdminFrozen);

    if(target.menuAdminFrozen)
    {
        self menuShowNotification("PLAYER CONTROL", "Player frozen.", "warning");
    }
    else
    {
        self menuShowNotification("PLAYER CONTROL", "Player unfrozen.", "success");
    }
}

menuSlaySelectedPlayer(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    target suicide();
}

menuRefillSelectedPlayerAmmo(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    menuRefillPlayerCurrentAmmo(target);
    self menuShowNotification("PLAYER UTILITY", "Player ammo refilled.", "success");
}

menuStripSelectedPlayerWeapons(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    target takeAllWeapons();
    self menuShowNotification("PLAYER UTILITY", "Player weapons removed.", "warning");
}

menuHealSelectedPlayer(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    health = 100;

    if(isDefined(target.maxhealth) && target.maxhealth > 0)
    {
        health = target.maxhealth;
    }

    target.health = health;
    self menuShowNotification("PLAYER UTILITY", "Player health restored.", "success");
}

menuResetSelectedPlayerState(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    target freezeControls(false);
    target show();
    target setContents(100);
    target.menuAdminFrozen = false;
    target.menuHidden = false;
    self menuShowNotification("PLAYER UTILITY", "Player state reset.", "success");
}

/* Shows the selected player's current weapon and available ammunition. */
menuShowSelectedPlayerWeapon(input)
{
    target = self menuGetAdminSelectedPlayer();
    if(!isDefined(target))
    {
        return;
    }
    weapon = target getCurrentWeapon();
    self menuShowNotification("PLAYER WEAPON", menuGetPlayerName(target) + " | " + weapon, "info");
}

/* Moves the selected player to a team or spectator state. */
menuMoveSelectedPlayerTeam(team)
{
    target = self menuGetAdminSelectedPlayer();
    if(!isDefined(target))
    {
        return;
    }

    if(team == "auto")
    {
        allies = 0;
        axis = 0;
        for(i = 0; i < level.players.size; i++)
        {
            if(level.players[i].team == "allies")
            {
                allies++;
            }
            else if(level.players[i].team == "axis")
            {
                axis++;
            }
        }
        team = "allies";
        if(allies > axis)
        {
            team = "axis";
        }
    }

    if(team == "spectator")
    {
        target.team = "spectator";
        target.sessionteam = "spectator";
        target.sessionstate = "spectator";
        target setContents(0);
    }
    else if(team == "allies" || team == "axis")
    {
        target.team = team;
        target.sessionteam = team;
        target.sessionstate = "playing";
        target show();
        target setContents(100);
    }
    else
    {
        return;
    }
    self menuShowNotification("TEAM MANAGEMENT", "Player moved to " + team + ".", "success");
}

menuSendSelectedPlayerMessage(message)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    target menuShowNotification("STAFF MESSAGE", message, "warning");
    self menuShowNotification("STAFF MESSAGE", "Private message sent.", "success");
}

menuRefillPlayerCurrentAmmo(player)
{
    if(!isDefined(player))
    {
        return;
    }

    weapon = player getCurrentWeapon();

    if(isDefined(weapon) && weapon != "" && weapon != "none")
    {
        player giveMaxAmmo(weapon);
    }
}

menuGetSelectedPlayerForAction()
{
    if(!isDefined(self.menu) || !isDefined(self.menu.selectedPlayer))
    {
        self menuShowNotification("PLAYER", "No player selected.", "error");
        return undefined;
    }

    target = self.menu.selectedPlayer;

    if(!isDefined(target))
    {
        self menuShowNotification("PLAYER", "That player is no longer connected.", "error");
        return undefined;
    }

    return target;
}

menuGetAdminSelectedPlayer()
{
    if(!self maps\mp\gametypes\menu::menuIsAdmin())
    {
        self menuShowNotification("ACCESS DENIED", "Administrator access is required.", "error");
        return undefined;
    }

    return self menuGetSelectedPlayerForAction();
}

/* Enters watch mode and owns spectator cleanup when watching ends. */
menuWatchPlayer(target)
{
    self endon("disconnect");
    self endon("menu_watch_stop");

    if(!isDefined(target))
    {
        return;
    }

    self.menuWatching = true;
    self.menuWatchTarget = target;
    self.menuWatchOldState = self.sessionstate;
    self.menuWatchOldOrigin = self.origin;
    self.menuWatchOldAngles = self getPlayerAngles();

    self maps\mp\gametypes\_playerlogic::respawn_asSpectator(self.menuWatchOldOrigin + (0, 0, 60), self.menuWatchOldAngles);
    waittillframeend;
    self menuEnableWatchSpectating();
    self menuApplyWatchCamera(target);
    self menuWatchEspEnable(target);
    self menuWatchTelemetryEnable();
    self thread menuWatchShotMonitor(target);
    self menuShowNotification("WATCHING", menuGetPlayerName(target) + " - melee, frag, or smoke exits.", "info");

    while(self MeleeButtonPressed() || self maps\mp\gametypes\menu::menuCloseButtonPressed())
    {
        wait .05;
    }

    for(;;)
    {
        if(!isDefined(target))
        {
            self menuStopWatching();
            return;
        }

        if(!isDefined(self.menuWatching) || !self.menuWatching)
        {
            return;
        }

        if(self MeleeButtonPressed() || self maps\mp\gametypes\menu::menuCloseButtonPressed())
        {
            self menuStopWatching();

            while(self MeleeButtonPressed() || self maps\mp\gametypes\menu::menuCloseButtonPressed())
            {
                wait .05;
            }

            return;
        }

        self menuApplyWatchCamera(target);
        self menuWatchEspRefresh(target);
        self menuDrawWatchTelemetry(target);
        wait .05;
    }
}

menuStopWatching()
{
    if(!isDefined(self.menuWatching) || !self.menuWatching)
    {
        return;
    }

    self.menuWatching = false;
    self menuWatchEspDisable();
    self menuWatchTelemetryDisable();
    self.spectatorclient = -1;
    self.archivetime = 0;

    restorePlaying = isDefined(self.menuWatchOldState) && self.menuWatchOldState == "playing";

    if(!restorePlaying && isDefined(self.menuWatchOldState))
    {
        self.sessionstate = self.menuWatchOldState;
    }

    if(restorePlaying)
    {
        self thread maps\mp\gametypes\_playerlogic::spawnClient();
        self thread menuRestoreAfterWatch(self.menuWatchOldOrigin, self.menuWatchOldAngles);
    }
    else if(isDefined(self.menuWatchOldAngles))
    {
        self setPlayerAngles(self.menuWatchOldAngles);
    }

    self maps\mp\gametypes\_spectating::setSpectatePermissions();

    self.menuWatchTarget = undefined;
    self menuShowNotification("WATCHING", "Stopped watching.", "info");
    self notify("menu_watch_stop");
}

menuKeepEyeOnSelectedPlayer(input)
{
    if(!self maps\mp\gametypes\menu::menuIsOwner())
    {
        self menuShowNotification("ACCESS DENIED", "Owner access is required.", "error");
        return;
    }

    target = self menuGetSelectedPlayerForAction();
    if(!isDefined(target) || target == self)
    {
        self menuShowNotification("PLAYER", "Select another connected player.", "error");
        return;
    }

    if(isDefined(self.menuKeepEyeActive) && self.menuKeepEyeActive && isDefined(self.menuKeepEyeTarget) && self.menuKeepEyeTarget == target)
    {
        self menuKeepEyeDisable();
        return;
    }

    self notify("menu_keep_eye_stop");
    self menuKeepEyeHudDisable();
    self.menuKeepEyeActive = true;
    self.menuKeepEyeTarget = target;
    self.menuKeepEyeScore = 0;
    self.menuKeepEyeLastTarget = undefined;
    self.menuKeepEyeLastSwitchTime = 0;
    self menuKeepEyeHudEnable();
    self maps\mp\gametypes\menu::closeBaseMenu();
    self menuShowNotification("KEEP EYE ON", "Monitoring " + menuGetPlayerName(target) + ".", "info");
    self thread menuKeepEyeLoop(target);
}

/* Evaluates aim proximity and updates the suspicion status HUD. */
menuKeepEyeLoop(watchedPlayer)
{
    self endon("disconnect");
    self endon("menu_keep_eye_stop");

    for(;;)
    {
        if(!isDefined(watchedPlayer) || !isDefined(self.menuKeepEyeActive) || !self.menuKeepEyeActive || !self maps\mp\gametypes\menu::menuIsOwner())
        {
            self menuKeepEyeDisable();
            return;
        }

        start = watchedPlayer getEye();
        end = start + (anglesToForward(watchedPlayer getPlayerAngles()) * 100000);
        trace = bulletTrace(start, end, true, watchedPlayer);
        closestTarget = menuGetClosestCrosshairPlayer(watchedPlayer);
        crosshairTarget = undefined;

        if(isDefined(trace["entity"]))
        {
            crosshairTarget = self menuGetKeepEyeTracePlayer(watchedPlayer, trace["entity"]);
        }

        confirmedTarget = isDefined(closestTarget) && isDefined(crosshairTarget) && closestTarget == crosshairTarget;
        self menuKeepEyeJudge(crosshairTarget, confirmedTarget);
        self menuUpdateKeepEyeHud(watchedPlayer, closestTarget, crosshairTarget);
        wait .1;
    }
}

menuGetKeepEyeTracePlayer(watchedPlayer, traceEntity)
{
    if(!isDefined(level.players))
    {
        return undefined;
    }

    for(i = 0; i < level.players.size; i++)
    {
        candidate = level.players[i];
        if(isDefined(candidate) && candidate == traceEntity && self menuWatchEspShouldTrack(watchedPlayer, candidate))
        {
            return candidate;
        }
    }

    return undefined;
}

menuKeepEyeJudge(crosshairTarget, confirmedTarget)
{
    if(!isDefined(self.menuKeepEyeScore))
    {
        self.menuKeepEyeScore = 0;
    }

    if(confirmedTarget)
    {
        self.menuKeepEyeScore++;

        if(!isDefined(self.menuKeepEyeLastTarget) || self.menuKeepEyeLastTarget != crosshairTarget)
        {
            if(isDefined(self.menuKeepEyeLastSwitchTime) && getTime() - self.menuKeepEyeLastSwitchTime <= 500)
            {
                self.menuKeepEyeScore += 5;
            }
            else
            {
                self.menuKeepEyeScore += 2;
            }

            self.menuKeepEyeLastTarget = crosshairTarget;
            self.menuKeepEyeLastSwitchTime = getTime();
        }
    }
    else
    {
        self.menuKeepEyeScore--;
    }

    if(self.menuKeepEyeScore < 0)
    {
        self.menuKeepEyeScore = 0;
    }
    else if(self.menuKeepEyeScore > 30)
    {
        self.menuKeepEyeScore = 30;
    }
}

menuKeepEyeHudEnable()
{
    self menuKeepEyeHudDisable();
    self.menuKeepEyeHud = [];
    labels = [];
    labels[0] = "Player Name: --";
    labels[1] = "Target: None";
    labels[2] = "Crosshair Target: None";
    labels[3] = "Status: Not suspicious";

    for(i = 0; i < labels.size; i++)
    {
        hud = self createFontString("default", 1.1);
        hud setPoint("LEFT", "LEFT", 18, -30 + (i * 18));
        hud.foreground = true;
        hud.hidewheninmenu = true;
        hud.archived = false;
        hud.sort = 45;
        hud.color = (1, 1, 1);
        hud.alpha = .9;
        menuSetHudTextIfChanged(hud, labels[i], labels[i]);
        self.menuKeepEyeHud[i] = hud;
    }
}

menuUpdateKeepEyeHud(watchedPlayer, closestTarget, crosshairTarget)
{
    if(!isDefined(self.menuKeepEyeHud) || self.menuKeepEyeHud.size < 4)
    {
        self menuKeepEyeHudEnable();
    }

    targetName = "None";
    crosshairName = "None";
    if(isDefined(closestTarget))
    {
        targetName = menuGetPlayerName(closestTarget);
    }
    if(isDefined(crosshairTarget))
    {
        crosshairName = menuGetPlayerName(crosshairTarget);
    }

    status = "^2Not suspicious";
    if(isDefined(self.menuKeepEyeScore) && self.menuKeepEyeScore >= 18)
    {
        status = "^1Should Watch";
    }

    menuSetHudTextIfChanged(self.menuKeepEyeHud[0], "^7Player Name: ^2" + menuGetPlayerName(watchedPlayer), "^7Player Name: ^2Player");
    menuSetHudTextIfChanged(self.menuKeepEyeHud[1], "^7Target: ^3" + targetName, "^7Target: ^3Player");
    menuSetHudTextIfChanged(self.menuKeepEyeHud[2], "^7Crosshair Target: ^3" + crosshairName, "^7Crosshair Target: ^3Player");
    menuSetHudTextIfChanged(self.menuKeepEyeHud[3], "^7Status: " + status, "^7Status: Monitoring");
}

menuKeepEyeDisable()
{
    wasActive = isDefined(self.menuKeepEyeActive) && self.menuKeepEyeActive;
    self.menuKeepEyeActive = false;
    self menuKeepEyeHudDisable();
    self.menuKeepEyeTarget = undefined;
    self.menuKeepEyeLastTarget = undefined;
    self.menuKeepEyeScore = 0;
    if(wasActive)
    {
        self menuShowNotification("KEEP EYE ON", "Monitoring stopped.", "info");
    }
    self notify("menu_keep_eye_stop");
}

menuKeepEyeHudDisable()
{
    if(!isDefined(self.menuKeepEyeHud))
    {
        return;
    }

    for(i = 0; i < self.menuKeepEyeHud.size; i++)
    {
        if(isDefined(self.menuKeepEyeHud[i]))
        {
            self.menuKeepEyeHud[i] destroy();
        }
    }

    self.menuKeepEyeHud = [];
}

menuRestoreAfterWatch(origin, angles)
{
    self endon("disconnect");

    for(i = 0; i < 80; i++)
    {
        if(isDefined(self.sessionstate) && self.sessionstate == "playing" && isAlive(self))
        {
            if(isDefined(origin))
            {
                self setOrigin(origin);
            }

            if(isDefined(angles))
            {
                self setPlayerAngles(angles);
            }

            return;
        }

        wait .05;
    }
}

menuEnableWatchSpectating()
{
    self.sessionstate = "spectator";
    self allowSpectateTeam("allies", true);
    self allowSpectateTeam("axis", true);
    self allowSpectateTeam("freelook", true);
    self allowSpectateTeam("none", true);
}

menuApplyWatchCamera(target)
{
    if(!isDefined(target))
    {
        return;
    }

    self.sessionstate = "spectator";
    self.spectatorclient = target getEntityNumber();
    self.archivetime = 0;
}

/* Colors tracked ESP markers relative to the watched player's team. */
menuWatchEspEnable(watchedPlayer)
{
    self menuWatchEspDisable();
    self.menuWatchIcons = [];

    if(!isDefined(level.players))
    {
        return;
    }

    for(i = 0; i < level.players.size; i++)
    {
        target = level.players[i];

        if(self menuWatchEspShouldTrack(watchedPlayer, target))
        {
            self menuWatchEspAddTarget(watchedPlayer, target);
        }
    }
}

menuWatchEspDisable()
{
    if(!isDefined(self.menuWatchIcons))
    {
        return;
    }

    for(i = 0; i < self.menuWatchIcons.size; i++)
    {
        icon = self.menuWatchIcons[i];

        if(isDefined(icon))
        {
            icon destroy();
        }
    }

    self.menuWatchIcons = [];
}

menuWatchEspRefresh(watchedPlayer)
{
    if(self maps\mp\gametypes\menu::isMenuOpen())
    {
        if(isDefined(self.menuWatchIcons) && self.menuWatchIcons.size > 0)
        {
            self menuWatchEspDisable();
        }

        return;
    }

    if(!isDefined(self.menuWatchIcons))
    {
        self menuWatchEspEnable(watchedPlayer);
        return;
    }

    activeIcons = [];
    for(i = 0; i < self.menuWatchIcons.size; i++)
    {
        icon = self.menuWatchIcons[i];

        if(!isDefined(icon))
        {
            continue;
        }

        if(!isDefined(icon.menuWatchTarget) || !self menuWatchEspShouldTrack(watchedPlayer, icon.menuWatchTarget))
        {
            icon destroy();
            continue;
        }

        icon.color = menuWatchEspColorForTarget(watchedPlayer, icon.menuWatchTarget);
        activeIcons[activeIcons.size] = icon;
    }
    self.menuWatchIcons = activeIcons;

    if(!isDefined(level.players))
    {
        return;
    }

    for(i = 0; i < level.players.size; i++)
    {
        target = level.players[i];

        if(self menuWatchEspShouldTrack(watchedPlayer, target) && !self menuWatchEspHasTarget(target))
        {
            self menuWatchEspAddTarget(watchedPlayer, target);
        }
    }
}

menuWatchEspAddTarget(watchedPlayer, target)
{
    icon = self createIcon("objpoint_default", 18, 18);
    icon.hidewheninmenu = true;
    icon.foreground = true;
    icon.archived = false;
    icon.sort = 10;
    icon.alpha = .9;
    icon.color = menuWatchEspColorForTarget(watchedPlayer, target);
    icon.menuWatchTarget = target;
    icon setWaypoint(false, false);
    icon setTargetEnt(target);

    self.menuWatchIcons[self.menuWatchIcons.size] = icon;
}

menuWatchEspHasTarget(target)
{
    if(!isDefined(self.menuWatchIcons))
    {
        return false;
    }

    for(i = 0; i < self.menuWatchIcons.size; i++)
    {
        icon = self.menuWatchIcons[i];

        if(isDefined(icon) && isDefined(icon.menuWatchTarget) && icon.menuWatchTarget == target)
        {
            return true;
        }
    }

    return false;
}

menuWatchEspShouldTrack(watchedPlayer, target)
{
    if(!isDefined(target) || target == watchedPlayer || target == self)
    {
        return false;
    }

    if(isDefined(target.sessionstate) && target.sessionstate == "spectator")
    {
        return false;
    }

    return true;
}

menuWatchEspColorForTarget(watchedPlayer, target)
{
    if(menuPlayersAreFriendly(watchedPlayer, target))
    {
        return (.05, .79, .29);
    }

    return (1, .29, .29);
}

menuWatchShotMonitor(watchedPlayer)
{
    self endon("disconnect");
    self endon("menu_watch_stop");
    watchedPlayer endon("disconnect");

    for(;;)
    {
        watchedPlayer waittill("weapon_fired");
        start = watchedPlayer getEye();
        end = start + (anglesToForward(watchedPlayer getPlayerAngles()) * 100000);
        trace = bulletTrace(start, end, true, watchedPlayer);
        self.menuLastShotStart = start;
        self.menuLastShotEnd = trace["position"];
        self.menuLastShotTime = getTime();
    }
}

/* Updates watched-player, nearest-target, and crosshair telemetry. */
menuDrawWatchTelemetry(watchedPlayer)
{
    start = watchedPlayer getEye();
    end = start + (anglesToForward(watchedPlayer getPlayerAngles()) * 100000);
    trace = bulletTrace(start, end, true, watchedPlayer);
    aimEnd = trace["position"];
    closestTarget = menuGetClosestCrosshairPlayer(watchedPlayer);
    crosshairOnTarget = false;

    if(isDefined(closestTarget) && isDefined(trace["entity"]) && trace["entity"] == closestTarget)
    {
        crosshairOnTarget = true;
    }

    self menuUpdateWatchTelemetryHud(watchedPlayer, closestTarget, crosshairOnTarget);

    line(start, aimEnd, (1, 1, 0));
    menuDrawEndpointCross(aimEnd, (1, 1, 0));

    if(isDefined(self.menuLastShotTime) && getTime() - self.menuLastShotTime <= 1500 && isDefined(self.menuLastShotStart) && isDefined(self.menuLastShotEnd))
    {
        line(self.menuLastShotStart, self.menuLastShotEnd, (1, .2, .8));
        menuDrawEndpointCross(self.menuLastShotEnd, (1, .2, .8));
    }

}

menuWatchTelemetryEnable()
{
    self menuWatchTelemetryDisable();
    self.menuWatchTelemetryHud = [];
    labels = [];
    labels[0] = "Player Name: --";
    labels[1] = "Target: None";
    labels[2] = "Crosshair Target: NO";

    for(i = 0; i < labels.size; i++)
    {
        hud = self createFontString("default", 1.1);
        hud setPoint("LEFT", "LEFT", 18, -42 + (i * 18));
        hud.foreground = true;
        hud.hidewheninmenu = true;
        hud.archived = false;
        hud.sort = 45;
        hud.color = (1, 1, 1);
        hud.alpha = .9;
        menuSetHudTextIfChanged(hud, labels[i], labels[i]);
        self.menuWatchTelemetryHud[i] = hud;
    }
}

menuWatchTelemetryDisable()
{
    if(!isDefined(self.menuWatchTelemetryHud))
    {
        return;
    }

    for(i = 0; i < self.menuWatchTelemetryHud.size; i++)
    {
        if(isDefined(self.menuWatchTelemetryHud[i]))
        {
            self.menuWatchTelemetryHud[i] destroy();
        }
    }

    self.menuWatchTelemetryHud = [];
}

menuUpdateWatchTelemetryHud(watchedPlayer, closestTarget, crosshairOnTarget)
{
    telemetryMissing = !isDefined(self.menuWatchTelemetryHud) || self.menuWatchTelemetryHud.size < 3;

    if(!telemetryMissing)
    {
        telemetryMissing = !isDefined(self.menuWatchTelemetryHud[0]);
        telemetryMissing = telemetryMissing || !isDefined(self.menuWatchTelemetryHud[1]);
        telemetryMissing = telemetryMissing || !isDefined(self.menuWatchTelemetryHud[2]);
    }

    if(telemetryMissing)
    {
        self menuWatchTelemetryEnable();
    }

    if(!isDefined(self.menuWatchTelemetryHud) || self.menuWatchTelemetryHud.size < 3)
    {
        return;
    }

    targetName = "None";

    if(isDefined(closestTarget))
    {
        targetName = menuGetPlayerName(closestTarget);
    }

    crosshairText = "^1NO";

    if(crosshairOnTarget)
    {
        crosshairText = "^2YES";
    }

    menuSetHudTextIfChanged(self.menuWatchTelemetryHud[0], "^7Player Name: ^2" + menuGetPlayerName(watchedPlayer), "^7Player Name: ^2Player");
    menuSetHudTextIfChanged(self.menuWatchTelemetryHud[1], "^7Target: ^3" + targetName, "^7Target: ^3Player");
    menuSetHudTextIfChanged(self.menuWatchTelemetryHud[2], "^7Crosshair Target: " + crosshairText, "^7Crosshair Target: Monitoring");
}

menuGetClosestCrosshairPlayer(watchedPlayer)
{
    if(!isDefined(level.players))
    {
        return undefined;
    }

    eye = watchedPlayer getEye();
    forward = anglesToForward(watchedPlayer getPlayerAngles());
    closestTarget = undefined;
    bestDot = .5;

    for(i = 0; i < level.players.size; i++)
    {
        target = level.players[i];

        if(!menuWatchEspShouldTrack(watchedPlayer, target))
        {
            continue;
        }

        direction = vectorNormalize((target.origin + (0, 0, 45)) - eye);
        aimDot = (forward[0] * direction[0]) + (forward[1] * direction[1]) + (forward[2] * direction[2]);

        if(aimDot > bestDot)
        {
            bestDot = aimDot;
            closestTarget = target;
        }
    }

    return closestTarget;
}

menuDrawEndpointCross(point, color)
{
    line(point + (-5, 0, 0), point + (5, 0, 0), color);
    line(point + (0, -5, 0), point + (0, 5, 0), color);
    line(point + (0, 0, -5), point + (0, 0, 5), color);
}

menuPlayersAreFriendly(firstPlayer, secondPlayer)
{
    if(!isDefined(level.teamBased) || !level.teamBased)
    {
        return false;
    }

    if(!isDefined(firstPlayer.team) || !isDefined(secondPlayer.team))
    {
        return false;
    }

    return firstPlayer.team == secondPlayer.team;
}

menuGetPlayerName(player)
{
    if(isDefined(player.name) && player.name != "")
    {
        return player.name;
    }

    return "Player";
}

/* Toggles UFO movement without granting god mode. */
menuToggleUfo(input)
{
    if(isDefined(self.menuUfo) && self.menuUfo)
    {
        self menuExitUfo();
        return;
    }

    if(isDefined(self.menuWatching) && self.menuWatching)
    {
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    maps\mp\gametypes\_spectating::setSpectatePermissions();
    self.menuUfo = true;
    self.menuUfoOldState = self.sessionstate;
    self.menuUfoWeapon = self getCurrentWeapon();
    self allowSpectateTeam("freelook", true);
    self.sessionstate = "spectator";
    self setContents(0);
    self menuShowNotification("UFO MODE", "Enabled - press melee to exit.", "success");
    self notify("menu_ufo_monitor_stop");
    self thread menuWatchUfoExit();
}

menuExitUfo()
{
    if(!isDefined(self.menuUfo) || !self.menuUfo)
    {
        return;
    }

    exitOrigin = self.origin + (0, 0, 48);
    self.menuUfo = false;
    self allowSpectateTeam("freelook", false);

    if(isDefined(self.menuUfoOldState))
    {
        self.sessionstate = self.menuUfoOldState;
    }
    else
    {
        self.sessionstate = "playing";
    }

    self setOrigin(exitOrigin);
    self setContents(100);

    if(isDefined(self.menuUfoWeapon) && self.menuUfoWeapon != "" && self.menuUfoWeapon != "none" && self hasWeapon(self.menuUfoWeapon))
    {
        self switchToWeapon(self.menuUfoWeapon);
    }

    self menuShowNotification("UFO MODE", "Disabled.", "info");
    self notify("menu_ufo_monitor_stop");
}

menuWatchUfoExit()
{
    self endon("disconnect");
    self endon("menu_ufo_monitor_stop");

    while(self MeleeButtonPressed())
    {
        wait .05;
    }

    for(;;)
    {
        if(!isDefined(self.menuUfo) || !self.menuUfo)
        {
            return;
        }

        if(self MeleeButtonPressed())
        {
            self menuExitUfo();
            return;
        }

        wait .05;
    }
}

/* Temporarily hides the administrator and restores state on exit. */
menuToggleHide(input)
{
    if(isDefined(self.menuHidden) && self.menuHidden)
    {
        self menuDisableHide();
        return;
    }

    if(isDefined(self.menuWatching) && self.menuWatching)
    {
        return;
    }

    self.menuHidden = true;
    self maps\mp\gametypes\menu::closeBaseMenu();
    self hide();
    self setContents(0);
    self menuShowNotification("HIDDEN", "Press melee to return.", "warning");
    self notify("menu_hide_monitor_stop");
    self thread menuWatchHideExit();
}

menuDisableHide()
{
    if(!isDefined(self.menuHidden) || !self.menuHidden)
    {
        return;
    }

    self.menuHidden = false;
    self show();
    self setContents(100);

    self menuShowNotification("VISIBILITY", "Visible again.", "success");
    self notify("menu_hide_monitor_stop");
}

menuWatchHideExit()
{
    self endon("disconnect");
    self endon("menu_hide_monitor_stop");

    while(self MeleeButtonPressed())
    {
        wait .05;
    }

    for(;;)
    {
        if(!isDefined(self.menuHidden) || !self.menuHidden)
        {
            return;
        }

        if(self MeleeButtonPressed())
        {
            self menuDisableHide();
            return;
        }

        wait .05;
    }
}



menuIsBotWarfareInstalled()
{
    fsGame = getDvar("fs_game");

    if(fsGame == "mods/mp_bots" || fsGame == "mp_bots" || fsGame == "mods\\mp_bots")
    {
        return true;
    }

    if(getDvar("bots_main") != "" || getDvar("bots_manage_fill") != "" || getDvar("bots_skill") != "")
    {
        return true;
    }

    return false;
}

menuShowBotWarfareStatus(input)
{
    if(!menuIsBotWarfareInstalled())
    {
        self menuShowNotification("BOT WARFARE", "Not detected on this server.", "error");
        return;
    }

    self menuShowNotification("BOT WARFARE", "Main: " + menuDvarText("bots_main") + " | Fill: " + menuDvarText("bots_manage_fill") + " | Mode: " + menuDvarText("bots_manage_fill_mode"), "info");
    self menuShowNotification("BOT SETUP", "Skill: " + menuDvarText("bots_skill") + " | Team: " + menuDvarText("bots_team") + " | Chat: " + menuDvarText("bots_main_chat"), "info");
    self menuShowNotification("BOT BEHAVIOUR", "Obj: " + menuDvarText("bots_play_obj") + " | Streaks: " + menuDvarText("bots_play_killstreak") + " | Camp: " + menuDvarText("bots_play_camp"), "info");
}

menuDvarText(dvarName)
{
    value = getDvar(dvarName);

    if(value == "")
    {
        return "default";
    }

    return value;
}

menuSetBotFill(amount)
{
    Exec("bots_manage_fill " + amount + "; bots_manage_fill_watchplayers 1");
    self menuShowNotification("BOT WARFARE", "Fill set to " + amount + ".", "success");
}

/* Matches Bot Warfare's bot identity checks without requiring its scripts at compile time. */
menuIsBotPlayer(player)
{
    if(!isDefined(player) || !isPlayer(player))
    {
        return false;
    }

    if(isDefined(player.pers["isBot"]) && player.pers["isBot"])
    {
        return true;
    }
    if(isDefined(player.pers["isBotWarfare"]) && player.pers["isBotWarfare"])
    {
        return true;
    }

    return isSubStr(player getGuid() + "", "bot");
}

menuBotIdentity(player)
{
    if(!isDefined(player))
    {
        return "unknown";
    }

    return player getGuid() + "";
}

/* Queues one additional bot without overwriting an existing Bot Warfare request. */
menuSpawnBot(input)
{
    pending = getDvarInt("bots_manage_add");
    if(pending < 0)
    {
        pending = 0;
    }
    if(pending >= 18)
    {
        self menuShowNotification("BOT WARFARE", "The bot spawn queue is full.", "warning");
        return;
    }

    setDvar("bots_manage_add", pending + 1);
    self menuShowNotification("BOT WARFARE", "One bot queued for spawning.", "success");
}

/* Maintains an exact bot-only ceiling from zero through eighteen. */
menuSetBotCount(amount)
{
    count = int(amount);
    if(count < 0)
    {
        count = 0;
    }
    else if(count > 18)
    {
        count = 18;
    }

    setDvar("bots_manage_fill_mode", "1");
    setDvar("bots_manage_fill", "" + count);
    setDvar("bots_manage_fill_kick", "1");
    setDvar("bots_manage_fill_watchplayers", "1");
    self menuShowNotification("BOT WARFARE", "Bot count set to " + count + ".", "success");
}

menuOpenBotKickConfirmation(input)
{
    self menuOpenConfirmation("CONFIRM BOT KICK", "confirm", ::menuKickBot, input, self.menu.current);
}

/* Revalidates both slot and bot GUID before removing the selected entity. */
menuKickBot(input)
{
    parts = strTok(input, "|");
    if(parts.size < 2 || !isDefined(level.players))
    {
        self menuShowNotification("BOT WARFARE", "That bot is no longer connected.", "error");
        return;
    }

    slot = int(parts[0]);
    identity = parts[1];
    for(i = 0; i < level.players.size; i++)
    {
        bot = level.players[i];
        if(isDefined(bot) && bot getEntityNumber() == slot && menuIsBotPlayer(bot) && menuBotIdentity(bot) == identity)
        {
            botName = menuGetPlayerName(bot);
            kick(slot, "EXE_PLAYERKICKED");
            self menuShowNotification("BOT WARFARE", botName + " was kicked.", "success");
            return;
        }
    }

    self menuShowNotification("BOT WARFARE", "That bot is no longer connected.", "error");
}


setServerSetting(input)
{
    parts = strTok(input, "|");

    if(parts.size < 3)
        return;

    dvar = parts[0];
    value = parts[1];
    name = parts[2];

    Exec("set " + dvar + " " + value);

    self menuShowNotification("SERVER SETTING", name + " set to " + value + ".", "success");
}

/* Initializes and enforces optional weapon restriction settings. */
initWeaponRestrictions()
{
    if(!isDefined(level.disabledWeapons))
        level.disabledWeapons = [];
}

toggleWeaponRestriction(weapon)
{
    maps\mp\gametypes\menu_functions::initWeaponRestrictions();

    if(isDefined(level.disabledWeapons[weapon]))
    {
        level.disabledWeapons[weapon] = undefined;
        self menuShowNotification("WEAPON RESTRICTION", weapon + " enabled.", "success");
    }
    else
    {
        level.disabledWeapons[weapon] = true;
        self menuShowNotification("WEAPON RESTRICTION", weapon + " disabled.", "warning");
    }
}

resetWeaponRestrictions()
{
    level.disabledWeapons = [];
    self menuShowNotification("WEAPON RESTRICTIONS", "All restrictions reset.", "success");
}

monitorRestrictedWeapons()
{
    self endon("disconnect");

    maps\mp\gametypes\menu_functions::initWeaponRestrictions();

    for(;;)
    {
        weapon = self getCurrentWeapon();

        if(isDefined(level.disabledWeapons[weapon]))
        {
            self takeWeapon(weapon);
            self menuShowNotification("WEAPON RESTRICTED", "That weapon is disabled on this server.", "warning");
        }

        wait 0.25;
    }
}


toggleChatWithOthers() 
{
    if(!isDefined(self.menu.otherschat)) {
        self.menu.otherschat = false;
    }

    if(self.menu.otherschat) {
        self.menu.otherschat = false;
        Exec("set cg_chatWithOtherTeams 0");
        self menuShowNotification("CHAT", "Chat with other teams disabled.", "info");

    } else {
        self.menu.otherschat = true;
        Exec("set cg_chatWithOtherTeams 1");
        self menuShowNotification("CHAT", "Chat with other teams enabled.", "success");
    }
}
