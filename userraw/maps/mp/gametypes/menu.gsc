#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;


/*
    CWS Admin Menu core.
    Owns initialization, access control, menu construction, HUD rendering,
    animation, navigation, and persistent control binds. Gameplay and
    moderation actions live in menu_functions.gsc.
*/
main()
{
    init();
}

init()
{
    if(isDefined(level.menuBaseStarted) && level.menuBaseStarted)
    {
        return;
    }

    level.menuBaseStarted = true;
    level.menu = [];
    level.menuSavedBinds = [];
    level.menu["menu_display_count"] = 7;
    level.menu["menu_option_y"] = -82;
    level.menu["menu_option_distance"] = 22;

    if(getDvar("menu_mod") == "")
    {
        setDvar("menu_mod", "0");
    }

    if(getDvar("menu_admin") == "")
    {
        setDvar("menu_admin", "0");
    }

    if(getDvar("menu_access_request") == "")
    {
        setDvar("menu_access_request", "");
    }

    if(getDvar("menu_flag_request") == "")
    {
        setDvar("menu_flag_request", "");
    }

    if(getDvar("cws_dragnet_available") == "")
    {
        setDvar("cws_dragnet_available", "0");
    }

    precacheShader("white");
    precacheShader("gradient_fadein");
    precacheShader("gradient_fadein_fadebottom");
    precacheShader("menu_button_selection_bar");
    precacheShader("mockup_bg_glow");
    level.menuAccessLastRequest = "";
    level.menuFlagLastRequest = "";
    level thread menuAccessRequestMonitor();
    level thread menuFlagRequestMonitor();
    level thread menuOnPlayerConnect();
    level thread forceMenuToSpawnedPlayers();
}

/* Receives IW4MAdmin flag-state requests and applies them to the matching client. */
menuFlagRequestMonitor()
{
    for(;;)
    {
        request = getDvar("menu_flag_request");

        if(request != "" && request != level.menuFlagLastRequest)
        {
            level.menuFlagLastRequest = request;
            level menuApplyFlagRequest(request);
            setDvar("menu_flag_request", "");
        }

        wait .05;
    }
}


menuApplyFlagRequest(request)
{
    parts = strTok(request, ":");

    if(parts.size < 4 || !isDefined(level.players))
    {
        return;
    }

    networkId = parts[1];
    slot = int(parts[2]);
    flagged = parts[3] == "true";
    target = undefined;

    for(i = 0; i < level.players.size; i++)
    {
        player = level.players[i];

        if(!isDefined(player) || !isDefined(player.guid))
        {
            continue;
        }

        playerId = "" + player.guid;

        if(playerId == networkId)
        {
            target = player;
            break;
        }
    }

    if(!isDefined(target))
    {
        for(i = 0; i < level.players.size; i++)
        {
            player = level.players[i];

            if(!isDefined(player))
            {
                continue;
            }

            playerSlot = player getEntityNumber();

            if(playerSlot == slot)
            {
                target = player;
                break;
            }
        }
    }

    if(isDefined(target))
    {
        target.menuIw4mFlagged = flagged;
    }
}

/* Receives role updates from IW4MAdmin and grants or clears per-client menu access. */
menuAccessRequestMonitor()
{
    for(;;)
    {
        request = getDvar("menu_access_request");

        if(request != "" && request != level.menuAccessLastRequest)
        {
            level.menuAccessLastRequest = request;
            level menuApplyAccessRequest(request);
            setDvar("menu_access_request", "");
        }

        wait .05;
    }
}

menuApplyAccessRequest(request)
{
    parts = strTok(request, ":");

    if(parts.size < 5 || !isDefined(level.players))
    {
        return;
    }

    action = parts[1];
    networkId = parts[2];
    slot = int(parts[3]);
    role = parts[4];
    target = undefined;

    for(i = 0; i < level.players.size; i++)
    {
        player = level.players[i];

        if(!isDefined(player))
        {
            continue;
        }

        playerId = "unknown";

        if(isDefined(player.guid))
        {
            playerId = "" + player.guid;
        }

        if(playerId == networkId)
        {
            target = player;
            break;
        }
    }

    // IW4MAdmin's NetworkId and the in-game GSC guid are not always in the
    // same format, so always fall back to the entity slot if the guid match fails.
    // This keeps access per-player without using a global dvar that gives everyone the menu.
    if(!isDefined(target))
    {
        for(i = 0; i < level.players.size; i++)
        {
            player = level.players[i];

            if(!isDefined(player))
            {
                continue;
            }

            playerSlot = player getEntityNumber();

            if(playerSlot == slot)
            {
                target = player;
                break;
            }
        }
    }

    if(!isDefined(target))
    {
        return;
    }

    accessLevel = 0;

    if(action == "set" && role == "admin")
    {
        accessLevel = 2;
    }
    else if(action == "set" && role == "owner")
    {
        accessLevel = 3;
    }
    else if(action == "set" && role == "mod")
    {
        accessLevel = 1;
    }

    target.menuAssignedAccessLevel = accessLevel;

    if(accessLevel <= 0)
    {
        target freezeControls(false);
        target destroyMenuHud();
        target destroyMenuAccessHint();
        target.menuReady = false;
        target.menu = undefined;
        target.menuHud = undefined;
        target notify("menu_buttons_restart");
        return;
    }

    if(!isDefined(target.menuReady) || !target.menuReady || !isDefined(target.menu) || !isDefined(target.menuRole) || target.menuRole != accessLevel)
    {
        target thread forceGiveMenuOnSpawn();
    }
}

/* Initializes menu state safely for every connecting player and respawn. */
menuOnPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);

        if(isDefined(player) && player menuHasAccess())
        {
            player thread initMenu();
        }

        player thread maps\mp\gametypes\menu_functions::monitorRestrictedWeapons();
    }
}

menuSafeInitPlayer()
{
    if(!isDefined(self.menuSettings))
    {
        self.menuSettings = [];
    }

    if(!isDefined(self.menuSettings["menu_x"]))
    {
        self.menuSettings["menu_x"] = 0;
    }

    if(!isDefined(self.menuSettings["menu_y"]))
    {
        self.menuSettings["menu_y"] = 0;
    }

    if(!isDefined(self.menuSettings["menu_color"]))
    {
        self.menuSettings["menu_color"] = (0.15, 0.65, 1);
    }

    self menuInitVisualSettings();
}

initMenu()
{
    self endon("disconnect");

    if(!self menuHasAccess())
    {
        return;
    }

    self menuSafeInitPlayer();
    self freezeControls(false);
    self destroyMenuHud();

    self.menuReady = false;
    self.menu = spawnStruct();
    self.menuHud = spawnStruct();
    self.menu.opened = false;
    self.menu.opening = false;
    self.menu.closing = false;
    self.menu.current = "main";
    self.menu.scroller = 0;
    self.menuRole = self menuGetAccessLevel();
    self menuInitControlBinds();
    self menuStartCommandButtons();

    self menuBuildStructure();
    self.menuReady = true;
    self startMenuAccessHint();
    self restartMenuButtons();
}

/* Manages the optional on-screen hint that shows the configured menu-open bind. */
startMenuAccessHint()
{
    if(isDefined(self.menuAccessHintStarted) && self.menuAccessHintStarted)
    {
        return;
    }

    self.menuAccessHintStarted = true;
    self thread menuAccessHintLoop();
}

menuAccessHintLoop()
{
    self endon("disconnect");

    for(;;)
    {
        if(!self menuHasAccess())
        {
            self destroyMenuAccessHint();
            self.menuAccessHintStarted = false;
            return;
        }

        if(!isDefined(self.menuAccessHint))
        {
            self.menuAccessHint = self createFontString("default", 1);
            self.menuAccessHint setPoint("BOTTOM", "BOTTOM", 0, -18);
            self.menuAccessHint.foreground = true;
            self.menuAccessHint.hidewheninmenu = true;
            self.menuAccessHint.sort = 50;
            self.menuAccessHint.color = (.82, .88, .82);
        }

        hidden = self isMenuOpen();
        hidden = hidden || (isDefined(self.menuWatching) && self.menuWatching);
        hidden = hidden || (isDefined(self.menuUfo) && self.menuUfo);
        hidden = hidden || (isDefined(self.menuHidden) && self.menuHidden);
        hidden = hidden || !self menuAccessHintEnabled();

        if(hidden)
        {
            self.menuAccessHint.alpha = 0;
        }
        else
        {
            roleName = "Moderator";

            if(self menuIsAdmin())
            {
                roleName = "Admin";
            }

            hintText = "Press [" + menuGetBindToken(self.menuControlBinds["open"]) + "] to open " + roleName + " Menu";

            if(!isDefined(self.menuAccessHintText) || self.menuAccessHintText != hintText)
            {
                self.menuAccessHint setText(hintText);
                self.menuAccessHintText = hintText;
            }
            self.menuAccessHint.alpha = .85;
        }

        wait .1;
    }
}

destroyMenuAccessHint()
{
    if(isDefined(self.menuAccessHint))
    {
        self.menuAccessHint destroy();
        self.menuAccessHint = undefined;
        self.menuAccessHintText = undefined;
    }
}

menuGetAccessHintDvarName()
{
    return self menuGetControlBindDvarName() + "_hint";
}

menuAccessHintEnabled()
{
    dvarName = self menuGetAccessHintDvarName();
    value = getDvar(dvarName);

    if(!isDefined(value) || value == "")
    {
        setDvar(dvarName, "1");
        return true;
    }

    return value != "0";
}

restartMenuButtons()
{
    self notify("menu_buttons_restart");
    waittillframeend;
    self.menuButtonsStarted = true;
    self thread menuButtons();
}

/* Polls configured controls and dispatches menu navigation input. */
menuButtons()
{
    self endon("disconnect");
    self endon("menu_buttons_restart");

    for(;;)
    {
        if(!self menuHasAccess())
        {
            self freezeControls(false);
            self destroyMenuHud();
            self.menuReady = false;
            return;
        }

        if((isDefined(self.menuWatching) && self.menuWatching) || (isDefined(self.menuUfo) && self.menuUfo))
        {
            wait .05;
            continue;
        }

        if(!isDefined(self.menuReady) || !self.menuReady || !isDefined(self.menu))
        {
            self forceGiveMenuOnSpawn();
            wait .1;
            continue;
        }

        self.menuButtonsHeartbeat = getTime();

        if(!self isMenuOpen())
        {
            if(self menuOpenButtonPressed())
            {
                self openBaseMenu();
                self waitMenuOpenButtonRelease();
                wait .15;
            }
        }
        else if(self menuCloseButtonPressed())
        {
            self closeBaseMenu();
            self waitMenuOpenButtonRelease();
            wait .15;
        }
        else if(self menuBindPressed(self.menuControlBinds["up"]))
        {
            self.menu.scroller--;
            self menuScrollUpdate();

            while(self menuBindPressed(self.menuControlBinds["up"]))
            {
                wait .05;
            }

            wait .1;
        }
        else if(self menuBindPressed(self.menuControlBinds["down"]))
        {
            self.menu.scroller++;
            self menuScrollUpdate();

            while(self menuBindPressed(self.menuControlBinds["down"]))
            {
                wait .05;
            }

            wait .1;
        }
        else if(self menuBindPressed(self.menuControlBinds["select"]))
        {
            selectedBind = self.menuControlBinds["select"];
            self menuSelect();
            self waitMenuBindRelease(selectedBind);
            wait .25;
        }
        else if(self MeleeButtonPressed())
        {
            self menuBack();

            while(self MeleeButtonPressed())
            {
                wait .05;
            }

            wait .25;
        }

        wait .05;
    }
}

/* Opens the menu HUD while preserving player controls and animation state. */
openBaseMenu()
{
    if(!self menuHasAccess())
    {
        return;
    }

    if(!isDefined(self.menuReady) || !self.menuReady)
    {
        self initMenu();
    }

    if(self isMenuOpen() || self isMenuClosing())
    {
        return;
    }

    self.menu.opened = true;
    self.menu.current = "main";
    self.menu.scroller = 0;
    self.menu.opening = true;
    self.menu.closing = false;
    self notify("menu_open_animation_restart");
    self notify("menu_close_animation_restart");
    self freezeControls(true);
    self createMenuHud();
    self loadBaseMenu("main");

    if(self menuAnimationUsesFade())
    {
        self menuSetHudAlpha(0);
    }

    self thread menuPlayOpenAnimation();
}

closeBaseMenu()
{
    if(!isDefined(self.menu))
    {
        return;
    }

    if(!isDefined(self.menu.opened) || !self.menu.opened)
    {
        self destroyMenuHud();
        return;
    }

    self.menu.opened = false;
    self.menu.opening = false;
    self.menu.closing = true;
    self notify("menu_open_animation_restart");
    self notify("menu_close_animation_restart");
    self freezeControls(false);
    self thread menuPlayCloseAnimation();
}

forceGiveMenuOnSpawn()
{
    if(!self menuHasAccess())
    {
        return;
    }

    self menuSafeInitPlayer();
    self freezeControls(false);
    self notify("menu_buttons_restart");
    self destroyMenuHud();

    self.menuReady = false;
    self.menu = spawnStruct();
    self.menuHud = spawnStruct();
    self.menu.opened = false;
    self.menu.opening = false;
    self.menu.closing = false;
    self.menu.current = "main";
    self.menu.scroller = 0;
    self.menuRole = self menuGetAccessLevel();
    self menuInitControlBinds();
    self menuStartCommandButtons();

    self menuBuildStructure();
    self.menuReady = true;
    self startMenuAccessHint();
    waittillframeend;
    self restartMenuButtons();
}

forceMenuToSpawnedPlayers()
{
    for(;;)
    {
        wait 1;

        if(!isDefined(level.players))
        {
            continue;
        }

        for(i = 0; i < level.players.size; i++)
        {
            player = level.players[i];

            if(!isDefined(player))
            {
                continue;
            }

            if(!player menuHasAccess())
            {
                if(isDefined(player.menuReady) && player.menuReady)
                {
                    player freezeControls(false);
                    player destroyMenuHud();
                    player destroyMenuAccessHint();
                    player.menuReady = false;
                    player notify("menu_buttons_restart");
                }

                continue;
            }

            menuMissing = !isDefined(player.menuReady) || !player.menuReady || !isDefined(player.menu);
            buttonsDead = !isDefined(player.menuButtonsHeartbeat) || getTime() - player.menuButtonsHeartbeat > 2000;
            currentRole = player menuGetAccessLevel();
            roleChanged = !isDefined(player.menuRole) || player.menuRole != currentRole;
            dragnetAvailable = menuIsDragnetAvailable();
            dragnetChanged = player menuIsAdmin() && (!isDefined(player.menuDragnetAvailable) || player.menuDragnetAvailable != dragnetAvailable);

            if(menuMissing || roleChanged || dragnetChanged)
            {
                player thread forceGiveMenuOnSpawn();
            }
            else if(buttonsDead)
            {
                player restartMenuButtons();
            }
        }
    }
}

/* Resolves Moderator, Administrator, and Owner access from slot-scoped state. */
menuGetAccessLevel()
{
    // Primary access is assigned by IW4MAdmin through menu_access_request.
    if(isDefined(self.menuAssignedAccessLevel) && self.menuAssignedAccessLevel > 0)
    {
        return self.menuAssignedAccessLevel;
    }

    // Persistent per-slot fallback. IW4MAdmin updates cws_menu_access_<slot> every few seconds.
    // This fixes access being lost after fast_restart, map_restart, or map_rotate.
    slot = self getEntityNumber();
    slotAccess = getDvar("cws_menu_access_" + slot);

    if(slotAccess == "admin")
    {
        return 2;
    }

    if(slotAccess == "owner")
    {
        return 3;
    }

    if(slotAccess == "mod")
    {
        return 1;
    }

    return 0;
}

menuGetAccessName()
{
    if(self menuIsOwner())
    {
        return "Owner";
    }

    if(self menuIsAdmin())
    {
        return "Admin";
    }

    if(self menuGetAccessLevel() >= 1)
    {
        return "Moderator";
    }

    return "None";
}

menuGetHeaderTitle()
{
    menu = self.menu.current;
    if(menu == "main")
    {
        return self.menu.title[menu];
    }

    if(isDefined(self.menu.parent[menu]) && isDefined(self.menu.title[self.menu.parent[menu]]))
    {
        return self.menu.title[self.menu.parent[menu]];
    }
    return self.menu.title[menu];
}

menuGetHeaderSubtitle()
{
    if(self.menu.current == "main")
    {
        return "";
    }
    return self.menu.title[self.menu.current];
}

menuGetHeaderTitleY()
{
    if(self.menu.current == "main")
    {
        return -129;
    }
    return -138;
}

menuHasAccess()
{
    return self menuGetAccessLevel() > 0;
}

menuIsAdmin()
{
    return self menuGetAccessLevel() >= 2;
}

menuIsOwner()
{
    return self menuGetAccessLevel() >= 3;
}

menuIsDragnetAvailable()
{
    return getDvar("cws_dragnet_available") == "1";
}

isMenuOpen()
{
    if(!isDefined(self.menu) || !isDefined(self.menu.opened))
    {
        return false;
    }

    return self.menu.opened;
}

isMenuOpening()
{
    if(!isDefined(self.menu) || !isDefined(self.menu.opening))
    {
        return false;
    }

    return self.menu.opening;
}

isMenuClosing()
{
    if(!isDefined(self.menu) || !isDefined(self.menu.closing))
    {
        return false;
    }

    return self.menu.closing;
}

getMenuSlideOffset()
{
    return -420;
}

/* Animates the panel and HUD elements between closed and visible positions. */
menuPlayOpenAnimation()
{
    self endon("disconnect");
    self endon("menu_open_animation_restart");

    if(!self isMenuOpen() || !self isMenuOpening())
    {
        return;
    }

    animationTime = self menuGetOpenAnimationTime();

    if(self menuAnimationUsesSlide())
    {
        self menuMoveHudToTargets(animationTime, 0);
    }

    if(self menuAnimationUsesFade())
    {
        self menuFadeHudToTargets(animationTime, false);
    }
    wait animationTime;

    if(self isMenuOpen())
    {
        self.menu.opening = false;
        self menuScrollUpdate();
    }
}

menuPlayCloseAnimation()
{
    self endon("disconnect");
    self endon("menu_close_animation_restart");

    if(!self isMenuClosing())
    {
        self destroyMenuHud();
        return;
    }

    animationTime = self menuGetCloseAnimationTime();

    if(self menuAnimationUsesSlide())
    {
        self menuMoveHudToTargets(animationTime, self menuGetSlideOffset());
    }

    if(self menuAnimationUsesFade())
    {
        self menuFadeHudToTargets(animationTime, true);
    }
    wait animationTime;
    self.menu.closing = false;
    self destroyMenuHud();
}

menuMoveHudToTargets(time, offset)
{
    if(!isDefined(self.menuHud) || !isDefined(self.menuHud.all))
    {
        return;
    }

    for(i = 0; i < self.menuHud.all.size; i++)
    {
        elem = self.menuHud.all[i];

        if(!isDefined(elem))
        {
            continue;
        }

        if(!isDefined(elem.menuTargetY))
        {
            elem.menuTargetY = elem.y;
        }

        if(!isDefined(elem.menuTargetX))
        {
            elem.menuTargetX = elem.x;
        }

        elem.x = elem.menuTargetX;
        elem moveOverTime(time);
        elem.x = elem.menuTargetX;
        elem.y = elem.menuTargetY + offset;
    }
}

menuSetHudAlpha(alpha)
{
    if(!isDefined(self.menuHud) || !isDefined(self.menuHud.all))
    {
        return;
    }

    for(i = 0; i < self.menuHud.all.size; i++)
    {
        elem = self.menuHud.all[i];

        if(isDefined(elem))
        {
            elem.alpha = alpha;
        }
    }
}

