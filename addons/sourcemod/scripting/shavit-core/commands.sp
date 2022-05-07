void RegisterCommands() {
	// style
	RegConsoleCmd("sm_style", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_styles", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_diff", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_difficulty", Command_Style, "Choose your bhop style.");
	gSM_StyleCommands = new StringMap();

	// timer start
	RegConsoleCmd("sm_start", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_r", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_restart", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_remake", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_main", Command_StartTimer, "Start your timer on the main track.");

	RegConsoleCmd("sm_b", Command_StartTimer, "Start your timer on the bonus track.");
	RegConsoleCmd("sm_bonus", Command_StartTimer, "Start your timer on the bonus track.");

	for (int i = Track_Bonus; i <= Track_Bonus_Last; i++)
	{
		char cmd[10], helptext[50];
		FormatEx(cmd, sizeof(cmd), "sm_b%d", i);
		FormatEx(helptext, sizeof(helptext), "Start your timer on the bonus %d track.", i);
		RegConsoleCmd(cmd, Command_StartTimer, helptext);
	}

	// teleport to end
	RegConsoleCmd("sm_end", Command_TeleportEnd, "Teleport to endzone.");

	RegConsoleCmd("sm_bend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");
	RegConsoleCmd("sm_bonusend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");

	// timer stop
	RegConsoleCmd("sm_stop", Command_StopTimer, "Stop your timer.");

	// timer pause / resume
	RegConsoleCmd("sm_pause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_unpause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_resume", Command_TogglePause, "Toggle pause");

	// autobhop toggle
	RegConsoleCmd("sm_auto", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_autobhop", Command_AutoBhop, "Toggle autobhop.");

	// admin
	RegAdminCmd("sm_deletemap", Command_DeleteMap, ADMFLAG_ROOT, "Deletes all map data. Usage: sm_deletemap <map>");
	RegAdminCmd("sm_wipeplayer", Command_WipePlayer, ADMFLAG_BAN, "Wipes all bhoptimer data for specified player. Usage: sm_wipeplayer <steamid3>");
	RegAdminCmd("sm_migration", Command_Migration, ADMFLAG_ROOT, "Force a database migration to run. Usage: sm_migration <migration id> or \"all\" to run all migrations.");
}

public Action Command_Style(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

        ShowStyleMenu(client);

	return Plugin_Handled;
}

public Action Command_StartTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	if(!gCV_Restart.BoolValue)
	{
		if(args != -1)
		{
			Shavit_PrintToChat(client, "%T", "CommandDisabled", client, sCommand);
		}

		return Plugin_Handled;
	}

	int track = Track_Main;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		// Pull out bonus number for commands like sm_b1 and sm_b2.
		if ('1' <= sCommand[4] <= ('0' + Track_Bonus_Last))
		{
			track = view_as<int>(sCommand[4] - '0');
		}
		else if (args < 1)
		{
			track = Track_Bonus;
		}
		else
		{
			char arg[6];
			GetCmdArg(1, arg, sizeof(arg));
			track = StringToInt(arg);
		}

		if (track < Track_Bonus || track > Track_Bonus_Last)
		{
			track = Track_Bonus;
		}
	}
	else if(StrContains(sCommand, "sm_r", false) == 0)
	{
		track = Track_Main;
	}

	Action result = Plugin_Continue;
	Call_OnRestartPre(client, track, result);

	if(result > Plugin_Continue)
	{
		return Plugin_Handled;
	}

	Call_OnRestart(client, track);

	return Plugin_Handled;
}

public Action Command_TeleportEnd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int track = Track_Main;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		if (args < 1)
		{
			track = Shavit_GetClientTrack(client);
		}
		else
		{
			char arg[6];
			GetCmdArg(1, arg, sizeof(arg));
			track = StringToInt(arg);
		}

		if (track < Track_Bonus || track > Track_Bonus_Last)
		{
			track = Track_Bonus;
		}
	}

	Call_OnEnd(client, track);

	return Plugin_Handled;
}

public Action Command_StopTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Shavit_StopTimer(client, false);

	return Plugin_Handled;
}

public Action Command_TogglePause(int client, int args)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	int iFlags = Shavit_CanPause(client);

	if((iFlags & CPR_NoTimer) > 0)
	{
		return Plugin_Handled;
	}

	if((iFlags & CPR_InStartZone) > 0)
	{
		Shavit_PrintToChat(client, "%T", "PauseStartZone", client);

		return Plugin_Handled;
	}

	if((iFlags & CPR_InEndZone) > 0)
	{
		Shavit_PrintToChat(client, "%T", "PauseEndZone", client);

		return Plugin_Handled;
	}

	if((iFlags & CPR_ByConVar) > 0)
	{
		char sCommand[16];
		GetCmdArg(0, sCommand, 16);

		Shavit_PrintToChat(client, "%T", "CommandDisabled", client, sCommand);

		return Plugin_Handled;
	}

	if (gA_Timers[client].bClientPaused)
	{
		if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
		{
			Shavit_PrintToChat(client, "%T", "BlockNoclipResume", client);

			return Plugin_Handled;
		}

		ResumePauseMovement(client);

		ResumeTimer(client);

		Shavit_PrintToChat(client, "%T", "MessageUnpause", client);
	}

	else
	{
		if((iFlags & CPR_NotOnGround) > 0)
		{
			Shavit_PrintToChat(client, "%T", "PauseNotOnGround", client);

			return Plugin_Handled;
		}

		if((iFlags & CPR_Moving) > 0)
		{
			Shavit_PrintToChat(client, "%T", "PauseMoving", client);

			return Plugin_Handled;
		}

		if((iFlags & CPR_Duck) > 0)
		{
			Shavit_PrintToChat(client, "%T", "PauseDuck", client);

			return Plugin_Handled;
		}

		GetPauseMovement(client);

		PauseTimer(client);

		Shavit_PrintToChat(client, "%T", "MessagePause", client);
	}

	return Plugin_Handled;
}

