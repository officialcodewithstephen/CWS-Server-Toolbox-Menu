#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;

/*
    CWS themed map voting for IW4x.

    The voting model and endgame insertion point were adapted from
    jakelooker/IW4x-Map-Voting-System (_mapvote.gsc), licensed GPL-3.0.
    Its HUD/menu implementation was intentionally replaced with the CWS menu
    layout, controls, themes, sizing, and bounded string behavior.
*/

init()
{
    if(isDefined(level.cwsMapVoteInitialized) && level.cwsMapVoteInitialized)
    {
        return;
    }

    level.cwsMapVoteInitialized = true;
    SetDvarIfUninitialized("mapvote_enabled", 1);
    SetDvarIfUninitialized("mapvote_small_maps", "mp_rust,mp_rust_long,mp_shipment,mp_shipment_long,mp_nuked,mp_dome,mp_killhouse,mp_firingrange,mp_checkpoint,mp_hardhat,mp_cargoship");
    SetDvarIfUninitialized("mapvote_med_maps", "mp_terminal,mp_highrise,mp_favela,mp_fav_tropical,mp_crash,mp_crash_snow,mp_crash_tropical,mp_backlot,mp_strike,mp_cross_fire,mp_citystreets,mp_showdown,mp_bravo,mp_alpha,mp_subbase,mp_invasion,mp_trailerpark,mp_compact,mp_complex,mp_abandon,mp_storm,mp_storm_spring,mp_seatown,mp_underground,mp_paris,mp_plaza2");
    SetDvarIfUninitialized("mapvote_big_maps", "mp_afghan,mp_derail,mp_estate,mp_estate_tropical,mp_boneyard,mp_brecourt,mp_rundown,mp_underpass,mp_fuel2,mp_overgrown,mp_pipeline,mp_bloc,mp_bloc_sh,mp_convoy,mp_countdown,mp_farm,mp_village,mp_broadcast,mp_carentan,mp_hangareturn,mp_efa_market,mp_quarry");
    SetDvarIfUninitialized("mapvote_modes", "arena,ctf,dd,dom,dm,gtnw,koth,oneflag,sab,sd,war");
    SetDvarIfUninitialized("mapvote_map_timer", 30);
    SetDvarIfUninitialized("mapvote_gamemode_timer", 30);
    SetDvarIfUninitialized("mapvote_optionsCount", 15);
    SetDvarIfUninitialized("cws_mapvote_bootstrapped", 0);
    if(getDvarInt("cws_mapvote_bootstrapped") <= 0)
    {
        setDvar("mapvote_enabled", "1");
        setDvar("cws_mapvote_bootstrapped", "1");
    }
    mapVoteInstallEndGameHook();
    logPrint("[CWSMAPVOTE] initialized enabled=" + getDvar("mapvote_enabled") + " hook=installed\n");
    level thread mapVoteConnectionMonitor();
}

mapVoteInstallEndGameHook()
{
    if(isDefined(level.cwsMapVoteHookInstalled) && level.cwsMapVoteHookInstalled)
    {
        return;
    }

    replaceFunc(maps\mp\gametypes\_gamelogic::endGame, ::mapVoteEndGameHook);
    level.cwsMapVoteHookInstalled = true;
}

/* Toggles persistent map voting and refreshes the state-labelled menu item. */
menuToggleEnabled(input)
{
    enabled = getDvarInt("mapvote_enabled") <= 0;
    if(enabled)
    {
        setDvar("mapvote_enabled", "1");
        mapVoteInstallEndGameHook();
        status = "enabled";
    }
    else
    {
        setDvar("mapvote_enabled", "0");
        status = "disabled";
    }

    self maps\mp\gametypes\menu_functions::menuShowNotification("MAP VOTING", "End-of-match voting " + status + ".", "success");
    self maps\mp\gametypes\menu::loadBaseMenu("server_map_voting");
}

menuSetOptionCount(value)
{
    count = int(value);
    if(count < 2)
    {
        count = 2;
    }
    else if(count > 15)
    {
        count = 15;
    }

    setDvar("mapvote_optionsCount", "" + count);
    self maps\mp\gametypes\menu_functions::menuShowNotification("MAP VOTING", "Vote choices set to " + count + ".", "success");
}

/* Admin-menu callback for a clamped zero-to-thirty-second timer. */
menuSetTimer(value)
{
    seconds = int(value);
    if(seconds < 0)
    {
        seconds = 0;
    }
    else if(seconds > 30)
    {
        seconds = 30;
    }

    setDvar("mapvote_map_timer", "" + seconds);
    self maps\mp\gametypes\menu_functions::menuShowNotification("MAP VOTING", "Timer set to " + seconds + " seconds.", "success");
}

mapVoteConnectionMonitor()
{
    for(;;)
    {
        level waittill("connected", player);
        if(isDefined(player) && isDefined(level.cwsMapVoteActive) && level.cwsMapVoteActive && !mapVoteIsBot(player))
        {
            player thread mapVotePlayer(level.cwsMapVoteId);
        }
    }
}

