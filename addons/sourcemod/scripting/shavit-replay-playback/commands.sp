// ======[ PUBLIC ]======

void RegisterCommands()
{
	// to disable replay client updates until next map so the server doesn't crash :)
	AddCommandListener(CommandListener_changelevel, "changelevel");
	AddCommandListener(CommandListener_changelevel, "changelevel2");

	RegAdminCmd("sm_deletereplay", Command_DeleteReplay, ADMFLAG_RCON, "Open replay deletion menu.");
	RegConsoleCmd("sm_replay", Command_Replay, "Opens the central bot menu. For admins: 'sm_replay stop' to stop the playback.");
}

public Action CommandListener_changelevel(int client, const char[] command, int args)
{
	gB_CanUpdateReplayClient = false;
	return Plugin_Continue;
}

public Action Command_DeleteReplay(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	OpenDeleteReplayMenu(client);
	return Plugin_Handled;
}

public Action Command_Replay(int client, int args)
{
	if (!IsValidClient(client) || !gCV_Enabled.BoolValue)
	{
		return Plugin_Handled;
	}

	if(GetClientTeam(client) > 1)
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
	}

	OpenReplayMenu(client);
	return Plugin_Handled;
}