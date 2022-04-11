void RegisterCommands()
{
	// wrcp
	RegConsoleCmd("sm_wrcp", Command_WRCP, "Show WRCP menu, select a style and a stage");
	RegConsoleCmd("sm_wrcps", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcp", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcps", Command_WRCP, "Alias of sm_wrcp");

	// maptop
	RegConsoleCmd("sm_mtop", Command_Maptop, "Show stage tops menu, select a style and a stage");
	RegConsoleCmd("sm_maptop", Command_Maptop, "Alias of sm_mtop");

	// cpr(compare personal records)
	RegConsoleCmd("sm_cpr", Command_CPR, "Show personal map/stages/checkpoints records comparations");

	// ccp(compare checkpoint informations)
	RegConsoleCmd("sm_ccp", Command_CCP, "Show checkpoints information comparations");

	// delete
	RegAdminCmd("sm_delwrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Delete a WRCP. Actually it's alias of sm_wrcp");
	RegAdminCmd("sm_delwrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_delsrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_delsrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletewrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletewrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletesrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletesrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");

	RegAdminCmd("sm_delmtop", Command_DeleteMaptop, ADMFLAG_RCON, "Delete a stage record. Actually it's alias of sm_delwrcp");
	RegAdminCmd("sm_delmaptop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	RegAdminCmd("sm_deletemtop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	RegAdminCmd("sm_deletemaptop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
}

public Action Command_WRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = false;

	OpenWRCPMenu(client);

	return Plugin_Handled;
}

public Action Command_DeleteWRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = true;

	OpenWRCPMenu(client);

	return Plugin_Handled;
}

public Action Command_Maptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteMaptop[client] = false;

	if(args == 0)
	{
		if(Shavit_IsLinearMap())
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenMaptopMenu(client, gS_Map);
	}

	else
	{
		char sMap[128];
		GetCmdArg(1, sMap, 128);
		OpenMaptopMenu(client, sMap);
	}

	return Plugin_Handled;
}

public Action Command_DeleteMaptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteMaptop[client] = true;

	if(args == 0)
	{
		if(Shavit_IsLinearMap())
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenMaptopMenu(client, gS_Map);
	}
	else
	{
		char sMap[128];
		GetCmdArg(1, sMap, 128);
		OpenMaptopMenu(client, sMap);
	}

	return Plugin_Handled;
}

public Action Command_CPR(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(args == 0)
	{
		OpenCPRMenu(client, 1);
	}

	else
	{
		char sArg[16];
		GetCmdArg(1, sArg, 16);

		Regex sRegex = new Regex("[0-9]{1,}");
		bool bMatch = (sRegex.Match(sArg) > 0);

		if(!bMatch)
		{
			Shavit_PrintToChat(client, "Invalid expression or missing numbers");
		}

		else
		{
			char sRank[16];
			sRegex.GetSubString(0, sRank, 16);
			OpenCPRMenu(client, StringToInt(sRank));
		}

		delete sRegex;
	}

	return Plugin_Handled;
}

public Action Command_CCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Shavit_PrintToChat(client, "this feature haven't done yet");

	return Plugin_Handled;
}