void RegisterCommands()
{
	RegConsoleCmd("sm_cpmenu", Command_Checkpoints, "Opens the checkpoints menu.");
	RegConsoleCmd("sm_cps", Command_Checkpoints, "Opens the checkpoints menu. Alias for sm_cpmenu.");
	RegConsoleCmd("sm_cpcaidan", Command_Checkpoints, "Opens the checkpoints menu. Alias for sm_cpmenu.");
	RegConsoleCmd("sm_checkpoint", Command_Checkpoints, "Opens the checkpoints menu. Alias for sm_cpmenu.");
	RegConsoleCmd("sm_checkpoints", Command_Checkpoints, "Opens the checkpoints menu. Alias for sm_cpmenu.");
	RegConsoleCmd("sm_save", Command_Save, "Saves checkpoint.");
	RegConsoleCmd("sm_saveloc", Command_Save, "Saves checkpoint.");
	RegConsoleCmd("sm_cp", Command_Save, "Saves checkpoint. Alias for sm_save.");
	RegConsoleCmd("sm_tele", Command_Tele, "Teleports to checkpoint. Usage: sm_tele [number]");
	RegConsoleCmd("sm_prac", Command_Tele, "Teleports to checkpoint. Usage: sm_tele [number]. Alias of sm_tele.");
	RegConsoleCmd("sm_practice", Command_Tele, "Teleports to checkpoint. Usage: sm_tele [number]. Alias of sm_tele.");

	// hook teamjoins
	AddCommandListener(Command_Jointeam, "jointeam");
}

public Action Command_Checkpoints(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "This command may be only performed in-game.");

		return Plugin_Handled;
	}

	OpenCheckpointsMenu(client);

	return Plugin_Handled;
}

public Action Command_Save(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "This command may be only performed in-game.");

		return Plugin_Handled;
	}

	bool bSegmenting = CanSegment(client);

	if(!gCV_Checkpoints.BoolValue && !bSegmenting)
	{
		Shavit_PrintToChat(client, "%T", "FeatureDisabled", client);

		return Plugin_Handled;
	}

	if(SaveCheckpoint(client))
	{ 
		Shavit_PrintToChat(client, "%T", "MiscCheckpointsSaved", client, gI_CurrentCheckpoint[client]);

		if (gB_InCheckpointMenu[client])
		{
			OpenCheckpointsMenu(client);
		}
	}

	return Plugin_Handled;
}

public Action Command_Tele(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "This command may be only performed in-game.");

		return Plugin_Handled;
	}

	if(!gCV_Checkpoints.BoolValue)
	{
		Shavit_PrintToChat(client, "%T", "FeatureDisabled", client);

		return Plugin_Handled;
	}

	bool usingOther = gB_UsingOtherCheckpoint[client];

	if(args > 0)
	{
		char arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		ReplaceString(arg, 8, "#", " ");

		int parsed = StringToInt(arg);

		if(0 < parsed <= gCV_MaxCP.IntValue)
		{
			if(usingOther)
			{
				gI_OtherCurrentCheckpoint[client] = parsed;
			}
			else
			{
				gI_CurrentCheckpoint[client] = parsed;
			}
		}
	}

	if(usingOther)
	{
		TeleportToOtherCheckpoint(client, gI_OtherClientIndex[client], gI_OtherCurrentCheckpoint[client], true);
	}
	else
	{
		TeleportToCheckpoint(client, gI_CurrentCheckpoint[client], true);
	}

	return Plugin_Handled;
}

public Action Command_Jointeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	if(!gB_SaveStates[client])
	{
		PersistData(client, false);
	}

	return Plugin_Continue;
}