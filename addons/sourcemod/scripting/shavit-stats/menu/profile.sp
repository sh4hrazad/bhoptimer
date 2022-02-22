public Action Command_Profile(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	int target = client;
	int iSteamID = 0;

	if(args > 0)
	{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);

		iSteamID = SteamIDToAuth(sArgs);

		if (iSteamID < 1)
		{
			target = FindTarget(client, sArgs, true, false);

			if (target == -1)
			{
				return Plugin_Handled;
			}
		}
	}

	gI_TargetSteamID[client] = (iSteamID > 0) ? iSteamID : GetSteamAccountID(target);

	return OpenStatsMenu(client, gI_TargetSteamID[client]);
}

Action OpenStatsMenu(int client, int steamid, int style = 0, int item = 0)
{
	gI_Style[client] = style;
	gI_MenuPos[client] = item;

	// no spam please
	if(!gB_CanOpenMenu[client])
	{
		return Plugin_Handled;
	}

	// big ass query, looking for optimizations TODO
	char sQuery[2048];

	if(gB_Rankings)
	{
		FormatEx(sQuery, 2048, "SELECT a.clears, b.maps, c.wrs, d.name, d.ip, d.lastlogin, f.clears, g.maps, h.wrs, d.points, e.rank, d.playtime, i.styleplaytime FROM " ...
				"(SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE auth = %d AND track = 0 AND style = %d GROUP BY map) s) a " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track = 0 AND type = 0 GROUP BY map) s) b " ...
				"JOIN (SELECT COUNT(*) wrs FROM %swrs WHERE auth = %d AND track = 0 AND style = %d) c " ...
				"JOIN (SELECT name, ip, lastlogin, FORMAT(points, 2) points, playtime FROM %susers WHERE auth = %d) d " ...
				"JOIN (SELECT COUNT(*) as 'rank' FROM %susers as u1 JOIN (SELECT points FROM %susers WHERE auth = %d) u2 WHERE u1.points >= u2.points) e " ...
				"JOIN (SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE auth = %d AND track > 0 AND style = %d GROUP BY map) s) f " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track > 0 AND type = 0 GROUP BY map) s) g " ...
				"JOIN (SELECT COUNT(*) wrs FROM %swrs WHERE auth = %d AND track > 0 AND style = %d) h " ...
				"JOIN (SELECT SUM(playtime) as styleplaytime FROM %sstyleplaytime WHERE auth = %d AND style = %d) i " ...
			"LIMIT 1;", gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, steamid, gS_MySQLPrefix, gS_MySQLPrefix, steamid, gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, steamid, style);
	}
	else
	{
		FormatEx(sQuery, 2048, "SELECT a.clears, b.maps, c.wrs, d.name, d.ip, d.lastlogin, e.clears, f.maps, g.wrs, d.playtime, i.styleplaytime FROM " ...
				"(SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE auth = %d AND track = 0 AND style = %d GROUP BY map) s) a " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track = 0 AND type = 0 GROUP BY map) s) b " ...
				"JOIN (SELECT COUNT(*) wrs FROM %swrs WHERE auth = %d AND track = 0 AND style = %d) c " ...
				"JOIN (SELECT name, ip, lastlogin, playtime FROM %susers WHERE auth = %d) d " ...
				"JOIN (SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE auth = %d AND track > 0 AND style = %d GROUP BY map) s) e " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track > 0 AND type = 0 GROUP BY map) s) f " ...
				"JOIN (SELECT COUNT(*) wrs FROM %swrs WHERE auth = %d AND track > 0 AND style = %d) g " ...
				"JOIN (SELECT SUM(playtime) as styleplaytime FROM %sstyleplaytime WHERE auth = %d AND style = %d) i " ...
			"LIMIT 1;", gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, steamid, gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, gS_MySQLPrefix, steamid, style, gS_MySQLPrefix, steamid, style);
	}

	gB_CanOpenMenu[client] = false;

	DataPack data = new DataPack();
	data.WriteCell(GetClientSerial(client));
	data.WriteCell(item);

	gH_SQL.Query(OpenStatsMenuCallback, sQuery, data, DBPrio_Low);

	return Plugin_Handled;
}