/* Builds a balanced vote from the configured small, medium, and large pools. */
mapVoteBuildMapOptions()
{
    installedMaps = GetMapList();
    smallMaps = mapVoteFilterInstalled(strTok(getDvar("mapvote_small_maps"), ","), installedMaps);
    mediumMaps = mapVoteFilterInstalled(strTok(getDvar("mapvote_med_maps"), ","), installedMaps);
    largeMaps = mapVoteFilterInstalled(strTok(getDvar("mapvote_big_maps"), ","), installedMaps);
    smallMaps = mapVoteShuffle(smallMaps);
    mediumMaps = mapVoteShuffle(mediumMaps);
    largeMaps = mapVoteShuffle(largeMaps);

    optionCount = getDvarInt("mapvote_optionsCount");
    if(optionCount < 2)
    {
        optionCount = 2;
    }
    else if(optionCount > 15)
    {
        optionCount = 15;
    }

    uniqueMaps = [];
    uniqueMaps = mapVoteAppendUnique(uniqueMaps, smallMaps);
    uniqueMaps = mapVoteAppendUnique(uniqueMaps, mediumMaps);
    uniqueMaps = mapVoteAppendUnique(uniqueMaps, largeMaps);
    if(uniqueMaps.size == 1)
    {
        return mapVoteBuildSingleMapChoices(uniqueMaps[0], optionCount);
    }

    options = [];
    poolIndex = 0;
    while(options.size < optionCount)
    {
        added = false;
        if(poolIndex < smallMaps.size && !mapVoteArrayContains(options, smallMaps[poolIndex]))
        {
            options[options.size] = smallMaps[poolIndex];
            added = true;
        }
        if(options.size < optionCount && poolIndex < mediumMaps.size && !mapVoteArrayContains(options, mediumMaps[poolIndex]))
        {
            options[options.size] = mediumMaps[poolIndex];
            added = true;
        }
        if(options.size < optionCount && poolIndex < largeMaps.size && !mapVoteArrayContains(options, largeMaps[poolIndex]))
        {
            options[options.size] = largeMaps[poolIndex];
            added = true;
        }
        poolIndex++;
        if(!added && poolIndex >= smallMaps.size && poolIndex >= mediumMaps.size && poolIndex >= largeMaps.size)
        {
            break;
        }
    }
    modes = mapVoteBuildModeOptions();
    if(modes.size <= 0)
    {
        modes[0] = getDvar("g_gametype");
    }

    choices = [];
    for(i = 0; i < options.size; i++)
    {
        choices[i] = options[i] + "|" + modes[i % modes.size];
    }
    return choices;
}

mapVoteFilterInstalled(configuredMaps, installedMaps)
{
    result = [];
    if(!isDefined(configuredMaps) || !isDefined(installedMaps))
    {
        return result;
    }

    for(i = 0; i < configuredMaps.size; i++)
    {
        mapName = configuredMaps[i];
        if(mapName == "" || !mapVoteArrayContains(installedMaps, mapName) || mapVoteArrayContains(result, mapName))
        {
            continue;
        }
        result[result.size] = mapName;
    }
    return result;
}

mapVoteAppendUnique(result, values)
{
    for(i = 0; i < values.size; i++)
    {
        if(!mapVoteArrayContains(result, values[i]))
        {
            result[result.size] = values[i];
        }
    }
    return result;
}

/* For 24/7 servers, keeps the map fixed and makes each gametype votable. */
mapVoteBuildSingleMapChoices(mapName, optionCount)
{
    modes = mapVoteBuildModeOptions();
    if(modes.size <= 0)
    {
        modes[0] = getDvar("g_gametype");
    }

    choices = [];
    for(i = 0; i < modes.size && i < optionCount; i++)
    {
        choices[choices.size] = mapName + "|" + modes[i];
    }
    return choices;
}

mapVoteBuildModeOptions()
{
    configuredModes = strTok(getDvar("mapvote_modes"), ",");
    modes = [];
    for(i = 0; i < configuredModes.size && modes.size < 15; i++)
    {
        mode = configuredModes[i];
        if(mode != "" && !mapVoteArrayContains(modes, mode))
        {
            modes[modes.size] = mode;
        }
    }
    return mapVoteShuffle(modes);
}

mapVoteArrayContains(values, value)
{
    if(!isDefined(values))
    {
        return false;
    }
    for(i = 0; i < values.size; i++)
    {
        if(values[i] == value)
        {
            return true;
        }
    }
    return false;
}

mapVoteShuffle(values)
{
    for(i = values.size - 1; i > 0; i--)
    {
        swapIndex = randomInt(i + 1);
        swapValue = values[i];
        values[i] = values[swapIndex];
        values[swapIndex] = swapValue;
    }
    return values;
}

/* Runs one map-and-gametype vote and updates rotation only outside test mode. */
mapVoteStart()
{
    if(isDefined(level.cwsMapVoteSessionActive) && level.cwsMapVoteSessionActive)
    {
        return;
    }

    mapOptions = mapVoteBuildMapOptions();
    logPrint("[CWSMAPVOTE] starting options=" + mapOptions.size + " timer=" + getDvar("mapvote_map_timer") + "\n");
    if(mapOptions.size < 2)
    {
        mapVoteNotifyAll("MAP VOTING", "At least two configured maps must be installed.", "error");
        return;
    }
    level.cwsMapVoteSessionActive = true;

    winningIndex = mapVoteRunPhase("map", mapOptions, getDvarInt("mapvote_map_timer"));
    winningChoice = mapOptions[winningIndex];
    winningMap = mapVoteChoiceMap(winningChoice);
    winningMode = mapVoteChoiceMode(winningChoice);
    level.cwsMapVoteSessionActive = false;

    rotation = "gametype " + winningMode + " map " + winningMap;
    setDvar("sv_maprotation", rotation);
    setDvar("sv_maprotationcurrent", rotation);
    mapVoteNotifyAll("MAP VOTE COMPLETE", mapVoteChoiceDisplayName(winningChoice) + " will be played next.", "success");
}

