public Action Command_MapsDoneLeft(int client, int args)
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
		else
		{
			FormatEx(gS_TargetName[client], sizeof(gS_TargetName[]), "[U:1:%d]", iSteamID);
		}
	}

	if (iSteamID < 1)
	{
		GetClientName(target, gS_TargetName[client], sizeof(gS_TargetName[]));
		iSteamID = GetSteamAccountID(target);
	}

	gI_TargetSteamID[client] = iSteamID;

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	ReplaceString(gS_TargetName[client], MAX_NAME_LENGTH, "#", "?");

	Menu menu = new Menu(MenuHandler_MapsDoneLeft);

	if(StrEqual(sCommand, "sm_mapsdone"))
	{
		gI_MapType[client] = MAPSDONE;
		menu.SetTitle("%T\n ", "MapsDoneOnStyle", client, gS_TargetName[client]);
	}
	else
	{
		gI_MapType[client] = MAPSLEFT;
		menu.SetTitle("%T\n ", "MapsLeftOnStyle", client, gS_TargetName[client]);
	}

	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = styles[i];

		if(Shavit_GetStyleSettingInt(iStyle, "unranked") || Shavit_GetStyleSettingInt(iStyle, "enabled") == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);
		menu.AddItem(sInfo, gS_StyleStrings[iStyle].sStyleName);
	}

	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_MapsDoneLeft(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		gI_Style[param1] = StringToInt(sInfo);

		Menu submenu = new Menu(MenuHandler_MapsDoneLeft_Track);
		submenu.SetTitle("%T\n ", "SelectTrack", param1);

		for(int i = 0; i < TRACKS_SIZE; i++)
		{
			IntToString(i, sInfo, 8);

			char sTrack[32];
			GetTrackName(param1, i, sTrack, 32);
			submenu.AddItem(sInfo, sTrack);
		}

		submenu.Display(param1, MENU_TIME_FOREVER);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_MapsDoneLeft_Track(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		gI_Track[param1] = StringToInt(sInfo);

		ShowMaps(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void ShowMaps(int client)
{
	if(!gB_CanOpenMenu[client])
	{
		return;
	}

	char sQuery[512];

	switch(gI_MapType[client])
	{
		case MAPSDONE:
		{
			FormatEx(sQuery, 512, mysql_show_mapsdone, gI_TargetSteamID[client], gI_Style[client], gI_Track[client], (gB_Rankings)? "points DESC":"map");
		}
		case MAPSLEFT:
		{
			if(gB_Rankings)
			{
				FormatEx(sQuery, 512, mysql_show_mapsleft_have_rankings, gI_Track[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client]);
			}
			else
			{
				FormatEx(sQuery, 512, mysql_show_mapsleft_no_rankings, gI_Track[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client]);
			}
		}
	}

	gB_CanOpenMenu[client] = false;

	gH_SQL.Query(ShowMapsCallback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void ShowMapsCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ShowMaps SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	gB_CanOpenMenu[client] = true;

	int rows = results.RowCount;

	char sTrack[32];
	GetTrackName(client, gI_Track[client], sTrack, 32);

	Menu menu = new Menu(MenuHandler_ShowMaps);

	if(gI_MapType[client] == MAPSDONE)
	{
		menu.SetTitle("%T (%s)", "MapsDoneFor", client, gS_StyleStrings[gI_Style[client]].sShortName, gS_TargetName[client], rows, sTrack);
	}

	else
	{
		menu.SetTitle("%T (%s)", "MapsLeftFor", client, gS_StyleStrings[gI_Style[client]].sShortName, gS_TargetName[client], rows, sTrack);
	}

	while(results.FetchRow())
	{
		char sMap[PLATFORM_MAX_PATH];
		results.FetchString(0, sMap, sizeof(sMap));

		char sRecordID[PLATFORM_MAX_PATH];
		char sDisplay[PLATFORM_MAX_PATH];

		if(gI_MapType[client] == MAPSDONE)
		{
			float time = results.FetchFloat(1);
			int jumps = results.FetchInt(2);
			int rank = results.FetchInt(4);

			char sTime[32];
			FormatSeconds(time, sTime, 32);

			float points = results.FetchFloat(5);

			if(gB_Rankings && points > 0.0)
			{
				FormatEx(sDisplay, sizeof(sDisplay), "[#%d] %s - %s (%.03f %T)", rank, sMap, sTime, points, "MapsPoints", client);
			}
			else
			{
				FormatEx(sDisplay, sizeof(sDisplay), "[#%d] %s - %s (%d %T)", rank, sMap, sTime, jumps, "MapsJumps", client);
			}

			int iRecordID = results.FetchInt(3);
			IntToString(iRecordID, sRecordID, sizeof(sRecordID));
		}
		else
		{
			if(gB_Rankings)
			{
				int iTier = results.FetchInt(1);

				if(results.IsFieldNull(1) || iTier == 0)
				{
					iTier = 1;
				}

				FormatEx(sDisplay, sizeof(sDisplay), "%s (Tier %d)", sMap, iTier);
			}
			else
			{
				sDisplay = sMap;
			}

			sRecordID = sMap;
		}

		menu.AddItem(sRecordID, sDisplay);
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "NoResults", client);
		menu.AddItem("nope", sMenuItem);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowMaps(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "nope"))
		{
			OpenStatsMenu(param1, gI_TargetSteamID[param1], gI_Style[param1], gI_MenuPos[param1]);

			return 0;
		}
		else if(StringToInt(sInfo) == 0)
		{
			FakeClientCommand(param1, "sm_nominate %s", sInfo);

			return 0;
		}

		char sQuery[512];
		FormatEx(sQuery, 512, mysql_showmaps_details, sInfo);

		gH_SQL.Query(SQL_SubMenu_Callback, sQuery, GetClientSerial(param1));
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

public void SQL_SubMenu_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (STATS SUBMENU) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	Menu hMenu = new Menu(SubMenu_Handler);

	char sName[MAX_NAME_LENGTH];
	int iSteamID = 0;
	char sMap[PLATFORM_MAX_PATH];

	if(results.FetchRow())
	{
		// 0 - name
		results.FetchString(0, sName, MAX_NAME_LENGTH);

		// 1 - time
		float time = results.FetchFloat(1);
		char sTime[16];
		FormatSeconds(time, sTime, 16);

		char sDisplay[128];
		FormatEx(sDisplay, 128, "%T: %s", "Time", client, sTime);
		hMenu.AddItem("-1", sDisplay);

		// 2 - jumps
		int jumps = results.FetchInt(2);
		FormatEx(sDisplay, 128, "%T: %d", "Jumps", client, jumps);
		hMenu.AddItem("-1", sDisplay);

		// 3 - style
		int style = results.FetchInt(3);
		FormatEx(sDisplay, 128, "%T: %s", "Style", client, gS_StyleStrings[style].sStyleName);
		hMenu.AddItem("-1", sDisplay);

		// 4 - steamid3
		iSteamID = results.FetchInt(4);

		// 6 - map
		results.FetchString(6, sMap, sizeof(sMap));

		float points = results.FetchFloat(9);

		if(gB_Rankings && points > 0.0)
		{
			FormatEx(sDisplay, 128, "%T: %.03f", "Points", client, points);
			hMenu.AddItem("-1", sDisplay);
		}

		// 5 - date
		char sDate[32];
		results.FetchString(5, sDate, 32);

		if(sDate[4] != '-')
		{
			FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sDate));
		}

		FormatEx(sDisplay, 128, "%T: %s", "Date", client, sDate);
		hMenu.AddItem("-1", sDisplay);

		int strafes = results.FetchInt(7);
		float sync = results.FetchFloat(8);

		if(jumps > 0 || strafes > 0)
		{
			FormatEx(sDisplay, 128, (sync > 0.0)? "%T: %d (%.02f%%)":"%T: %d", "Strafes", client, strafes, sync, "Strafes", client, strafes);
			hMenu.AddItem("-1", sDisplay);
		}
	}

	char sFormattedTitle[256];
	FormatEx(sFormattedTitle, 256, "%s [U:1:%d]\n--- %s:", sName, iSteamID, sMap);

	hMenu.SetTitle(sFormattedTitle);
	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int SubMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowMaps(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}