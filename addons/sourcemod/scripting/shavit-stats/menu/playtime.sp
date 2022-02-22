public Action Command_Playtime(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery),
		"(SELECT auth, name, playtime, -1 as ownrank FROM %susers WHERE playtime > 0 ORDER BY playtime DESC LIMIT 100) " ...
		"UNION " ...
		"(SELECT -1, '', u2.playtime, COUNT(*) as ownrank FROM %susers u1 JOIN (SELECT playtime FROM %susers WHERE auth = %d) u2 WHERE u1.playtime >= u2.playtime);",
		gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, GetSteamAccountID(client));
	gH_SQL.Query(SQL_TopPlaytime_Callback, sQuery, GetClientSerial(client), DBPrio_Normal);

	return Plugin_Handled;
}

public void SQL_TopPlaytime_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || !results.RowCount)
	{
		LogError("Timer (!playtime) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if (client < 1)
	{
		return;
	}

	Menu menu = new Menu(PlaytimeMenu_Handler);

	char sOwnPlaytime[16];
	int own_rank = 0;
	int rank = 1;

	while (results.FetchRow())
	{
		char sSteamID[20];
		results.FetchString(0, sSteamID, sizeof(sSteamID));

		char sName[PLATFORM_MAX_PATH];
		results.FetchString(1, sName, sizeof(sName));

		float fPlaytime = results.FetchFloat(2);
		char sPlaytime[16];
		FormatSeconds(fPlaytime, sPlaytime, sizeof(sPlaytime), false, true, true);

		int iOwnRank = results.FetchInt(3);

		if (iOwnRank != -1)
		{
			own_rank = iOwnRank;
			sOwnPlaytime = sPlaytime;
		}
		else
		{
			char sDisplay[128];
			FormatEx(sDisplay, sizeof(sDisplay), "#%d - %s - %s", rank++, sPlaytime, sName);
			menu.AddItem(sSteamID, sDisplay, ITEMDRAW_DEFAULT);
		}
	}

	menu.SetTitle("%T\n%T (#%d): %s", "Playtime", client, "YourPlaytime", client, own_rank, sOwnPlaytime);

	if (menu.ItemCount <= 8)
	{
		menu.Pagination = MENU_NO_PAGINATION;
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PlaytimeMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[20];
		menu.GetItem(param2, info, sizeof(info));
		FakeClientCommand(param1, "sm_profile [U:1:%s]", info);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}