mapVoteChoiceMap(choice)
{
    parts = strTok(choice, "|");
    if(parts.size > 0)
    {
        return parts[0];
    }
    return choice;
}

mapVoteChoiceMode(choice)
{
    parts = strTok(choice, "|");
    if(parts.size > 1)
    {
        return parts[1];
    }
    return getDvar("g_gametype");
}

mapVoteRunPhase(phase, options, duration)
{
    if(!isDefined(level.cwsMapVoteId))
    {
        level.cwsMapVoteId = 0;
    }
    level.cwsMapVoteId++;
    voteId = level.cwsMapVoteId;
    level.cwsMapVoteActive = true;
    level.cwsMapVotePhase = phase;
    level.cwsMapVoteOptions = options;
    level.cwsMapVoteResults = [];
    level.cwsMapVoteFirstVoter = [];
    level.cwsMapVoteNextOrder = 0;
    for(i = 0; i < options.size; i++)
    {
        level.cwsMapVoteResults[i] = 0;
        level.cwsMapVoteFirstVoter[i] = "";
    }

    if(duration < 0)
    {
        duration = 0;
    }
    else if(duration > 30)
    {
        duration = 30;
    }
    level.cwsMapVoteRemaining = duration;

    for(i = 0; i < level.players.size; i++)
    {
        player = level.players[i];
        if(isDefined(player) && !mapVoteIsBot(player))
        {
            player.menuMapVoteHasVoted = false;
            player.menuMapVoteSelection = 0;
            player.menuMapVoteVotedSelection = -1;
            player.menuMapVoteOrder = undefined;
            player thread mapVotePlayer(voteId);
        }
    }

    endTime = getTime() + (duration * 1000);
    for(;;)
    {
        mapVoteRecount();
        milliseconds = endTime - getTime();
        if(milliseconds <= 0)
        {
            level.cwsMapVoteRemaining = 0;
            break;
        }
        level.cwsMapVoteRemaining = int((milliseconds + 999) / 1000);
        wait .1;
    }

    mapVoteRecount();
    winningIndex = mapVoteGetWinner(level.cwsMapVoteResults);
    level.cwsMapVoteActive = false;
    level notify("cws_map_vote_end");
    wait .2;
    return winningIndex;
}

mapVoteRecount()
{
    if(!isDefined(level.cwsMapVoteOptions) || !isDefined(level.cwsMapVoteResults))
    {
        return;
    }

    for(i = 0; i < level.cwsMapVoteResults.size; i++)
    {
        level.cwsMapVoteResults[i] = 0;
        level.cwsMapVoteFirstVoter[i] = "";
    }

    firstOrders = [];

    for(i = 0; i < level.players.size; i++)
    {
        player = level.players[i];
        if(!isDefined(player) || mapVoteIsBot(player) || !isDefined(player.menuMapVoteHasVoted) || !player.menuMapVoteHasVoted)
        {
            continue;
        }

        selection = player.menuMapVoteVotedSelection;
        if(selection >= 0 && selection < level.cwsMapVoteResults.size)
        {
            level.cwsMapVoteResults[selection]++;
            order = 999999;
            if(isDefined(player.menuMapVoteOrder))
            {
                order = player.menuMapVoteOrder;
            }
            if(!isDefined(firstOrders[selection]) || order < firstOrders[selection])
            {
                firstOrders[selection] = order;
                level.cwsMapVoteFirstVoter[selection] = mapVotePlayerName(player);
            }
        }
    }
}

mapVoteGetWinner(results)
{
    highest = -1;
    winners = [];
    for(i = 0; i < results.size; i++)
    {
        if(results[i] > highest)
        {
            highest = results[i];
            winners = [];
            winners[0] = i;
        }
        else if(results[i] == highest)
        {
            winners[winners.size] = i;
        }
    }
    return winners[randomInt(winners.size)];
}

mapVoteIsBot(player)
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

mapVoteNotifyAll(title, caption, kind)
{
    if(!isDefined(level.players))
    {
        return;
    }
    for(i = 0; i < level.players.size; i++)
    {
        if(isDefined(level.players[i]) && !mapVoteIsBot(level.players[i]))
        {
            level.players[i] maps\mp\gametypes\menu_functions::menuShowNotification(title, caption, kind);
        }
    }
}

mapVotePlayerName(player)
{
    name = "Player";
    if(isDefined(player) && isDefined(player.name) && player.name != "")
    {
        name = player.name;
    }
    return maps\mp\gametypes\menu::menuGetStaticMenuText(name, 14);
}

mapVoteVoterSummary(firstVoter, voteCount)
{
    if(voteCount <= 0 || !isDefined(firstVoter) || firstVoter == "")
    {
        return "";
    }

    summary = firstVoter;
    if(voteCount > 1)
    {
        summary += " + " + (voteCount - 1) + " more";
    }
    return mapVoteStableVoterSummary(summary, voteCount);
}

