void OpenWRCPMenu(int client)
{
	strcopy(gS_MapChoice[client], 160, gS_Map);

	Menu menu = new Menu(WRCPMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem("", sDisplay);
	}

	menu.Display(client, -1);
}

public int WRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		OpenStageMenu(param1, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenStageMenu(int client, bool wrcp)
{
	char sQuery[128];
	FormatEx(sQuery, 128, "SELECT data FROM `mapzones` WHERE map = '%s' AND type = %d AND track = %d ORDER BY data DESC;", gS_MapChoice[client], Zone_Stage, Track_Main);

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(wrcp?1:0);

	gH_SQL.Query(SQL_OpenStageMenu_Callback, sQuery, dp);
}

public void SQL_OpenStageMenu_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	bool wrcp = (dp.ReadCell() == 1);

	delete dp;

	if(results == null)
	{
		LogError("Timer (GetStageMenu) SQL query failed. Reason: %s", error);
		return;
	}

	Menu submenu = new Menu(wrcp?WRCP_StageMenu_Handler:Maptop_StageMenu_Handler);
	submenu.SetTitle("%T", "WrcpMenuTitle-Stage", client);

	int stages = Shavit_GetMapStages();

	if(results.FetchRow())
	{
		stages = results.FetchInt(0);
	}

	for(int i = 1; i <= stages; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", client, i);

		submenu.AddItem("", sDisplay);
	}

	submenu.ExitBackButton = true;
	submenu.Display(client, -1);
}

public int WRCP_StageMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;

		int style = gI_StyleChoice[param1];
		int stage = gI_StageChoice[param1];
		float time = gA_WRStageInfo[style][stage].fTime;
		char sName[MAX_NAME_LENGTH];
		strcopy(sName, MAX_NAME_LENGTH, gA_WRStageInfo[style][stage].sName);

		if(gB_DeleteWRCP[param1])
		{
			DeleteWRCPConfirm(param1);
		}

		else
		{
			char sMessage[255];
			if(time > 0.0)
			{
				char sTime[32];
				FormatHUDSeconds(time, sTime, 32);
				FormatEx(sMessage, 255, "%T", "Chat-WRCP", param1, sName, stage, gS_StyleStrings[style].sStyleName, sTime);
			}
			else
			{
				FormatEx(sMessage, 255, "%T", "Chat-WRCP-NoRecord", param1, stage, gS_StyleStrings[style].sStyleName);
			}

			Shavit_PrintToChat(param1, "%s", sMessage);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenWRCPMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void DeleteWRCPConfirm(int client)
{
	Menu menu = new Menu(DeleteWRCPMenu_Handler);

	char sTitle[64];
	FormatEx(sTitle, 64, "%T", "DeleteWrcpMenuTitle-Confirm", client, gI_StageChoice[client], gS_StyleStrings[gI_StyleChoice[client]].sStyleName);
	menu.SetTitle(sTitle);

	menu.AddItem("", "Yes");
	menu.AddItem("", "No");

	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int DeleteWRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			DB_DeleteStageData(style, stage, gA_WRStageInfo[style][stage].iSteamid, gS_Map, SQL_DeleteWRStage_Callback, GetClientSerial(param1));
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenStageMenu(param1, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteWRStage_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];
	int steamid = gA_WRStageInfo[style][stage].iSteamid;

	if(results == null)
	{
		SetFailState("SQL_DeleteWRStage_Callback failed! Error: %s", error);
		return;
	}

	Call_OnWRCPDeleted(stage, style, steamid, gS_Map);

	ResetAllClientsCache();
	ResetWRStages();

	Shavit_PrintToChat(client, "%T", "WRCPDeleteSuccessful", client, stage, gS_StyleStrings[style].sStyleName, steamid);

	OpenStageMenu(client, true);
}