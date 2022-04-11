static bool gB_CanTouchTrigger[MAXPLAYERS+1];
static int gI_LastNoclipTick[MAXPLAYERS+1];


// ======[ EVENTS ]======

void AddCommandListeners_Noclip()
{
	RegConsoleCmd("sm_nc", Command_Noclip, "Toggles noclip.");
	RegConsoleCmd("sm_noclipme", Command_Noclip, "Toggles noclip.");
	RegConsoleCmd("sm_nctrigger", Command_NoclipIgnoreTrigger);
	RegConsoleCmd("sm_nctriggers", Command_NoclipIgnoreTrigger);

	AddCommandListener(CommandListener_Noclip, "+noclip");
	AddCommandListener(CommandListener_Noclip, "-noclip");
	// Hijack sourcemod's sm_noclip from funcommands to work when no args are specified.
	AddCommandListener(CommandListener_funcommands_Noclip, "sm_noclip");
	AddCommandListener(CommandListener_Real_Noclip, "noclip");
}

void OnClientPutInServer_InitNoclip(int client)
{
	gB_CanTouchTrigger[client] = false;
	gI_LastNoclipTick[client] = 0;
}

void OnEntityCreated_HookTrigger(int entity, const char[] classname)
{
	if(StrEqual(classname, "trigger_multiple") || StrEqual(classname, "trigger_once") || StrEqual(classname, "trigger_push") || StrEqual(classname, "trigger_teleport") || StrEqual(classname, "trigger_gravity"))
	{
		SDKHook(entity, SDKHook_StartTouch, HookTrigger);
		SDKHook(entity, SDKHook_EndTouch, HookTrigger);
		SDKHook(entity, SDKHook_Touch, HookTrigger);
	}
}



// ======[ PRIVATE ]======

public Action Command_Noclip(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (gI_LastNoclipTick[client] == GetGameTickCount())
	{
		return Plugin_Handled;
	}

	gI_LastNoclipTick[client] = GetGameTickCount();

	if(gCV_NoclipMe.IntValue == 0)
	{
		Shavit_PrintToChat(client, "%T", "FeatureDisabled", client);

		return Plugin_Handled;
	}
	else if(gCV_NoclipMe.IntValue == 2 && !CheckCommandAccess(client, "admin_noclipme", ADMFLAG_CHEATS))
	{
		Shavit_PrintToChat(client, "%T", "LackingAccess", client);

		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "CommandAlive", client);

		return Plugin_Handled;
	}

	UpdateByNoclipStatus(client, GetEntityMoveType(client) == MOVETYPE_WALK);

	return Plugin_Handled;
}

public Action CommandListener_Noclip(int client, const char[] command, int args)
{
	if(!IsValidClient(client, true))
	{
		return Plugin_Handled;
	}

	gI_LastNoclipTick[client] = GetGameTickCount();

	UpdateByNoclipStatus(client, command[0] == '+');

	return Plugin_Handled;
}

public Action Command_NoclipIgnoreTrigger(int client, int args)
{
	gB_CanTouchTrigger[client] = !gB_CanTouchTrigger[client];
	Shavit_PrintToChat(client, "%T", (gB_CanTouchTrigger[client])?"NoclipCanTrigger":"NoclipCannotTrigger", client);

	return Plugin_Handled;
}

public Action CommandListener_funcommands_Noclip(int client, const char[] command, int args)
{
	if (IsValidClient(client, true) && args < 1)
	{
		Command_Noclip(client, 0);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action CommandListener_Real_Noclip(int client, const char[] command, int args)
{
	if (sv_cheats.BoolValue)
	{
		if (gI_LastNoclipTick[client] == GetGameTickCount())
		{
			return Plugin_Stop;
		}

		gI_LastNoclipTick[client] = GetGameTickCount();
	}

	return Plugin_Continue;
}

public Action HookTrigger(int entity, int other)
{
	if(IsValidClient(other))
	{
		if(!gB_CanTouchTrigger[other] && GetEntityMoveType(other) & MOVETYPE_NOCLIP)
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

static void UpdateByNoclipStatus(int client, bool walking)
{
	if(walking)
	{
		if(Shavit_GetTimerStatus(client) != Timer_Paused && !Shavit_IsPracticeMode(client))
		{
			Shavit_PauseTimer(client);
		}

		Shavit_PrintToChat(client, "%T", (gB_CanTouchTrigger[client])?"NoclipCanTrigger":"NoclipCannotTrigger", client);
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}
	else
	{
		if(Shavit_GetTimerStatus(client) == Timer_Paused)
		{
			Shavit_PrintToChat(client, "输入{palered}%s{default}恢复计时器", Shavit_GetClientTime(client) != 0.0 ? "!pause" : "!r");
		}

		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}