/* Caps unique player/count combinations generated across repeated votes. */
mapVoteStableVoterSummary(summary, voteCount)
{
    if(!isDefined(level.cwsMapVoteVoterTextCache))
    {
        level.cwsMapVoteVoterTextCache = [];
    }
    for(i = 0; i < level.cwsMapVoteVoterTextCache.size; i++)
    {
        if(level.cwsMapVoteVoterTextCache[i] == summary)
        {
            return summary;
        }
    }
    if(level.cwsMapVoteVoterTextCache.size >= 48)
    {
        if(voteCount > 1)
        {
            return "Player + " + (voteCount - 1) + " more";
        }
        return "Player";
    }
    level.cwsMapVoteVoterTextCache[level.cwsMapVoteVoterTextCache.size] = summary;
    return summary;
}

/* Owns one player's vote HUD and input until the active vote generation ends. */
mapVotePlayer(voteId)
{
    self endon("disconnect");
    if(isDefined(self.menuMapVoteThreadId) && self.menuMapVoteThreadId == voteId)
    {
        return;
    }

    self.menuMapVoteThreadId = voteId;
    self.menuMapVoteActive = true;
    if(!isDefined(self.menuMapVoteSelection))
    {
        self.menuMapVoteSelection = 0;
    }
    if(!isDefined(self.menuMapVoteHasVoted))
    {
        self.menuMapVoteHasVoted = false;
    }
    if(!isDefined(self.menuMapVoteVotedSelection))
    {
        self.menuMapVoteVotedSelection = -1;
    }
    self maps\mp\gametypes\menu::menuSafeInitPlayer();
    self maps\mp\gametypes\menu::menuInitControlBinds();
    self maps\mp\gametypes\menu::menuStartCommandButtons();
    self maps\mp\gametypes\menu::menuInitVisualSettings();
    self maps\mp\gametypes\menu::closeBaseMenu();
    self freezeControls(true);
    self mapVoteCreateHud();

    while(isDefined(level.cwsMapVoteActive) && level.cwsMapVoteActive && level.cwsMapVoteId == voteId)
    {
        if(self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["up"]))
        {
            self.menuMapVoteSelection--;
            if(self.menuMapVoteSelection < 0)
            {
                self.menuMapVoteSelection = level.cwsMapVoteOptions.size - 1;
            }
            self mapVoteUpdateSelection();
            self mapVoteWaitBindRelease(self.menuControlBinds["up"], voteId);
        }
        else if(self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["down"]))
        {
            self.menuMapVoteSelection++;
            if(self.menuMapVoteSelection >= level.cwsMapVoteOptions.size)
            {
                self.menuMapVoteSelection = 0;
            }
            self mapVoteUpdateSelection();
            self mapVoteWaitBindRelease(self.menuControlBinds["down"], voteId);
        }
        else if(self maps\mp\gametypes\menu::menuBindPressed(self.menuControlBinds["select"]))
        {
            hadVote = self.menuMapVoteHasVoted;
            newVote = !self.menuMapVoteHasVoted || self.menuMapVoteVotedSelection != self.menuMapVoteSelection;
            self.menuMapVoteHasVoted = true;
            self.menuMapVoteVotedSelection = self.menuMapVoteSelection;
            if(newVote)
            {
                level.cwsMapVoteNextOrder++;
                self.menuMapVoteOrder = level.cwsMapVoteNextOrder;
                actionText = " voted for ";
                if(hadVote)
                {
                    actionText = " changed vote to ";
                }
                mapVoteNotifyAll("MAP VOTE", mapVotePlayerName(self) + actionText + mapVoteChoiceDisplayName(level.cwsMapVoteOptions[self.menuMapVoteSelection]) + ".", "info");
            }
            self playLocalSound("mouse_click");
            self mapVoteWaitBindRelease(self.menuControlBinds["select"], voteId);
        }

        self mapVoteUpdateValues();
        wait .05;
    }

    self mapVoteDestroyHud();
    self.menuMapVoteActive = false;
    self.menuMapVoteThreadId = undefined;
    self freezeControls(false);
}

mapVoteWaitBindRelease(bind, voteId)
{
    while(isDefined(level.cwsMapVoteActive) && level.cwsMapVoteActive && level.cwsMapVoteId == voteId && self maps\mp\gametypes\menu::menuBindPressed(bind))
    {
        wait .05;
    }
}

