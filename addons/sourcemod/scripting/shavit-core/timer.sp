TimerStatus GetTimerStatus(int client)
{
	if (!gA_Timers[client].bTimerEnabled)
	{
		return Timer_Stopped;
	}
	else if (gA_Timers[client].bClientPaused)
	{
		return Timer_Paused;
	}

	return Timer_Running;
}

void StartTimer(int client, int track)
{
	if(!IsValidClient(client, true) || GetClientTeam(client) < 2 || IsFakeClient(client) || !gB_CookiesRetrieved[client])
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);
	float curVel = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));

	Action result = Plugin_Continue;
	Call_OnStartPre(client, track, result);

	if(result == Plugin_Continue)
	{
		Call_OnStart(client, track, result);

		gA_Timers[client].iZoneIncrement = 0;
		gA_Timers[client].fTimescaledTicks = 0.0;
		gA_Timers[client].bClientPaused = false;
		gA_Timers[client].iStrafes = 0;
		gA_Timers[client].iJumps = 0;
		gA_Timers[client].iTotalMeasures = 0;
		gA_Timers[client].iGoodGains = 0;

		if (gA_Timers[client].iTimerTrack != track)
		{
			Call_OnTrackChanged(client, gA_Timers[client].iTimerTrack, track);
		}

		gA_Timers[client].iTimerTrack = track;
		gA_Timers[client].bTimerEnabled = true;
		gA_Timers[client].iSHSWCombination = -1;
		gA_Timers[client].fCurrentTime = 0.0;
		gA_Timers[client].bPracticeMode = false;
		gA_Timers[client].bCanUseAllKeys = false;
		gA_Timers[client].fZoneOffset[Zone_Start] = 0.0;
		gA_Timers[client].fZoneOffset[Zone_End] = 0.0;
		gA_Timers[client].fDistanceOffset[Zone_Start] = 0.0;
		gA_Timers[client].fDistanceOffset[Zone_End] = 0.0;
		gA_Timers[client].fAvgVelocity = curVel;
		gA_Timers[client].fMaxVelocity = curVel;

		UpdateLaggedMovement(client, true);
		SetEntityGravity(client, GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity"));
	}
}

void StopTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	gA_Timers[client].bTimerEnabled = false;
	gA_Timers[client].iJumps = 0;
	gA_Timers[client].fCurrentTime = 0.0;
	gA_Timers[client].bClientPaused = false;
	gA_Timers[client].iStrafes = 0;
	gA_Timers[client].iTotalMeasures = 0;
	gA_Timers[client].iGoodGains = 0;
}

void StopTimer_Cheat(int client, const char[] message)
{
	Shavit_StopTimer(client);
	Shavit_PrintToChat(client, "%T", "CheatTimerStop", client, message);
}

void PauseTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_OnPause(client, gA_Timers[client].iTimerTrack);

	gA_Timers[client].bClientPaused = true;
}

void ResumeTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_OnResume(client, gA_Timers[client].iTimerTrack);

	gA_Timers[client].bClientPaused = false;
}

void BuildSnapshot(int client, timer_snapshot_t snapshot)
{
	snapshot = gA_Timers[client];
	snapshot.fServerTime = GetEngineTime();
	snapshot.fTimescale = (gA_Timers[client].fTimescale > 0.0) ? gA_Timers[client].fTimescale : 1.0;
}