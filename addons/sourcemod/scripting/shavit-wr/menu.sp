/*
	wr menus.
*/



/*
	Delete Single Record
*/

void OpenSingleDeleteMenu_Pre(int client)
{
	Menu menu = new Menu(MenuHandler_SingleDelete_Pre);
	menu.SetTitle("%T\n ", "DeleteTrackSingle", client);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		char sInfo[8];
		IntToString(i, sInfo, 8);

		int records = GetTrackRecordCount(i);

		char sTrack[64];
		GetTrackName(client, i, sTrack, 64);

		if(records > 0)
		{
			Format(sTrack, 64, "%s (%T: %d)", sTrack, "WRRecord", client, records);
		}

		menu.AddItem(sInfo, sTrack, (records > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int MenuHandler_SingleDelete_Pre(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);
		gA_WRCache[param1].iLastTrack = StringToInt(info);

		SingleDeleteSubmenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SingleDeleteSubmenu(int client)
{
	Menu menu = new Menu(MenuHandler_Delete);
	menu.SetTitle("%T\n ", "DeleteMenuTitle", client);

	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = styles[i];

		if(Shavit_GetStyleSettingInt(iStyle, "enabled") == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s (%T: %d)", gS_StyleStrings[iStyle].sStyleName, "WRRecord", client, GetRecordAmount(iStyle, gA_WRCache[client].iLastTrack));

		menu.AddItem(sInfo, sDisplay, (GetRecordAmount(iStyle, gA_WRCache[client].iLastTrack) > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int MenuHandler_Delete(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);
		gA_WRCache[param1].iLastStyle = StringToInt(info);

		OpenDeleteMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenDeleteMenu(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512, mysql_open_delete_menu, gS_Map, gA_WRCache[client].iLastStyle, gA_WRCache[client].iLastTrack);
	gH_SQL.Query(SQL_OpenDeleteMenu_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_OpenDeleteMenu_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OpenDeleteMenu) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	int iStyle = gA_WRCache[client].iLastStyle;

	Menu menu = new Menu(OpenDeleteSubMenu_Handler);
	menu.SetTitle("%t", "ListClientRecords", gS_Map, gS_StyleStrings[iStyle].sStyleName);

	int iCount = 0;

	while(results.FetchRow())
	{
		iCount++;

		// 0 - record id, for statistic purposes.
		int id = results.FetchInt(0);
		char sID[8];
		IntToString(id, sID, 8);

		// 1 - player name
		char sName[MAX_NAME_LENGTH];
		results.FetchString(1, sName, MAX_NAME_LENGTH);
		ReplaceString(sName, MAX_NAME_LENGTH, "#", "?");

		// 2 - time
		float time = results.FetchFloat(2);
		char sTime[16];
		FormatSeconds(time, sTime, 16);

		// 3 - jumps
		int jumps = results.FetchInt(3);

		char sDisplay[128];
		FormatEx(sDisplay, 128, "#%d - %s - %s (%d jump%s)", iCount, sName, sTime, jumps, (jumps != 1)? "s":"");
		menu.AddItem(sID, sDisplay);
	}

	if(iCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "WRMapNoRecords", client);
		menu.AddItem("-1", sNoRecords);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int OpenDeleteSubMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int id = StringToInt(sInfo);

		if(id != -1)
		{
			OpenDeleteSubMenu(param1, id);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenDeleteSubMenu(int client, int id)
{
	char sMenuItem[64];

	Menu menu = new Menu(DeleteConfirm_Handler);
	menu.SetTitle("%T\n ", "DeleteConfirm", client);

	for(int i = 1; i <= GetRandomInt(1, 4); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	FormatEx(sMenuItem, 64, "%T", "MenuResponseYesSingle", client);

	char sInfo[16];
	IntToString(id, sInfo, 16);
	menu.AddItem(sInfo, sMenuItem);

	for(int i = 1; i <= GetRandomInt(1, 3); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int DeleteConfirm_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int iRecordID = StringToInt(sInfo);

		if(iRecordID == -1)
		{
			Shavit_PrintToChat(param1, "%T", "DeletionAborted", param1);

			return 0;
		}

		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), mysql_get_records_details,
			gA_WRCache[param1].iLastStyle, gA_WRCache[param1].iLastTrack, iRecordID);
		gH_SQL.Query(GetRecordDetails_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void GetRecordDetails_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR GetRecordDetails) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow())
	{
		int iSteamID = results.FetchInt(0);

		char sName[MAX_NAME_LENGTH];
		results.FetchString(1, sName, MAX_NAME_LENGTH);

		char sMap[PLATFORM_MAX_PATH];
		results.FetchString(2, sMap, sizeof(sMap));

		float fTime = results.FetchFloat(3);
		float fSync = results.FetchFloat(4);
		float fPerfectJumps = results.FetchFloat(5);

		int iJumps = results.FetchInt(6);
		int iStrafes = results.FetchInt(7);
		int iRecordID = results.FetchInt(8);
		int iTimestamp = results.FetchInt(9);
		int iWRRecordID = results.FetchInt(10);

		int iStyle = gA_WRCache[client].iLastStyle;
		int iTrack = gA_WRCache[client].iLastTrack;

		// that's a big datapack ya yeet
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(client));
		hPack.WriteCell(iSteamID);
		hPack.WriteString(sName);
		hPack.WriteString(sMap);
		hPack.WriteCell(fTime);
		hPack.WriteCell(fSync);
		hPack.WriteCell(fPerfectJumps);
		hPack.WriteCell(iJumps);
		hPack.WriteCell(iStrafes);
		hPack.WriteCell(iRecordID);
		hPack.WriteCell(iTimestamp);
		hPack.WriteCell(iStyle);
		hPack.WriteCell(iTrack);

		bool bWRDeleted = iWRRecordID == iRecordID;
		hPack.WriteCell(bWRDeleted);

		char sQuery[256];
		FormatEx(sQuery, 256, mysql_delete_by_id, iRecordID);
		gH_SQL.Query(DeleteConfirm_Callback, sQuery, hPack, DBPrio_High);
	}
}

public void DeleteConfirm_Callback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	hPack.Reset();

	int iSerial = hPack.ReadCell();
	int iSteamID = hPack.ReadCell();

	char sName[MAX_NAME_LENGTH];
	hPack.ReadString(sName, MAX_NAME_LENGTH);

	char sMap[PLATFORM_MAX_PATH];
	hPack.ReadString(sMap, sizeof(sMap));

	float fTime = view_as<float>(hPack.ReadCell());
	float fSync = view_as<float>(hPack.ReadCell());
	float fPerfectJumps = view_as<float>(hPack.ReadCell());

	int iJumps = hPack.ReadCell();
	int iStrafes = hPack.ReadCell();
	int iRecordID = hPack.ReadCell();
	int iTimestamp = hPack.ReadCell();
	int iStyle = hPack.ReadCell();
	int iTrack = hPack.ReadCell();

	bool bWRDeleted = view_as<bool>(hPack.ReadCell());
	delete hPack;

	if(results == null)
	{
		LogError("Timer (WR DeleteConfirm) SQL query failed. Reason: %s", error);

		return;
	}

	if(bWRDeleted)
	{
		DB_DeleteWR(iStyle, iTrack, sMap, iSteamID, iRecordID, false, true);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetSteamAccountID(i) == iSteamID)
			{
				UpdateClientCache(i);
				break;
			}
		}
	}

	int client = GetClientFromSerial(iSerial);

	char sTrack[32];
	GetTrackName(client, iTrack, sTrack, 32);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", iTimestamp);

	// above the client == 0 so log doesn't get lost if admin disconnects between deleting record and query execution
	Shavit_LogMessage("%L - deleted record. Runner: %s ([U:1:%d]) | Map: %s | Style: %s | Track: %s | Time: %.2f (%s) | Strafes: %d (%.1f%%) | Jumps: %d (%.1f%%) | Run date: %s | Record ID: %d",
		client, sName, iSteamID, sMap, gS_StyleStrings[iStyle].sStyleName, sTrack, fTime, (bWRDeleted)? "WR":"not WR", iStrafes, fSync, iJumps, fPerfectJumps, sDate, iRecordID);

	if(client == 0)
	{
		return;
	}

	Shavit_PrintToChat(client, "%T", "DeletedRecord", client);
}



/*
	Delete All Records
*/

void OpenAllDeleteMenu_Pre(int client)
{
	Menu menu = new Menu(MenuHandler_DeleteAll_Pre);
	menu.SetTitle("%T\n ", "DeleteTrackAll", client);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		char sInfo[8];
		IntToString(i, sInfo, 8);

		int iRecords = GetTrackRecordCount(i);

		char sTrack[64];
		GetTrackName(client, i, sTrack, 64);

		if(iRecords > 0)
		{
			Format(sTrack, 64, "%s (%T: %d)", sTrack, "WRRecord", client, iRecords);
		}

		menu.AddItem(sInfo, sTrack, (iRecords > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int MenuHandler_DeleteAll_Pre(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		int iTrack = gA_WRCache[param1].iLastTrack = StringToInt(sInfo);

		char sTrack[64];
		GetTrackName(param1, iTrack, sTrack, 64);

		Menu subMenu = new Menu(MenuHandler_DeleteAll_Post);
		subMenu.SetTitle("%T\n ", "DeleteTrackAllStyle", param1, sTrack);

		int[] styles = new int[gI_Styles];
		Shavit_GetOrderedStyles(styles, gI_Styles);

		for(int i = 0; i < gI_Styles; i++)
		{
			int iStyle = styles[i];

			if(Shavit_GetStyleSettingInt(iStyle, "enabled") == -1)
			{
				continue;
			}

			char sStyle[64];
			strcopy(sStyle, 64, gS_StyleStrings[iStyle].sStyleName);

			IntToString(iStyle, sInfo, 8);

			int iRecords = GetRecordAmount(iStyle, iTrack);

			if(iRecords > 0)
			{
				Format(sStyle, 64, "%s (%T: %d)", sStyle, "WRRecord", param1, iRecords);
			}

			subMenu.AddItem(sInfo, sStyle, (iRecords > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}

		subMenu.ExitButton = true;
		subMenu.Display(param1, 300);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_DeleteAll_Post(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		gA_WRCache[param1].iLastStyle = StringToInt(sInfo);

		DeleteAllSubmenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void DeleteAllSubmenu(int client)
{
	char sTrack[32];
	GetTrackName(client, gA_WRCache[client].iLastTrack, sTrack, 32);

	Menu menu = new Menu(MenuHandler_DeleteAll);
	menu.SetTitle("%T\n ", "DeleteAllRecordsMenuTitle", client, gS_Map, sTrack, gS_StyleStrings[gA_WRCache[client].iLastStyle].sStyleName);

	char sMenuItem[64];

	for(int i = 1; i <= GetRandomInt(1, 4); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	FormatEx(sMenuItem, 64, "%T", "MenuResponseYes", client);
	menu.AddItem("yes", sMenuItem);

	for(int i = 1; i <= GetRandomInt(1, 3); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int MenuHandler_DeleteAll(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);

		if(StringToInt(info) == -1)
		{
			Shavit_PrintToChat(param1, "%T", "DeletionAborted", param1);

			return 0;
		}

		char sTrack[32];
		GetTrackName(LANG_SERVER, gA_WRCache[param1].iLastTrack, sTrack, 32);

		Shavit_LogMessage("%L - deleted all %s track and %s style records from map `%s`.",
			param1, sTrack, gS_StyleStrings[gA_WRCache[param1].iLastStyle].sStyleName, gS_Map);

		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), mysql_delete_all, gS_Map, gA_WRCache[param1].iLastStyle, gA_WRCache[param1].iLastTrack);

		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(param1));
		hPack.WriteCell(gA_WRCache[param1].iLastStyle);
		hPack.WriteCell(gA_WRCache[param1].iLastTrack);

		gH_SQL.Query(DeleteAll_Callback, sQuery, hPack, DBPrio_High);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void DeleteAll_Callback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	hPack.Reset();
	int client = GetClientFromSerial(hPack.ReadCell());
	int style = hPack.ReadCell();
	int track = hPack.ReadCell();
	delete hPack;

	if(results == null)
	{
		LogError("Timer (WR DeleteAll) SQL query failed. Reason: %s", error);

		return;
	}

	DB_DeleteWR(style, track, gS_Map, 0, -1, false, true);

	Shavit_PrintToChat(client, "%T", "DeletedRecordsMap", client, gS_Map);
}



/*
	Query WR
*/

void RetrieveWRMenu(int client, int track)
{
	if (gA_WRCache[client].bPendingMenu)
	{
		return;
	}

	if (StrEqual(gA_WRCache[client].sClientMap, gS_Map))
	{
		for (int i = 0; i < gI_Styles; i++)
		{
			gA_WRCache[client].fWRs[i] = gF_WRTime[i][track];
		}

		if (gA_WRCache[client].bForceStyle)
		{
			StartWRMenu(client);
		}
		else
		{
			ShowWRStyleMenu(client);
		}
	}
	else
	{
		gA_WRCache[client].bPendingMenu = true;

		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), mysql_retrieve_wr_menu, gA_WRCache[client].sClientMap, track, gI_Styles);
		gH_SQL.Query(SQL_RetrieveWRMenu_Callback, sQuery, GetClientSerial(client));
	}
}

public void SQL_RetrieveWRMenu_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR RetrieveWRMenu) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	gA_WRCache[client].bPendingMenu = false;

	for (int i = 0; i < gI_Styles; i++)
	{
		gA_WRCache[client].fWRs[i] = 0.0;
	}

	while (results.FetchRow())
	{
		int style  = results.FetchInt(0);
		float time = results.FetchFloat(1);
		gA_WRCache[client].fWRs[style] = time;
	}

	if (gA_WRCache[client].bForceStyle)
	{
		StartWRMenu(client);
	}
	else
	{
		ShowWRStyleMenu(client);
	}
}

void ShowWRStyleMenu(int client, int first_item=0)
{
	Menu menu = new Menu(MenuHandler_StyleChooser);
	menu.SetTitle("%T", "WRMenuTitle", client);

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

		char sDisplay[64];

		if (gA_WRCache[client].fWRs[iStyle] > 0.0)
		{
			char sTime[32];
			FormatSeconds(gA_WRCache[client].fWRs[iStyle], sTime, 32, false);

			FormatEx(sDisplay, 64, "%s - WR: %s", gS_StyleStrings[iStyle].sStyleName, sTime);
		}
		else
		{
			strcopy(sDisplay, 64, gS_StyleStrings[iStyle].sStyleName);
		}

		menu.AddItem(sInfo, sDisplay, (gA_WRCache[client].fWRs[iStyle] > 0.0) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}

	// should NEVER happen
	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "WRStyleNothing", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, first_item, MENU_TIME_FOREVER);
}

public int MenuHandler_StyleChooser(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(!IsValidClient(param1))
		{
			return 0;
		}

		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		int iStyle = StringToInt(sInfo);

		if(iStyle == -1)
		{
			Shavit_PrintToChat(param1, "%T", "NoStyles", param1);

			return 0;
		}

		gA_WRCache[param1].iLastStyle = iStyle;
		gA_WRCache[param1].iPagePosition = GetMenuSelectionPosition();

		StartWRMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void StartWRMenu(int client)
{
	gA_WRCache[client].bForceStyle = false;

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(gA_WRCache[client].iLastTrack);
	dp.WriteString(gA_WRCache[client].sClientMap);

	int iLength = ((strlen(gA_WRCache[client].sClientMap) * 2) + 1);
	char[] sEscapedMap = new char[iLength];
	gH_SQL.Escape(gA_WRCache[client].sClientMap, sEscapedMap, iLength);

	char sQuery[512];
	FormatEx(sQuery, 512, mysql_select_wr, sEscapedMap, gA_WRCache[client].iLastStyle, gA_WRCache[client].iLastTrack);
	gH_SQL.Query(SQL_WR_Callback, sQuery, dp);
}

public void SQL_WR_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int serial = data.ReadCell();
	int track = data.ReadCell();

	char sMap[PLATFORM_MAX_PATH];
	data.ReadString(sMap, sizeof(sMap));

	delete data;

	if(results == null)
	{
		LogError("Timer (WR SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(serial);

	if(client == 0)
	{
		return;
	}

	int iSteamID = GetSteamAccountID(client);

	Menu hMenu = new Menu(WRMenu_Handler);

	int iCount = 0;
	int iMyRank = 0;

	while(results.FetchRow())
	{
		if(++iCount <= gCV_RecordsLimit.IntValue)
		{
			// 0 - record id, for statistic purposes.
			int id = results.FetchInt(0);
			char sID[8];
			IntToString(id, sID, 8);

			// 1 - player name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(1, sName, MAX_NAME_LENGTH);

			// 2 - time
			float time = results.FetchFloat(2);
			char sTime[16];
			FormatSeconds(time, sTime, 16);

			// 3 - jumps
			int jumps = results.FetchInt(3);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "#%d - %s - %s (%d %T)", iCount, sName, sTime, jumps, "WRJumps", client);
			hMenu.AddItem(sID, sDisplay);
		}

		// check if record exists in the map's top X
		int iQuerySteamID = results.FetchInt(4);

		if(iQuerySteamID == iSteamID)
		{
			iMyRank = iCount;
		}
	}

	char sFormattedTitle[256];

	if(hMenu.ItemCount == 0)
	{
		hMenu.SetTitle("%T", "WRMap", client, sMap);
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "WRMapNoRecords", client);

		hMenu.AddItem("-1", sNoRecords);
	}

	else
	{
		int iStyle = gA_WRCache[client].iLastStyle;
		int iRecords = results.RowCount;

		// [32] just in case there are 150k records on a map and you're ranked 100k or something
		char sRanks[32];

		if(gF_PlayerRecord[client][iStyle][track] == 0.0 || iMyRank == 0)
		{
			FormatEx(sRanks, 32, "(%d %T)", iRecords, "WRRecord", client);
		}

		else
		{
			FormatEx(sRanks, 32, "(#%d/%d)", iMyRank, iRecords);
		}

		char sTrack[32];
		GetTrackName(client, track, sTrack, 32);

		FormatEx(sFormattedTitle, 192, "%T %s: [%s]\n%s", "WRRecordFor", client, sMap, sTrack, sRanks);
		hMenu.SetTitle(sFormattedTitle);
	}

	hMenu.ExitBackButton = true;
	hMenu.Display(client, 300);
}

public int WRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);
		int id = StringToInt(sInfo);

		if(id != -1)
		{
			OpenSubMenu(param1, id);
		}

		else
		{
			ShowWRStyleMenu(param1);
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRStyleMenu(param1, gA_WRCache[param1].iPagePosition);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenSubMenu(int client, int id)
{
	char sQuery[512];
	FormatEx(sQuery, 512, mysql_select_wr_submenu, id);

	DataPack datapack = new DataPack();
	datapack.WriteCell(GetClientSerial(client));
	datapack.WriteCell(id);

	gH_SQL.Query(SQL_SubMenu_Callback, sQuery, datapack, DBPrio_High);
}

public void SQL_SubMenu_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int client = GetClientFromSerial(data.ReadCell());
	int id = data.ReadCell();
	delete data;

	if(results == null)
	{
		LogError("Timer (WR SUBMENU) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	Menu hMenu = new Menu(SubMenu_Handler);

	char sFormattedTitle[256];
	char sName[MAX_NAME_LENGTH];
	int iSteamID = 0;
	char sTrack[32];
	char sMap[PLATFORM_MAX_PATH];

	if(results.FetchRow())
	{
		results.FetchString(0, sName, MAX_NAME_LENGTH);

		float fTime = results.FetchFloat(1);
		char sTime[16];
		FormatSeconds(fTime, sTime, 16);

		char sDisplay[128];
		FormatEx(sDisplay, 128, "%T: %s", "WRTime", client, sTime);
		hMenu.AddItem("-1", sDisplay);

		int iStyle = results.FetchInt(3);
		int iJumps = results.FetchInt(2);

		FormatEx(sDisplay, 128, "%T: %d", "WRJumps", client, iJumps);

		hMenu.AddItem("-1", sDisplay);

		FormatEx(sDisplay, 128, "%T: %d", "WRCompletions", client, results.FetchInt(11));
		hMenu.AddItem("-1", sDisplay);

		FormatEx(sDisplay, 128, "%T: %s", "WRStyle", client, gS_StyleStrings[iStyle].sStyleName);
		hMenu.AddItem("-1", sDisplay);

		results.FetchString(6, sMap, sizeof(sMap));

		float fPoints = results.FetchFloat(9);

		if(gB_Rankings && fPoints > 0.0)
		{
			FormatEx(sDisplay, 128, "%T: %.03f", "WRPointsCap", client, fPoints);
			hMenu.AddItem("-1", sDisplay);
		}

		iSteamID = results.FetchInt(4);

		char sDate[32];
		results.FetchString(5, sDate, 32);

		if(sDate[4] != '-')
		{
			FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sDate));
		}

		FormatEx(sDisplay, 128, "%T: %s", "WRDate", client, sDate);
		hMenu.AddItem("-1", sDisplay);

		int strafes = results.FetchInt(7);
		float sync = results.FetchFloat(8);

		if(iJumps > 0 || strafes > 0)
		{
			FormatEx(sDisplay, 128, (sync != -1.0)? "%T: %d (%.02f%%)":"%T: %d", "WRStrafes", client, strafes, sync);
			hMenu.AddItem("-1", sDisplay);
		}

		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "WRPlayerStats", client);

		char sInfo[32];
		FormatEx(sInfo, 32, "0;%d", iSteamID);

		if(gB_Stats)
		{
			hMenu.AddItem(sInfo, sMenuItem);
		}

		if(CheckCommandAccess(client, "sm_delete", ADMFLAG_RCON))
		{
			FormatEx(sMenuItem, 64, "%T", "WRDeleteRecord", client);
			FormatEx(sInfo, 32, "1;%d", id);
			hMenu.AddItem(sInfo, sMenuItem);
		}

		GetTrackName(client, results.FetchInt(10), sTrack, 32);
	}

	else
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "DatabaseError", client);
		hMenu.AddItem("-1", sMenuItem);
	}

	if(strlen(sName) > 0)
	{
		FormatEx(sFormattedTitle, 256, "%s [U:1:%d]\n--- %s: [%s]", sName, iSteamID, sMap, sTrack);
	}

	else
	{
		FormatEx(sFormattedTitle, 256, "%T", "Error", client);
	}

	hMenu.SetTitle(sFormattedTitle);
	hMenu.ExitBackButton = true;
	hMenu.Display(client, 300);
}