mapVoteCreateHud()
{
    self mapVoteDestroyHud();
    self.menuMapVoteHud = [];
    self.menuMapVoteLabels = [];
    self.menuMapVoteCounts = [];

    width = maps\mp\gametypes\menu::getMenuPanelWidth();
    optionY = maps\mp\gametypes\menu::getMenuOptionY();
    distance = maps\mp\gametypes\menu::getMenuOptionDistance();
    optionCount = level.cwsMapVoteOptions.size;
    visibleCount = optionCount;
    if(visibleCount > maps\mp\gametypes\menu::getMenuDisplayCount())
    {
        visibleCount = maps\mp\gametypes\menu::getMenuDisplayCount();
    }
    self.menuMapVoteVisibleCount = visibleCount;
    self.menuMapVoteFirstOption = 0;
    panelTop = maps\mp\gametypes\menu::getMenuPanelTopY();
    footerSeparatorY = optionY + ((visibleCount - 1) * distance) + 17;
    footerY = footerSeparatorY + 11;
    panelBottom = footerY + 10;
    panelHeight = panelBottom - panelTop;
    panelCenterY = panelTop + (panelHeight / 2);
    centerX = self maps\mp\gametypes\menu::getMenuX(0);
    centerY = self maps\mp\gametypes\menu::getMenuY(panelCenterY);
    headerTopY = self maps\mp\gametypes\menu::getMenuY(-157);
    headerSeparatorY = self maps\mp\gametypes\menu::getMenuY(-99);
    footerSeparatorY = self maps\mp\gametypes\menu::getMenuY(footerSeparatorY);
    footerY = self maps\mp\gametypes\menu::getMenuY(footerY);
    background = self maps\mp\gametypes\menu::menuGetBackgroundColor();
    accent = self maps\mp\gametypes\menu::getMenuAccentColor();
    fontColor = self maps\mp\gametypes\menu::menuGetFontColor();
    selection = self maps\mp\gametypes\menu::menuGetSelectionColor();
    font = self maps\mp\gametypes\menu::menuGetFontName();

    self mapVoteTrackHud(self mapVoteRectangle(centerX, centerY, width, panelHeight, background, self maps\mp\gametypes\menu::menuGetPanelOpacity(), 200, self maps\mp\gametypes\menu::menuGetBackgroundShader()));
    self mapVoteTrackHud(self mapVoteRectangle(centerX, headerTopY, width, 3, accent, 1, 202, "white"));
    self mapVoteTrackHud(self mapVoteRectangle(centerX, headerSeparatorY, width, 2, accent, .9, 202, "white"));
    self mapVoteTrackHud(self mapVoteRectangle(centerX, footerSeparatorY, width, 2, accent, .9, 202, "white"));
    self.menuMapVoteSelector = self mapVoteRectangle(centerX, self maps\mp\gametypes\menu::getMenuY(optionY), width, maps\mp\gametypes\menu::getMenuSelectionHeight(""), selection, .95, 201, "white");
    self mapVoteTrackHud(self.menuMapVoteSelector);
    self mapVoteTrackHud(self mapVoteText(self maps\mp\gametypes\menu::getMenuX(-122), self maps\mp\gametypes\menu::getMenuY(-138), 1.45, "left", font, fontColor, "MAP VOTE"));
    self mapVoteTrackHud(self mapVoteText(self maps\mp\gametypes\menu::getMenuX(-122), self maps\mp\gametypes\menu::getMenuY(-118), .85, "left", font, accent, "TIME REMAINING"));
    self.menuMapVoteTimer = self mapVoteValue(self maps\mp\gametypes\menu::getMenuX(118), self maps\mp\gametypes\menu::getMenuY(-118), .9, "right", font, accent);
    self mapVoteTrackHud(self.menuMapVoteTimer);

    footer = "[" + maps\mp\gametypes\menu::menuGetBindToken(self.menuControlBinds["up"]) + "]/";
    footer += "[" + maps\mp\gametypes\menu::menuGetBindToken(self.menuControlBinds["down"]) + "] scroll  ";
    footer += "[" + maps\mp\gametypes\menu::menuGetBindToken(self.menuControlBinds["select"]) + "] vote";
    self mapVoteTrackHud(self mapVoteText(centerX, footerY, .9, "center", font, fontColor, footer));

    for(i = 0; i < visibleCount; i++)
    {
        rowY = self maps\mp\gametypes\menu::getMenuY(optionY + (i * distance));
        label = self mapVoteText(self maps\mp\gametypes\menu::getMenuX(-118), rowY, maps\mp\gametypes\menu::getMenuDefaultFontScale(), "left", font, fontColor, "");
        count = self mapVoteText(self maps\mp\gametypes\menu::getMenuX(118), rowY, .82, "right", font, fontColor, "");
        label.alpha = .65;
        count.alpha = .65;
        self.menuMapVoteLabels[i] = label;
        self.menuMapVoteCounts[i] = count;
        self mapVoteTrackHud(label);
        self mapVoteTrackHud(count);
    }

    self mapVoteRefreshRows();
    self mapVoteUpdateSelection();
    self mapVoteUpdateValues();
}