public void OpenStatsMenuCallback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int client = GetClientFromSerial(data.ReadCell());
	int item = data.ReadCell();

	gB_CanOpenMenu[client] = true;

	if(results == null)
	{
		LogError("Timer (statsmenu) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow())
	{
		// create variables
		int iClears = results.FetchInt(0);
		int iTotalMaps = results.FetchInt(1);
		int iWRs = results.FetchInt(2);
		results.FetchString(3, gS_TargetName[client], MAX_NAME_LENGTH);
		ReplaceString(gS_TargetName[client], MAX_NAME_LENGTH, "#", "?");

		int iIPAddress = results.FetchInt(4);
		char sIPAddress[32];
		IPAddressToString(iIPAddress, sIPAddress, 32);

		char sCountry[64];

		if(!GeoipCountry(sIPAddress, sCountry, 64))
		{
			strcopy(sCountry, 64, "Local Area Network");
		}

		int iLastLogin = results.FetchInt(5);
		char sLastLogin[32];
		FormatTime(sLastLogin, 32, "%Y-%m-%d %H:%M:%S", iLastLogin);
		Format(sLastLogin, 32, "%T: %s", "LastLogin", client, (iLastLogin != -1)? sLastLogin:"N/A");

		int iBonusClears = results.FetchInt(6);
		int iBonusTotalMaps = results.FetchInt(7);
		int iBonusWRs = results.FetchInt(8);

		char sPoints[16];
		char sRank[16];

		if(gB_Rankings)
		{
			results.FetchString(9, sPoints, 16);
			results.FetchString(10, sRank, 16);
		}

		float fPlaytime = results.FetchFloat(gB_Rankings ? 11 : 9);
		char sPlaytime[16];
		FormatSeconds(fPlaytime, sPlaytime, sizeof(sPlaytime), false, true, true);

		float fStylePlaytime = results.FetchFloat(gB_Rankings ? 12 : 10);
		char sStylePlaytime[16];
		FormatSeconds(fStylePlaytime, sStylePlaytime, sizeof(sStylePlaytime), false, true, true);

		char sRankingString[64];

		if(gB_Rankings)
		{
			if(StringToInt(sRank) > 0 && StringToInt(sPoints) > 0)
			{
				FormatEx(sRankingString, 64, "\n%T: #%s/%d\n%T: %s", "Rank", client, sRank, Shavit_GetRankedPlayers(), "Points", client, sPoints);
			}
			else
			{
				FormatEx(sRankingString, 64, "\n%T: %T", "Rank", client, "PointsUnranked", client);
			}
		}

		if(iClears > iTotalMaps)
		{
			iClears = iTotalMaps;
		}

		Menu menu = new Menu(MenuHandler_ProfileHandler);
		menu.SetTitle("%s's %T. [U:1:%d]\n%T: %s\n%s\n%s\n%T: %s\n",
			gS_TargetName[client], "Profile", client, gI_TargetSteamID[client], "Country", client, sCountry, sLastLogin,
			sRankingString, "Playtime", client, sPlaytime);

		int[] styles = new int[gI_Styles];
		Shavit_GetOrderedStyles(styles, gI_Styles);

		for(int i = 0; i < gI_Styles; i++)
		{
			int iStyle = styles[i];

			if(Shavit_GetStyleSettingInt(iStyle, "unranked") || Shavit_GetStyleSettingInt(iStyle, "enabled") <= 0)
			{
				continue;
			}

			char sInfo[4];
			IntToString(iStyle, sInfo, 4);

			char sStyleInfo[256];

			if (iStyle == gI_Style[client])
			{
				FormatEx(sStyleInfo, sizeof(sStyleInfo),
					"%s\n"...
					"    [Main] %T: %d/%d (%0.1f%%)\n"...
					"    [Main] %T: %d\n"...
					"    [Bonus] %T: %d/%d (%0.1f%%)\n"...
					"    [Bonus] %T: %d\n"...
					"    [%T] %s\n"...
					"",
					gS_StyleStrings[iStyle].sStyleName,
					"MapCompletions", client, iClears, iTotalMaps, ((float(iClears) / (iTotalMaps > 0 ? float(iTotalMaps) : 0.0)) * 100.0),
					"WorldRecords", client, iWRs,
					"MapCompletions", client, iBonusClears, iBonusTotalMaps, ((float(iBonusClears) / (iBonusTotalMaps > 0 ? float(iBonusTotalMaps) : 0.0)) * 100.0),
					"WorldRecords", client, iBonusWRs,
					"Playtime", client, sStylePlaytime
				);
			}
			else
			{
				FormatEx(sStyleInfo, sizeof(sStyleInfo), "%s\n", gS_StyleStrings[iStyle].sStyleName);
			}

			menu.AddItem(sInfo, sStyleInfo);
		}

		// should NEVER happen
		if(menu.ItemCount == 0)
		{
			char sMenuItem[64];
			FormatEx(sMenuItem, 64, "%T", "NoRecords", client);
			menu.AddItem("-1", sMenuItem);
		}

		menu.ExitButton = true;
		menu.DisplayAt(client, item, MENU_TIME_FOREVER);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "StatsMenuFailure", client);
	}
}

public int MenuHandler_ProfileHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];

		menu.GetItem(param2, sInfo, 32);
		int iSelectedStyle = StringToInt(sInfo);
		gI_MenuPos[param1] = GetMenuSelectionPosition();

		// If we select the same style, then display these
		if(iSelectedStyle == gI_Style[param1])
		{
			Menu submenu = new Menu(MenuHandler_TypeHandler);
			submenu.SetTitle("%T", "MapsMenu", param1, gS_StyleStrings[gI_Style[param1]].sShortName);

			for(int j = 0; j < TRACKS_SIZE; j++)
			{
				char sTrack[32];
				GetTrackName(param1, j, sTrack, 32);

				char sMenuItem[64];
				FormatEx(sMenuItem, 64, "%T (%s)", "MapsDone", param1, sTrack);

				char sNewInfo[32];
				FormatEx(sNewInfo, 32, "%d;0", j);
				submenu.AddItem(sNewInfo, sMenuItem);

				FormatEx(sMenuItem, 64, "%T (%s)", "MapsLeft", param1, sTrack);
				FormatEx(sNewInfo, 32, "%d;1", j);
				submenu.AddItem(sNewInfo, sMenuItem);
			}

			submenu.ExitBackButton = true;
			submenu.Display(param1, MENU_TIME_FOREVER);
		}
		else // No? display stats menu but different style
		{
			OpenStatsMenu(param1, gI_TargetSteamID[param1], iSelectedStyle, gI_MenuPos[param1]);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_TypeHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, 32);

		char sExploded[2][4];
		ExplodeString(sInfo, ";", sExploded, 2, 4);

		gI_Track[param1] = StringToInt(sExploded[0]);
		gI_MapType[param1] = StringToInt(sExploded[1]);

		ShowMaps(param1);
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenStatsMenu(param1, gI_TargetSteamID[param1], gI_Style[param1], gI_MenuPos[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}