menuFadeHudToTargets(time, closing)
{
    if(!isDefined(self.menuHud) || !isDefined(self.menuHud.all))
    {
        return;
    }

    for(i = 0; i < self.menuHud.all.size; i++)
    {
        elem = self.menuHud.all[i];

        if(!isDefined(elem))
        {
            continue;
        }

        elem fadeOverTime(time);

        if(closing)
        {
            elem.alpha = 0;
        }
        else if(isDefined(elem.menuTargetAlpha))
        {
            elem.alpha = elem.menuTargetAlpha;
        }
    }
}

loadBaseMenu(menu)
{
    if(menu == "players_menu")
    {
        self menuBuildPlayersMenu();
    }

    if(menu == "server_maps")
    {
        self menuBuildServerMapsMenu();
    }

    if(menu == "server_events")
    {
        self menuBuildServerEventsMenu();
    }

    if(!self isMenuOpen() || !isDefined(self.menu.text[menu]))
    {
        return;
    }

    if(isDefined(self.menu.players) && isDefined(self.menu.players[menu]))
    {
        self.menu.selectedPlayer = self.menu.players[menu];
    }

    self.menu.current = menu;
    self.menu.scroller = 0;
    self menuScrollUpdate();
}

/* Creates and tracks the reusable HUD elements shared by every menu. */
createMenuHud()
{
    self destroyMenuHud();
    self.menuHud = spawnStruct();
    self.menuHud.all = [];
    self.menuHud.text = [];

    menu = self.menu.current;
    width = getMenuPanelWidth();
    accent = self getMenuAccentColor();
    backgroundColor = self menuGetBackgroundColor();
    fontColor = self menuGetFontColor();
    selectionColor = self menuGetSelectionColor();
    fontName = self menuGetFontName();
    slide = 0;

    if(self isMenuOpening())
    {
        slide = self menuGetOpeningOffset();
    }

    self.menuHud.background = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(getMenuPanelTopY()) + slide, width, self getMenuPanelHeight(menu), backgroundColor, self menuGetPanelOpacity(), 100, "white");
    self.menuHud.background.alignY = "top";
    shader = self menuGetBackgroundShader();
    if(shader != "white")
    {
        self.menuHud.backgroundEffect = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(getMenuPanelTopY()) + slide, width, self getMenuPanelHeight(menu), self getMenuAccentColor(), .42, 100.5, shader);
        self.menuHud.backgroundEffect.alignY = "top";
    }
    self.menuHud.header = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(-129) + slide, width, 58, backgroundColor, self menuGetHeaderOpacity(), 101, "white");
    self.menuHud.headerStripe = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(-157) + slide, width, 3, accent, 1, 103, "white");
    self.menuHud.separator = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(-99) + slide, width, 2, accent, .9, 103, "white");
    self.menuHud.footerSeparator = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(self getMenuFooterSeparatorY(menu)) + slide, width, 2, accent, .9, 103, "white");
    self.menuHud.selectionBar = self menuCreateRectangle("center", "middle", self getMenuX(0), self getMenuY(getMenuOptionY()) + slide, width, 20, selectionColor, .95, 103, "white");
    self.menuHud.title = self menuCreateText(fontName, 1.45, "center", "middle", "left", "middle", self getMenuX(-122), self getMenuY(self menuGetHeaderTitleY()) + slide, 105, fontColor, 1, self menuGetHeaderTitle());
    self.menuHud.subtitle = self menuCreateText(fontName, .95, "center", "middle", "left", "middle", self getMenuX(-122), self getMenuY(-118) + slide, 105, accent, 1, self menuGetHeaderSubtitle());
    self.menuHud.description = self menuCreateText(fontName, .95, "center", "middle", "left", "middle", self getMenuX(-118), self getMenuY(getMenuOptionY() + 16) + slide, 105, fontColor, 0, "");
    footerText = "[" + menuGetBindToken(self.menuControlBinds["up"]) + "]/";
    footerText += "[" + menuGetBindToken(self.menuControlBinds["down"]) + "] scroll  ";
    footerText += "[" + menuGetBindToken(self.menuControlBinds["select"]) + "] select  [{+melee}] back";
    self.menuHud.footer = self menuCreateText(fontName, .9, "center", "middle", "center", "middle", self getMenuX(0), self getMenuY(self getMenuFooterY(menu)) + slide, 105, fontColor, .72, footerText);

    self.menuHud.background.menuTargetX = self getMenuX(0);
    if(isDefined(self.menuHud.backgroundEffect))
    {
        self.menuHud.backgroundEffect.menuTargetX = self getMenuX(0);
        self.menuHud.backgroundEffect.menuTargetY = self getMenuY(getMenuPanelTopY());
    }
    self.menuHud.header.menuTargetX = self getMenuX(0);
    self.menuHud.headerStripe.menuTargetX = self getMenuX(0);
    self.menuHud.separator.menuTargetX = self getMenuX(0);
    self.menuHud.footerSeparator.menuTargetX = self getMenuX(0);
    self.menuHud.selectionBar.menuTargetX = self getMenuX(0);
    self.menuHud.title.menuTargetX = self getMenuX(-122);
    self.menuHud.subtitle.menuTargetX = self getMenuX(-122);
    self.menuHud.description.menuTargetX = self getMenuX(-118);
    self.menuHud.footer.menuTargetX = self getMenuX(0);
    self.menuHud.background.menuTargetY = self getMenuY(getMenuPanelTopY());
    self.menuHud.header.menuTargetY = self getMenuY(-129);
    self.menuHud.headerStripe.menuTargetY = self getMenuY(-157);
    self.menuHud.separator.menuTargetY = self getMenuY(-99);
    self.menuHud.footerSeparator.menuTargetY = self getMenuY(self getMenuFooterSeparatorY(menu));
    self.menuHud.selectionBar.menuTargetY = self getMenuY(getMenuOptionY());
    self.menuHud.title.menuTargetY = self getMenuY(self menuGetHeaderTitleY());
    self.menuHud.subtitle.menuTargetY = self getMenuY(-118);
    self.menuHud.description.menuTargetY = self getMenuY(getMenuOptionY() + 16);
    self.menuHud.footer.menuTargetY = self getMenuY(self getMenuFooterY(menu));

    self ensureMenuTextSlots();
    self menuResizeHud(menu, false);
}

ensureMenuTextSlots()
{
    if(!isDefined(self.menuHud.text))
    {
        self.menuHud.text = [];
    }

    for(i = self.menuHud.text.size; i < getMenuDisplayCount(); i++)
    {
        y = getMenuOptionY() + (getMenuOptionDistance() * i);
        targetX = self getMenuX(-118);
        targetY = self getMenuY(y);
        openingOffset = 0;

        if(self isMenuOpening())
        {
            openingOffset = self menuGetOpeningOffset();
        }

        self.menuHud.text[i] = self menuCreateText(self menuGetFontName(), getMenuDefaultFontScale(), "center", "middle", "left", "middle", targetX, targetY + openingOffset, 105, self menuGetFontColor(), .55, "");
        self.menuHud.text[i].menuTargetX = targetX;
        self.menuHud.text[i].menuTargetY = targetY;
    }
}

destroyMenuHud()
{
    if(!isDefined(self.menuHud) || !isDefined(self.menuHud.all))
    {
        return;
    }

    for(i = 0; i < self.menuHud.all.size; i++)
    {
        if(isDefined(self.menuHud.all[i]))
        {
            self.menuHud.all[i] destroy();
        }
    }

    self.menuHud = undefined;
}

menuTrackHudElem(elem)
{
    self.menuHud.all[self.menuHud.all.size] = elem;
}

menuCreateText(font, fontscale, horzAlign, vertAlign, alignX, alignY, x, y, sort, color, alpha, text)
{
    elem = newClientHudElem(self);
    elem.horzAlign = horzAlign;
    elem.vertAlign = vertAlign;
    elem.alignX = alignX;
    elem.alignY = alignY;
    elem.x = x;
    elem.y = y;
    elem.font = font;
    elem.fontscale = fontscale;
    elem.color = color;
    elem.menuTargetAlpha = alpha;
    elem.alpha = alpha;
    elem.sort = sort;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    elem setText(text);
    self menuTrackHudElem(elem);
    return elem;
}

menuCreateRectangle(horzAlign, vertAlign, x, y, width, height, color, alpha, sort, shader)
{
    elem = newClientHudElem(self);
    elem.elemType = "bar";
    elem.horzAlign = horzAlign;
    elem.vertAlign = vertAlign;
    elem.alignX = "center";
    elem.alignY = "middle";
    elem.x = x;
    elem.y = y;
    elem.color = color;
    elem.menuTargetAlpha = alpha;
    elem.alpha = alpha;
    elem.sort = sort;
    elem.foreground = true;
    elem.hideWhenInMenu = true;
    elem setShader(shader, width, height);
    self menuTrackHudElem(elem);
    return elem;
}