mapVoteUpdateSelection()
{
    if(!isDefined(self.menuMapVoteSelector) || !isDefined(self.menuMapVoteLabels))
    {
        return;
    }

    distance = maps\mp\gametypes\menu::getMenuOptionDistance();
    firstOption = 0;
    if(level.cwsMapVoteOptions.size > self.menuMapVoteVisibleCount && self.menuMapVoteSelection >= self.menuMapVoteVisibleCount)
    {
        firstOption = self.menuMapVoteSelection - self.menuMapVoteVisibleCount + 1;
    }
    if(!isDefined(self.menuMapVoteFirstOption) || self.menuMapVoteFirstOption != firstOption)
    {
        self.menuMapVoteFirstOption = firstOption;
        self mapVoteRefreshRows();
    }
    selectedSlot = self.menuMapVoteSelection - self.menuMapVoteFirstOption;
    self.menuMapVoteSelector moveOverTime(.12);
    self.menuMapVoteSelector.y = self maps\mp\gametypes\menu::getMenuY(maps\mp\gametypes\menu::getMenuOptionY() + (selectedSlot * distance));

    for(i = 0; i < self.menuMapVoteLabels.size; i++)
    {
        self.menuMapVoteLabels[i].alpha = .65;
        self.menuMapVoteCounts[i].alpha = .65;
        self.menuMapVoteLabels[i] changeFontScaleOverTime(.12);
        self.menuMapVoteCounts[i] changeFontScaleOverTime(.12);
        self.menuMapVoteLabels[i].fontscale = maps\mp\gametypes\menu::getMenuDefaultFontScale();
        self.menuMapVoteCounts[i].fontscale = maps\mp\gametypes\menu::getMenuDefaultFontScale();
    }

    self.menuMapVoteLabels[selectedSlot].alpha = 1;
    self.menuMapVoteCounts[selectedSlot].alpha = 1;
    self.menuMapVoteLabels[selectedSlot] changeFontScaleOverTime(.12);
    self.menuMapVoteCounts[selectedSlot] changeFontScaleOverTime(.12);
    self.menuMapVoteLabels[selectedSlot].fontscale = maps\mp\gametypes\menu::getMenuSelectedFontScale();
    self.menuMapVoteCounts[selectedSlot].fontscale = maps\mp\gametypes\menu::getMenuSelectedFontScale();
    self playLocalSound("mouse_over");
}

mapVoteRefreshRows()
{
    if(!isDefined(self.menuMapVoteLabels) || !isDefined(self.menuMapVoteFirstOption))
    {
        return;
    }

    for(i = 0; i < self.menuMapVoteLabels.size; i++)
    {
        optionIndex = self.menuMapVoteFirstOption + i;
        labelText = mapVoteStableDisplayName(level.cwsMapVotePhase, level.cwsMapVoteOptions[optionIndex], optionIndex);
        self maps\mp\gametypes\menu::menuSetTextIfChanged(self.menuMapVoteLabels[i], labelText);
        self.menuMapVoteCounts[i].menuLastValue = undefined;
        self.menuMapVoteCounts[i].menuLastVoter = undefined;
    }
}

mapVoteUpdateValues()
{
    if(!isDefined(self.menuMapVoteTimer) || !isDefined(self.menuMapVoteCounts) || !isDefined(level.cwsMapVoteResults))
    {
        return;
    }

    if(!isDefined(self.menuMapVoteLastTime) || self.menuMapVoteLastTime != level.cwsMapVoteRemaining)
    {
        self.menuMapVoteTimer setValue(level.cwsMapVoteRemaining);
        self.menuMapVoteLastTime = level.cwsMapVoteRemaining;
    }
    for(i = 0; i < self.menuMapVoteCounts.size && i < level.cwsMapVoteResults.size; i++)
    {
        optionIndex = self.menuMapVoteFirstOption + i;
        if(optionIndex >= level.cwsMapVoteResults.size)
        {
            continue;
        }
        voteCount = level.cwsMapVoteResults[optionIndex];
        firstVoter = level.cwsMapVoteFirstVoter[optionIndex];
        if(!isDefined(self.menuMapVoteCounts[i].menuLastValue) || self.menuMapVoteCounts[i].menuLastValue != voteCount || !isDefined(self.menuMapVoteCounts[i].menuLastVoter) || self.menuMapVoteCounts[i].menuLastVoter != firstVoter)
        {
            summary = mapVoteVoterSummary(firstVoter, voteCount);
            self maps\mp\gametypes\menu::menuSetTextIfChanged(self.menuMapVoteCounts[i], summary);
            self.menuMapVoteCounts[i].menuLastValue = voteCount;
            self.menuMapVoteCounts[i].menuLastVoter = firstVoter;
        }
    }
}

mapVoteDisplayName(mapName)
{
    displayName = GetMapArenaInfo(mapName, "longname");
    if(!isDefined(displayName) || displayName == "")
    {
        return mapName;
    }
    return maps\mp\gametypes\menu::menuCleanMapDisplayName(displayName);
}

mapVoteModeDisplayName(mode)
{
    switch(mode)
    {
        case "arena": return "Arena";
        case "ctf": return "Capture the Flag";
        case "dd": return "Demolition";
        case "dom": return "Domination";
        case "dm": return "Free For All";
        case "gtnw": return "Global Thermonuclear War";
        case "koth": return "Headquarters";
        case "oneflag": return "One Flag CTF";
        case "sab": return "Sabotage";
        case "sd": return "Search and Destroy";
        case "war": return "Team Deathmatch";
        case "gun": return "Gun Game";
        case "oic": return "One in the Chamber";
    }
    return mode;
}

mapVoteModeShortName(mode)
{
    switch(mode)
    {
        case "arena": return "Arena";
        case "ctf": return "CTF";
        case "dd": return "Demo";
        case "dom": return "Dom";
        case "dm": return "FFA";
        case "gtnw": return "GTNW";
        case "koth": return "HQ";
        case "oneflag": return "1F CTF";
        case "sab": return "Sab";
        case "sd": return "S&D";
        case "war": return "TDM";
    }
    return mapVoteModeDisplayName(mode);
}

mapVoteChoiceDisplayName(choice)
{
    mapName = mapVoteChoiceMap(choice);
    mode = mapVoteChoiceMode(choice);
    return mapVotePlatform(mapName) + " " + mapVoteDisplayName(mapName) + " (" + mapVoteModeShortName(mode) + ")";
}

