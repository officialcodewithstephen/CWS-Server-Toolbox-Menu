#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

/*
    CWS Admin Menu actions.
    Implements moderation requests, remote IW4MAdmin and Dragnet views, server
    controls, player utilities, spectator telemetry, ESP, and self tools.
    Layout and HUD navigation remain in menu.gsc.
*/

/* Starts spectator tracking for the currently selected connected player. */
menuWatchSelectedPlayer(input)
{
    if(!isDefined(self.menu) || !isDefined(self.menu.selectedPlayer))
    {
        self iprintln("^1No player selected.");
        return;
    }

    target = self.menu.selectedPlayer;

    if(!isDefined(target))
    {
        self iprintln("^1That player is no longer connected.");
        return;
    }

    if(target == self)
    {
        self iprintln("^1You cannot watch yourself.");
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
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
    menu = "moderation_action_confirm";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Confirm Moderation", parent);
    self maps\mp\gametypes\menu::menuAddOption(menu, 0, "Confirm", ::menuConfirmPresetModeration, input, "Apply this moderation action to the selected player.");
    self maps\mp\gametypes\menu::menuAddOption(menu, 1, "Cancel", ::menuOpenGeneratedMenu, parent, "Return without taking action.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
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
        self iprintln("^1Set a custom reason first: ^7/set cws_menu_custom_reason your_reason_here");
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
        self iprintln("^1Set a custom reason first: ^7/set cws_menu_custom_reason your_reason_here");
        return;
    }

    self.menuTempBanReason = reason;
    self.menu.text[menu][0] = "Reason: Custom";
    self iprintln("^2Custom reason set: ^7" + reason);
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
    menuConfirm = "tempban_action_confirm";
    self maps\mp\gametypes\menu::menuCreateMenu(menuConfirm, "Confirm Temp Ban", parent);
    self maps\mp\gametypes\menu::menuAddOption(menuConfirm, 0, "Confirm", ::menuConfirmTempBan, "", "Apply this temporary ban to the selected player.");
    self maps\mp\gametypes\menu::menuAddOption(menuConfirm, 1, "Cancel", ::menuOpenGeneratedMenu, parent, "Return without taking action.");
    self maps\mp\gametypes\menu::loadBaseMenu(menuConfirm);
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
        self iprintln("^1That player disconnected.");
        return;
    }

    self maps\mp\gametypes\menu::closeBaseMenu();
    logPrint("[CWSADMIN] action=" + action + " origin=" + menuActionPlayerGuid(self) + " origin_slot=" + self getEntityNumber() + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + " duration=" + duration + " reason=\"" + reason + "\"\n");
    self iprintln("^2Moderation request sent to IW4MAdmin.");
}

menuActionPlayerGuid(player)
{
    if(isDefined(player.guid))
    {
        return "" + player.guid;
    }

    return "unknown";
}

