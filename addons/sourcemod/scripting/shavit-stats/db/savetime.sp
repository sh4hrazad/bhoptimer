// ======[ EVENTS ]======

void OnClientDisconnect_SavePlayTime(int client)
{
	if (gH_SQL == null || IsFakeClient(client) || !IsClientAuthorized(client) || !gCV_SavePlaytime.BoolValue)
	{
		return;
	}

	Transaction2 trans = null;
	SavePlaytime(client, GetEngineTime(), trans);

	if (trans != null)
	{
		gH_SQL.Execute(trans, Trans_SavePlaytime_Success, Trans_SavePlaytime_Failure);
	}
}

public Action Timer_SavePlaytime(Handle timer, any data)
{
	if (gH_SQL == null || !gCV_SavePlaytime.BoolValue)
	{
		return Plugin_Continue;
	}

	Transaction2 trans = null;
	float now = GetEngineTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsClientAuthorized(i))
		{
			continue;
		}

		if (gB_QueriedPlaytime[i])
		{
			SavePlaytime(i, now, trans);
		}
		else if ((now - gF_PlaytimeStart[i]) > 15.0)
		{
			QueryPlaytime(i);
		}
	}

	if (trans != null)
	{
		gH_SQL.Execute(trans, Trans_SavePlaytime_Success, Trans_SavePlaytime_Failure);
	}

	return Plugin_Continue;
}

void SavePlaytime(int client, float now, Transaction2 &trans)
{
	if (GetSteamAccountID(client) == 0)
	{
		// how HOW HOW
		return;
	}

	if (!gB_QueriedPlaytime[client])
	{
		return;
	}

	for (int i = -1 /* yes */; i < gI_Styles; i++)
	{
		SavePlaytime222(client, now, trans, i, GetSteamAccountID(client));
	}
}

void SavePlaytime222(int client, float now, Transaction2 &trans, int style, int iSteamID)
{
	char sQuery[512];

	if (style == -1) // regular playtime
	{
		if (gF_PlaytimeStart[client] <= 0.0)
		{
			return;
		}

		float diff = now - gF_PlaytimeStart[client];
		gF_PlaytimeStart[client] = now;

		if (diff <= 0.0)
		{
			return;
		}

		FormatEx(sQuery, sizeof(sQuery), mysql_update_regular_playtime, diff, iSteamID);
	}
	else
	{
		float diff = gF_PlaytimeStyleSum[client][style];

		if (gI_CurrentStyle[client] == style)
		{
			diff += now - gF_PlaytimeStyleStart[client];
			gF_PlaytimeStyleStart[client] = now;
		}

		gF_PlaytimeStyleSum[client][style] = 0.0;

		if (diff <= 0.0)
		{
			return;
		}

		if (gB_HavePlaytimeOnStyle[client][style])
		{
			FormatEx(sQuery, sizeof(sQuery), mysql_update_style_playtime, diff, iSteamID, style);
		}
		else
		{
			gB_HavePlaytimeOnStyle[client][style] = true;
			FormatEx(sQuery, sizeof(sQuery), mysql_insert_style_playtime, iSteamID, style, diff);
		}
	}

	if (trans == null)
	{
		trans = view_as<Transaction2>(new Transaction());
	}

	trans.AddQuery(sQuery);
}

public void Trans_SavePlaytime_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
}

public void Trans_SavePlaytime_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (stats save playtime) SQL query %d/%d failed. Reason: %s", failIndex, numQueries, error);
}