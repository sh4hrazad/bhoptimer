static ClosestPos gH_ClosestPos[TRACKS_SIZE][STYLE_LIMIT];



// ======[ PUBLIC ]======

void DropClosestPos(int style, int track)
{
    delete gH_ClosestPos[track][style];
}

void OnDefaultLoadReplay_ClosestPos(frame_cache_t cache, int style, int track)
{
    if (gB_ClosestPos)
	{
		delete gH_ClosestPos[track][style];
		gH_ClosestPos[track][style] = new ClosestPos(cache.aFrames);
	}
}

void Shavit_OnReplaySaved_ClosestPos(int style, int track)
{
    if (gB_ClosestPos)
	{
		delete gH_ClosestPos[track][style];
		gH_ClosestPos[track][style] = new ClosestPos(gA_FrameCache[style][track].aFrames);
	}
}

Action OnPlayerRunCmd_ClosestPos(int client)
{
    if (!gCV_EnableDynamicTimeDifference.BoolValue)
    {
        return Plugin_Continue;
    }

    if(Shavit_InsideZone(client, Zone_Start, -1))
    {
        gF_VelocityDifference2D[client] = 0.0;
        gF_VelocityDifference3D[client] = 0.0;
        return Plugin_Continue;
    }

    if ((GetGameTickCount() % gCV_DynamicTimeTick.IntValue) == 0)
    {
        gF_TimeDifference[client] = GetClosestReplayTime(client);
    }

    return Plugin_Continue;
}

// also calculates gF_VelocityDifference2D & gF_VelocityDifference3D
float GetClosestReplayTime(int client)
{
	int style = gI_TimeDifferenceStyle[client];
	int track = Shavit_GetClientTrack(client);

	if (gA_FrameCache[style][track].aFrames == null)
	{
		return -1.0;
	}

	int iLength = gA_FrameCache[style][track].aFrames.Length;

	if (iLength < 1)
	{
		return -1.0;
	}

	int iPreFrames = gA_FrameCache[style][track].iPreFrames;
	int iPostFrames = gA_FrameCache[style][track].iPostFrames;
	int iSearch = RoundToFloor(gCV_DynamicTimeSearch.FloatValue * (1.0 / GetTickInterval()));

	float fClientPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fClientPos);

	int iClosestFrame;
	int iEndFrame;

	if (gB_ClosestPos)
	{
		iClosestFrame = gH_ClosestPos[track][style].Find(fClientPos);
		iEndFrame = iLength - 1;
		iSearch = 0;
	}
	else
	{
		int iPlayerFrames = Shavit_GetClientFrameCount(client) - Shavit_GetPlayerPreFrames(client);
		int iStartFrame = iPlayerFrames - iSearch;
		iEndFrame = iPlayerFrames + iSearch;

		if(iSearch == 0)
		{
			iStartFrame = 0;
			iEndFrame = iLength - 1 - iPostFrames;
		}
		else
		{
			// Check if the search behind flag is off
			if(iStartFrame < 0 || gCV_DynamicTimeCheap.IntValue & 2 == 0)
			{
				iStartFrame = 0;
			}
			
			// check if the search ahead flag is off
			if(gCV_DynamicTimeCheap.IntValue & 1 == 0)
			{
				iEndFrame = iLength - 1;
			}
		}

		if (iEndFrame >= iLength)
		{
			iEndFrame = iLength - 1;
		}

		float fReplayPos[3];
		// Single.MaxValue
		float fMinDist = view_as<float>(0x7f7fffff);

		for(int frame = iStartFrame; frame < iEndFrame; frame++)
		{
			gA_FrameCache[style][track].aFrames.GetArray(frame, fReplayPos, 3);

			float dist = GetVectorDistance(fClientPos, fReplayPos, true);
			if(dist < fMinDist)
			{
				fMinDist = dist;
				iClosestFrame = frame;
			}
		}
	}

	// out of bounds
	if(/*iClosestFrame == 0 ||*/ iClosestFrame == iEndFrame)
	{
		return -1.0;
	}

	// inside start zone
	if(iClosestFrame < iPreFrames)
	{
		gF_VelocityDifference2D[client] = 0.0;
		gF_VelocityDifference3D[client] = 0.0;
		return 0.0;
	}

	float frametime = GetReplayLength(style, track, gA_FrameCache[style][track]) / float(gA_FrameCache[style][track].iFrameCount);
	float timeDifference = (iClosestFrame - iPreFrames) * frametime;

	// Hides the hud if we are using the cheap search method and too far behind to be accurate
	if(iSearch > 0 && gCV_DynamicTimeCheap.BoolValue)
	{
		float preframes = float(Shavit_GetPlayerPreFrames(client)) / (1.0 / GetTickInterval());
		if(Shavit_GetClientTime(client) - timeDifference >= gCV_DynamicTimeSearch.FloatValue - preframes)
		{
			return -1.0;
		}
	}

	float clientVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", clientVel);

	float fReplayPrevPos[3], fReplayClosestPos[3];
	gA_FrameCache[style][track].aFrames.GetArray(iClosestFrame, fReplayClosestPos, 3);
	gA_FrameCache[style][track].aFrames.GetArray(iClosestFrame == 0 ? 0 : iClosestFrame-1, fReplayPrevPos, 3);

	float replayVel[3];
	MakeVectorFromPoints(fReplayClosestPos, fReplayPrevPos, replayVel);
	ScaleVector(replayVel, gF_Tickrate / Shavit_GetStyleSettingFloat(style, "speed") / Shavit_GetStyleSettingFloat(style, "timescale"));

	gF_VelocityDifference2D[client] = (SquareRoot(Pow(clientVel[0], 2.0) + Pow(clientVel[1], 2.0))) - (SquareRoot(Pow(replayVel[0], 2.0) + Pow(replayVel[1], 2.0)));
	gF_VelocityDifference3D[client] = GetVectorLength(clientVel) - GetVectorLength(replayVel);

	return timeDifference;
}