mapVotePlatform(mapName)
{
    switch(mapName)
    {
        case "mp_abandon":
        case "mp_afghan":
        case "mp_boneyard":
        case "mp_brecourt":
        case "mp_checkpoint":
        case "mp_compact":
        case "mp_complex":
        case "mp_derail":
        case "mp_estate":
        case "mp_estate_tropical":
        case "mp_favela":
        case "mp_fav_tropical":
        case "mp_fuel2":
        case "mp_highrise":
        case "mp_invasion":
        case "mp_quarry":
        case "mp_rundown":
        case "mp_rust":
        case "mp_rust_long":
        case "mp_subbase":
        case "mp_terminal":
        case "mp_trailerpark":
        case "mp_underpass":
        case "mp_storm":
        case "mp_storm_spring":
            return "[^3MW2^7]";

        case "mp_alpha":
        case "mp_bravo":
        case "mp_dome":
        case "mp_hardhat":
        case "mp_paris":
        case "mp_plaza2":
        case "mp_seatown":
        case "mp_underground":
        case "mp_village":
            return "[^2MW3^7]";

        case "mp_firingrange":
        case "mp_nuked":
            return "[^5BO1^7]";

        case "mp_backlot":
        case "mp_bloc":
        case "mp_bloc_sh":
        case "mp_broadcast":
        case "mp_carentan":
        case "mp_cargoship":
        case "mp_citystreets":
        case "mp_convoy":
        case "mp_countdown":
        case "mp_crash":
        case "mp_crash_snow":
        case "mp_crash_tropical":
        case "mp_cross_fire":
        case "mp_farm":
        case "mp_killhouse":
        case "mp_overgrown":
        case "mp_pipeline":
        case "mp_shipment":
        case "mp_shipment_long":
        case "mp_showdown":
        case "mp_strike":
            return "[^6COD4^7]";
    }
    return "[^1Custom^7]";
}

/* Bounds unique map labels across repeated votes on one long-running map. */
mapVoteStableDisplayName(phase, value, optionIndex)
{
    if(!isDefined(level.cwsMapVoteLabelKeys))
    {
        level.cwsMapVoteLabelKeys = [];
        level.cwsMapVoteLabelValues = [];
    }

    for(i = 0; i < level.cwsMapVoteLabelKeys.size; i++)
    {
        key = phase + "|" + value;
        if(level.cwsMapVoteLabelKeys[i] == key)
        {
            return level.cwsMapVoteLabelValues[i];
        }
    }

    if(level.cwsMapVoteLabelKeys.size >= 48)
    {
        if(phase == "gamemode")
        {
            return "Mode Option " + (optionIndex + 1);
        }
        return "Map Option " + (optionIndex + 1);
    }

    label = mapVoteChoiceDisplayName(value);
    level.cwsMapVoteLabelKeys[level.cwsMapVoteLabelKeys.size] = phase + "|" + value;
    level.cwsMapVoteLabelValues[level.cwsMapVoteLabelValues.size] = label;
    return label;
}

mapVoteTrackHud(elem)
{
    self.menuMapVoteHud[self.menuMapVoteHud.size] = elem;
}

mapVoteRectangle(x, y, width, height, color, alpha, sort, shader)
{
    elem = newClientHudElem(self);
    elem.elemType = "bar";
    elem.horzAlign = "center";
    elem.vertAlign = "middle";
    elem.alignX = "center";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = alpha;
    elem.sort = sort;
    elem.foreground = true;
    elem setShader(shader, width, height);
    return elem;
}

mapVoteText(x, y, scale, align, font, color, text)
{
    elem = self createFontString(font, scale);
    elem.horzAlign = "center";
    elem.vertAlign = "middle";
    elem.alignX = align;
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = 1;
    elem.sort = 203;
    elem.foreground = true;
    elem setText(text);
    return elem;
}

mapVoteValue(x, y, scale, align, font, color)
{
    elem = self createFontString(font, scale);
    elem.horzAlign = "center";
    elem.vertAlign = "middle";
    elem.alignX = align;
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.alpha = 1;
    elem.sort = 203;
    elem.foreground = true;
    elem setValue(0);
    return elem;
}

mapVoteDestroyHud()
{
    if(isDefined(self.menuMapVoteHud))
    {
        for(i = 0; i < self.menuMapVoteHud.size; i++)
        {
            if(isDefined(self.menuMapVoteHud[i]))
            {
                self.menuMapVoteHud[i] destroy();
            }
        }
    }

    self.menuMapVoteHud = undefined;
    self.menuMapVoteLabels = undefined;
    self.menuMapVoteCounts = undefined;
    self.menuMapVoteSelector = undefined;
    self.menuMapVoteTimer = undefined;
    self.menuMapVoteLastTime = undefined;
    self.menuMapVoteVisibleCount = undefined;
    self.menuMapVoteFirstOption = undefined;
}

