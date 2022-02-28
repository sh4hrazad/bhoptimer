void DB_SaveChatSettings(int client)
{
	if(!gB_ChangedSinceLogin[client])
	{
		return;
	}

	int iSteamID = GetSteamAccountID(client);

	if(iSteamID == 0)
	{
		return;
	}

	int iLength = ((strlen(gS_CustomName[client]) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	gH_SQL.Escape(gS_CustomName[client], sEscapedName, iLength);

	iLength = ((strlen(gS_CustomMessage[client]) * 2) + 1);
	char[] sEscapedMessage = new char[iLength];
	gH_SQL.Escape(gS_CustomMessage[client], sEscapedMessage, iLength);

	char sQuery[512];
	FormatEx(sQuery, 512, mysql_update_chat_settings, iSteamID, gB_NameEnabled[client], sEscapedName, gB_MessageEnabled[client], sEscapedMessage);

	gH_SQL.Query(SQL_UpdateUser_Callback, sQuery, 0, DBPrio_Low);
}

void DB_LoadChatSettings(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	int iSteamID = GetSteamAccountID(client);

	if(iSteamID == 0)
	{
		return;
	}

	char sQuery[256];
	FormatEx(sQuery, 256, mysql_load_chat_settings, iSteamID);

	gH_SQL.Query(SQL_GetChat_Callback, sQuery, GetClientSerial(client), DBPrio_Low);
}

public void SQL_GetChat_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (Chat cache update) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	gB_ChangedSinceLogin[client] = false;

	while(results.FetchRow())
	{
		gB_CCAccess[client] = view_as<bool>(results.FetchInt(4));

		if (!HasCustomChat(client))
		{
			return;
		}

		gB_NameEnabled[client] = view_as<bool>(results.FetchInt(0));
		results.FetchString(1, gS_CustomName[client], 128);

		gB_MessageEnabled[client] = view_as<bool>(results.FetchInt(2));
		results.FetchString(3, gS_CustomMessage[client], 16);
	}
}

void DB_AddCCAccess(int steamid)
{
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), mysql_add_cc_access, steamid);
	gH_SQL.Query(SQL_UpdateUser_Callback, sQuery, 0, DBPrio_Low);
}

void DB_DeleteCCAccess(int steamid)
{
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), mysql_delete_cc_access, steamid);
	gH_SQL.Query(SQL_UpdateUser_Callback, sQuery, 0, DBPrio_Low);
}

public void SQL_UpdateUser_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Failed to insert chat data. Reason: %s", error);

		return;
	}
}