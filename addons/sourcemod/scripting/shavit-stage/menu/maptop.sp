void OpenMaptopMenu(int client, const char[] map)
{
	strcopy(gS_MapChoice[client], 160, map);

	Menu menu = new Menu(MaptopMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem("", sDisplay);
	}

	menu.Display(client, -1);
}

public int MaptopMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		OpenStageMenu(param1, false);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int Maptop_StageMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;

		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];

		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), sql_get_maptop_info, stage, style, gS_MapChoice[param1]);
		gH_SQL.Query(SQL_Maptop_Callback, sQuery, GetClientSerial(param1));
	}

	else if(action == MenuAction_Cancel)
	{
		OpenMaptopMenu(param1, gS_MapChoice[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_Maptop_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];

	if(results == null)
	{
		LogError("Timer (GetWrcp) SQL query failed. Reason: %s", error);
		return;
	}

	Menu finalMenu = new Menu(Maptop_FinalMenu_Handler);

	char sTitle[128];
	if(gB_DeleteMaptop[client])
	{
		FormatEx(sTitle, 128, "%T", "DeleteMaptopMenuTitle-Maptop", client, gS_MapChoice[client], stage);
	}
	else
	{
		FormatEx(sTitle, 128, "%T", "WrcpMenuTitle-Maptop", client, gS_MapChoice[client], stage);
	}

	finalMenu.SetTitle(sTitle);

	int iCount = 0;

	while(results.FetchRow())
	{
		if(++iCount <= 100)
		{
			// 0 - steamid (mysql delete index)
			char sSteamid[32];
			IntToString(results.FetchInt(0), sSteamid, 32);

			// 1 - time
			float time = results.FetchFloat(1);
			char sTime[32];
			FormatHUDSeconds(time, sTime, 32);

			// compareTime
			float compareTime = time - gA_WRStageInfo[style][stage].fTime;
			char sCompareTime[32];
			FormatHUDSeconds(compareTime, sCompareTime, 32);

			// 2 - completions
			int completions = results.FetchInt(2);

			// 3 - name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(3, sName, MAX_NAME_LENGTH);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "#%d | %s (+%s) - %s (%d)", iCount, sTime, sCompareTime, sName, completions, client);
			finalMenu.AddItem(sSteamid, sDisplay, ITEMDRAW_DEFAULT);
		}
	}

	if(finalMenu.ItemCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "WrcpMenuItem-NoRecord", client);

		finalMenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
	}

	finalMenu.ExitBackButton = true;
	finalMenu.Display(client, -1);
}

public int Maptop_FinalMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sSteamid[32];
		menu.GetItem(param2, sSteamid, 32);
		int steamid = StringToInt(sSteamid);

		if(gB_DeleteMaptop[param1])
		{
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			DataPack dp = new DataPack();
			dp.WriteCell(GetClientSerial(param1));
			dp.WriteCell(param2 + 1);
			dp.WriteCell(steamid);

			DB_DeleteStageData(style, stage, steamid, gS_MapChoice[param1], SQL_DeleteMaptop_Callback, dp);
		}
		else
		{
			FormatEx(sSteamid, 32, "U:1:%d", steamid);
			FakeClientCommand(param1, "sm_p %s", sSteamid);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenStageMenu(param1, false);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteMaptop_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int rank = dp.ReadCell();
	int steamid = dp.ReadCell();

	delete dp;

	if(results == null)
	{
		LogError("Timer (single stage record delete) SQL query failed. Reason: %s", error);

		return;
	}

	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];

	if(StrEqual(gS_MapChoice[client], gS_Map))
	{
		ResetAllClientsCache();
		ResetWRStages();
	}

	if(rank == 1)
	{
		Call_OnWRCPDeleted(stage, style, steamid, gS_MapChoice[client]);
	}

	Shavit_PrintToChat(client, "%T", "StageRecordDeleteSuccessful", client, stage, gS_StyleStrings[style].sStyleName, steamid);

	OpenStageMenu(client, false);
}