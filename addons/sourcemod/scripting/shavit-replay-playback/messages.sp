static float gF_PrevFrameTime[MAXPLAYERS + 1];
static bool gB_InsideZone[MAXPLAYERS + 1];

void OnReplayStart_ResetPrestrafeMsg(int index)
{
	gB_InsideZone[index] = false;
	gF_PrevFrameTime[index] = 0.0;
}

void Replay_PrestrafeMessage(bot_info_t info)
{
	if(info.aCache.fTime < 0.0)
	{
		return;
	}

	float fCurrentTime = GetReplayTime(info.iEnt);
	
	// fTime = 0.0 输出一次
	if(fCurrentTime == 0.0)
	{
		SendMessageToSpectator(info.iEnt, "起点 | 速度: {lightgreen}%d u/s", RoundToFloor(GetSpeed(info.iEnt)), true);
	}
	// fTime != fPrevFrameTime 时输出一次
	else if(fCurrentTime == gF_PrevFrameTime[info.iEnt])
	{
		gB_InsideZone[info.iEnt] = true;
	}
	else if(fCurrentTime != gF_PrevFrameTime[info.iEnt])
	{
		if (gB_InsideZone[info.iEnt] == true)
		{
			SendMessageToSpectator(info.iEnt, "速度: {lightgreen}%d u/s", RoundToFloor(GetSpeed(info.iEnt)), true);

			gB_InsideZone[info.iEnt] = false;
		}
	}

	gF_PrevFrameTime[info.iEnt] = fCurrentTime;
}

float GetReplayTime(int index)
{
	if (gA_BotInfo[index].iTick > (gA_BotInfo[index].aCache.iFrameCount + gA_BotInfo[index].aCache.iPreFrames))
	{
		return gA_BotInfo[index].aCache.fTime;
	}

	if(gA_BotInfo[index].iStage != 0)
	{
		int preframes = RoundToFloor(FindConVar("shavit_stage_replay_preruntime").FloatValue * gF_Tickrate);

		if (gA_BotInfo[index].iTick > (gA_BotInfo[index].aCache.iFrameCount - preframes))
		{
			return gA_BotInfo[index].aCache.fTime;
		}

		return float(gA_BotInfo[index].iTick - preframes) / gF_Tickrate * Shavit_GetStyleSettingFloat(gA_BotInfo[index].iStyle, "timescale");
	}

	if(gA_BotInfo[index].iTrack != 0)
	{
		return float(gA_BotInfo[index].iTick - gA_BotInfo[index].aCache.iPreFrames) / gF_Tickrate * Shavit_GetStyleSettingFloat(gA_BotInfo[index].iStyle, "timescale");
	}
	else
	{
		return float(gA_BotInfo[index].iRealTick - gA_BotInfo[index].aCache.iPreFrames) / gF_Tickrate * Shavit_GetStyleSettingFloat(gA_BotInfo[index].iStyle, "timescale") + gA_BotInfo[index].fRealTime;
	}
}

static float GetSpeed(int index)
{
	float fSpeed[3];
	GetEntPropVector(index, Prop_Data, "m_vecAbsVelocity", fSpeed);
	return (SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0) + Pow(fSpeed[2], 2.0)));
}