menuSetHudTextIfChanged(hud, text)
{
    if(!isDefined(hud))
    {
        return;
    }

    if(!isDefined(hud.menuLastText) || hud.menuLastText != text)
    {
        hud setText(text);
        hud.menuLastText = text;
    }
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
        target = self menuGetSelectedPlayerForAction();
        logPrint("[CWSADMIN] action=playerhistory origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + "\n");
    }
    else if(kind == "totals")
    {
        target = self menuGetSelectedPlayerForAction();
        logPrint("[CWSADMIN] action=playertotals origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " target=" + menuActionPlayerGuid(target) + " target_slot=" + target getEntityNumber() + "\n");
    }
    else if(kind == "known" || kind == "baninfo")
    {
        target = self menuGetSelectedPlayerForAction();
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
        if(getDvar(revisionDvar) != oldRevision)
        {
            break;
        }

        wait .05;
    }

    if(getDvar(revisionDvar) == oldRevision)
    {
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
            self.menuHud.text[0] setText(loadingText);
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
            self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, label, ::menuOpenDragnetPeerDetails, row, description);
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

menuOpenDragnetPeerDetails(input)
{
    rowParts = strTok(input, "~");

    if(rowParts.size < 2)
    {
        return;
    }

    menu = "dragnet_peer_details";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, rowParts[0], "dragnet_results");
    details = strTok(rowParts[1], "|");
    option = 0;

    originId = "";

    for(i = 0; i < details.size; i++)
    {
        if(details[i] == "")
        {
            continue;
        }

        detailLabel = details[i];
        detailDescription = details[i];
        detailParts = strTok(details[i], ":");

        if(detailParts.size > 1)
        {
            detailLabel = detailParts[0];
            valueStart = detailLabel.size + 1;

            if(details[i].size > valueStart && getSubStr(details[i], valueStart, valueStart + 1) == " ")
            {
                valueStart++;
            }

            detailDescription = getSubStr(details[i], valueStart, details[i].size);
        }

        self maps\mp\gametypes\menu::menuAddDetailedOption(menu, option, detailLabel, ::menuNoRemoteAction, "", detailDescription);
        option++;

        if(details[i].size > 11 && getSubStr(details[i], 0, 10) == "Origin ID:")
        {
            originId = getSubStr(details[i], 11, details[i].size);
        }
    }

    if(originId != "")
    {
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Request Resync", ::menuOpenDragnetConfirmation, "resync|" + originId, "Queue a full event resync from this peer.");
        option++;
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Clear Error", ::menuOpenDragnetConfirmation, "clearerror|" + originId, "Clear this peer's current transport error.");
        option++;
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Trust Peer", ::menuOpenDragnetConfirmation, "trust|" + originId, "Trust events signed by this Dragnet origin.");
        option++;
        self maps\mp\gametypes\menu::menuAddOption(menu, option, "Untrust Peer", ::menuOpenDragnetConfirmation, "untrust|" + originId, "Remove trust from this Dragnet origin.");
    }

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
    menu = "dragnet_action_confirm";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Confirm Action", self.menuPendingDragnetParent);
    self maps\mp\gametypes\menu::menuAddOption(menu, 0, "Confirm", ::menuSubmitDragnetAction, input, "Apply this action. This operation is recorded by IW4MAdmin.");
    self maps\mp\gametypes\menu::menuAddOption(menu, 1, "Cancel", ::menuOpenGeneratedMenu, self.menuPendingDragnetParent, "Return without making changes.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
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
    self menuShowRemoteLoading("action");
    logPrint("[CWSADMIN] action=dragnetaction origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + parts[0] + " id=" + parts[1] + "\n");
    self thread menuWaitForRemoteAction(oldRevision);
}

menuWaitForRemoteAction(oldRevision)
{
    self endon("disconnect");
    slot = self getEntityNumber();

    for(i = 0; i < 120; i++)
    {
        if(getDvar("cws_dragnet_revision_" + slot) != oldRevision)
        {
            self menuBuildRemoteInfoResults("action");
            return;
        }

        wait .05;
    }
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
    menu = "report_action_confirm";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Confirm Report Action", parent);
    self maps\mp\gametypes\menu::menuAddOption(menu, 0, "Confirm", ::menuSubmitReportAction, input, "Apply this report review state.");
    self maps\mp\gametypes\menu::menuAddOption(menu, 1, "Cancel", ::menuOpenGeneratedMenu, parent, "Return without changing the report.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
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
    self menuShowRemoteLoading("reports");
    logPrint("[CWSADMIN] action=reportaction origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + parts[0] + " id=" + parts[1] + "\n");
    self thread menuWaitForIw4mRefresh(oldRevision, "reports");
}

menuOpenRotationConfirmation(command)
{
    parent = self.menu.current;
    menu = "rotation_action_confirm";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Confirm Rotation Change", parent);
    self maps\mp\gametypes\menu::menuAddOption(menu, 0, "Confirm", ::menuSubmitRotationAction, command, "Apply this map rotation operation.");
    self maps\mp\gametypes\menu::menuAddOption(menu, 1, "Cancel", ::menuOpenGeneratedMenu, parent, "Return without changing the rotation.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuSubmitRotationAction(command)
{
    slot = self getEntityNumber();
    oldRevision = getDvar("cws_dragnet_revision_" + slot);
    self menuShowRemoteLoading("rotation");
    logPrint("[CWSADMIN] action=rotationaction origin=" + menuActionPlayerGuid(self) + " origin_slot=" + slot + " command=" + command + "\n");
    self thread menuWaitForIw4mRefresh(oldRevision, "rotation");
}

menuWaitForIw4mRefresh(oldRevision, kind)
{
    self endon("disconnect");
    slot = self getEntityNumber();
    for(i = 0; i < 120; i++)
    {
        if(getDvar("cws_dragnet_revision_" + slot) != oldRevision)
        {
            if(kind == "reports")
            {
                self menuBuildReportsResults();
            }
            else
            {
                self menuBuildRemoteInfoResults(kind);
            }
            return;
        }
        wait .05;
    }
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
    menu = "unban_action_confirm";
    self maps\mp\gametypes\menu::menuCreateMenu(menu, "Confirm Unban", parent);
    self maps\mp\gametypes\menu::menuAddOption(menu, 0, "Confirm", ::menuSubmitUnbanId, offenderId, "Remove this player's active ban.");
    self maps\mp\gametypes\menu::menuAddOption(menu, 1, "Cancel", ::menuOpenGeneratedMenu, parent, "Return without removing the ban.");
    self maps\mp\gametypes\menu::loadBaseMenu(menu);
}

menuWaitForBanRefresh(oldRevision)
{
    self endon("disconnect");
    slot = self getEntityNumber();

    for(i = 0; i < 80; i++)
    {
        if(getDvar("cws_dragnet_revision_" + slot) != oldRevision)
        {
            self menuBuildBanResults();
            return;
        }

        wait .05;
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
        self menuDestroyServerStatusHud();
        self.menuServerStatusOpen = false;
        self iprintln("^3Server details hidden.");
        return;
    }

    self.menuServerStatusOpen = true;
    self thread menuServerStatusHudLoop();
    self iprintln("^2Server details shown. Select Server Status again to hide.");
}

menuServerStatusHudLoop()
{
    self endon("disconnect");

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
        title setText("SERVER INFO");

        bodyText = rows[0];

        for(i = 1; i < rows.size; i++)
        {
            bodyText += "\n" + rows[i];
        }

        self.menuServerStatusHud[1].x = textLeft;
        self.menuServerStatusHud[1].y = panelTop + 42;

        if(!isDefined(self.menuServerStatusBodyText) || self.menuServerStatusBodyText != bodyText)
        {
            self.menuServerStatusHud[1] setText(bodyText);
            self.menuServerStatusBodyText = bodyText;
        }

        wait .5;
    }

    self menuDestroyServerStatusHud();
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
    self iprintln("^2Friendly fire mode: ^7" + value);
}

menuSetServerGravity(value)
{
    Exec("g_gravity " + value);
    self iprintln("^2Gravity set to ^7" + value);
}

menuSetServerDvar(input)
{
    parts = strTok(input, "|");

    if(parts.size < 3)
    {
        return;
    }

    Exec(parts[0] + " " + parts[1]);
    self iprintln("^2" + parts[2] + " set to ^7" + parts[1]);
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
        self iprintln("^2" + parts[1] + " toggled ^7ON");
    }
    else
    {
        self iprintln("^1" + parts[1] + " toggled ^7OFF");
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
    self iprintln("^2" + parts[0] + " set to ^7" + parts[1] + " ^2for ^7" + gametype);
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
    iprintlnbold("^3Overtime: ^7" + parts[0] + " is now " + value);
}

menuBroadcastServerMessage(message)
{
    iprintlnbold("^3[SERVER] ^7" + message);
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
        self iprintln("^2Third Person: ON");
    }
    else
    {
        self setClientDvar("cg_thirdPerson", "0");
        self iprintln("^1Third Person: OFF");
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
        self iprintln("^2Fullbright: ON");
    }
    else
    {
        self setClientDvar("r_fullbright", "0");
        self iprintln("^1Fullbright: OFF");
    }
}

menuRefillSelfAmmo(input)
{
    menuRefillPlayerCurrentAmmo(self);
    self iprintln("^2Current weapon ammo refilled.");
}

menuSetControlBind(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2)
    {
        return;
    }

    self maps\mp\gametypes\menu::menuApplyControlBind(parts[0], parts[1]);
    self iprintln("^2Menu " + parts[0] + " bind set to ^7" + parts[1] + ".");
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
        self iprintln("^3Menu open hint: OFF");
    }
    else
    {
        setDvar(dvarName, "1");
        self maps\mp\gametypes\menu::startMenuAccessHint();
        self.menu.text["self_display"][3] = "Hide Open Hint";
        self iprintln("^2Menu open hint: ON");
    }

    self maps\mp\gametypes\menu::loadBaseMenu("self_display");
}

menuSetSelfFov(value)
{
    self setClientDvar("cg_fov", value);
    self iprintln("^2Field of view: ^7" + value);
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
        self iprintln("^2" + parts[2] + ".");
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
    self iprintln("^2Vision preset: ^7" + preset);
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
        iprintlnbold("^3" + i);
        wait 1;
    }
    iprintlnbold("^2GO!");
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
        iprintlnbold("^1SERVER LOCKDOWN ENABLED ^7- new joins are blocked.");
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
    iprintlnbold("^2SERVER LOCKDOWN DISABLED ^7- joining is open.");
    menuAddAdminActivity(actor, "disabled server lockdown");
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

    if(!isDefined(level.cwsScheduledEventId))
    {
        level.cwsScheduledEventId = 0;
    }
    level.cwsScheduledEventId++;
    eventId = level.cwsScheduledEventId;
    level.cwsScheduledEventActive = true;
    level.cwsScheduledEventType = eventType;
    level.cwsScheduledEventMaintenance = false;
    actor = menuGetPlayerName(self);
    menuAddAdminActivity(actor, "scheduled " + eventType + " in " + delay + " seconds");
    self maps\mp\gametypes\menu::closeBaseMenu();
    iprintlnbold("^3Scheduled " + eventType + " in ^7" + delay + " seconds.");
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
            iprintlnbold("^3Scheduled " + eventType + " in ^710 seconds.");
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
        iprintlnbold("^3[SERVER] ^7" + payload);
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
    if(!isDefined(level.cwsScheduledEventId))
    {
        level.cwsScheduledEventId = 0;
    }
    level.cwsScheduledEventId++;
    eventId = level.cwsScheduledEventId;
    level.cwsScheduledEventActive = true;
    level.cwsScheduledEventType = "maintenance " + action;
    level.cwsScheduledEventMaintenance = true;
    actor = menuGetPlayerName(self);
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
            iprintlnbold("^1MAINTENANCE: ^7server " + action + " in " + remaining + " seconds.");
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
    self iprintln("^2Server preset applied: ^7" + preset);
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
    iprintlnbold("^3Teams updated: ^7" + moved + " players");
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
    self iprintln("^2Allies: ^7" + allies + " ^1Axis: ^7" + axis + " ^3Spectators: ^7" + spectators);
    if(isDefined(game["teamScores"]) && isDefined(game["teamScores"]["allies"]) && isDefined(game["teamScores"]["axis"]))
    {
        self iprintln("^2Allies score: ^7" + game["teamScores"]["allies"] + " ^1Axis score: ^7" + game["teamScores"]["axis"]);
    }
}

/* Prints live menu and server state to the requesting administrator. */
menuShowGscDiagnostics(input)
{
    self iprintln("^3GSC menu: ^2Loaded ^3Role: ^7" + self maps\mp\gametypes\menu::menuGetAccessName());
    self iprintln("^3Map: ^7" + getDvar("mapname") + " ^3Mode: ^7" + getDvar("g_gametype") + " ^3Players: ^7" + level.players.size);
    self iprintln("^3Gravity: ^7" + getDvar("g_gravity") + " ^3Speed: ^7" + getDvar("g_speed") + " ^3Timescale: ^7" + getDvar("timescale"));
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

    self iprintln("^3Player: ^7" + menuGetPlayerName(target) + " ^3Slot: ^7" + target getEntityNumber());
    self iprintln("^3GUID: ^7" + guid);
    self iprintln("^3Team: ^7" + team + " ^3State: ^7" + state);
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
    self iprintln("^2Player brought to you.");
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
        self iprintln("^1Player frozen.");
    }
    else
    {
        self iprintln("^2Player unfrozen.");
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
    self iprintln("^2Player ammo refilled.");
}

menuStripSelectedPlayerWeapons(input)
{
    target = self menuGetAdminSelectedPlayer();

    if(!isDefined(target))
    {
        return;
    }

    target takeAllWeapons();
    self iprintln("^1Player weapons removed.");
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
    self iprintln("^2Player health restored.");
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
    self iprintln("^2Player state reset.");
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
    self iprintln("^3Player: ^7" + menuGetPlayerName(target) + " ^3Weapon: ^7" + weapon);
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
    self iprintln("^2Player moved to ^7" + team + ".");
}

menuSendSelectedPlayerMessage(message)
{
    target = self menuGetSelectedPlayerForAction();

    if(!isDefined(target))
    {
        return;
    }

    target iprintlnbold("^3[STAFF] ^7" + message);
    self iprintln("^2Private staff message sent.");
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
        self iprintln("^1No player selected.");
        return undefined;
    }

    target = self.menu.selectedPlayer;

    if(!isDefined(target))
    {
        self iprintln("^1That player is no longer connected.");
        return undefined;
    }

    return target;
}

menuGetAdminSelectedPlayer()
{
    if(!self maps\mp\gametypes\menu::menuIsAdmin())
    {
        self iprintln("^1Admin access is required.");
        return undefined;
    }

    return self menuGetSelectedPlayerForAction();
}

/* Enters watch mode and owns spectator cleanup when watching ends. */
menuWatchPlayer(target)
{
    self endon("disconnect");

    if(!isDefined(target))
    {
        return;
    }

    self notify("menu_watch_stop");
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
    self iprintln("^2Watching ^7" + menuGetPlayerName(target) + "^2. Melee, Frag, or Smoke exits.");

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
    self notify("menu_watch_stop");
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
    self iprintln("^3Stopped watching.");
}

menuKeepEyeOnSelectedPlayer(input)
{
    if(!self maps\mp\gametypes\menu::menuIsOwner())
    {
        self iprintln("^1Owner access is required.");
        return;
    }

    target = self menuGetSelectedPlayerForAction();
    if(!isDefined(target) || target == self)
    {
        self iprintln("^1Select another connected player.");
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
    self iprintln("^2Keeping an eye on ^7" + menuGetPlayerName(target) + "^2. Select Keep Eye On again to stop.");
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
        menuSetHudTextIfChanged(hud, labels[i]);
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

    menuSetHudTextIfChanged(self.menuKeepEyeHud[0], "^7Player Name: ^2" + menuGetPlayerName(watchedPlayer));
    menuSetHudTextIfChanged(self.menuKeepEyeHud[1], "^7Target: ^3" + targetName);
    menuSetHudTextIfChanged(self.menuKeepEyeHud[2], "^7Crosshair Target: ^3" + crosshairName);
    menuSetHudTextIfChanged(self.menuKeepEyeHud[3], "^7Status: " + status);
}

menuKeepEyeDisable()
{
    wasActive = isDefined(self.menuKeepEyeActive) && self.menuKeepEyeActive;
    self.menuKeepEyeActive = false;
    self menuKeepEyeHudDisable();
    self.menuKeepEyeTarget = undefined;
    self.menuKeepEyeLastTarget = undefined;
    self.menuKeepEyeScore = 0;
    self notify("menu_keep_eye_stop");

    if(wasActive)
    {
        self iprintln("^3Keep Eye On stopped.");
    }
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

    for(i = 0; i < self.menuWatchIcons.size; i++)
    {
        icon = self.menuWatchIcons[i];

        if(!isDefined(icon) || !isDefined(icon.menuWatchTarget))
        {
            continue;
        }

        icon.color = menuWatchEspColorForTarget(watchedPlayer, icon.menuWatchTarget);
    }

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
        menuSetHudTextIfChanged(hud, labels[i]);
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

    menuSetHudTextIfChanged(self.menuWatchTelemetryHud[0], "^7Player Name: ^2" + menuGetPlayerName(watchedPlayer));
    menuSetHudTextIfChanged(self.menuWatchTelemetryHud[1], "^7Target: ^3" + targetName);
    menuSetHudTextIfChanged(self.menuWatchTelemetryHud[2], "^7Crosshair Target: " + crosshairText);
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
    self iprintln("^2UFO Mode: ON ^7- press melee to exit.");
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

    self iprintln("^1UFO Mode: OFF");
}

menuWatchUfoExit()
{
    self endon("disconnect");

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
    self iprintln("^2Hidden. ^7Press melee to return.");
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

    self iprintln("^3Visible again.");
}

menuWatchHideExit()
{
    self endon("disconnect");

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
        self iprintln("^1Bot Warfare is not detected on this server.");
        return;
    }

    self iprintln("^3Bot Warfare: ^7" + menuDvarText("bots_main") + " ^3Fill: ^7" + menuDvarText("bots_manage_fill") + " ^3Mode: ^7" + menuDvarText("bots_manage_fill_mode"));
    self iprintln("^3Skill: ^7" + menuDvarText("bots_skill") + " ^3Team: ^7" + menuDvarText("bots_team") + " ^3Chat: ^7" + menuDvarText("bots_main_chat"));
    self iprintln("^3Obj: ^7" + menuDvarText("bots_play_obj") + " ^3Streaks: ^7" + menuDvarText("bots_play_killstreak") + " ^3Camp: ^7" + menuDvarText("bots_play_camp"));
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
    self iprintln("^2Bot fill set to ^7" + amount + " ^2and watch players enabled.");
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

    self iPrintln("^2" + name + " set to ^7" + value);
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
        self iPrintln("^2Enabled ^7" + weapon);
    }
    else
    {
        level.disabledWeapons[weapon] = true;
        self iPrintln("^1Disabled ^7" + weapon);
    }
}

resetWeaponRestrictions()
{
    level.disabledWeapons = [];
    self iPrintln("^2All weapon restrictions reset.");
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
            self iPrintln("^1That weapon is restricted.");
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
        self iprintln("^2Chat with others: ^7OFF");

    } else {
        self.menu.otherschat = true;
        Exec("set cg_chatWithOtherTeams 1");
        self iprintln("^2Chat with others: ^7ON");
    }
}