public Action Command_DeleteMap(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_deletemap <map>\nOnce a map is chosen, \"sm_deletemap confirm\" to run the deletion.");

		return Plugin_Handled;
	}

	char sArgs[PLATFORM_MAX_PATH];
	GetCmdArgString(sArgs, sizeof(sArgs));
	LowercaseString(sArgs);

	if(StrEqual(sArgs, "confirm") && strlen(gS_DeleteMap[client]) > 0)
	{
		Call_OnDeleteMapData(client, gS_DeleteMap[client]);

		ReplyToCommand(client, "Finished deleting data for %s.", gS_DeleteMap[client]);
		gS_DeleteMap[client] = "";
	}
	else
	{
		gS_DeleteMap[client] = sArgs;
		ReplyToCommand(client, "Map to delete is now %s.\nRun \"sm_deletemap confirm\" to delete all data regarding the map %s.", gS_DeleteMap[client], gS_DeleteMap[client]);
	}

	return Plugin_Handled;
}

public Action Command_Migration(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_migration <migration id or \"all\" to run all migrationsd>.");

		return Plugin_Handled;
	}

	char sArg[16];
	GetCmdArg(1, sArg, 16);

	bool bApplyMigration[MIGRATIONS_END];

	if(StrEqual(sArg, "all"))
	{
		for(int i = 0; i < MIGRATIONS_END; i++)
		{
			bApplyMigration[i] = true;
		}
	}

	else
	{
		int iMigration = StringToInt(sArg);

		if(0 <= iMigration < MIGRATIONS_END)
		{
			bApplyMigration[iMigration] = true;
		}
	}

	for(int i = 0; i < MIGRATIONS_END; i++)
	{
		if(bApplyMigration[i])
		{
			ReplyToCommand(client, "Applying database migration %d", i);
			ApplyMigration(i);
		}
	}

	return Plugin_Handled;
}

public Action Command_WipePlayer(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_wipeplayer <steamid3>\nAfter entering a SteamID, you will be prompted with a verification captcha.");

		return Plugin_Handled;
	}

	char sArgString[32];
	GetCmdArgString(sArgString, 32);

	if(strlen(gS_Verification[client]) == 0 || !StrEqual(sArgString, gS_Verification[client]))
	{
		gI_WipePlayerID[client] = SteamIDToAuth(sArgString);

		if(gI_WipePlayerID[client] <= 0)
		{
			Shavit_PrintToChat(client, "Entered SteamID (%s) is invalid. The range for valid SteamIDs is [U:1:1] to [U:1:2147483647].", sArgString);

			return Plugin_Handled;
		}

		char sAlphabet[] = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#";
		strcopy(gS_Verification[client], 8, "");

		for(int i = 0; i < 5; i++)
		{
			gS_Verification[client][i] = sAlphabet[GetRandomInt(0, sizeof(sAlphabet) - 1)];
		}

		Shavit_PrintToChat(client, "Preparing to delete all user data for SteamID {gold}[U:1:%d]{white}. To confirm, enter {orchid}!wipeplayer %s",
			gI_WipePlayerID[client], gS_Verification[client]);
	}
	else
	{
		Shavit_PrintToChat(client, "Deleting data for SteamID {gold}[U:1:%d]{white}...", gI_WipePlayerID[client]);

		DeleteUserData(client, gI_WipePlayerID[client]);

		strcopy(gS_Verification[client], 8, "");
		gI_WipePlayerID[client] = -1;
	}

	return Plugin_Handled;
}

public Action Command_AutoBhop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_Auto[client] = !gB_Auto[client];

	if (gB_Auto[client])
	{
		Shavit_PrintToChat(client, "%T", "AutobhopEnabled", client, gS_ChatStrings.sGood, gS_ChatStrings.sText);
	}
	else
	{
		Shavit_PrintToChat(client, "%T", "AutobhopDisabled", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
	}

	char sAutoBhop[4];
	IntToString(view_as<int>(gB_Auto[client]), sAutoBhop, 4);
	SetClientCookie(client, gH_AutoBhopCookie, sAutoBhop);

	UpdateStyleSettings(client);

	return Plugin_Handled;
}