/*
    IW4 endgame flow with one deliberate insertion: the synchronous map vote
    runs after the result screen and before intermission/exitLevel rotation.
*/
mapVoteEndGameHook(winner, endReasonText, nukeDetonated)
{
    if(!isDefined(nukeDetonated))
    {
        nukeDetonated = false;
    }

    if(game["state"] == "postgame" || level.gameEnded || (isDefined(level.nukeIncoming) && !nukeDetonated && (!isDefined(level.gtnw) || !level.gtnw)))
    {
        return;
    }

    game["state"] = "postgame";
    level.gameEndTime = getTime();
    level.gameEnded = true;
    level.inGracePeriod = false;
    level notify("game_ended", winner);
    levelFlagSet("game_over");
    levelFlagSet("block_notifies");
    waitframe();
    setGameEndTime(0);
    maps\mp\gametypes\_playerlogic::printPredictedSpawnpointCorrectness();

    if(isDefined(winner) && isString(winner) && winner == "overtime")
    {
        maps\mp\gametypes\_gamelogic::endGameOvertime(winner, endReasonText);
        return;
    }
    if(isDefined(winner) && isString(winner) && winner == "halftime")
    {
        maps\mp\gametypes\_gamelogic::endGameHalftime();
        return;
    }

    game["roundsPlayed"]++;
    if(level.teamBased)
    {
        if(winner == "axis" || winner == "allies")
        {
            game["roundsWon"][winner]++;
        }
        maps\mp\gametypes\_gamescore::updateTeamScore("axis");
        maps\mp\gametypes\_gamescore::updateTeamScore("allies");
    }
    else if(isDefined(winner) && isPlayer(winner))
    {
        game["roundsWon"][winner.guid]++;
    }

    maps\mp\gametypes\_gamescore::updatePlacement();
    maps\mp\gametypes\_gamelogic::rankedMatchUpdates(winner);
    foreach(player in level.players)
    {
        player setClientDvar("ui_opensummary", 1);
    }
    setDvar("g_deadChat", 1);
    setDvar("ui_allow_teamchange", 0);

    foreach(player in level.players)
    {
        player thread maps\mp\gametypes\_gamelogic::freezePlayerForRoundEnd(1.0);
        player thread maps\mp\gametypes\_gamelogic::roundEndDoF(4.0);
        player maps\mp\gametypes\_gamelogic::freeGameplayHudElems();
        player setClientDvars("cg_everyoneHearsEveryone", 1);
        player setClientDvars("cg_drawSpectatorMessages", 0, "g_compassShowEnemies", 0);
        if(player.pers["team"] == "spectator")
        {
            player thread maps\mp\gametypes\_playerlogic::spawnIntermission();
        }
    }

    if(!wasOnlyRound() && !nukeDetonated)
    {
        setDvar("scr_gameended", 2);
        maps\mp\gametypes\_gamelogic::displayRoundEnd(winner, endReasonText);
        if(level.showingFinalKillcam)
        {
            foreach(player in level.players)
            {
                player notify("reset_outcome");
            }
            level notify("game_cleanup");
            maps\mp\gametypes\_gamelogic::waittillFinalKillcamDone();
        }

        if(!wasLastRound())
        {
            levelFlagClear("block_notifies");
            if(maps\mp\gametypes\_gamelogic::checkRoundSwitch())
            {
                maps\mp\gametypes\_gamelogic::displayRoundSwitch();
            }
            foreach(player in level.players)
            {
                player.pers["stats"] = player.stats;
            }
            level notify("restarting");
            game["state"] = "playing";
            map_restart(true);
            return;
        }

        if(!level.forcedEnd)
        {
            endReasonText = maps\mp\gametypes\_gamelogic::updateEndReasonText(winner);
        }
    }

    setDvar("scr_gameended", 1);
    if(!isDefined(game["clientMatchDataDef"]))
    {
        game["clientMatchDataDef"] = "mp/clientmatchdata.def";
        setClientMatchDataDef(game["clientMatchDataDef"]);
    }

    maps\mp\gametypes\_missions::roundEnd(winner);
    maps\mp\gametypes\_gamelogic::displayGameEnd(winner, endReasonText);
    if(level.showingFinalKillcam && wasOnlyRound())
    {
        foreach(player in level.players)
        {
            player notify("reset_outcome");
        }
        level notify("game_cleanup");
        maps\mp\gametypes\_gamelogic::waittillFinalKillcamDone();
    }

    levelFlagClear("block_notifies");
    level.intermission = true;
    level notify("spawning_intermission");
    foreach(player in level.players)
    {
        player closeMenus();
        player notify("reset_outcome");
    }

    logPrint("[CWSMAPVOTE] endgame enabled=" + getDvar("mapvote_enabled") + " players=" + level.players.size + "\n");
    if(getDvarInt("mapvote_enabled") > 0)
    {
        level mapVoteStart();
    }

    if(!nukeDetonated)
    {
        visionSetNaked("mpOutro", 0.5);
    }
    foreach(player in level.players)
    {
        player thread maps\mp\gametypes\_playerlogic::spawnIntermission();
    }

    maps\mp\gametypes\_gamelogic::processLobbyData();
    if(matchMakingGame())
    {
        sendMatchData();
    }
    foreach(player in level.players)
    {
        player.pers["stats"] = player.stats;
    }
    logString("game ended");

    if(!nukeDetonated && !level.postGameNotifies)
    {
        if(!wasOnlyRound())
        {
            wait 6.0;
        }
        else
        {
            wait 3.0;
        }
    }
    else
    {
        wait(min(10.0, 4.0 + level.postGameNotifies));
    }

    level notify("exitLevel_called");
    exitLevel(false);
}