public int SubMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, 32);

		if(gB_Stats && StringToInt(sInfo) != -1)
		{
			char sExploded[2][32];
			ExplodeString(sInfo, ";", sExploded, 2, 32, true);

			int first = StringToInt(sExploded[0]);

			switch(first)
			{
				case 0:
				{
					Shavit_OpenStatsMenu(param1, StringToInt(sExploded[1]));
				}

				case 1:
				{
					OpenDeleteSubMenu(param1, StringToInt(sExploded[1]));
				}
			}
		}

		else
		{
			StartWRMenu(param1);
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		StartWRMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenBonusWRMenu(int client)
{
	Menu menu = new Menu(BonusWRMenu_Handler);
	menu.SetTitle("选择一个奖励关");

	for(int i = 1; i <= Track_Bonus_Last; i++)
	{
		char sTrack[32];
		GetTrackName(client, i, sTrack, 32);

		char sItem[8];
		IntToString(i, sItem, 8);
		menu.AddItem(sItem, sTrack);
	}

	menu.Display(client, -1);
}

public int BonusWRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		int track = StringToInt(sInfo);
		gA_WRCache[param1].iLastTrack = track;
		RetrieveWRMenu(param1, track);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}



/*
	Recent Records
*/

void OpenRRMenu(int client)
{
	gH_SQL.Query(SQL_RR_Callback, mysql_recent_records_menu, GetClientSerial(client), DBPrio_Low);
}