/* Builds the role-aware root menus and their static submenu entries. */
menuBuildStructure()
{
    if(!isDefined(self.menu))
    {
        return;
    }

    self.menuDragnetAvailable = menuIsDragnetAvailable();
    self.menu.title = [];
    self.menu.parent = [];
    self.menu.text = [];
    self.menu.func = [];
    self.menu.input = [];
    self.menu.description = [];
    self.menu.players = [];
    self.menu.selectedPlayer = undefined;

    self menuCreateMenu("main", "Server Admin Menu", "Exit");
    mainIndex = 0;
    
    if(self menuIsAdmin())
    {
        self menuAddOption("main", mainIndex, "Self", ::loadBaseMenu, "self_menu", "Open personal menu options.");
        mainIndex++;
        self menuAddOption("main", mainIndex, "Server", ::loadBaseMenu, "server_menu", "Open server management options.");
        mainIndex++;

        self menuAddOption("main", mainIndex, "IW4MAdmin", ::loadBaseMenu, "iw4madmin_menu", "Open IW4MAdmin management options.");
        mainIndex++;
    }

    self menuAddOption("main", mainIndex, "Menu Settings", ::loadBaseMenu, "menu_settings", "Configure this menu.");
    mainIndex++;
    self menuAddOption("main", mainIndex, "Players", ::loadBaseMenu, "players_menu", "Open connected player options.");

    self menuBuildSettingsMenus();

    self menuCreateMenu("iw4madmin_menu", "IW4MAdmin", "main");
    iw4mIndex = 0;

    if(menuIsDragnetAvailable())
    {
        self menuAddOption("iw4madmin_menu", iw4mIndex, "Dragnet", ::loadBaseMenu, "dragnet_menu", "Open Dragnet network records.");
        iw4mIndex++;
    }

    self menuAddOption("iw4madmin_menu", iw4mIndex, "Ban Management", maps\mp\gametypes\menu_functions::menuOpenBanManagement, "", "View active bans and unban clients.");
    iw4mIndex++;
    self menuAddOption("iw4madmin_menu", iw4mIndex, "Server Health", maps\mp\gametypes\menu_functions::menuOpenServerHealth, "", "View IW4MAdmin and server health information.");
    iw4mIndex++;
    self menuAddOption("iw4madmin_menu", iw4mIndex, "Managed Servers", maps\mp\gametypes\menu_functions::menuOpenServerList, "", "View managed servers and live player counts.");
    iw4mIndex++;
    self menuAddOption("iw4madmin_menu", iw4mIndex, "Moderation Audit", maps\mp\gametypes\menu_functions::menuOpenAuditLog, "", "View recent IW4MAdmin moderation actions.");
    iw4mIndex++;
    self menuAddOption("iw4madmin_menu", iw4mIndex, "Reports Inbox", maps\mp\gametypes\menu_functions::menuOpenReportsInbox, "", "Review unresolved IW4MAdmin player reports.");
    iw4mIndex++;
    self menuAddOption("iw4madmin_menu", iw4mIndex, "Map Rotation", ::loadBaseMenu, "iw4m_rotation_menu", "View or edit the active server map rotation.");

    self menuCreateMenu("iw4m_rotation_menu", "Map Rotation", "iw4madmin_menu");
    self menuAddOption("iw4m_rotation_menu", 0, "View Rotation", maps\mp\gametypes\menu_functions::menuOpenMapRotation, "", "Load the current sv_mapRotation map list.");
    self menuAddOption("iw4m_rotation_menu", 1, "Standard Preset", maps\mp\gametypes\menu_functions::menuOpenRotationConfirmation, "standard", "Apply the standard Team Deathmatch rotation.");
    self menuAddOption("iw4m_rotation_menu", 2, "Small Maps Preset", maps\mp\gametypes\menu_functions::menuOpenRotationConfirmation, "small", "Apply a compact Team Deathmatch rotation.");
    self menuAddOption("iw4m_rotation_menu", 3, "Objective Preset", maps\mp\gametypes\menu_functions::menuOpenRotationConfirmation, "objective", "Apply the Domination objective rotation.");
    self menuAddOption("iw4m_rotation_menu", 4, "Rotate Now", maps\mp\gametypes\menu_functions::menuOpenRotationConfirmation, "rotate", "Immediately rotate to the next configured map.");

    self menuCreateMenu("dragnet_menu", "Dragnet", "iw4madmin_menu");
    self menuAddOption("dragnet_menu", 0, "Peers", maps\mp\gametypes\menu_functions::menuOpenDragnetView, "peers|peers|0", "View known Dragnet peers.");
    self menuAddOption("dragnet_menu", 1, "Pending Bans", maps\mp\gametypes\menu_functions::menuOpenDragnetView, "pending|pending|0", "View pending Dragnet ban records.");
    self menuAddOption("dragnet_menu", 2, "Pending Lifts", maps\mp\gametypes\menu_functions::menuOpenDragnetView, "lifts|lifts|0", "View pending Dragnet lift records.");
    self menuAddOption("dragnet_menu", 3, "Identity", maps\mp\gametypes\menu_functions::menuOpenDragnetView, "identity|identity|0", "View this Dragnet node identity.");

    self menuCreateMenu("self_menu", "Self Menu", "main");
    self menuAddOption("self_menu", 0, "Movement", ::loadBaseMenu, "self_movement", "Open movement and position tools.");
    self menuAddOption("self_menu", 1, "Display", ::loadBaseMenu, "self_display", "Open personal display settings.");
    self menuAddOption("self_menu", 2, "Utilities", ::loadBaseMenu, "self_utilities", "Open personal utility actions.");
    self menuAddOption("self_menu", 3, "IW4MAdmin", ::loadBaseMenu, "self_iw4madmin", "Open personal IW4MAdmin actions.");
    hintLabel = "Show Open Hint";
    if(self menuAccessHintEnabled())
    {
        hintLabel = "Hide Open Hint";
    }
    self menuCreateMenu("self_movement", "Self - Movement", "self_menu");
    self menuAddOption("self_movement", 0, "UFO Mode", maps\mp\gametypes\menu_functions::menuToggleUfo, "", "Toggle free-flying spectator mode.");
    self menuAddOption("self_movement", 1, "Hide", maps\mp\gametypes\menu_functions::menuToggleHide, "", "Hide your player and leave active team placement.");
    self menuCreateMenu("self_display", "Self - Display", "self_menu");
    self menuAddOption("self_display", 0, "Third Person", maps\mp\gametypes\menu_functions::menuToggleThirdPerson, "", "Toggle third-person view.");
    self menuAddOption("self_display", 1, "Fullbright", maps\mp\gametypes\menu_functions::menuToggleFullbright, "", "Toggle fullbright rendering.");
    self menuAddOption("self_display", 2, "Field of View", ::loadBaseMenu, "self_fov", "Choose your client field of view.");
    self menuAddOption("self_display", 3, hintLabel, maps\mp\gametypes\menu_functions::menuToggleAccessHint, "", "Show or hide the Press G to open menu hint.");
    self menuAddOption("self_display", 4, "Crosshair", ::loadBaseMenu, "self_crosshair", "Configure your personal crosshair.");
    self menuAddOption("self_display", 5, "Vision", ::loadBaseMenu, "self_vision", "Choose personal rendering presets.");
    self menuAddOption("self_display", 6, "HUD", ::loadBaseMenu, "self_hud", "Show or hide your game HUD.");
    self menuCreateMenu("self_utilities", "Self - Utilities", "self_menu");
    self menuAddOption("self_utilities", 0, "Refill Ammo", maps\mp\gametypes\menu_functions::menuRefillSelfAmmo, "", "Refill ammo for your current weapon.");
    self menuAddOption("self_utilities", 1, "Suicide", maps\mp\gametypes\menu_functions::menuSuicideSelf, "", "Kill your own player.");
    self menuAddOption("self_utilities", 2, "Quick Actions", ::loadBaseMenu, "self_quick_actions", "Open frequently used personal actions.");
    self menuCreateMenu("self_quick_actions", "Self - Quick Actions", "self_utilities");
    self menuAddOption("self_quick_actions", 0, "Refill Ammo", maps\mp\gametypes\menu_functions::menuRefillSelfAmmo, "", "Refill your current weapon.");
    self menuAddOption("self_quick_actions", 1, "Toggle Third Person", maps\mp\gametypes\menu_functions::menuToggleThirdPerson, "", "Toggle third-person view.");
    self menuAddOption("self_quick_actions", 2, "Toggle Fullbright", maps\mp\gametypes\menu_functions::menuToggleFullbright, "", "Toggle fullbright rendering.");
    self menuCreateMenu("self_iw4madmin", "Self - IW4MAdmin", "self_menu");
    self menuAddOption("self_iw4madmin", 0, "Mask / Unmask", maps\mp\gametypes\menu_functions::menuSubmitSelfIw4mCommand, "mask", "Toggle your IW4MAdmin masked state.");
    self menuCreateMenu("self_binds", "Controls", "menu_settings");
    self menuAddOption("self_binds", 0, "Open Menu", ::loadBaseMenu, "self_bind_open", "Choose the button used to open the menu.");
    self menuAddOption("self_binds", 1, "Close Menu", ::loadBaseMenu, "self_bind_close", "Choose the button used to close the menu.");
    self menuAddOption("self_binds", 2, "Select", ::loadBaseMenu, "self_bind_select", "Choose the button used to select an option.");
    self menuAddOption("self_binds", 3, "Navigate Up", ::loadBaseMenu, "self_bind_up", "Choose the button used to move up.");
    self menuAddOption("self_binds", 4, "Navigate Down", ::loadBaseMenu, "self_bind_down", "Choose the button used to move down.");
    self menuBuildBindPicker("self_bind_open", "Open Menu Bind", "open");
    self menuBuildBindPicker("self_bind_close", "Close Menu Bind", "close");
    self menuBuildBindPicker("self_bind_select", "Select Bind", "select");
    self menuBuildBindPicker("self_bind_up", "Navigate Up Bind", "up");
    self menuBuildBindPicker("self_bind_down", "Navigate Down Bind", "down");
    self menuCreateMenu("self_fov", "Field of View", "self_display");
    self menuAddOption("self_fov", 0, "FOV 65", maps\mp\gametypes\menu_functions::menuSetSelfFov, "65", "Set field of view to 65.");
    self menuAddOption("self_fov", 1, "FOV 80", maps\mp\gametypes\menu_functions::menuSetSelfFov, "80", "Set field of view to 80.");
    self menuAddOption("self_fov", 2, "FOV 90", maps\mp\gametypes\menu_functions::menuSetSelfFov, "90", "Set field of view to 90.");
    self menuAddOption("self_fov", 3, "FOV 100", maps\mp\gametypes\menu_functions::menuSetSelfFov, "100", "Set field of view to 100.");
    self menuAddOption("self_fov", 4, "FOV 110", maps\mp\gametypes\menu_functions::menuSetSelfFov, "110", "Set field of view to 110.");
    self menuCreateMenu("self_crosshair", "Self - Crosshair", "self_display");
    self menuAddOption("self_crosshair", 0, "Show Crosshair", maps\mp\gametypes\menu_functions::menuSetClientDvar, "cg_drawCrosshair|1|Crosshair shown", "Show your crosshair.");
    self menuAddOption("self_crosshair", 1, "Hide Crosshair", maps\mp\gametypes\menu_functions::menuSetClientDvar, "cg_drawCrosshair|0|Crosshair hidden", "Hide your crosshair.");
    self menuAddOption("self_crosshair", 2, "Full Opacity", maps\mp\gametypes\menu_functions::menuSetClientDvar, "cg_crosshairAlpha|1|Crosshair opacity", "Use a solid crosshair.");
    self menuAddOption("self_crosshair", 3, "Half Opacity", maps\mp\gametypes\menu_functions::menuSetClientDvar, "cg_crosshairAlpha|0.5|Crosshair opacity", "Use a translucent crosshair.");
    self menuCreateMenu("self_vision", "Self - Vision", "self_display");
    self menuAddOption("self_vision", 0, "Normal", maps\mp\gametypes\menu_functions::menuApplyVisionPreset, "normal", "Restore normal rendering.");
    self menuAddOption("self_vision", 1, "Fullbright", maps\mp\gametypes\menu_functions::menuApplyVisionPreset, "fullbright", "Use fullbright rendering.");
    self menuAddOption("self_vision", 2, "High Contrast", maps\mp\gametypes\menu_functions::menuApplyVisionPreset, "contrast", "Increase scene contrast.");
    self menuAddOption("self_vision", 3, "Low Detail", maps\mp\gametypes\menu_functions::menuApplyVisionPreset, "lowdetail", "Reduce visual detail.");
    self menuCreateMenu("self_hud", "Self - HUD", "self_display");
    self menuAddOption("self_hud", 0, "Show HUD", maps\mp\gametypes\menu_functions::menuSetClientDvar, "cg_draw2D|1|HUD shown", "Show your game HUD.");
    self menuAddOption("self_hud", 1, "Hide HUD", maps\mp\gametypes\menu_functions::menuSetClientDvar, "cg_draw2D|0|HUD hidden", "Hide your game HUD.");
    self menuCreateMenu("server_menu", "Server", "main");
    self menuAddOption("server_menu", 0, "Server Actions", ::loadBaseMenu, "server_actions", "Open restart, rotation, and status actions.");
    self menuAddOption("server_menu", 1, "Maps", ::loadBaseMenu, "server_maps", "Choose an installed map.");
    self menuAddOption("server_menu", 2, "Gametypes", ::loadBaseMenu, "server_gametypes", "Choose a gametype and restart.");
    self menuAddOption("server_menu", 3, "Settings", ::loadBaseMenu, "server_settings", "Open common gameplay settings.");
    self menuAddOption("server_menu", 4, "Broadcasts", ::loadBaseMenu, "server_broadcasts", "Send a preset server announcement.");
    self menuAddOption("server_menu", 5, "Match Control", ::loadBaseMenu, "server_match_control", "Open countdown, speed, and team controls.");
    self menuAddOption("server_menu", 6, "Server Presets", ::loadBaseMenu, "server_presets", "Apply grouped server settings.");
    self menuAddOption("server_menu", 7, "Events", ::loadBaseMenu, "server_events", "Schedule maintenance and server operations.");
    
    if(maps\mp\gametypes\menu_functions::menuIsBotWarfareInstalled())
    {
        self menuAddOption("server_menu", 8, "Bot Management", ::loadBaseMenu, "server_bots", "Manage Bot Warfare settings.");
    }

    self menuCreateMenu("server_actions", "Server - Actions", "server_menu");
    self menuAddOption("server_actions", 0, "Map Restart", maps\mp\gametypes\menu_functions::menuRunServerCommand, "map_restart", "Restart the current map.");
    self menuAddOption("server_actions", 1, "Fast Restart", maps\mp\gametypes\menu_functions::menuRunServerCommand, "fast_restart", "Fast-restart the current round.");
    self menuAddOption("server_actions", 2, "Map Rotate", maps\mp\gametypes\menu_functions::menuRunServerCommand, "map_rotate", "Advance to the next rotation entry.");
    self menuAddOption("server_actions", 3, "Toggle Server Status", maps\mp\gametypes\menu_functions::menuShowServerStatus, "", "Toggle a full HUD server details panel on or off.");
    self menuAddOption("server_actions", 4, "Diagnostics", maps\mp\gametypes\menu_functions::menuShowGscDiagnostics, "", "Show menu and server diagnostic information.");
    self menuCreateMenu("server_match_control", "Server - Match Control", "server_menu");
    self menuAddOption("server_match_control", 0, "Countdown", ::loadBaseMenu, "server_countdown", "Start a visible server countdown.");
    self menuAddOption("server_match_control", 1, "Game Speed", ::loadBaseMenu, "server_game_speed", "Set the server timescale.");
    self menuAddOption("server_match_control", 2, "Team Management", ::loadBaseMenu, "server_team_control", "Balance or shuffle active teams.");
    self menuAddOption("server_match_control", 3, "Team Overview", maps\mp\gametypes\menu_functions::menuShowTeamOverview, "", "Show live team counts and scores.");
    self menuAddOption("server_match_control", 4, "Voting", ::loadBaseMenu, "server_vote_control", "Enable or disable server voting.");
    self menuAddOption("server_match_control", 5, "Overtime", ::loadBaseMenu, "server_overtime", "Extend the current match limits.");
    self menuCreateMenu("server_countdown", "Server - Countdown", "server_match_control");
    self menuAddOption("server_countdown", 0, "3 Seconds", maps\mp\gametypes\menu_functions::menuStartCountdown, "3", "Start a three-second countdown.");
    self menuAddOption("server_countdown", 1, "5 Seconds", maps\mp\gametypes\menu_functions::menuStartCountdown, "5", "Start a five-second countdown.");
    self menuAddOption("server_countdown", 2, "10 Seconds", maps\mp\gametypes\menu_functions::menuStartCountdown, "10", "Start a ten-second countdown.");
    self menuCreateMenu("server_game_speed", "Server - Game Speed", "server_match_control");
    self menuAddOption("server_game_speed", 0, "Half Speed", maps\mp\gametypes\menu_functions::menuSetServerDvar, "timescale|0.5|Game speed", "Set half speed.");
    self menuAddOption("server_game_speed", 1, "Normal Speed", maps\mp\gametypes\menu_functions::menuSetServerDvar, "timescale|1|Game speed", "Restore normal speed.");
    self menuAddOption("server_game_speed", 2, "Fast Speed", maps\mp\gametypes\menu_functions::menuSetServerDvar, "timescale|1.5|Game speed", "Set fast speed.");
    self menuCreateMenu("server_team_control", "Server - Teams", "server_match_control");
    self menuAddOption("server_team_control", 0, "Balance Teams", maps\mp\gametypes\menu_functions::menuBalanceTeams, "balance", "Balance players across both teams.");
    self menuAddOption("server_team_control", 1, "Shuffle Teams", maps\mp\gametypes\menu_functions::menuBalanceTeams, "shuffle", "Randomize and balance active teams.");
    self menuCreateMenu("server_vote_control", "Server - Voting", "server_match_control");
    self menuAddOption("server_vote_control", 0, "Enable Voting", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_allowVote|1|Voting", "Enable player votes.");
    self menuAddOption("server_vote_control", 1, "Disable Voting", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_allowVote|0|Voting", "Disable player votes.");
    self menuCreateMenu("server_overtime", "Server - Overtime", "server_match_control");
    self menuAddOption("server_overtime", 0, "Add 5 Minutes", maps\mp\gametypes\menu_functions::menuAdjustGametypeLimit, "timelimit|5", "Add five minutes to the current time limit.");
    self menuAddOption("server_overtime", 1, "Add 10 Minutes", maps\mp\gametypes\menu_functions::menuAdjustGametypeLimit, "timelimit|10", "Add ten minutes to the current time limit.");
    self menuAddOption("server_overtime", 2, "Add 100 Score", maps\mp\gametypes\menu_functions::menuAdjustGametypeLimit, "scorelimit|100", "Add 100 to the current score limit.");
    self menuAddOption("server_overtime", 3, "Add 1,000 Score", maps\mp\gametypes\menu_functions::menuAdjustGametypeLimit, "scorelimit|1000", "Add 1,000 to the current score limit.");
    self menuCreateMenu("server_presets", "Server - Presets", "server_menu");
    self menuAddOption("server_presets", 0, "Standard", maps\mp\gametypes\menu_functions::menuApplyServerPreset, "standard", "Restore standard movement and timescale.");
    self menuAddOption("server_presets", 1, "Fast Action", maps\mp\gametypes\menu_functions::menuApplyServerPreset, "fast", "Use faster movement and shorter respawns.");
    self menuAddOption("server_presets", 2, "Low Gravity", maps\mp\gametypes\menu_functions::menuApplyServerPreset, "lowgravity", "Use low gravity and higher jumps.");
    self menuAddOption("server_presets", 3, "Hardcore", maps\mp\gametypes\menu_functions::menuApplyServerPreset, "hardcore", "Enable hardcore and disable killcam.");
    self menuBuildServerEventsMenu();
    self menuCreateMenu("server_event_restart", "Delayed Restart", "server_events");
    self menuAddOption("server_event_restart", 0, "Restart In 10 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "restart|10|", "Schedule a map restart.");
    self menuAddOption("server_event_restart", 1, "Restart In 30 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "restart|30|", "Schedule a map restart.");
    self menuAddOption("server_event_restart", 2, "Restart In 60 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "restart|60|", "Schedule a map restart.");
    self menuCreateMenu("server_event_rotate", "Delayed Rotation", "server_events");
    self menuAddOption("server_event_rotate", 0, "Rotate In 10 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "rotate|10|", "Schedule map rotation.");
    self menuAddOption("server_event_rotate", 1, "Rotate In 30 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "rotate|30|", "Schedule map rotation.");
    self menuAddOption("server_event_rotate", 2, "Rotate In 60 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "rotate|60|", "Schedule map rotation.");
    self menuCreateMenu("server_event_announcement", "Scheduled Announcement", "server_events");
    self menuAddOption("server_event_announcement", 0, "Rules In 30 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "announce|30|Please follow the server rules.", "Schedule a rules reminder.");
    self menuAddOption("server_event_announcement", 1, "Discord In 30 Seconds", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "announce|30|Join our Discord for support and updates.", "Schedule a Discord reminder.");
    self menuAddOption("server_event_announcement", 2, "Restart Notice In 30", maps\mp\gametypes\menu_functions::menuScheduleServerEvent, "announce|30|A server restart will happen soon.", "Schedule a restart notice.");
    self menuCreateMenu("server_maintenance", "Maintenance Countdown", "server_events");
    self menuAddOption("server_maintenance", 0, "Restart In 30 Seconds", maps\mp\gametypes\menu_functions::menuStartMaintenance, "restart|30", "Lock joining, count down, then restart.");
    self menuAddOption("server_maintenance", 1, "Restart In 60 Seconds", maps\mp\gametypes\menu_functions::menuStartMaintenance, "restart|60", "Lock joining, count down, then restart.");
    self menuAddOption("server_maintenance", 2, "Restart In 5 Minutes", maps\mp\gametypes\menu_functions::menuStartMaintenance, "restart|300", "Lock joining, count down, then restart.");
    self menuAddOption("server_maintenance", 3, "Rotate In 60 Seconds", maps\mp\gametypes\menu_functions::menuStartMaintenance, "rotate|60", "Lock joining, count down, then rotate.");
    self menuBuildServerMapsMenu();
    self menuBuildServerGametypesMenu();
    self menuBuildServerSettingsMenu();
    self menuBuildServerBroadcastsMenu();

    if(maps\mp\gametypes\menu_functions::menuIsBotWarfareInstalled())
    {
        self menuBuildBotWarfareMenu();
    }

    self menuCreateMenu("players_menu", "Players", "main");
    self menuBuildPlayersMenu();
}

/* Rebuilds event controls so lockdown and pending-event state stay current. */
menuBuildServerEventsMenu()
{
    self menuCreateMenu("server_events", "Server Events", "server_menu");
    lockdownLabel = "Enable Server Lockdown";
    lockdownDescription = "Blocks new players from joining by applying a temporary private password. Connected players remain in the server, and the previous password is restored when lockdown is disabled.";
    if(getDvarInt("cws_server_lockdown") > 0)
    {
        lockdownLabel = "Disable Server Lockdown";
        lockdownDescription = "Reopens the server to new players and restores the password that was active before lockdown.";
    }
    self menuStoreOption("server_events", 0, lockdownLabel, maps\mp\gametypes\menu_functions::menuToggleServerLockdown, "", lockdownDescription);
    self menuAddOption("server_events", 1, "Maintenance Countdown", ::loadBaseMenu, "server_maintenance", "Start a maintenance countdown.");
    self menuAddOption("server_events", 2, "Delayed Restart", ::loadBaseMenu, "server_event_restart", "Schedule a map restart.");
    self menuAddOption("server_events", 3, "Delayed Rotation", ::loadBaseMenu, "server_event_rotate", "Schedule map rotation.");
    self menuAddOption("server_events", 4, "Scheduled Announcement", ::loadBaseMenu, "server_event_announcement", "Schedule an announcement.");
    self menuAddOption("server_events", 5, "Admin Activity Log", maps\mp\gametypes\menu_functions::menuOpenAdminActivityLog, "", "View event actions from this map.");
    if(isDefined(level.cwsScheduledEventActive) && level.cwsScheduledEventActive)
    {
        self menuAddDetailedOption("server_events", 6, "Cancel Pending Event", maps\mp\gametypes\menu_functions::menuCancelScheduledEvent, "", "Cancels the currently pending " + level.cwsScheduledEventType + " event.");
    }
}

menuBuildSettingsMenus()
{
    self menuCreateMenu("menu_settings", "Menu Settings", "main");
    self menuAddOption("menu_settings", 0, "Menu Colors", ::loadBaseMenu, "menu_settings_colors", "");
    self menuAddOption("menu_settings", 1, "Background Shader", ::loadBaseMenu, "menu_settings_shader", "");
    self menuAddOption("menu_settings", 2, "Fonts", ::loadBaseMenu, "menu_settings_fonts", "");
    self menuAddOption("menu_settings", 3, "Animation", ::loadBaseMenu, "menu_settings_animation", "");
    self menuAddOption("menu_settings", 4, "Layout", ::loadBaseMenu, "menu_settings_layout", "");
    self menuAddOption("menu_settings", 5, "Theme Presets", ::loadBaseMenu, "menu_settings_themes", "");
    self menuAddOption("menu_settings", 6, "Diagnostics", ::menuShowDiagnostics, "", "");
    self menuAddOption("menu_settings", 7, "Controls", ::loadBaseMenu, "self_binds", "");
    self menuAddOption("menu_settings", 8, "Reset Settings", ::menuResetVisualSettings, "", "");

    self menuCreateMenu("menu_settings_colors", "Menu Colors", "menu_settings");
    self menuAddOption("menu_settings_colors", 0, "Background", ::loadBaseMenu, "menu_color_background", "");
    self menuAddOption("menu_settings_colors", 1, "Borders", ::loadBaseMenu, "menu_color_border", "");
    self menuAddOption("menu_settings_colors", 2, "Font Color", ::loadBaseMenu, "menu_color_font", "");
    self menuAddOption("menu_settings_colors", 3, "Selection", ::loadBaseMenu, "menu_color_selection", "");

    self menuBuildColorPicker("menu_color_background", "Background Color", "background", true);
    self menuBuildColorPicker("menu_color_border", "Border Color", "border", false);
    self menuBuildColorPicker("menu_color_font", "Font Color", "font_color", false);
    self menuBuildColorPicker("menu_color_selection", "Selection Color", "selection", false);

    self menuCreateMenu("menu_settings_shader", "Background Shader", "menu_settings");
    self menuAddOption("menu_settings_shader", 0, "Solid", ::menuSetVisualSetting, "background_shader|white", "");
    self menuAddOption("menu_settings_shader", 1, "Horizontal Gradient", ::menuSetVisualSetting, "background_shader|gradient_fadein", "");
    self menuAddOption("menu_settings_shader", 2, "Bottom Fade", ::menuSetVisualSetting, "background_shader|gradient_fadein_fadebottom", "");
    self menuAddOption("menu_settings_shader", 3, "Selection Texture", ::menuSetVisualSetting, "background_shader|menu_button_selection_bar", "");
    self menuAddOption("menu_settings_shader", 4, "Soft Glow", ::menuSetVisualSetting, "background_shader|mockup_bg_glow", "");

    self menuCreateMenu("menu_settings_fonts", "Font Type", "menu_settings");
    self menuAddOption("menu_settings_fonts", 0, "Default", ::menuSetVisualSetting, "font|default", "");
    self menuAddOption("menu_settings_fonts", 1, "Objective", ::menuSetVisualSetting, "font|objective", "");
    self menuAddOption("menu_settings_fonts", 2, "Big Fixed", ::menuSetVisualSetting, "font|bigfixed", "");
    self menuAddOption("menu_settings_fonts", 3, "HUD Big", ::menuSetVisualSetting, "font|hudbig", "");
    self menuAddOption("menu_settings_fonts", 4, "Small Fixed", ::menuSetVisualSetting, "font|smallfixed", "");
    self menuAddOption("menu_settings_fonts", 5, "HUD Small", ::menuSetVisualSetting, "font|hudsmall", "");

    self menuCreateMenu("menu_settings_animation", "Menu Animation", "menu_settings");
    self menuAddOption("menu_settings_animation", 0, "Drop", ::menuSetVisualSetting, "animation|slide", "");
    self menuAddOption("menu_settings_animation", 1, "Fade", ::menuSetVisualSetting, "animation|fade", "");
    self menuAddOption("menu_settings_animation", 2, "Drop + Fade", ::menuSetVisualSetting, "animation|both", "");
    self menuAddOption("menu_settings_animation", 3, "Rise", ::menuSetVisualSetting, "animation|rise", "");
    self menuAddOption("menu_settings_animation", 4, "Rise + Fade", ::menuSetVisualSetting, "animation|risefade", "");
    self menuAddOption("menu_settings_animation", 5, "Quick Drop", ::menuSetVisualSetting, "animation|quickdrop", "");
    self menuAddOption("menu_settings_animation", 6, "Slow Drop", ::menuSetVisualSetting, "animation|slowdrop", "");
    self menuAddOption("menu_settings_animation", 7, "Slow Fade", ::menuSetVisualSetting, "animation|slowfade", "");
    self menuAddOption("menu_settings_animation", 8, "Slow Drop + Fade", ::menuSetVisualSetting, "animation|slowboth", "");
    self menuAddOption("menu_settings_animation", 9, "Instant", ::menuSetVisualSetting, "animation|none", "");
    self menuCreateMenu("menu_settings_layout", "Menu Layout", "menu_settings");
    self menuAddOption("menu_settings_layout", 0, "Position", ::loadBaseMenu, "menu_settings_position", "");
    self menuAddOption("menu_settings_layout", 1, "Opacity", ::loadBaseMenu, "menu_settings_opacity", "");
    self menuCreateMenu("menu_settings_position", "Menu Position", "menu_settings_layout");
    self menuAddOption("menu_settings_position", 0, "Left", ::menuSetVisualSetting, "position|left", "");
    self menuAddOption("menu_settings_position", 1, "Center", ::menuSetVisualSetting, "position|center", "");
    self menuAddOption("menu_settings_position", 2, "Right", ::menuSetVisualSetting, "position|right", "");
    self menuCreateMenu("menu_settings_opacity", "Panel Opacity", "menu_settings_layout");
    self menuAddOption("menu_settings_opacity", 0, "Low", ::menuSetVisualSetting, "opacity|low", "");
    self menuAddOption("menu_settings_opacity", 1, "Medium", ::menuSetVisualSetting, "opacity|medium", "");
    self menuAddOption("menu_settings_opacity", 2, "High", ::menuSetVisualSetting, "opacity|high", "");
    self menuAddOption("menu_settings_opacity", 3, "Solid", ::menuSetVisualSetting, "opacity|solid", "");
    self menuCreateMenu("menu_settings_themes", "Theme Presets", "menu_settings");
    self menuAddOption("menu_settings_themes", 0, "Classic", ::menuApplyTheme, "classic", "");
    self menuAddOption("menu_settings_themes", 1, "CWS", ::menuApplyTheme, "cws", "");
    self menuAddOption("menu_settings_themes", 2, "Tactical", ::menuApplyTheme, "tactical", "");
    self menuAddOption("menu_settings_themes", 3, "Crimson", ::menuApplyTheme, "crimson", "");
}

menuBuildColorPicker(menu, title, setting, backgroundOnly)
{
    parent = "menu_settings_colors";
    self menuCreateMenu(menu, title, parent);
    self menuAddOption(menu, 0, "Black", ::menuSetVisualSetting, setting + "|black", "");
    self menuAddOption(menu, 1, "Charcoal", ::menuSetVisualSetting, setting + "|charcoal", "");
    self menuAddOption(menu, 2, "Slate", ::menuSetVisualSetting, setting + "|slate", "");

    if(backgroundOnly)
    {
        self menuAddOption(menu, 3, "Navy", ::menuSetVisualSetting, setting + "|navy", "");
        self menuAddOption(menu, 4, "Forest", ::menuSetVisualSetting, setting + "|forest", "");
        self menuAddOption(menu, 5, "Crimson", ::menuSetVisualSetting, setting + "|crimson", "");
        self menuAddOption(menu, 6, "Deep Teal", ::menuSetVisualSetting, setting + "|deepteal", "");
        self menuAddOption(menu, 7, "Aubergine", ::menuSetVisualSetting, setting + "|aubergine", "");
        return;
    }

    self menuAddOption(menu, 3, "Gray", ::menuSetVisualSetting, setting + "|gray", "");
    self menuAddOption(menu, 4, "White", ::menuSetVisualSetting, setting + "|white", "");
    self menuAddOption(menu, 5, "Cyan", ::menuSetVisualSetting, setting + "|cyan", "");
    self menuAddOption(menu, 6, "Blue", ::menuSetVisualSetting, setting + "|blue", "");
    self menuAddOption(menu, 7, "Teal", ::menuSetVisualSetting, setting + "|teal", "");
    self menuAddOption(menu, 8, "Green", ::menuSetVisualSetting, setting + "|green", "");
    self menuAddOption(menu, 9, "Lime", ::menuSetVisualSetting, setting + "|lime", "");
    self menuAddOption(menu, 10, "Yellow", ::menuSetVisualSetting, setting + "|yellow", "");
    self menuAddOption(menu, 11, "Gold", ::menuSetVisualSetting, setting + "|gold", "");
    self menuAddOption(menu, 12, "Orange", ::menuSetVisualSetting, setting + "|orange", "");
    self menuAddOption(menu, 13, "Red", ::menuSetVisualSetting, setting + "|red", "");
    self menuAddOption(menu, 14, "Pink", ::menuSetVisualSetting, setting + "|pink", "");
    self menuAddOption(menu, 15, "Purple", ::menuSetVisualSetting, setting + "|purple", "");
}


menuBuildBotWarfareMenu()
{
    self menuCreateMenu("server_bots", "Bot Management", "server_menu");
    self menuAddOption("server_bots", 0, "Show Bot Status", maps\mp\gametypes\menu_functions::menuShowBotWarfareStatus, "", "Print the current Bot Warfare settings.");
    self menuAddOption("server_bots", 1, "Bot Main", ::loadBaseMenu, "server_bots_main", "Enable, disable, and basic bot controls.");
    self menuAddOption("server_bots", 2, "Add Bots", ::loadBaseMenu, "server_bots_add", "Add bots now.");
    self menuAddOption("server_bots", 3, "Fill Bots", ::loadBaseMenu, "server_bots_fill", "Maintain a target amount of players/bots.");
    self menuAddOption("server_bots", 4, "Bot Skill", ::loadBaseMenu, "server_bots_skill", "Set Bot Warfare difficulty.");
    self menuAddOption("server_bots", 5, "Bot Team", ::loadBaseMenu, "server_bots_team", "Choose which team bots join.");
    self menuAddOption("server_bots", 6, "Bot Behaviour", ::loadBaseMenu, "server_bots_behaviour", "Toggle bot behaviour options.");

    self menuCreateMenu("server_bots_main", "Bot Main", "server_bots");
    self menuAddOption("server_bots_main", 0, "Toggle Bots", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_main|Bot Warfare", "Toggle Bot Warfare on or off.");
    self menuAddOption("server_bots_main", 1, "Toggle BW Host Menu", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_main_menu|Bot Warfare menu", "Toggle Bot Warfare's own host menu.");
    self menuAddOption("server_bots_main", 2, "Toggle Kick Bots At End", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_main_kickBotsAtEnd|Kick bots at end", "Toggle kicking bots at match end.");

    self menuCreateMenu("server_bots_add", "Add Bots", "server_bots");
    self menuAddOption("server_bots_add", 0, "Add 1 Bot", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_manage_add|1|Add bots", "Add one bot now.");
    self menuAddOption("server_bots_add", 1, "Add 2 Bots", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_manage_add|2|Add bots", "Add two bots now.");
    self menuAddOption("server_bots_add", 2, "Add 5 Bots", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_manage_add|5|Add bots", "Add five bots now.");
    self menuAddOption("server_bots_add", 3, "Add 10 Bots", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_manage_add|10|Add bots", "Add ten bots now.");

    self menuCreateMenu("server_bots_fill", "Fill Bots", "server_bots");
    self menuAddOption("server_bots_fill", 0, "Disable Fill", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_manage_fill|0|Bot fill", "Stop automatically filling bots.");
    self menuAddOption("server_bots_fill", 1, "Fill To 2", maps\mp\gametypes\menu_functions::menuSetBotFill, "2", "Keep the match filled to 2.");
    self menuAddOption("server_bots_fill", 2, "Fill To 6", maps\mp\gametypes\menu_functions::menuSetBotFill, "6", "Keep the match filled to 6.");
    self menuAddOption("server_bots_fill", 3, "Fill To 12", maps\mp\gametypes\menu_functions::menuSetBotFill, "12", "Keep the match filled to 12.");
    self menuAddOption("server_bots_fill", 4, "Fill To 18", maps\mp\gametypes\menu_functions::menuSetBotFill, "18", "Keep the match filled to 18.");
    self menuAddOption("server_bots_fill", 5, "Toggle Fill Count Mode", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_manage_fill_mode|Fill mode", "Toggle between counting bots only and players plus bots.");
    self menuAddOption("server_bots_fill", 6, "Toggle Kick Excess Bots", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_manage_fill_kick|Kick excess bots", "Toggle kicking bots above the fill amount.");

    self menuCreateMenu("server_bots_skill", "Bot Skill", "server_bots");
    self menuAddOption("server_bots_skill", 0, "Random", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_skill|0|Bot skill", "Random difficulty for each bot.");
    self menuAddOption("server_bots_skill", 1, "Easy", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_skill|2|Bot skill", "Set easy bots.");
    self menuAddOption("server_bots_skill", 2, "Normal", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_skill|4|Bot skill", "Set normal bots.");
    self menuAddOption("server_bots_skill", 3, "Hard", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_skill|6|Bot skill", "Set hard bots.");
    self menuAddOption("server_bots_skill", 4, "Insane", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_skill|7|Bot skill", "Set hardest bots.");
    self menuAddOption("server_bots_skill", 5, "Random Parameters", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_skill|9|Bot skill", "Randomize difficulty parameters.");

    self menuCreateMenu("server_bots_team", "Bot Team", "server_bots");
    self menuAddOption("server_bots_team", 0, "Auto Assign", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_team|autoassign|Bot team", "Put bots on autoassign.");
    self menuAddOption("server_bots_team", 1, "Allies", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_team|allies|Bot team", "Put bots on allies.");
    self menuAddOption("server_bots_team", 2, "Axis", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_team|axis|Bot team", "Put bots on axis.");
    self menuAddOption("server_bots_team", 3, "Spectator", maps\mp\gametypes\menu_functions::menuSetServerDvar, "bots_team|spectator|Bot team", "Put bots as spectators.");
    self menuAddOption("server_bots_team", 4, "Toggle Force Teams", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_team_force|Force bot teams", "Toggle forcing bots to the selected team.");

    self menuCreateMenu("server_bots_behaviour", "Bot Behaviour", "server_bots");
    self menuAddOption("server_bots_behaviour", 0, "Toggle Chat", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_main_chat|Bot chat", "Toggle bot chat on or off.");
    self menuAddOption("server_bots_behaviour", 1, "Toggle Objectives", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_play_obj|Bot objectives", "Toggle bots playing objectives.");
    self menuAddOption("server_bots_behaviour", 2, "Toggle Killstreaks", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_play_killstreak|Bot killstreaks", "Toggle bots using killstreaks.");
    self menuAddOption("server_bots_behaviour", 3, "Toggle Camping", maps\mp\gametypes\menu_functions::menuToggleServerDvar, "bots_play_camp|Bot camping", "Toggle bot camping behaviour.");
}
/* Builds server controls without changing settings merely by viewing them. */
menuBuildServerSettingsMenu()
{
    self menuCreateMenu("server_settings", "Server Settings", "server_menu");

    self menuAddOption("server_settings", 0, "Movement", ::loadBaseMenu, "server_movement", "Set server gravity, speed, and jump height.");
    self menuAddOption("server_settings", 1, "Match Limits", ::loadBaseMenu, "server_limits", "Set time and score limits for the current gametype.");
    self menuAddOption("server_settings", 2, "Max Clients", ::loadBaseMenu, "max_clients", "Change the amount of players allowed on this server.");
    self menuAddOption("server_settings", 3, "Weapon Restrictions", ::loadBaseMenu, "weapon_restrictions", "Restrict Weapons on this server.");
    self menuAddOption("server_settings", 4, "Toggles", ::loadBaseMenu, "settings_toggles", "Killcam, hardcore, friendly fire.");
    self menuAddOption("server_settings", 5, "Chat", ::loadBaseMenu, "chat_settings", "Sets the chat configuration.");


    self menuCreateMenu("chat_settings", "Server - Chat Settings", "server_settings");
    self menuAddOption("chat_settings", 0, "ChatHeight", ::loadbaseMenu, "chat_height", "");
    self menuAddOption("chat_settings", 1, "ChatWidth", ::loadbaseMenu, "chat_width", "");
    self menuAddOption("chat_settings", 2, "Chat to other teams", maps\mp\gametypes\menu_functions::toggleChatWithOthers, "", "Allow chats to be seen by everyone.");

    self menuCreateMenu("chat_width", "Chat Width", "chat_settings");
    self menuAddOption("chat_width", 0, "1", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|1|Chat width", "Set chat width to 1.");
    self menuAddOption("chat_width", 1, "2", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|2|Chat width", "Set chat width to 2.");
    self menuAddOption("chat_width", 2, "3", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|3|Chat width", "Set chat width to 3.");
    self menuAddOption("chat_width", 3, "4", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|4|Chat width", "Set chat width to 4.");
    self menuAddOption("chat_width", 4, "5", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|5|Chat width", "Set chat width to 5.");
    self menuAddOption("chat_width", 5, "6", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|6|Chat width", "Set chat width to 6.");
    self menuAddOption("chat_width", 6, "7", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|7|Chat width", "Set chat width to 7.");
    self menuAddOption("chat_width", 7, "8", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatWidth|8|Chat width", "Set chat width to 8.");


    self menuCreateMenu("chat_height", "Chat Height", "chat_settings");
    self menuAddOption("chat_height", 0, "1", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|1|Chat height", "Set chat height to 1.");
    self menuAddOption("chat_height", 1, "2", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|2|Chat height", "Set chat height to 2.");
    self menuAddOption("chat_height", 2, "3", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|3|Chat height", "Set chat height to 3.");
    self menuAddOption("chat_height", 3, "4", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|4|Chat height", "Set chat height to 4.");
    self menuAddOption("chat_height", 4, "5", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|5|Chat height", "Set chat height to 5.");
    self menuAddOption("chat_height", 5, "6", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|6|Chat height", "Set chat height to 6.");
    self menuAddOption("chat_height", 6, "7", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|7|Chat height", "Set chat height to 7.");
    self menuAddOption("chat_height", 7, "8", maps\mp\gametypes\menu_functions::menuSetServerDvar, "cg_chatHeight|8|Chat height", "Set chat height to 8.");


    self menuCreateMenu("settings_toggles", "Server - Toggles", "server_settings");
    self menuAddOption("settings_toggles", 0, "Toggle Killcam", maps\mp\gametypes\menu_functions::menuToggleServerKillcam, "", "Toggle the final killcam and restart.");
    self menuAddOption("settings_toggles", 1, "Toggle Hardcore", maps\mp\gametypes\menu_functions::menuToggleServerHardcore, "", "Toggle hardcore mode and restart.");
    self menuAddOption("settings_toggles", 2, "Cycle Friendly Fire", maps\mp\gametypes\menu_functions::menuCycleFriendlyFire, "", "Cycle disabled, enabled, reflect, and shared.");


  
    self menuCreateMenu("server_limits", "Server - Match Limits", "server_settings");
    self menuAddOption("server_limits", 0, "Time Limit", ::loadBaseMenu, "server_timelimit", "Set the current gametype time limit.");
    self menuAddOption("server_limits", 1, "Score Limit", ::loadBaseMenu, "server_scorelimit", "Set the current gametype score limit.");

    self menuCreateMenu("server_timelimit", "Time Limit", "server_limits");
    self menuAddOption("server_timelimit", 0, "Unlimited", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "timelimit|0", "Disable the time limit.");
    self menuAddOption("server_timelimit", 1, "5 Minutes", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "timelimit|5", "Set a 5-minute time limit.");
    self menuAddOption("server_timelimit", 2, "10 Minutes", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "timelimit|10", "Set a 10-minute time limit.");
    self menuAddOption("server_timelimit", 3, "15 Minutes", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "timelimit|15", "Set a 15-minute time limit.");
    self menuAddOption("server_timelimit", 4, "20 Minutes", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "timelimit|20", "Set a 20-minute time limit.");
    self menuCreateMenu("server_scorelimit", "Score Limit", "server_limits");

    self menuAddOption("server_scorelimit", 0, "Unlimited", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|0", "Disable the score limit.");
    self menuAddOption("server_scorelimit", 1, "50", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|50", "Set score limit to 50.");
    self menuAddOption("server_scorelimit", 2, "75", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|75", "Set score limit to 75.");
    self menuAddOption("server_scorelimit", 3, "100", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|100", "Set score limit to 100.");
    self menuAddOption("server_scorelimit", 4, "200", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|200", "Set score limit to 200.");
    self menuAddOption("server_scorelimit", 5, "500", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|500", "Set score limit to 500.");
    self menuAddOption("server_scorelimit", 6, "1,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|1000", "Set score limit to 1,000.");
    self menuAddOption("server_scorelimit", 7, "2,500", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|2500", "Set score limit to 2,500.");
    self menuAddOption("server_scorelimit", 8, "5,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|5000", "Set score limit to 5,000.");
    self menuAddOption("server_scorelimit", 9, "10,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|10000", "Set score limit to 10,000.");
    self menuAddOption("server_scorelimit", 10, "25,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|25000", "Set score limit to 25,000.");
    self menuAddOption("server_scorelimit", 11, "50,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|50000", "Set score limit to 50,000.");
    self menuAddOption("server_scorelimit", 12, "100,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|100000", "Set score limit to 100,000.");
    self menuAddOption("server_scorelimit", 13, "250,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|250000", "Set score limit to 250,000.");
    self menuAddOption("server_scorelimit", 14, "500,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|500000", "Set score limit to 500,000.");
    self menuAddOption("server_scorelimit", 15, "1,000,000", maps\mp\gametypes\menu_functions::menuSetGametypeLimit, "scorelimit|1000000", "Set score limit to 1,000,000.");
   
    self menuCreateMenu("server_movement", "Server - Movement", "server_settings");
    self menuAddOption("server_movement", 0, "Normal Gravity", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_gravity|800|Gravity", "Set normal gravity.");
    self menuAddOption("server_movement", 1, "Low Gravity", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_gravity|300|Gravity", "Set low gravity.");
    self menuAddOption("server_movement", 2, "Moon Gravity", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_gravity|120|Gravity", "Set very low gravity.");
    self menuAddOption("server_movement", 3, "Normal Speed", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_speed|190|Speed", "Set normal player speed.");
    self menuAddOption("server_movement", 4, "Fast Speed", maps\mp\gametypes\menu_functions::menuSetServerDvar, "g_speed|260|Speed", "Set fast player speed.");
    self menuAddOption("server_movement", 5, "Normal Jump", maps\mp\gametypes\menu_functions::menuSetServerDvar, "jump_height|39|Jump height", "Set normal jump height.");
    self menuAddOption("server_movement", 6, "High Jump", maps\mp\gametypes\menu_functions::menuSetServerDvar, "jump_height|90|Jump height", "Set high jump height.");

    self menuCreateMenu("max_clients", "Server - Max Clients", "server_settings");

    self menuAddOption("max_clients", 0, "1 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|1|Max Clients", "Set 1 max connectable client(s).");
    self menuAddOption("max_clients", 1, "2 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|2|Max Clients", "Set 2 max connectable client(s).");
    self menuAddOption("max_clients", 2, "3 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|3|Max Clients", "Set 3 max connectable client(s).");
    self menuAddOption("max_clients", 3, "4 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|4|Max Clients", "Set 4 max connectable client(s).");
    self menuAddOption("max_clients", 4, "5 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|5|Max Clients", "Set 5 max connectable client(s).");
    self menuAddOption("max_clients", 5, "6 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|6|Max Clients", "Set 6 max connectable client(s).");
    self menuAddOption("max_clients", 6, "7 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|7|Max Clients", "Set 7 max connectable client(s).");
    self menuAddOption("max_clients", 7, "8 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|8|Max Clients", "Set 8 max connectable client(s).");
    self menuAddOption("max_clients", 8, "9 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|9|Max Clients", "Set 9 max connectable client(s).");
    self menuAddOption("max_clients", 9, "10 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|10|Max Clients", "Set 10 max connectable client(s).");
    self menuAddOption("max_clients", 10, "11 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|11|Max Clients", "Set 11 max connectable client(s).");
    self menuAddOption("max_clients", 11, "12 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|12|Max Clients", "Set 12 max connectable client(s).");
    self menuAddOption("max_clients", 12, "13 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|13|Max Clients", "Set 13 max connectable client(s).");
    self menuAddOption("max_clients", 13, "14 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|14|Max Clients", "Set 14 max connectable client(s).");
    self menuAddOption("max_clients", 14, "15 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|15|Max Clients", "Set 15 max connectable client(s).");
    self menuAddOption("max_clients", 15, "16 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|16|Max Clients", "Set 16 max connectable client(s).");
    self menuAddOption("max_clients", 16, "17 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|17|Max Clients", "Set 17 max connectable client(s).");
    self menuAddOption("max_clients", 17, "18 Max", maps\mp\gametypes\menu_functions::setServerSetting, "sv_maxclients|18|Max Clients", "Set 18 max connectable client(s).");

    self menuCreateMenu("weapon_restrictions", "Weapon Restrictions", "server_settings");
    self menuAddOption("weapon_restrictions", 0, "Primary Weapons", ::loadBaseMenu, "weapon_primary", "Restrict primary weapons.");
    self menuAddOption("weapon_restrictions", 1, "Secondary Weapons", ::loadBaseMenu, "weapon_secondary", "Restrict secondary weapons.");
    self menuAddOption("weapon_restrictions", 2, "Equipment", ::loadBaseMenu, "weapon_equipment", "Restrict equipment.");
    self menuAddOption("weapon_restrictions", 3, "Reset All", maps\mp\gametypes\menu_functions::resetWeaponRestrictions, "", "Allow all weapons.");

    self menuCreateMenu("weapon_primary", "Weapons - Primary", "weapon_restrictions");
    self menuAddOption("weapon_primary", 0, "Assault Rifles", ::loadBaseMenu, "weapon_primary_ar", "Restrict assault rifles.");
    self menuAddOption("weapon_primary", 1, "SMGs", ::loadBaseMenu, "weapon_primary_smg", "Restrict SMGs.");
    self menuAddOption("weapon_primary", 2, "LMGs", ::loadBaseMenu, "weapon_primary_lmg", "Restrict LMGs.");
    self menuAddOption("weapon_primary", 3, "Shotguns", ::loadBaseMenu, "weapon_primary_shotgun", "Restrict shotguns.");
    self menuAddOption("weapon_primary", 4, "Snipers", ::loadBaseMenu, "weapon_primary_sniper", "Restrict snipers.");
    self menuAddOption("weapon_primary", 5, "Launchers", ::loadBaseMenu, "weapon_primary_launcher", "Restrict launchers.");
    self menuAddOption("weapon_primary", 6, "Toggle Riot Shield", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "riotshield_mp", "Toggle Riot Shield.");

    self menuCreateMenu("weapon_primary_ar", "Primary - Assault Rifles", "weapon_primary");
    self menuAddOption("weapon_primary_ar", 0, "Toggle FAMAS", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "famas_mp", "");
    self menuAddOption("weapon_primary_ar", 1, "Toggle M4A1", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "m4_mp", "");
    self menuAddOption("weapon_primary_ar", 2, "Toggle SCAR-H", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "scar_mp", "");
    self menuAddOption("weapon_primary_ar", 3, "Toggle TAR-21", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "tavor_mp", "");
    self menuAddOption("weapon_primary_ar", 4, "Toggle ACR", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "acr_mp", "");
    self menuAddOption("weapon_primary_ar", 5, "Toggle FAL", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "fal_mp", "");
    self menuAddOption("weapon_primary_ar", 6, "Toggle AK-47", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "ak47_mp", "");
    self menuAddOption("weapon_primary_ar", 7, "Toggle M16A4", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "m16_mp", "");

    self menuCreateMenu("weapon_primary_smg", "Primary - SMGs", "weapon_primary");
    self menuAddOption("weapon_primary_smg", 0, "Toggle UMP45", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "ump45_mp", "");
    self menuAddOption("weapon_primary_smg", 1, "Toggle MP5K", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "mp5k_mp", "");
    self menuAddOption("weapon_primary_smg", 2, "Toggle Vector", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "kriss_mp", "");
    self menuAddOption("weapon_primary_smg", 3, "Toggle P90", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "p90_mp", "");
    self menuAddOption("weapon_primary_smg", 4, "Toggle Mini-Uzi", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "uzi_mp", "");

    self menuCreateMenu("weapon_primary_lmg", "Primary - LMGs", "weapon_primary");
    self menuAddOption("weapon_primary_lmg", 0, "Toggle L86 LSW", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "sa80lmg_mp", "");
    self menuAddOption("weapon_primary_lmg", 1, "Toggle RPD", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "rpd_mp", "");
    self menuAddOption("weapon_primary_lmg", 2, "Toggle MG4", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "mg4_mp", "");
    self menuAddOption("weapon_primary_lmg", 3, "Toggle AUG HBAR", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "augbar_mp", "");

    self menuCreateMenu("weapon_primary_shotgun", "Primary - Shotguns", "weapon_primary");
    self menuAddOption("weapon_primary_shotgun", 0, "Toggle SPAS-12", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "spas12_mp", "");
    self menuAddOption("weapon_primary_shotgun", 1, "Toggle AA-12", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "aa12_mp", "");
    self menuAddOption("weapon_primary_shotgun", 2, "Toggle Striker", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "striker_mp", "");
    self menuAddOption("weapon_primary_shotgun", 3, "Toggle M1014", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "m1014_mp", "");

    self menuCreateMenu("weapon_primary_sniper", "Primary - Snipers", "weapon_primary");
    self menuAddOption("weapon_primary_sniper", 0, "Toggle Intervention", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "cheytac_mp", "");
    self menuAddOption("weapon_primary_sniper", 1, "Toggle Barrett", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "barrett_mp", "");
    self menuAddOption("weapon_primary_sniper", 2, "Toggle WA2000", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "wa2000_mp", "");
    self menuAddOption("weapon_primary_sniper", 3, "Toggle M21 EBR", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "m21_mp", "");

    self menuCreateMenu("weapon_primary_launcher", "Primary - Launchers", "weapon_primary");
    self menuAddOption("weapon_primary_launcher", 0, "Toggle AT4", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "at4_mp", "");
    self menuAddOption("weapon_primary_launcher", 1, "Toggle RPG", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "rpg_mp", "");
    self menuAddOption("weapon_primary_launcher", 2, "Toggle Stinger", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "stinger_mp", "");
    self menuAddOption("weapon_primary_launcher", 3, "Toggle Javelin", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "javelin_mp", "");

    self menuCreateMenu("weapon_secondary", "Weapons - Secondary", "weapon_restrictions");
    self menuAddOption("weapon_secondary", 0, "Handguns", ::loadBaseMenu, "weapon_secondary_handgun", "Restrict handguns.");
    self menuAddOption("weapon_secondary", 1, "Machine Pistols", ::loadBaseMenu, "weapon_secondary_machine", "Restrict machine pistols.");

    self menuCreateMenu("weapon_secondary_handgun", "Secondary - Handguns", "weapon_secondary");
    self menuAddOption("weapon_secondary_handgun", 0, "Toggle USP .45", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "usp_mp", "");
    self menuAddOption("weapon_secondary_handgun", 1, "Toggle M9", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "beretta_mp", "");
    self menuAddOption("weapon_secondary_handgun", 2, "Toggle Desert Eagle", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "deserteagle_mp", "");
    self menuAddOption("weapon_secondary_handgun", 3, "Toggle .44 Magnum", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "coltanaconda_mp", "");

    self menuCreateMenu("weapon_secondary_machine", "Secondary - Machine Pistols", "weapon_secondary");
    self menuAddOption("weapon_secondary_machine", 0, "Toggle Raffica", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "beretta393_mp", "");
    self menuAddOption("weapon_secondary_machine", 1, "Toggle TMP", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "tmp_mp", "");
    self menuAddOption("weapon_secondary_machine", 2, "Toggle PP2000", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "pp2000_mp", "");
    self menuAddOption("weapon_secondary_machine", 3, "Toggle G18", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "glock_mp", "");

    self menuCreateMenu("weapon_equipment", "Weapons - Equipment", "weapon_restrictions");
    self menuAddOption("weapon_equipment", 0, "Toggle Frag", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "frag_grenade_mp", "");
    self menuAddOption("weapon_equipment", 1, "Toggle Semtex", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "semtex_mp", "");
    self menuAddOption("weapon_equipment", 2, "Toggle Throwing Knife", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "throwingknife_mp", "");
    self menuAddOption("weapon_equipment", 3, "Toggle Tactical Insertion", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "tactical_insertion_mp", "");
    self menuAddOption("weapon_equipment", 4, "Toggle Blast Shield", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "blastshield_mp", "");
    self menuAddOption("weapon_equipment", 5, "Toggle Flash", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "flash_grenade_mp", "");
    self menuAddOption("weapon_equipment", 6, "Toggle Stun", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "concussion_grenade_mp", "");
    self menuAddOption("weapon_equipment", 7, "Toggle Smoke", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "smoke_grenade_mp", "");
    self menuAddOption("weapon_equipment", 8, "Toggle Claymore", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "claymore_mp", "");
    self menuAddOption("weapon_equipment", 9, "Toggle C4", maps\mp\gametypes\menu_functions::toggleWeaponRestriction, "c4_mp", "");

}

menuBuildServerBroadcastsMenu()
{
    self menuCreateMenu("server_broadcasts", "Server Broadcasts", "server_menu");
    self menuAddOption("server_broadcasts", 0, "Follow The Rules", maps\mp\gametypes\menu_functions::menuBroadcastServerMessage, "Follow the server rules.", "Broadcast a rules reminder.");
    self menuAddOption("server_broadcasts", 1, "Respect Players", maps\mp\gametypes\menu_functions::menuBroadcastServerMessage, "Respect other players and staff.", "Broadcast a respect reminder.");
    self menuAddOption("server_broadcasts", 2, "No Cheating", maps\mp\gametypes\menu_functions::menuBroadcastServerMessage, "Cheating and exploiting are not allowed.", "Broadcast an anti-cheating reminder.");
    self menuAddOption("server_broadcasts", 3, "Restart Soon", maps\mp\gametypes\menu_functions::menuBroadcastServerMessage, "The server will restart shortly.", "Broadcast a restart warning.");
    self menuAddOption("server_broadcasts", 4, "Map Changing", maps\mp\gametypes\menu_functions::menuBroadcastServerMessage, "The map will change shortly.", "Broadcast a map-change warning.");
    self menuAddOption("server_broadcasts", 5, "Final Warning", maps\mp\gametypes\menu_functions::menuBroadcastServerMessage, "This is your final warning.", "Broadcast a final warning.");
}

menuBuildServerMapsMenu()
{
    self menuCreateMenu("server_maps", "Change Map", "server_menu");
    installedMaps = GetMapList();

    if(!isDefined(installedMaps) || installedMaps.size <= 0)
    {
        self menuAddOption("server_maps", 0, "No maps detected", ::menuNoAction, "", "");
        return;
    }

    currentMap = getDvar("mapname");
    option = 0;
    for(i = 0; i < installedMaps.size; i++)
    {
        mapName = installedMaps[i];
        if(!isDefined(mapName) || mapName == "")
        {
            continue;
        }

        displayName = GetMapArenaInfo(mapName, "longname");
        if(!isDefined(displayName) || displayName == "")
        {
            displayName = mapName;
        }
        displayName = menuCleanMapDisplayName(displayName);
        if(mapName == currentMap)
        {
            displayName += " [CURRENT]";
        }

        self menuAddOption("server_maps", option, displayName, maps\mp\gametypes\menu_functions::menuChangeMap, mapName, "");
        option++;
    }

    if(option <= 0)
    {
        self menuAddOption("server_maps", 0, "No maps detected", ::menuNoAction, "", "");
    }
}

/* Converts arena localization keys such as MPUI_FACTORY_SH into readable labels. */
menuCleanMapDisplayName(displayName)
{
    if(!isDefined(displayName) || displayName.size < 6 || getSubStr(displayName, 0, 5) != "MPUI_")
    {
        return displayName;
    }

    parts = strTok(displayName, "_");
    cleanName = "";
    for(i = 1; i < parts.size; i++)
    {
        if(cleanName != "")
        {
            cleanName += " ";
        }
        cleanName += parts[i];
    }

    if(cleanName == "")
    {
        return displayName;
    }
    return cleanName;
}

menuBuildServerGametypesMenu()
{
    self menuCreateMenu("server_gametypes", "Change Gametype", "server_menu");
    self menuAddOption("server_gametypes", 0, "Team Deathmatch", maps\mp\gametypes\menu_functions::menuChangeGametype, "war", "Set Team Deathmatch.");
    self menuAddOption("server_gametypes", 1, "Free For All", maps\mp\gametypes\menu_functions::menuChangeGametype, "dm", "Set Free For All.");
    self menuAddOption("server_gametypes", 2, "Domination", maps\mp\gametypes\menu_functions::menuChangeGametype, "dom", "Set Domination.");
    self menuAddOption("server_gametypes", 3, "Search and Destroy", maps\mp\gametypes\menu_functions::menuChangeGametype, "sd", "Set Search and Destroy.");
    self menuAddOption("server_gametypes", 4, "Sabotage", maps\mp\gametypes\menu_functions::menuChangeGametype, "sab", "Set Sabotage.");
    self menuAddOption("server_gametypes", 5, "Headquarters", maps\mp\gametypes\menu_functions::menuChangeGametype, "koth", "Set Headquarters.");
    self menuAddOption("server_gametypes", 6, "Capture the Flag", maps\mp\gametypes\menu_functions::menuChangeGametype, "ctf", "Set Capture the Flag.");
    self menuAddOption("server_gametypes", 7, "Demolition", maps\mp\gametypes\menu_functions::menuChangeGametype, "dd", "Set Demolition.");
    self menuAddOption("server_gametypes", 8, "One in the Chamber", maps\mp\gametypes\menu_functions::menuChangeGametype, "oic", "Set One in the Chamber.");
    self menuAddOption("server_gametypes", 9, "Gun Game", maps\mp\gametypes\menu_functions::menuChangeGametype, "gun", "Set Gun Game.");
}

/* Rebuilds connected-player menus with role-appropriate actions. */
menuBuildPlayersMenu()
{
    self menuCreateMenu("players_menu", "Players", "main");

    if(!isDefined(level.players))
    {
        return;
    }

    optionIndex = 0;

    for(i = 0; i < level.players.size; i++)
    {
        player = level.players[i];

        if(!isDefined(player))
        {
            continue;
        }

        entityNumber = player getEntityNumber();
        playerMenu = "player_" + entityNumber;
        playerName = "Player " + entityNumber;

        if(isDefined(player.name) && player.name != "")
        {
            playerName = player.name;
        }

        playerListName = playerName;
        if(player menuHasAccess())
        {
            playerListName += " [" + player menuGetAccessName() + "]";
        }

        self menuCreateMenu(playerMenu, playerName, "players_menu");
        self.menu.players[playerMenu] = player;
        self menuAddOption("players_menu", optionIndex, playerListName, ::loadBaseMenu, playerMenu, "Open this player's menu.");
        self menuAddOption(playerMenu, 0, "Player Info", maps\mp\gametypes\menu_functions::menuShowSelectedPlayerInfo, "", "Show this player's slot, GUID, team, and state.");
        playerWatchingMenu = playerMenu + "_watching";
        playerIw4mMenu = playerMenu + "_iw4madmin";
        self menuCreateMenu(playerWatchingMenu, playerName + " - Watching", playerMenu);
        self menuCreateMenu(playerIw4mMenu, playerName + " - IW4MAdmin", playerMenu);
        self.menu.players[playerWatchingMenu] = player;
        self.menu.players[playerIw4mMenu] = player;
        self menuAddOption(playerMenu, 1, "Watching", ::loadBaseMenu, playerWatchingMenu, "Open player observation tools.");
        self menuAddOption(playerMenu, 2, "IW4MAdmin", ::loadBaseMenu, playerIw4mMenu, "Open this player's IW4MAdmin records and actions.");
        self menuAddOption(playerWatchingMenu, 0, "Watch", maps\mp\gametypes\menu_functions::menuWatchSelectedPlayer, "", "Spectate this player with team-colored icons.");
        self menuAddOption(playerIw4mMenu, 0, "Moderation History", maps\mp\gametypes\menu_functions::menuOpenSelectedPlayerHistory, "", "View this player's IW4MAdmin moderation history.");
        self menuAddOption(playerIw4mMenu, 1, "Warnings & Penalties", maps\mp\gametypes\menu_functions::menuOpenSelectedPlayerTotals, "", "View active warnings and penalty totals.");
        playerModerationMenu = playerMenu + "_moderation";
        playerKickMenu = playerMenu + "_kick";
        playerKickSebzMenu = playerKickMenu + "_sebz";
        playerMuteMenu = playerMenu + "_mute";
        playerMuteReasonMenu = playerMuteMenu + "_reason";
        playerMuteSebzMenu = playerMuteReasonMenu + "_sebz";
        playerTempMuteMenu = playerMuteMenu + "_temporary";
        playerTempMuteReasonMenu = playerTempMuteMenu + "_reason";
        playerTempMuteDurationMenu = playerTempMuteMenu + "_duration";
        playerTempMuteSebzMenu = playerTempMuteReasonMenu + "_sebz";
        self menuCreateMenu(playerModerationMenu, playerName + " - Moderation", playerIw4mMenu);
        self menuCreateMenu(playerKickMenu, playerName + " - Kick", playerModerationMenu);
        self menuCreateMenu(playerKickSebzMenu, "Kick - Sebz", playerKickMenu);
        self menuCreateMenu(playerMuteMenu, playerName + " - Mute", playerModerationMenu);
        self menuCreateMenu(playerMuteReasonMenu, "Mute - Reason", playerMuteMenu);
        self menuCreateMenu(playerMuteSebzMenu, "Mute - Sebz", playerMuteReasonMenu);
        self menuCreateMenu(playerTempMuteMenu, playerName + " - Temp Mute", playerMuteMenu);
        self menuCreateMenu(playerTempMuteReasonMenu, "Temp Mute - Reason", playerTempMuteMenu);
        self menuCreateMenu(playerTempMuteDurationMenu, "Temp Mute - Duration", playerTempMuteMenu);
        self menuCreateMenu(playerTempMuteSebzMenu, "Temp Mute - Sebz", playerTempMuteReasonMenu);
        self.menu.players[playerModerationMenu] = player;
        self.menu.players[playerKickMenu] = player;
        self.menu.players[playerKickSebzMenu] = player;
        self.menu.players[playerMuteMenu] = player;
        self.menu.players[playerMuteReasonMenu] = player;
        self.menu.players[playerMuteSebzMenu] = player;
        self.menu.players[playerTempMuteMenu] = player;
        self.menu.players[playerTempMuteReasonMenu] = player;
        self.menu.players[playerTempMuteDurationMenu] = player;
        self.menu.players[playerTempMuteSebzMenu] = player;
        self menuAddOption(playerIw4mMenu, 2, "Moderation", ::loadBaseMenu, playerModerationMenu, "Open IW4MAdmin moderation actions.");
        playerWarnMenu = playerMenu + "_warn";
        playerFlagMenu = playerMenu + "_flag";
        playerMessagesMenu = playerMenu + "_messages";
        self menuCreateMenu(playerWarnMenu, playerName + " - Warn", playerModerationMenu);
        self menuCreateMenu(playerFlagMenu, playerName + " - Flag", playerModerationMenu);
        self menuCreateMenu(playerMessagesMenu, playerName + " - Messages", playerMenu);
        self.menu.players[playerWarnMenu] = player;
        self.menu.players[playerFlagMenu] = player;
        self.menu.players[playerMessagesMenu] = player;
        self menuAddOption(playerModerationMenu, 0, "Warn", ::loadBaseMenu, playerWarnMenu, "Choose a preset warning reason.");
        self menuAddOption(playerModerationMenu, 1, "Kick", ::loadBaseMenu, playerKickMenu, "Choose a preset kick reason.");

        if(isDefined(player.menuIw4mFlagged) && player.menuIw4mFlagged)
        {
            self menuAddOption(playerModerationMenu, 2, "Unflag Player [FLAGGED]", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "unflag|Reviewed by staff", "Remove this player's IW4MAdmin flag.");
        }
        else
        {
            self menuAddOption(playerModerationMenu, 2, "Flag Player", ::loadBaseMenu, playerFlagMenu, "Flag this player for staff review.");
        }

        self menuAddOption(playerModerationMenu, 3, "Clear Warnings", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "warnclear|Warnings cleared by staff", "Clear this player's active warnings.");
        self menuAddOption(playerModerationMenu, 4, "Mute", ::loadBaseMenu, playerMuteMenu, "Open IW4MAdmin mute commands.");
        self menuAddOption(playerModerationMenu, 5, "Known Aliases", maps\mp\gametypes\menu_functions::menuOpenSelectedPlayerKnown, "", "View this player's known names and addresses.");
        self menuAddOption(playerModerationMenu, 6, "Ban Info", maps\mp\gametypes\menu_functions::menuOpenSelectedPlayerBanInfo, "", "View this player's IW4MAdmin ban information.");
        self menuAddOption(playerMenu, 3, "Staff Messages", ::loadBaseMenu, playerMessagesMenu, "Send this player a private preset message.");
        self menuAddOption(playerMessagesMenu, 0, "You Are Being Watched", maps\mp\gametypes\menu_functions::menuSendSelectedPlayerMessage, "You are being watched by server staff.", "Tell the player they are being watched.");
        self menuAddOption(playerMessagesMenu, 1, "Read The Rules", maps\mp\gametypes\menu_functions::menuSendSelectedPlayerMessage, "Please read and follow the server rules.", "Tell the player to read the rules.");
        self menuAddOption(playerMessagesMenu, 2, "Stop Exploiting", maps\mp\gametypes\menu_functions::menuSendSelectedPlayerMessage, "Stop exploiting immediately.", "Tell the player to stop exploiting.");
        self menuAddOption(playerMessagesMenu, 3, "Change Your Name", maps\mp\gametypes\menu_functions::menuSendSelectedPlayerMessage, "Please change your player name.", "Tell the player to change their name.");
        self menuAddOption(playerMessagesMenu, 4, "Final Warning", maps\mp\gametypes\menu_functions::menuSendSelectedPlayerMessage, "This is your final warning.", "Send a final warning message.");
        self menuAddOption(playerWarnMenu, 0, "Rule Violation", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "warn|Rule Violation", "Warn for a rule violation.");
        self menuAddOption(playerWarnMenu, 1, "Abusive Language", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "warn|Abusive Language", "Warn for abusive language.");
        self menuAddOption(playerWarnMenu, 2, "Spam / Advertising", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "warn|Spam or Advertising", "Warn for spam or advertising.");
        self menuAddOption(playerWarnMenu, 3, "Unsportsmanlike", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "warn|Unsportsmanlike Behavior", "Warn for unsportsmanlike behavior.");
        self menuAddOption(playerWarnMenu, 4, "Inappropriate Name", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "warn|Inappropriate Name", "Warn for an inappropriate name.");
        self menuAddOption(playerFlagMenu, 0, "Suspected Cheating", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "flag|Suspected Cheating", "Flag for suspected cheating.");
        self menuAddOption(playerFlagMenu, 1, "Suspected Exploiting", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "flag|Suspected Exploiting", "Flag for suspected exploiting.");
        self menuAddOption(playerFlagMenu, 2, "Staff Review Required", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "flag|Staff Review Required", "Flag for further staff review.");
        self menuAddOption(playerKickMenu, 0, "Cheating", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Cheating", "Kick for cheating.");
        self menuAddOption(playerKickMenu, 1, "Exploiting", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Exploiting", "Kick for exploiting.");
        self menuAddOption(playerKickMenu, 2, "Rule Violation", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Rule Violation", "Kick for a rule violation.");
        self menuAddOption(playerKickMenu, 3, "Disruptive Behavior", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Disruptive Behavior", "Kick for disruptive behavior.");
        self menuAddOption(playerKickMenu, 4, "AFK", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Away From Keyboard", "Kick for being AFK.");
        self menuAddOption(playerKickMenu, 5, "Abusive Language", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Abusive Language", "Kick for abusive language.");
        self menuAddOption(playerKickMenu, 6, "Griefing", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Griefing", "Kick for griefing.");
        self menuAddOption(playerKickMenu, 7, "Spam / Advertising", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Spam or Advertising", "Kick for spam or advertising.");
        self menuAddOption(playerKickMenu, 8, "Inappropriate Name", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Inappropriate Name", "Kick for an inappropriate name.");
        self menuAddOption(playerKickMenu, 9, "Custom", maps\mp\gametypes\menu_functions::menuSubmitCustomModeration, "kick", "Use the cws_menu_custom_reason dvar as the kick reason.");
        self menuAddOption(playerKickMenu, 10, "Sebz", ::loadBaseMenu, playerKickSebzMenu, "Open Sebz kick reasons with the appeal address.");
        self menuAddOption(playerKickSebzMenu, 0, "Cheating", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Cheating - Appeal @ discord.sebz.xyz", "Kick for cheating with the Sebz appeal address.");
        self menuAddOption(playerKickSebzMenu, 1, "Exploiting", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Exploiting - Appeal @ discord.sebz.xyz", "Kick for exploiting with the Sebz appeal address.");
        self menuAddOption(playerKickSebzMenu, 2, "Rule Violation", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Rule Violation - Appeal @ discord.sebz.xyz", "Kick for a rule violation with the Sebz appeal address.");
        self menuAddOption(playerKickSebzMenu, 3, "Toxic Behavior", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "kick|Toxic Behavior - Appeal @ discord.sebz.xyz", "Kick for toxic behavior with the Sebz appeal address.");
        self menuAddOption(playerMuteMenu, 0, "Mute", ::loadBaseMenu, playerMuteReasonMenu, "Choose a permanent mute reason.");
        self menuAddOption(playerMuteMenu, 1, "Temporary Mute", maps\mp\gametypes\menu_functions::menuOpenTempMuteSettings, playerTempMuteMenu, "Configure a temporary mute.");
        self menuAddOption(playerMuteMenu, 2, "Mute Info", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "muteinfo|Mute information requested", "Show IW4MAdmin mute information for this player.");
        self menuAddOption(playerMuteMenu, 3, "Unmute", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "unmute|Unmuted by staff", "Remove this player's mute.");
        self menuAddOption(playerMuteReasonMenu, 0, "Abusive Language", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Abusive Language", "Mute for abusive language.");
        self menuAddOption(playerMuteReasonMenu, 1, "Mic Spam", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Microphone Spam", "Mute for microphone spam.");
        self menuAddOption(playerMuteReasonMenu, 2, "Toxic Behavior", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Toxic Behavior", "Mute for toxic behavior.");
        self menuAddOption(playerMuteReasonMenu, 3, "Harassment", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Harassment", "Mute for harassment.");
        self menuAddOption(playerMuteReasonMenu, 4, "Hate Speech", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Hate Speech", "Mute for hate speech.");
        self menuAddOption(playerMuteReasonMenu, 5, "Advertising", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Advertising", "Mute for advertising.");
        self menuAddOption(playerMuteReasonMenu, 6, "Sebz", ::loadBaseMenu, playerMuteSebzMenu, "Open Sebz mute reasons with the appeal address.");
        self menuAddOption(playerMuteSebzMenu, 0, "Abusive Language", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Abusive Language - Appeal @ discord.sebz.xyz", "Mute with the Sebz appeal address.");
        self menuAddOption(playerMuteSebzMenu, 1, "Mic Spam", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Microphone Spam - Appeal @ discord.sebz.xyz", "Mute with the Sebz appeal address.");
        self menuAddOption(playerMuteSebzMenu, 2, "Toxic Behavior", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Toxic Behavior - Appeal @ discord.sebz.xyz", "Mute with the Sebz appeal address.");
        self menuAddOption(playerMuteSebzMenu, 3, "Hate Speech", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "mute|Hate Speech - Appeal @ discord.sebz.xyz", "Mute with the Sebz appeal address.");
        self menuAddOption(playerTempMuteMenu, 0, "Reason: Toxic Behavior", ::loadBaseMenu, playerTempMuteReasonMenu, "Choose the temporary-mute reason.");
        self menuAddOption(playerTempMuteMenu, 1, "Duration: 1 Hour", ::loadBaseMenu, playerTempMuteDurationMenu, "Choose the temporary-mute duration.");
        self menuAddOption(playerTempMuteMenu, 2, "Submit Temp Mute", maps\mp\gametypes\menu_functions::menuSubmitTempMute, playerTempMuteMenu, "Submit this temporary mute to IW4MAdmin.");
        self menuAddOption(playerTempMuteReasonMenu, 0, "Abusive Language", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Abusive Language", "Use abusive language as the reason.");
        self menuAddOption(playerTempMuteReasonMenu, 1, "Mic Spam", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Microphone Spam", "Use microphone spam as the reason.");
        self menuAddOption(playerTempMuteReasonMenu, 2, "Toxic Behavior", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Toxic Behavior", "Use toxic behavior as the reason.");
        self menuAddOption(playerTempMuteReasonMenu, 3, "Harassment", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Harassment", "Use harassment as the reason.");
        self menuAddOption(playerTempMuteReasonMenu, 4, "Hate Speech", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Hate Speech", "Use hate speech as the reason.");
        self menuAddOption(playerTempMuteReasonMenu, 5, "Sebz", ::loadBaseMenu, playerTempMuteSebzMenu, "Open Sebz temporary-mute reasons.");
        self menuAddOption(playerTempMuteSebzMenu, 0, "Abusive Language", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Abusive Language - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
        self menuAddOption(playerTempMuteSebzMenu, 1, "Mic Spam", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Microphone Spam - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
        self menuAddOption(playerTempMuteSebzMenu, 2, "Toxic Behavior", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Toxic Behavior - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
        self menuAddOption(playerTempMuteSebzMenu, 3, "Hate Speech", maps\mp\gametypes\menu_functions::menuSetTempMuteReason, playerTempMuteMenu + "|Hate Speech - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
        self menuAddOption(playerTempMuteDurationMenu, 0, "15 Minutes", maps\mp\gametypes\menu_functions::menuSetTempMuteDuration, playerTempMuteMenu + "|15m|15 Minutes", "Mute for 15 minutes.");
        self menuAddOption(playerTempMuteDurationMenu, 1, "30 Minutes", maps\mp\gametypes\menu_functions::menuSetTempMuteDuration, playerTempMuteMenu + "|30m|30 Minutes", "Mute for 30 minutes.");
        self menuAddOption(playerTempMuteDurationMenu, 2, "1 Hour", maps\mp\gametypes\menu_functions::menuSetTempMuteDuration, playerTempMuteMenu + "|1h|1 Hour", "Mute for 1 hour.");
        self menuAddOption(playerTempMuteDurationMenu, 3, "6 Hours", maps\mp\gametypes\menu_functions::menuSetTempMuteDuration, playerTempMuteMenu + "|6h|6 Hours", "Mute for 6 hours.");
        self menuAddOption(playerTempMuteDurationMenu, 4, "1 Day", maps\mp\gametypes\menu_functions::menuSetTempMuteDuration, playerTempMuteMenu + "|1d|1 Day", "Mute for 1 day.");
        self menuAddOption(playerTempMuteDurationMenu, 5, "7 Days", maps\mp\gametypes\menu_functions::menuSetTempMuteDuration, playerTempMuteMenu + "|7d|7 Days", "Mute for 7 days.");

        if(self menuIsAdmin())
        {
            playerTempBanMenu = playerMenu + "_tempban";
            playerTempBanReasonMenu = playerTempBanMenu + "_reason";
            playerTempBanDurationMenu = playerTempBanMenu + "_duration";
            playerTempBanSebzMenu = playerTempBanReasonMenu + "_sebz";
            playerBanMenu = playerMenu + "_ban";
            playerBanSebzMenu = playerBanMenu + "_sebz";
            playerMovementMenu = playerMenu + "_movement";
            playerActionsMenu = playerMenu + "_actions";
            playerTeamMenu = playerMenu + "_team";
            self menuCreateMenu(playerTempBanMenu, playerName + " - Temp Ban", playerModerationMenu);
            self menuCreateMenu(playerTempBanReasonMenu, "Temp Ban - Reason", playerTempBanMenu);
            self menuCreateMenu(playerTempBanDurationMenu, "Temp Ban - Duration", playerTempBanMenu);
            self menuCreateMenu(playerTempBanSebzMenu, "Temp Ban - Sebz", playerTempBanReasonMenu);
            self menuCreateMenu(playerBanMenu, playerName + " - Ban", playerModerationMenu);
            self menuCreateMenu(playerBanSebzMenu, "Ban - Sebz", playerBanMenu);
            self menuCreateMenu(playerMovementMenu, playerName + " - Movement", playerMenu);
            self menuCreateMenu(playerActionsMenu, playerName + " - Actions", playerMenu);
            self menuCreateMenu(playerTeamMenu, playerName + " - Team", playerActionsMenu);
            self.menu.players[playerTempBanMenu] = player;
            self.menu.players[playerTempBanReasonMenu] = player;
            self.menu.players[playerTempBanDurationMenu] = player;
            self.menu.players[playerTempBanSebzMenu] = player;
            self.menu.players[playerBanMenu] = player;
            self.menu.players[playerBanSebzMenu] = player;
            self.menu.players[playerMovementMenu] = player;
            self.menu.players[playerActionsMenu] = player;
            self.menu.players[playerTeamMenu] = player;
            self menuAddOption(playerModerationMenu, 7, "Temp Ban", maps\mp\gametypes\menu_functions::menuOpenTempBanSettings, playerTempBanMenu, "Configure a temporary ban.");
            self menuAddOption(playerModerationMenu, 8, "Ban", ::loadBaseMenu, playerBanMenu, "Choose a preset permanent-ban reason.");
            self menuAddOption(playerTempBanMenu, 0, "Reason: Cheating", ::loadBaseMenu, playerTempBanReasonMenu, "Choose the temporary-ban reason.");
            self menuAddOption(playerTempBanMenu, 1, "Duration: 1 Hour", ::loadBaseMenu, playerTempBanDurationMenu, "Choose the temporary-ban duration.");
            self menuAddOption(playerTempBanMenu, 2, "Submit Temp Ban", maps\mp\gametypes\menu_functions::menuSubmitTempBan, playerTempBanMenu, "Submit this temporary ban to IW4MAdmin.");
            self menuAddOption(playerTempBanReasonMenu, 0, "Cheating", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Cheating", "Use cheating as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 1, "Exploiting", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Exploiting", "Use exploiting as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 2, "Rule Violation", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Rule Violation", "Use rule violation as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 3, "Disruptive Behavior", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Disruptive Behavior", "Use disruptive behavior as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 4, "Griefing", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Griefing", "Use griefing as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 5, "Toxic Behavior", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Toxic Behavior", "Use toxic behavior as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 6, "Repeated Violations", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Repeated Rule Violations", "Use repeated rule violations as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 7, "Spam / Advertising", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Spam or Advertising", "Use spam or advertising as the reason.");
            self menuAddOption(playerTempBanReasonMenu, 8, "Custom", maps\mp\gametypes\menu_functions::menuSetTempBanCustomReason, playerTempBanMenu, "Use the cws_menu_custom_reason dvar as the temp-ban reason.");
            self menuAddOption(playerTempBanReasonMenu, 9, "Sebz", ::loadBaseMenu, playerTempBanSebzMenu, "Open Sebz temporary-ban reasons.");
            self menuAddOption(playerTempBanSebzMenu, 0, "Cheating", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Cheating - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
            self menuAddOption(playerTempBanSebzMenu, 1, "Exploiting", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Exploiting - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
            self menuAddOption(playerTempBanSebzMenu, 2, "Ban Evasion", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Ban Evasion - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
            self menuAddOption(playerTempBanSebzMenu, 3, "Rule Violation", maps\mp\gametypes\menu_functions::menuSetTempBanReason, playerTempBanMenu + "|Rule Violation - Appeal @ discord.sebz.xyz", "Use the Sebz reason and appeal address.");
            self menuAddOption(playerTempBanDurationMenu, 0, "15 Minutes", maps\mp\gametypes\menu_functions::menuSetTempBanDuration, playerTempBanMenu + "|15m|15 Minutes", "Set duration to 15 minutes.");
            self menuAddOption(playerTempBanDurationMenu, 1, "30 Minutes", maps\mp\gametypes\menu_functions::menuSetTempBanDuration, playerTempBanMenu + "|30m|30 Minutes", "Set duration to 30 minutes.");
            self menuAddOption(playerTempBanDurationMenu, 2, "1 Hour", maps\mp\gametypes\menu_functions::menuSetTempBanDuration, playerTempBanMenu + "|1h|1 Hour", "Set duration to 1 hour.");
            self menuAddOption(playerTempBanDurationMenu, 3, "6 Hours", maps\mp\gametypes\menu_functions::menuSetTempBanDuration, playerTempBanMenu + "|6h|6 Hours", "Set duration to 6 hours.");
            self menuAddOption(playerTempBanDurationMenu, 4, "1 Day", maps\mp\gametypes\menu_functions::menuSetTempBanDuration, playerTempBanMenu + "|1d|1 Day", "Set duration to 1 day.");
            self menuAddOption(playerTempBanDurationMenu, 5, "7 Days", maps\mp\gametypes\menu_functions::menuSetTempBanDuration, playerTempBanMenu + "|7d|7 Days", "Set duration to 7 days.");
            self menuAddOption(playerBanMenu, 0, "Cheating", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Cheating", "Permanently ban for cheating.");
            self menuAddOption(playerBanMenu, 1, "Exploiting", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Exploiting", "Permanently ban for exploiting.");
            self menuAddOption(playerBanMenu, 2, "Severe Rule Violation", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Severe Rule Violation", "Permanently ban for severe rule violations.");
            self menuAddOption(playerBanMenu, 3, "Ban Evasion", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Ban Evasion", "Permanently ban for ban evasion.");
            self menuAddOption(playerBanMenu, 4, "Aimbot", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Aimbot", "Permanently ban for aimbot use.");
            self menuAddOption(playerBanMenu, 5, "Wallhack", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Wallhack", "Permanently ban for wallhack use.");
            self menuAddOption(playerBanMenu, 6, "Repeated Violations", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Repeated Rule Violations", "Permanently ban for repeated violations.");
            self menuAddOption(playerBanMenu, 7, "Threats / DDoS", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Threats or DDoS", "Permanently ban for threats or attacks.");
            self menuAddOption(playerBanMenu, 8, "Custom", maps\mp\gametypes\menu_functions::menuSubmitCustomModeration, "ban", "Use the cws_menu_custom_reason dvar as the ban reason.");
            self menuAddOption(playerBanMenu, 9, "Sebz", ::loadBaseMenu, playerBanSebzMenu, "Open Sebz permanent-ban reasons.");
            self menuAddOption(playerBanSebzMenu, 0, "Cheating", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Cheating - Appeal @ discord.sebz.xyz", "Ban with the Sebz appeal address.");
            self menuAddOption(playerBanSebzMenu, 1, "Exploiting", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Exploiting - Appeal @ discord.sebz.xyz", "Ban with the Sebz appeal address.");
            self menuAddOption(playerBanSebzMenu, 2, "Ban Evasion", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Ban Evasion - Appeal @ discord.sebz.xyz", "Ban with the Sebz appeal address.");
            self menuAddOption(playerBanSebzMenu, 3, "Aimbot", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Aimbot - Appeal @ discord.sebz.xyz", "Ban with the Sebz appeal address.");
            self menuAddOption(playerBanSebzMenu, 4, "Wallhack", maps\mp\gametypes\menu_functions::menuSubmitPresetModeration, "ban|Wallhack - Appeal @ discord.sebz.xyz", "Ban with the Sebz appeal address.");
            self menuAddOption(playerMenu, 4, "Movement", ::loadBaseMenu, playerMovementMenu, "Open teleport and freeze controls.");
            self menuAddOption(playerMenu, 5, "Actions", ::loadBaseMenu, playerActionsMenu, "Open player utility actions.");
            self menuAddOption(playerMovementMenu, 0, "Teleport To", maps\mp\gametypes\menu_functions::menuTeleportToSelectedPlayer, "", "Teleport yourself to this player.");
            self menuAddOption(playerMovementMenu, 1, "Bring Here", maps\mp\gametypes\menu_functions::menuBringSelectedPlayer, "", "Teleport this player to you.");
            self menuAddOption(playerMovementMenu, 2, "Freeze / Unfreeze", maps\mp\gametypes\menu_functions::menuToggleFreezeSelectedPlayer, "", "Toggle this player's controls.");
            self menuAddOption(playerActionsMenu, 0, "Slay", maps\mp\gametypes\menu_functions::menuSlaySelectedPlayer, "", "Kill this player.");
            self menuAddOption(playerActionsMenu, 1, "Refill Ammo", maps\mp\gametypes\menu_functions::menuRefillSelectedPlayerAmmo, "", "Refill this player's current weapon.");
            self menuAddOption(playerActionsMenu, 2, "Strip Weapons", maps\mp\gametypes\menu_functions::menuStripSelectedPlayerWeapons, "", "Remove all weapons from this player.");
            self menuAddOption(playerActionsMenu, 3, "Heal Player", maps\mp\gametypes\menu_functions::menuHealSelectedPlayer, "", "Restore this player's health.");
            self menuAddOption(playerActionsMenu, 4, "Reset Player State", maps\mp\gametypes\menu_functions::menuResetSelectedPlayerState, "", "Unfreeze and restore this player's visibility and collision.");
            self menuAddOption(playerActionsMenu, 5, "Weapon Info", maps\mp\gametypes\menu_functions::menuShowSelectedPlayerWeapon, "", "Show this player's current weapon and ammunition.");
            self menuAddOption(playerActionsMenu, 6, "Team", ::loadBaseMenu, playerTeamMenu, "Move this player to a team or spectator.");
            self menuAddOption(playerTeamMenu, 0, "Allies", maps\mp\gametypes\menu_functions::menuMoveSelectedPlayerTeam, "allies", "Move this player to Allies.");
            self menuAddOption(playerTeamMenu, 1, "Axis", maps\mp\gametypes\menu_functions::menuMoveSelectedPlayerTeam, "axis", "Move this player to Axis.");
            self menuAddOption(playerTeamMenu, 2, "Auto Assign", maps\mp\gametypes\menu_functions::menuMoveSelectedPlayerTeam, "auto", "Move this player to the smaller team.");
            self menuAddOption(playerTeamMenu, 3, "Spectator", maps\mp\gametypes\menu_functions::menuMoveSelectedPlayerTeam, "spectator", "Force this player to spectator.");
        }

        if(self menuIsOwner())
        {
            playerLevelMenu = playerMenu + "_level";
            self menuCreateMenu(playerLevelMenu, playerName + " - Level", playerMenu + "_actions");
            self.menu.players[playerLevelMenu] = player;
            self menuAddOption(playerMenu + "_actions", 7, "Level", ::loadBaseMenu, playerLevelMenu, "Change this player's IW4MAdmin access level.");
            self menuAddOption(playerWatchingMenu, 1, "Keep Eye On", maps\mp\gametypes\menu_functions::menuKeepEyeOnSelectedPlayer, "", "Monitor this player's aim target and review status.");
            self menuAddOption(playerLevelMenu, 0, "Administrator", maps\mp\gametypes\menu_functions::menuSubmitSetLevel, "Administrator", "Set this player to Administrator.");
            self menuAddOption(playerLevelMenu, 1, "Moderator", maps\mp\gametypes\menu_functions::menuSubmitSetLevel, "Moderator", "Set this player to Moderator.");
            self menuAddOption(playerLevelMenu, 2, "User", maps\mp\gametypes\menu_functions::menuSubmitSetLevel, "User", "Set this player to User.");
        }

        optionIndex++;
    }
}

/* Stores menu definitions, options, callbacks, descriptions, and parent links. */
menuCreateMenu(menu, title, parent)
{
    self.menu.title[menu] = title;
    self.menu.parent[menu] = parent;
    self.menu.text[menu] = [];
    self.menu.func[menu] = [];
    self.menu.input[menu] = [];
    self.menu.description[menu] = [];
}

menuAddOption(menu, index, text, func, input, description)
{
    if(isDefined(description) && description != "")
    {
        if(text == "Confirm")
        {
            description = "Confirm this action.";
        }
        else if(text == "Cancel")
        {
            description = "Return without changes.";
        }
        else if(text == "Refresh")
        {
            description = "Refresh this menu.";
        }
        else
        {
            description = "";
        }
    }

    self menuStoreOption(menu, index, text, func, input, description);
}

menuAddDetailedOption(menu, index, text, func, input, description)
{
    if(isDefined(description) && description != "")
    {
        if(!isDefined(level.menuDetailedTextCount))
        {
            level.menuDetailedTextCount = 0;
        }

        if(level.menuDetailedTextCount >= 96)
        {
            description = "Additional details hidden until next map.";
        }
        else
        {
            level.menuDetailedTextCount++;
        }
    }

    self menuStoreOption(menu, index, text, func, input, description);
}

menuStoreOption(menu, index, text, func, input, description)
{
    self.menu.text[menu][index] = text;
    self.menu.func[menu][index] = func;
    self.menu.input[menu][index] = input;

    if(!isDefined(description))
    {
        description = "";
    }

    self.menu.description[menu][index] = description;
}

getMenuOptionDescription(menu, index)
{
    if(!isDefined(self.menu.description[menu]) || !isDefined(self.menu.description[menu][index]))
    {
        return "";
    }

    return self.menu.description[menu][index];
}

getMenuX(x)
{
    self menuSafeInitPlayer();
    return x + self.menuSettings["menu_x"];
}

getMenuY(y)
{
    self menuSafeInitPlayer();
    return y + self.menuSettings["menu_y"];
}

getMenuAccentColor()
{
    self menuSafeInitPlayer();
    return menuGetColorValue(self.menuSettings["border"]);
}

/* Updates visible rows, selection, descriptions, and dynamic panel bounds. */
menuScrollUpdate()
{
    if(!self isMenuOpen())
    {
        return;
    }

    menu = self.menu.current;

    if(!isDefined(self.menu.text[menu]))
    {
        return;
    }

    optionCount = self.menu.text[menu].size;
    self.menuHud.title setText(self menuGetHeaderTitle());
    self.menuHud.subtitle setText(self menuGetHeaderSubtitle());
    slideResize = true;

    if(self isMenuOpening())
    {
        slideResize = false;
    }

    self menuResizeHud(menu, slideResize);
    self ensureMenuTextSlots();

    if(optionCount <= 0)
    {
        for(i = 0; i < getMenuDisplayCount(); i++)
        {
            self.menuHud.text[i] setText("");
            self.menuHud.text[i].menuTargetAlpha = 0;
            self.menuHud.text[i].alpha = 0;
        }

        self.menuHud.selectionBar.menuTargetAlpha = 0;
        self.menuHud.selectionBar.alpha = 0;
        self.menuHud.description setText("");
        self.menuHud.description.menuTargetAlpha = 0;
        return;
    }

    if(self.menu.scroller < 0)
    {
        self.menu.scroller = optionCount - 1;
    }

    if(self.menu.scroller >= optionCount)
    {
        self.menu.scroller = 0;
    }

    displayCount = self getMenuVisibleCount(menu);
    firstOption = 0;

    if(optionCount > displayCount && self.menu.scroller >= displayCount)
    {
        firstOption = self.menu.scroller - displayCount + 1;
    }

    selectedSlot = self.menu.scroller - firstOption;
    selectedDescription = getMenuOptionDescription(menu, self.menu.scroller);
    descriptionGap = 0;

    if(selectedDescription != "")
    {
        descriptionGap = getMenuDescriptionGap();
    }

    openingOffset = 0;

    if(self isMenuOpening())
    {
        openingOffset = self menuGetOpeningOffset();
    }

    for(i = 0; i < displayCount; i++)
    {
        optionIndex = firstOption + i;
        itemY = getMenuOptionY() + (getMenuOptionDistance() * i);

        if(descriptionGap > 0 && i > selectedSlot)
        {
            itemY += descriptionGap;
        }

        elem = self.menuHud.text[i];
        itemTargetX = self getMenuX(-118);
        itemTargetY = self getMenuY(itemY);
        elem.menuTargetX = itemTargetX;
        elem.menuTargetY = itemTargetY;
        elem.x = itemTargetX;
        elem.y = itemTargetY + openingOffset;
        elem.menuLastX = itemTargetX;
        elem.menuLastY = itemTargetY;
        if(optionIndex == self.menu.scroller)
        {
            elem setText(menuGetStaticMenuText(self.menu.text[menu][optionIndex], 30));
            elem.menuTargetAlpha = 1;
            elem.alpha = 1;
            elem.color = self menuGetFontColor();
            elem changeFontScaleOverTime(.14);
            elem.fontscale = getMenuSelectedFontScale();
        }
        else
        {
            elem setText(menuGetStaticMenuText(self.menu.text[menu][optionIndex], 30));
            elem.menuTargetAlpha = .62;
            elem.alpha = .62;
            elem.color = self menuGetFontColor();
            elem changeFontScaleOverTime(.14);
            elem.fontscale = getMenuDefaultFontScale();
        }
    }

    for(i = displayCount; i < getMenuDisplayCount(); i++)
    {
        self.menuHud.text[i] setText("");
        self.menuHud.text[i].menuTargetAlpha = 0;
        self.menuHud.text[i].alpha = 0;
    }


    selectionY = getMenuOptionY() + (getMenuOptionDistance() * selectedSlot);
    selectionHeight = getMenuSelectionHeight(selectedDescription);

    if(descriptionGap > 0)
    {
        selectionY += 8;
        self.menuHud.description setText(menuGetStaticMenuText(selectedDescription, 42));
        descriptionTargetX = self getMenuX(-118);
        descriptionTargetY = self getMenuY(getMenuOptionY() + (getMenuOptionDistance() * selectedSlot) + 16);
        self.menuHud.description.menuTargetX = descriptionTargetX;
        self.menuHud.description.menuTargetY = descriptionTargetY;
        self.menuHud.description.x = descriptionTargetX;
        self.menuHud.description.y = descriptionTargetY + openingOffset;
        self.menuHud.description.menuLastX = descriptionTargetX;
        self.menuHud.description.menuLastY = descriptionTargetY;
        self.menuHud.description.menuTargetAlpha = .9;
        self.menuHud.description.alpha = .9;
    }
    else
    {
        self.menuHud.description setText("");
        self.menuHud.description.menuTargetAlpha = 0;
        self.menuHud.description.alpha = 0;
    }

    self.menuHud.selectionBar.menuTargetAlpha = .95;
    self.menuHud.selectionBar.alpha = .95;
    self.menuHud.selectionBar.menuTargetY = self getMenuY(selectionY);
    self.menuHud.selectionBar moveOverTime(.14);
    self.menuHud.selectionBar.y = self.menuHud.selectionBar.menuTargetY + openingOffset;
    self.menuHud.selectionBar scaleOverTime(.14, getMenuPanelWidth(), selectionHeight);
    self.menuHud.selectionBar.width = getMenuPanelWidth();
    self.menuHud.selectionBar.height = selectionHeight;
}

menuGetStaticMenuText(text, maxCharacters)
{
    if(!isDefined(text))
    {
        return "";
    }

    if(text.size <= maxCharacters)
    {
        return text;
    }

    return getSubStr(text, 0, maxCharacters);
}

menuSelect()
{
    if(!self isMenuOpen())
    {
        return;
    }

    menu = self.menu.current;
    index = self.menu.scroller;

    if(isDefined(self.menu.func[menu][index]))
    {
        self [[self.menu.func[menu][index]]](self.menu.input[menu][index]);
    }
}

menuNoAction(input)
{
}

menuBack()
{
    if(!self isMenuOpen())
    {
        return;
    }

    menu = self.menu.current;

    if(!isDefined(self.menu.parent[menu]) || self.menu.parent[menu] == "Exit")
    {
        self closeBaseMenu();
        return;
    }

    self loadBaseMenu(self.menu.parent[menu]);
}

menuRefresh()
{
    if(self isMenuOpen())
    {
        self menuResizeHud(self.menu.current, false);
        self menuScrollUpdate();
    }
}

getMenuPanelWidth()
{
    return 264;
}

getMenuPanelTopY()
{
    return -158;
}

getMenuDisplayCount()
{
    return level.menu["menu_display_count"];
}

getMenuVisibleCount(menu)
{
    maxCount = getMenuDisplayCount();
    optionCount = self.menu.text[menu].size;

    if(optionCount <= 0)
    {
        return 1;
    }

    if(optionCount < maxCount)
    {
        return optionCount;
    }

    return maxCount;
}

getMenuFooterY(menu)
{
    return self getMenuFooterSeparatorY(menu) + 11;
}

/* Returns the lowest rendered edge of the final row or expanded description. */
getMenuContentBottomY(menu)
{
    visibleCount = self getMenuVisibleCount(menu);
    lastItemY = getMenuOptionY() + (getMenuOptionDistance() * (visibleCount - 1));
    contentHalfHeight = 11;

    if(isDefined(self.menu) && isDefined(self.menu.scroller))
    {
        selectedDescription = getMenuOptionDescription(menu, self.menu.scroller);

        if(selectedDescription != "")
        {
            contentHalfHeight = 29;
        }
    }

    return lastItemY + contentHalfHeight;
}

/* Mirrors the five-pixel gap between the header separator and first row. */
getMenuFooterSeparatorY(menu)
{
    return self getMenuContentBottomY(menu) + getMenuContentEdgeGap() + 1;
}

getMenuContentEdgeGap()
{
    return 5;
}

getMenuPanelHeight(menu)
{
    return (self getMenuFooterY(menu) + 10) - getMenuPanelTopY();
}

menuResizeHud(menu, slide)
{
    if(!isDefined(self.menuHud))
    {
        return;
    }

    width = getMenuPanelWidth();
    height = self getMenuPanelHeight(menu);
    footerY = self getMenuFooterY(menu);
    separatorY = self getMenuFooterSeparatorY(menu);
    accent = self getMenuAccentColor();
    openingOffset = 0;

    if(self isMenuOpening())
    {
        openingOffset = self menuGetOpeningOffset();
    }

    self.menuHud.background.menuTargetX = self getMenuX(0);
    self.menuHud.background.menuTargetY = self getMenuY(getMenuPanelTopY());
    self.menuHud.background.y = self.menuHud.background.menuTargetY + openingOffset;

    if(isDefined(self.menuHud.backgroundEffect))
    {
        self.menuHud.backgroundEffect.menuTargetX = self getMenuX(0);
        self.menuHud.backgroundEffect.menuTargetY = self getMenuY(getMenuPanelTopY());
        self.menuHud.backgroundEffect.y = self.menuHud.backgroundEffect.menuTargetY + openingOffset;
    }

    if(slide)
    {
        self.menuHud.background scaleOverTime(.14, width, height);
        if(isDefined(self.menuHud.backgroundEffect))
        {
            self.menuHud.backgroundEffect scaleOverTime(.14, width, height);
        }
    }
    else
    {
        self.menuHud.background setShader("white", width, height);
        if(isDefined(self.menuHud.backgroundEffect))
        {
            self.menuHud.backgroundEffect setShader(self menuGetBackgroundShader(), width, height);
        }
    }

    self.menuHud.background.width = width;
    self.menuHud.background.height = height;
    if(isDefined(self.menuHud.backgroundEffect))
    {
        self.menuHud.backgroundEffect.width = width;
        self.menuHud.backgroundEffect.height = height;
    }
    self.menuHud.footer.menuTargetY = self getMenuY(footerY);
    self.menuHud.footer moveOverTime(.14);
    self.menuHud.footer.y = self.menuHud.footer.menuTargetY + openingOffset;
    self.menuHud.footerSeparator.menuTargetY = self getMenuY(separatorY);
    self.menuHud.footerSeparator moveOverTime(.14);
    self.menuHud.footerSeparator.y = self.menuHud.footerSeparator.menuTargetY + openingOffset;
    self.menuHud.title.menuTargetX = self getMenuX(-122);
    self.menuHud.title.menuTargetY = self getMenuY(self menuGetHeaderTitleY());
    self.menuHud.title moveOverTime(.14);
    self.menuHud.title.x = self.menuHud.title.menuTargetX;
    self.menuHud.title.y = self.menuHud.title.menuTargetY + openingOffset;
    self.menuHud.subtitle.menuTargetX = self getMenuX(-122);
    self.menuHud.subtitle.menuTargetY = self getMenuY(-118);
    self.menuHud.subtitle moveOverTime(.14);
    self.menuHud.subtitle.x = self.menuHud.subtitle.menuTargetX;
    self.menuHud.subtitle.y = self.menuHud.subtitle.menuTargetY + openingOffset;
    self.menuHud.headerStripe.color = accent;
    self.menuHud.separator.color = accent;
    self.menuHud.footerSeparator.color = accent;
    self.menuHud.selectionBar.color = self menuGetSelectionColor();
    self.menuHud.subtitle.color = accent;
}

getMenuOptionY()
{
    return level.menu["menu_option_y"];
}

getMenuOptionDistance()
{
    return level.menu["menu_option_distance"];
}

getMenuDefaultFontScale()
{
    return 1.1;
}

getMenuSelectedFontScale()
{
    return 1.22;
}

getMenuDescriptionGap()
{
    return 20;
}

getMenuDescriptionOffset(menu)
{
    if(!isDefined(self.menu) || !isDefined(self.menu.scroller))
    {
        return 0;
    }

    description = getMenuOptionDescription(menu, self.menu.scroller);

    if(description == "")
    {
        return 0;
    }

    return getMenuDescriptionGap();
}

getMenuSelectionHeight(description)
{
    if(!isDefined(description) || description == "")
    {
        return 22;
    }

    return 42;
}

menuInitVisualSettings()
{
    if(isDefined(self.menuVisualSettingsLoaded) && self.menuVisualSettingsLoaded)
    {
        return;
    }

    self.menuSettings["background"] = "black";
    self.menuSettings["border"] = "cyan";
    self.menuSettings["font_color"] = "white";
    self.menuSettings["selection"] = "cyan";
    self.menuSettings["font"] = "default";
    self.menuSettings["animation"] = "slide";
    self.menuSettings["background_shader"] = "white";
    self.menuSettings["opacity"] = "high";
    self.menuSettings["position"] = "center";
    savedValue = getDvar(self menuGetVisualSettingsDvarName());

    if(isDefined(savedValue) && savedValue != "")
    {
        parts = strTok(savedValue, "|");

        if(parts.size >= 6)
        {
            if(menuIsValidVisualSetting("background", parts[0]))
            {
                self.menuSettings["background"] = parts[0];
            }

            if(menuIsValidVisualSetting("border", parts[1]))
            {
                self.menuSettings["border"] = parts[1];
            }

            if(menuIsValidVisualSetting("font_color", parts[2]))
            {
                self.menuSettings["font_color"] = parts[2];
            }

            if(menuIsValidVisualSetting("selection", parts[3]))
            {
                self.menuSettings["selection"] = parts[3];
            }

            if(menuIsValidVisualSetting("font", parts[4]))
            {
                self.menuSettings["font"] = parts[4];
            }

            if(menuIsValidVisualSetting("animation", parts[5]))
            {
                self.menuSettings["animation"] = parts[5];
            }

            if(parts.size >= 7 && menuIsValidVisualSetting("background_shader", parts[6]))
            {
                self.menuSettings["background_shader"] = parts[6];
            }

            if(parts.size >= 8 && menuIsValidVisualSetting("opacity", parts[7]))
            {
                self.menuSettings["opacity"] = parts[7];
            }

            if(parts.size >= 9 && menuIsValidVisualSetting("position", parts[8]))
            {
                self.menuSettings["position"] = parts[8];
            }
        }
    }

    self.menuVisualSettingsLoaded = true;
    self menuApplyVisualPosition();
    self menuPersistVisualSettings();
}

menuSetVisualSetting(input)
{
    parts = strTok(input, "|");

    if(parts.size < 2 || !menuIsValidVisualSetting(parts[0], parts[1]))
    {
        return;
    }

    self.menuSettings[parts[0]] = parts[1];
    if(parts[0] == "position")
    {
        self menuApplyVisualPosition();
    }
    self menuPersistVisualSettings();
    self menuRefreshVisualHud();
}

/* Applies a coordinated set of colors, font, shader, and animation settings. */
menuApplyTheme(theme)
{
    if(theme == "classic")
    {
        self.menuSettings["background"] = "black";
        self.menuSettings["border"] = "cyan";
        self.menuSettings["font_color"] = "white";
        self.menuSettings["selection"] = "cyan";
        self.menuSettings["font"] = "default";
        self.menuSettings["background_shader"] = "white";
    }
    else if(theme == "cws")
    {
        self.menuSettings["background"] = "navy";
        self.menuSettings["border"] = "cyan";
        self.menuSettings["font_color"] = "white";
        self.menuSettings["selection"] = "blue";
        self.menuSettings["font"] = "objective";
        self.menuSettings["background_shader"] = "gradient_fadein";
    }
    else if(theme == "tactical")
    {
        self.menuSettings["background"] = "forest";
        self.menuSettings["border"] = "lime";
        self.menuSettings["font_color"] = "white";
        self.menuSettings["selection"] = "green";
        self.menuSettings["font"] = "smallfixed";
        self.menuSettings["background_shader"] = "gradient_fadein_fadebottom";
    }
    else if(theme == "crimson")
    {
        self.menuSettings["background"] = "crimson";
        self.menuSettings["border"] = "red";
        self.menuSettings["font_color"] = "white";
        self.menuSettings["selection"] = "orange";
        self.menuSettings["font"] = "hudbig";
        self.menuSettings["background_shader"] = "mockup_bg_glow";
    }
    else
    {
        return;
    }

    self menuPersistVisualSettings();
    self menuRefreshVisualHud();
}

/* Shows the active GSC visual profile and access state to the current player. */
menuShowDiagnostics(input)
{
    self iprintln("^3Menu: ^7" + self.menu.current + " ^3Access: ^7" + self menuGetAccessName());
    self iprintln("^3Theme: ^7" + self.menuSettings["background"] + " / " + self.menuSettings["border"] + " ^3Font: ^7" + self.menuSettings["font"]);
    self iprintln("^3Shader: ^7" + self.menuSettings["background_shader"] + " ^3Animation: ^7" + self.menuSettings["animation"]);
}

menuApplyVisualPosition()
{
    self.menuSettings["menu_x"] = 0;
    if(self.menuSettings["position"] == "left")
    {
        self.menuSettings["menu_x"] = -230;
    }
    else if(self.menuSettings["position"] == "right")
    {
        self.menuSettings["menu_x"] = 230;
    }
}

menuResetVisualSettings(input)
{
    self.menuSettings["background"] = "black";
    self.menuSettings["border"] = "cyan";
    self.menuSettings["font_color"] = "white";
    self.menuSettings["selection"] = "cyan";
    self.menuSettings["font"] = "default";
    self.menuSettings["animation"] = "slide";
    self.menuSettings["background_shader"] = "white";
    self.menuSettings["opacity"] = "high";
    self.menuSettings["position"] = "center";
    self menuApplyVisualPosition();
    self menuPersistVisualSettings();
    self menuRefreshVisualHud();
}

menuRefreshVisualHud()
{
    if(!self isMenuOpen())
    {
        return;
    }

    currentMenu = self.menu.current;
    currentScroller = self.menu.scroller;
    self destroyMenuHud();
    self.menu.current = currentMenu;
    self.menu.scroller = currentScroller;
    self createMenuHud();
    self.menu.scroller = currentScroller;
    self menuScrollUpdate();
}

menuPersistVisualSettings()
{
    value = self.menuSettings["background"] + "|";
    value += self.menuSettings["border"] + "|";
    value += self.menuSettings["font_color"] + "|";
    value += self.menuSettings["selection"] + "|";
    value += self.menuSettings["font"] + "|";
    value += self.menuSettings["animation"] + "|";
    value += self.menuSettings["background_shader"] + "|";
    value += self.menuSettings["opacity"] + "|";
    value += self.menuSettings["position"];
    setDvar(self menuGetVisualSettingsDvarName(), value);
}

menuGetVisualSettingsDvarName()
{
    return self menuGetControlBindDvarName() + "_visual";
}

menuIsValidVisualSetting(setting, value)
{
    if(setting == "background")
    {
        return value == "black" || value == "charcoal" || value == "slate" || value == "navy" || value == "forest" || value == "crimson" || value == "deepteal" || value == "aubergine";
    }

    if(setting == "border" || setting == "font_color" || setting == "selection")
    {
        return value == "black" || value == "charcoal" || value == "slate" || value == "gray" || value == "white" || value == "cyan" || value == "blue" || value == "teal" || value == "green" || value == "lime" || value == "yellow" || value == "gold" || value == "orange" || value == "red" || value == "pink" || value == "purple";
    }

    if(setting == "font")
    {
        return value == "default" || value == "objective" || value == "bigfixed" || value == "hudbig" || value == "smallfixed" || value == "hudsmall";
    }

    if(setting == "animation")
    {
        return value == "slide" || value == "fade" || value == "both" || value == "rise" || value == "risefade" || value == "quickdrop" || value == "slowdrop" || value == "slowfade" || value == "slowboth" || value == "none";
    }

    if(setting == "background_shader")
    {
        return value == "white" || value == "gradient_fadein" || value == "gradient_fadein_fadebottom" || value == "menu_button_selection_bar" || value == "mockup_bg_glow";
    }

    if(setting == "opacity")
    {
        return value == "low" || value == "medium" || value == "high" || value == "solid";
    }

    if(setting == "position")
    {
        return value == "left" || value == "center" || value == "right";
    }

    return false;
}

menuGetColorValue(value)
{
    switch(value)
    {
        case "charcoal": return (.1, .11, .11);
        case "slate": return (.16, .19, .23);
        case "navy": return (.02, .07, .16);
        case "forest": return (.02, .14, .06);
        case "crimson": return (.18, .02, .04);
        case "deepteal": return (.01, .14, .15);
        case "aubergine": return (.14, .03, .16);
        case "gray": return (.58, .61, .64);
        case "white": return (1, 1, 1);
        case "cyan": return (.15, .65, 1);
        case "blue": return (.16, .34, 1);
        case "teal": return (.04, .72, .68);
        case "green": return (.08, .8, .28);
        case "lime": return (.58, 1, .12);
        case "yellow": return (1, .78, .08);
        case "gold": return (1, .56, .06);
        case "orange": return (1, .31, .05);
        case "red": return (1, .16, .16);
        case "pink": return (1, .28, .62);
        case "purple": return (.68, .28, 1);
    }

    return (0, 0, 0);
}

menuGetBackgroundColor()
{
    self menuInitVisualSettings();
    return menuGetColorValue(self.menuSettings["background"]);
}

/* Returns the player's persisted material for the main menu panel. */
menuGetBackgroundShader()
{
    self menuInitVisualSettings();
    return self.menuSettings["background_shader"];
}

menuGetPanelOpacity()
{
    self menuInitVisualSettings();
    value = self.menuSettings["opacity"];
    if(value == "low")
    {
        return .45;
    }
    if(value == "medium")
    {
        return .65;
    }
    if(value == "solid")
    {
        return 1;
    }
    return .82;
}

menuGetHeaderOpacity()
{
    value = self menuGetPanelOpacity() + .12;
    if(value > 1)
    {
        value = 1;
    }
    return value;
}

menuGetFontColor()
{
    self menuInitVisualSettings();
    return menuGetColorValue(self.menuSettings["font_color"]);
}

menuGetSelectionColor()
{
    self menuInitVisualSettings();
    return menuGetColorValue(self.menuSettings["selection"]);
}

menuGetFontName()
{
    self menuInitVisualSettings();
    return self.menuSettings["font"];
}

menuAnimationUsesSlide()
{
    self menuInitVisualSettings();
    animation = self.menuSettings["animation"];
    return animation == "slide" || animation == "both" || animation == "rise" || animation == "risefade" || animation == "quickdrop" || animation == "slowdrop" || animation == "slowboth";
}

menuAnimationUsesFade()
{
    self menuInitVisualSettings();
    animation = self.menuSettings["animation"];
    return animation == "fade" || animation == "both" || animation == "risefade" || animation == "slowfade" || animation == "slowboth";
}

/* Returns the off-screen start position for the selected slide direction. */
menuGetSlideOffset()
{
    self menuInitVisualSettings();

    if(self.menuSettings["animation"] == "rise" || self.menuSettings["animation"] == "risefade")
    {
        return 420;
    }

    return getMenuSlideOffset();
}

/* Returns the opening duration selected by the player's visual profile. */
menuGetOpenAnimationTime()
{
    self menuInitVisualSettings();
    animation = self.menuSettings["animation"];

    if(animation == "quickdrop" || animation == "none")
    {
        return .08;
    }

    if(animation == "slowdrop" || animation == "slowfade" || animation == "slowboth")
    {
        return .35;
    }

    return .18;
}

/* Keeps closing responsive while respecting quick and slow animation modes. */
menuGetCloseAnimationTime()
{
    time = self menuGetOpenAnimationTime();

    if(time > .3)
    {
        return .3;
    }

    if(time < .1)
    {
        return .06;
    }

    return .16;
}

menuGetOpeningOffset()
{
    if(self menuAnimationUsesSlide())
    {
        return self menuGetSlideOffset();
    }

    return 0;
}

menuBindPressed(bind)
{
    switch(bind)
    {
        case "ads": return self AdsButtonPressed();
        case "attack": return self AttackButtonPressed();
        case "frag": return self FragButtonPressed();
        case "smoke": return self SecondaryOffhandButtonPressed();
        case "use": return self UseButtonPressed();
        case "melee": return self MeleeButtonPressed();
        case "ads_melee": return self AdsButtonPressed() && self MeleeButtonPressed();
        case "ads_use": return self AdsButtonPressed() && self UseButtonPressed();
        case "ads_frag": return self AdsButtonPressed() && self FragButtonPressed();
        case "ads_smoke": return self AdsButtonPressed() && self SecondaryOffhandButtonPressed();
        case "use_melee": return self UseButtonPressed() && self MeleeButtonPressed();
        case "attack_melee": return self AttackButtonPressed() && self MeleeButtonPressed();
        case "dpad_up": return self menuCommandButtonPressed("dpad_up");
        case "dpad_down": return self menuCommandButtonPressed("dpad_down");
        case "dpad_left": return self menuCommandButtonPressed("dpad_left");
        case "dpad_right": return self menuCommandButtonPressed("dpad_right");
    }

    return false;
}

menuInitControlBinds()
{
    if(isDefined(self.menuControlBinds))
    {
        self menuPersistControlBinds();
        return;
    }

    storageKey = self menuGetControlBindStorageKey();

    if(isDefined(level.menuSavedBinds) && isDefined(level.menuSavedBinds[storageKey]))
    {
        self.menuControlBinds = level.menuSavedBinds[storageKey];
        return;
    }

    savedBinds = self menuReadControlBindDvar();

    if(isDefined(savedBinds))
    {
        self.menuControlBinds = savedBinds;
        self menuPersistControlBinds();
        return;
    }

    self.menuControlBinds = [];
    self.menuControlBinds["open"] = "frag";
    self.menuControlBinds["close"] = "frag";
    self.menuControlBinds["select"] = "use";
    self.menuControlBinds["up"] = "ads";
    self.menuControlBinds["down"] = "attack";
    self menuPersistControlBinds();
}

menuBuildBindPicker(menu, title, action)
{
    self menuCreateMenu(menu, title, "self_binds");
    self menuAddOption(menu, 0, "Aim Down Sight", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|ads", "Use the aim-down-sight button.");
    self menuAddOption(menu, 1, "Fire", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|attack", "Use the fire button.");
    self menuAddOption(menu, 2, "Frag Grenade", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|frag", "Use the frag grenade button.");
    self menuAddOption(menu, 3, "Special Grenade", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|smoke", "Use the special grenade button.");
    self menuAddOption(menu, 4, "Use / Reload", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|use", "Use the interact and reload button.");
    self menuAddOption(menu, 5, "Melee", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|melee", "Use the melee button.");
    self menuAddOption(menu, 6, "D-Pad Up", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|dpad_up", "Use D-pad up or Action Slot 1.");
    self menuAddOption(menu, 7, "D-Pad Down", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|dpad_down", "Use D-pad down or Action Slot 2.");
    self menuAddOption(menu, 8, "D-Pad Left", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|dpad_left", "Use D-pad left or Action Slot 3.");
    self menuAddOption(menu, 9, "D-Pad Right", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|dpad_right", "Use D-pad right or Action Slot 4.");
    self menuAddOption(menu, 10, "Aim + Melee", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|ads_melee", "Hold aim and press melee together.");
    self menuAddOption(menu, 11, "Aim + Use", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|ads_use", "Hold aim and press use or reload.");
    self menuAddOption(menu, 12, "Aim + Frag", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|ads_frag", "Hold aim and press the frag button.");
    self menuAddOption(menu, 13, "Aim + Special", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|ads_smoke", "Hold aim and press the special grenade button.");
    self menuAddOption(menu, 14, "Use + Melee", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|use_melee", "Hold use and press melee together.");
    self menuAddOption(menu, 15, "Fire + Melee", maps\mp\gametypes\menu_functions::menuSetControlBind, action + "|attack_melee", "Hold fire and press melee together.");
}

menuApplyControlBind(action, bind)
{
    self menuInitControlBinds();
    self.menuControlBinds[action] = bind;
    self menuPersistControlBinds();
}

menuPersistControlBinds()
{
    if(!isDefined(self.menuControlBinds))
    {
        return;
    }

    if(!isDefined(level.menuSavedBinds))
    {
        level.menuSavedBinds = [];
    }

    storageKey = self menuGetControlBindStorageKey();
    level.menuSavedBinds[storageKey] = self.menuControlBinds;
    setDvar(self menuGetControlBindDvarName(), self.menuControlBinds["open"] + "|" + self.menuControlBinds["close"] + "|" + self.menuControlBinds["select"] + "|" + self.menuControlBinds["up"] + "|" + self.menuControlBinds["down"]);
}

menuGetControlBindStorageKey()
{
    if(isDefined(self.guid))
    {
        return "guid_" + self.guid;
    }

    return "slot_" + self getEntityNumber();
}

menuGetControlBindDvarName()
{
    if(!isDefined(self.guid))
    {
        return "cws_menu_binds_slot_" + self getEntityNumber();
    }

    guidText = "" + self.guid;
    guidParts = strTok(guidText, "-");
    guidToken = guidText;
    signToken = "p";

    if(guidParts.size > 0)
    {
        guidToken = guidParts[0];

        if(guidText != guidToken)
        {
            signToken = "n";
        }
    }

    return "cws_menu_binds_" + signToken + guidToken;
}

menuReadControlBindDvar()
{
    savedValue = getDvar(self menuGetControlBindDvarName());

    if(!isDefined(savedValue) || savedValue == "")
    {
        return undefined;
    }

    parts = strTok(savedValue, "|");

    if(parts.size < 5)
    {
        return undefined;
    }

    for(i = 0; i < 5; i++)
    {
        if(!menuIsValidControlBind(parts[i]))
        {
            return undefined;
        }
    }

    binds = [];
    binds["open"] = parts[0];
    binds["close"] = parts[1];
    binds["select"] = parts[2];
    binds["up"] = parts[3];
    binds["down"] = parts[4];
    return binds;
}

menuIsValidControlBind(bind)
{
    switch(bind)
    {
        case "ads":
        case "attack":
        case "frag":
        case "smoke":
        case "use":
        case "melee":
        case "ads_melee":
        case "ads_use":
        case "ads_frag":
        case "ads_smoke":
        case "use_melee":
        case "attack_melee":
        case "dpad_up":
        case "dpad_down":
        case "dpad_left":
        case "dpad_right":
            return true;
    }

    return false;
}

menuGetBindToken(bind)
{
    switch(bind)
    {
        case "ads": return "{+speed_throw}";
        case "attack": return "{+attack}";
        case "frag": return "{+frag}";
        case "smoke": return "{+smoke}";
        case "use": return "{+activate}";
        case "melee": return "{+melee}";
        case "ads_melee": return "{+speed_throw}+{+melee}";
        case "ads_use": return "{+speed_throw}+{+activate}";
        case "ads_frag": return "{+speed_throw}+{+frag}";
        case "ads_smoke": return "{+speed_throw}+{+smoke}";
        case "use_melee": return "{+activate}+{+melee}";
        case "attack_melee": return "{+attack}+{+melee}";
        case "dpad_up": return "{+actionslot 1}";
        case "dpad_down": return "{+actionslot 2}";
        case "dpad_left": return "{+actionslot 3}";
        case "dpad_right": return "{+actionslot 4}";
    }

    return bind;
}

menuStartCommandButtons()
{
    if(isDefined(self.menuCommandButtonsStarted) && self.menuCommandButtonsStarted)
    {
        return;
    }

    self.menuCommandButtonsStarted = true;
    self.menuCommandButtonPending = [];
    self notifyOnPlayerCommand("menu_dpad_up", "+actionslot 1");
    self notifyOnPlayerCommand("menu_dpad_down", "+actionslot 2");
    self notifyOnPlayerCommand("menu_dpad_left", "+actionslot 3");
    self notifyOnPlayerCommand("menu_dpad_right", "+actionslot 4");
    self thread menuTrackCommandButton("dpad_up", "menu_dpad_up");
    self thread menuTrackCommandButton("dpad_down", "menu_dpad_down");
    self thread menuTrackCommandButton("dpad_left", "menu_dpad_left");
    self thread menuTrackCommandButton("dpad_right", "menu_dpad_right");
}

menuTrackCommandButton(bind, notification)
{
    self endon("disconnect");

    for(;;)
    {
        self waittill(notification);
        self.menuCommandButtonPending[bind] = true;
    }
}

menuCommandButtonPressed(bind)
{
    if(!isDefined(self.menuCommandButtonPending) || !isDefined(self.menuCommandButtonPending[bind]) || !self.menuCommandButtonPending[bind])
    {
        return false;
    }

    self.menuCommandButtonPending[bind] = false;
    return true;
}

menuOpenButtonPressed()
{
    self menuInitControlBinds();
    return self menuBindPressed(self.menuControlBinds["open"]);
}

menuCloseButtonPressed()
{
    self menuInitControlBinds();
    return self menuBindPressed(self.menuControlBinds["close"]);
}

waitMenuOpenButtonRelease()
{
    while(self menuOpenButtonPressed())
    {
        wait .05;
    }
}

waitMenuBindRelease(bind)
{
    while(self menuBindPressed(bind))
    {
        wait .05;
    }
}
