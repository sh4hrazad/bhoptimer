void RegisterCommands()
{
	RegConsoleCmd("sm_cchelp", Command_CCHelp, "Provides help with setting a custom chat name/message color.");
	RegConsoleCmd("sm_ccname", Command_CCName, "Toggles/sets a custom chat name. Usage: sm_ccname <text> or sm_ccname \"off\" to disable.");
	RegConsoleCmd("sm_ccmsg", Command_CCMessage, "Toggles/sets a custom chat message color. Usage: sm_ccmsg <color> or sm_ccmsg \"off\" to disable.");
	RegConsoleCmd("sm_ccmessage", Command_CCMessage, "Toggles/sets a custom chat message color. Usage: sm_ccmessage <color> or sm_ccmessage \"off\" to disable.");
	RegConsoleCmd("sm_chatrank", Command_ChatRanks, "View a menu with the chat ranks available to you.");
	RegConsoleCmd("sm_chatranks", Command_ChatRanks, "View a menu with the chat ranks available to you.");
	RegConsoleCmd("sm_ranks", Command_Ranks, "View a menu with all the obtainable chat ranks.");

	RegAdminCmd("sm_cclist", Command_CCList, ADMFLAG_CHAT, "Print the custom chat setting of all online players.");
	RegAdminCmd("sm_reloadchatranks", Command_ReloadChatRanks, ADMFLAG_ROOT, "Reloads the chatranks config file.");
	RegAdminCmd("sm_ccadd", Command_CCAdd, ADMFLAG_ROOT, "Grant a user access to using ccname and ccmsg. Usage: sm_ccadd <steamid3>");
	RegAdminCmd("sm_ccdelete", Command_CCDelete, ADMFLAG_ROOT, "Remove access granted to a user with sm_ccadd. Usage: sm_ccdelete <steamid3>");
}

public Action Command_CCHelp(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "%t", "NoConsole");

		return Plugin_Handled;
	}

	Shavit_PrintToChat(client, "%T", "CheckConsole", client);

	PrintToConsole(client, "%T\n\n%T\n\n%T\n",
		"CCHelp_Intro", client,
		"CCHelp_Generic", client,
		"CCHelp_GenericVariables", client);

	PrintToConsole(client, "%T", "CCHelp_CSGO_1", client);

	return Plugin_Handled;
}

public Action Command_CCName(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "%t", "NoConsole");

		return Plugin_Handled;
	}

	if(!HasCustomChat(client))
	{
		Shavit_PrintToChat(client, "%T", "NoCommandAccess", client);

		return Plugin_Handled;
	}

	char sArgs[128];
	GetCmdArgString(sArgs, 128);
	TrimString(sArgs);

	if(args == 0 || strlen(sArgs) == 0)
	{
		Shavit_PrintToChat(client, "%T", "ArgumentsMissing", client, "sm_ccname <text>");
		Shavit_PrintToChat(client, "%T", "ChatCurrent", client, gS_CustomName[client]);

		return Plugin_Handled;
	}

	else if(StrEqual(sArgs, "off"))
	{
		Shavit_PrintToChat(client, "%T", "NameOff", client, sArgs);

		gB_NameEnabled[client] = false;

		return Plugin_Handled;
	}

	Shavit_PrintToChat(client, "%T", "ChatUpdated", client);

	if(!StrEqual(gS_CustomName[client], sArgs))
	{
		gB_ChangedSinceLogin[client] = true;
	}

	gB_NameEnabled[client] = true;
	strcopy(gS_CustomName[client], 128, sArgs);

	return Plugin_Handled;
}

public Action Command_CCMessage(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "%t", "NoConsole");

		return Plugin_Handled;
	}

	if(!HasCustomChat(client))
	{
		Shavit_PrintToChat(client, "%T", "NoCommandAccess", client);

		return Plugin_Handled;
	}

	char sArgs[32];
	GetCmdArgString(sArgs, 32);
	TrimString(sArgs);

	if(args == 0 || strlen(sArgs) == 0)
	{
		Shavit_PrintToChat(client, "%T", "ArgumentsMissing", client, "sm_ccmsg <text>");
		Shavit_PrintToChat(client, "%T", "ChatCurrent", client, gS_CustomMessage[client]);

		return Plugin_Handled;
	}

	else if(StrEqual(sArgs, "off"))
	{
		Shavit_PrintToChat(client, "%T", "MessageOff", client, sArgs);

		gB_MessageEnabled[client] = false;

		return Plugin_Handled;
	}

	Shavit_PrintToChat(client, "%T", "ChatUpdated", client);

	if(!StrEqual(gS_CustomMessage[client], sArgs))
	{
		gB_ChangedSinceLogin[client] = true;
	}

	gB_MessageEnabled[client] = true;
	strcopy(gS_CustomMessage[client], 16, sArgs);

	return Plugin_Handled;
}

public Action Command_ChatRanks(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	ShowChatRanksMenu(client, 0);

	return Plugin_Handled;
}

public Action Command_Ranks(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	ShowRanksMenu(client, 0);

	return Plugin_Handled;
}

public Action Command_CCList(int client, int args)
{
	ReplyToCommand(client, "%T", "CheckConsole", client);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i) && HasCustomChat(client))
		{
			PrintToConsole(client, "%N (%d/#%d) (name: \"%s\"; message: \"%s\")", i, i, GetClientUserId(i), gS_CustomName[i], gS_CustomMessage[i]);
		}
	}

	return Plugin_Handled;
}

public Action Command_ReloadChatRanks(int client, int args)
{
	if(LoadChatConfig())
	{
		ReplyToCommand(client, "Reloaded chatranks config.");
	}

	return Plugin_Handled;
}

public Action Command_CCAdd(int client, int args)
{
	if (args == 0)
	{
		ReplyToCommand(client, "Missing steamid3");
		return Plugin_Handled;
	}

	char sArgString[32];
	GetCmdArgString(sArgString, 32);

	int iSteamID = SteamIDToAuth(sArgString);

	if (iSteamID < 1)
	{
		ReplyToCommand(client, "Invalid steamid");
		return Plugin_Handled;
	}

	DB_AddCCAccess(iSteamID);

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetSteamAccountID(i) == iSteamID)
		{
			gB_CCAccess[i] = true;
		}
	}

	ReplyToCommand(client, "Added CC access for %s", sArgString);

	return Plugin_Handled;
}

public Action Command_CCDelete(int client, int args)
{
	if (args == 0)
	{
		ReplyToCommand(client, "Missing steamid3");
		return Plugin_Handled;
	}

	char sArgString[32];
	GetCmdArgString(sArgString, 32);

	int iSteamID = SteamIDToAuth(sArgString);

	if (iSteamID < 1)
	{
		ReplyToCommand(client, "Invalid steamid");
		return Plugin_Handled;
	}

	DB_DeleteCCAccess(iSteamID);

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetSteamAccountID(i) == iSteamID)
		{
			gB_CCAccess[i] = false;
		}
	}

	ReplyToCommand(client, "Deleted CC access for %s", sArgString);

	return Plugin_Handled;
}