public void SQL_RR_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	gA_WRCache[client].bPendingMenu = false;

	if(results == null)
	{
		LogError("Timer (RR SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	Menu menu = new Menu(RRMenu_Handler);
	menu.SetTitle("%T:", "RecentRecords", client, gCV_RecentLimit.IntValue);

	while(results.FetchRow())
	{
		char sMap[PLATFORM_MAX_PATH];
		results.FetchString(1, sMap, sizeof(sMap));

		char sName[MAX_NAME_LENGTH];
		results.FetchString(2, sName, sizeof(sName));
		TrimDisplayString(sName, sName, sizeof(sName), 9);

		char sTime[16];
		float fTime = results.FetchFloat(3);
		FormatSeconds(fTime, sTime, 16);

		int iStyle = results.FetchInt(4);
		if(iStyle >= gI_Styles || iStyle < 0 || Shavit_GetStyleSettingInt(iStyle, "unranked"))
		{
			continue;
		}

		char sTrack[32];
		GetTrackName(client, results.FetchInt(5), sTrack, 32);

		char sDisplay[192];
		FormatEx(sDisplay, 192, "[%s/%s] %s - %s @ %s", gS_StyleStrings[iStyle].sShortName, sTrack, sMap, sName, sTime);

		char sInfo[192];
		FormatEx(sInfo, 192, "%d;%s", results.FetchInt(0), sMap);

		menu.AddItem(sInfo, sDisplay);
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "WRMapNoRecords", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, 300);
}

public int RRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, 128);

		if(StringToInt(sInfo) != -1)
		{
			char sExploded[2][128];
			ExplodeString(sInfo, ";", sExploded, 2, 128, true);

			strcopy(gA_WRCache[param1].sClientMap, 128, sExploded[1]);

			OpenSubMenu(param1, StringToInt(sExploded[0]));
		}

		else
		{
			RetrieveWRMenu(param1, gA_WRCache[param1].iLastTrack);
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		RetrieveWRMenu(param1, gA_WRCache[param1].iLastTrack);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}



/*
	Maptop
*/

void OpenMaptopMenu(int client)
{
	Menu menu = new Menu(MaptopMenu_Handler);

	menu.AddItem("Main", "主线记录");
	menu.AddItem("Bonus", "奖励关记录");
	menu.AddItem("Stage", "关卡记录");

	menu.Display(client, -1);
}

public int MaptopMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		if(StrEqual(sInfo, "Main"))
		{
			FakeClientCommand(param1, "sm_wr %s", gA_WRCache[param1].sClientMap);
		}

		else if(StrEqual(sInfo, "Bonus"))
		{
			FakeClientCommand(param1, "sm_bwr %s", gA_WRCache[param1].sClientMap);
		}

		else if(StrEqual(sInfo, "Stage"))
		{
			FakeClientCommand(param1, "sm_maptop %s", gA_WRCache[param1].sClientMap);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}



// ======[ PRIVATE ]======

static int GetTrackRecordCount(int track)
{
	int count = 0;

	for(int i = 0; i < gI_Styles; i++)
	{
		count += GetRecordAmount(i, track);
	}

	return count;
}