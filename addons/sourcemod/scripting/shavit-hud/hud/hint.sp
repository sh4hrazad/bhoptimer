void UpdateHintHud(int client)
{
	UpdateMainHUD(client);
	SetEntProp(client, Prop_Data, "m_bDrawViewmodel", ((gI_HUDSettings[client] & HUD_HIDEWEAPON) > 0)? 0:1);
}

static void UpdateMainHUD(int client)
{
	int target = GetSpectatorTarget(client, client);

	if(target < 1 || target > MaxClients ||
		(gI_HUDSettings[client] & HUD_CENTER) == 0 ||
		((gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target))
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", fSpeed);

	float fSpeedHUD = ((gI_HUDSettings[client] & HUD_2DVEL) == 0)? GetVectorLength(fSpeed):(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
	bool bReplay = (gB_Replay && Shavit_IsReplayEntity(target));
	ZoneHUD iZoneHUD = ZoneHUD_None;
	float fReplayTime = 0.0;
	float fReplayLength = 0.0;

	huddata_t huddata;
	huddata.iStyle = (bReplay) ? Shavit_GetReplayBotStyle(target) : Shavit_GetBhopStyle(target);
	huddata.iTrack = (bReplay) ? Shavit_GetReplayBotTrack(target) : Shavit_GetClientTrack(target);
	huddata.iStage = (bReplay) ? Shavit_GetReplayBotStage(target) : Shavit_GetCurrentStage(target);

	if(!bReplay)
	{
		if(Shavit_InsideZone(target, Zone_Start, huddata.iTrack))
		{
			iZoneHUD = ZoneHUD_Start;
		}
		else if (Shavit_InsideZone(target, Zone_End, huddata.iTrack))
		{
			iZoneHUD = ZoneHUD_End;
		}
		else if(Shavit_InsideZone(target, Zone_Stage, huddata.iTrack) && Shavit_IsStageTimer(target))
		{
			iZoneHUD = ZoneHUD_Stage;
		}
	}

	int iReplayStyle = Shavit_GetReplayBotStyle(target);
	int iReplayTrack = Shavit_GetReplayBotTrack(target);
	int iReplayStage = Shavit_GetReplayBotStage(target);

	if(iReplayStyle != -1)
	{
		fReplayTime = Shavit_GetReplayTime(target);
		fReplayLength = Shavit_GetReplayLength(iReplayStyle, iReplayTrack, iReplayStage);
		fSpeedHUD /= Shavit_GetStyleSettingFloat(huddata.iStyle, "speed") * Shavit_GetStyleSettingFloat(huddata.iStyle, "timescale");
	}

	huddata.iTarget = target;
	huddata.iSpeed = RoundToNearest(fSpeedHUD);
	huddata.iZoneHUD = iZoneHUD;
	huddata.fTime = (bReplay)? fReplayTime:Shavit_GetClientTime(target);
	huddata.iJumps = (bReplay)? 0:Shavit_GetClientJumps(target);
	huddata.iStrafes = (bReplay)? 0:Shavit_GetStrafeCount(target);
	huddata.fSync = (bReplay)? 0.0:Shavit_GetSync(target);
	huddata.fPB = (bReplay)? 0.0:Shavit_GetClientPB(target, huddata.iStyle, huddata.iTrack);
	huddata.fWR = (bReplay)? fReplayLength:Shavit_GetWorldRecord(huddata.iStyle, huddata.iTrack);
	huddata.iRank = (bReplay)? 0:Shavit_GetRankForTime(huddata.iStyle, huddata.fPB, huddata.iTrack);
	huddata.iTimerStatus = (bReplay)? Timer_Running:Shavit_GetTimerStatus(target);
	huddata.bReplay = bReplay;
	huddata.bPractice = (bReplay)? false:Shavit_IsPracticeMode(target);
	huddata.iFinishNum = (huddata.iStyle == -1 || huddata.iTrack == -1)?Shavit_GetRecordAmount(0, 0):Shavit_GetRecordAmount(huddata.iStyle, huddata.iTrack);
	huddata.bStageTimer = Shavit_IsStageTimer(target);
	strcopy(huddata.sDiff, 64, gS_DiffTime[target]);
	strcopy(huddata.sPreStrafe, 64, gS_PreStrafeDiff[target]);

	if(huddata.iStage > Shavit_GetMapStages())
	{
		huddata.iStage = Shavit_GetMapStages();
	}

	if(huddata.iZoneHUD != ZoneHUD_End)
	{
		huddata.iCheckpoint = (Shavit_IsLinearMap())? Shavit_GetCurrentCP(target) : Shavit_GetCurrentStage(target) - 1;
	}

	char sBuffer[512];
	
	int iLines = AddHUDToBuffer(client, huddata, sBuffer, sizeof(sBuffer));

	if(iLines > 0)
	{
		PrintHintText(client, "%s", sBuffer);
	}
}

// TODO: remake the hint hud
static int AddHUDToBuffer(int client, huddata_t data, char[] buffer, int maxlen)
{
	int iLines = 0;
	char sLine[256];

	char sTransTime[8];
	FormatEx(sTransTime, 8, "%T", "Time", client);

	char sSpeed[8];
	FormatEx(sSpeed, 8, "%T", "Speed", client);

	if(data.bReplay)
	{
		if(data.iStyle != -1 && Shavit_IsReplayDataLoaded(data.iStyle, data.iTrack, data.iStage))
		{
			char sTrack[64];
			if(data.iStage == 0)
			{
				GetTrackName(client, data.iTrack, sTrack, 64);
			}

			else
			{
				Format(sTrack, 64, "%T #%d", "Stage", client, data.iStage);
			}

			FormatEx(sLine, 128, "%T ", "ReplayText", client);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			
			FormatEx(sLine, 128, "[%s - %s]", sTrack, gS_StyleStrings[data.iStyle].sStyleName);
			AddHUDLine(buffer, maxlen, sLine, iLines);

			iLines++;

			if((gI_HUD2Settings[client] & HUD2_TIME) == 0)
			{
				char sTime[32];
				FormatSeconds(data.fTime, sTime, 32, false);

				char sPlayerName[16]; // shouldn't too long bytes.
				Shavit_GetReplayName(data.iStyle, data.iTrack, sPlayerName, sizeof(sPlayerName), data.iStage);

				FormatEx(sLine, 128, "%s: %s (%s)", sTransTime, sTime, sPlayerName);
				AddHUDLine(buffer, maxlen, sLine, iLines);
				iLines++;
			}

			if((gI_HUD2Settings[client] & HUD2_SPEED) == 0)
			{
				FormatEx(sLine, 128, "%s: %d", sSpeed, data.iSpeed);
				AddHUDLine(buffer, maxlen, sLine, iLines);
				iLines++;
			}
		}

		else
		{
			FormatEx(sLine, 128, "%T", "NoReplayData", client);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
	}

	else
	{
		switch(data.iZoneHUD)
		{
			case ZoneHUD_Start:
			{
				if(data.iTrack == 0)
				{
					FormatEx(sLine, 32, "In Main Start Zone");
				}
				else
				{
					FormatEx(sLine, 32, "In Bonus %d Start Zone", data.iTrack);
				}
			}
			case ZoneHUD_End:
			{
				if(data.iTrack == 0)
				{
					FormatEx(sLine, 32, "In Main End Zone");
				}
				else
				{
					FormatEx(sLine, 32, "In Bonus %d End Zone", data.iTrack);
				}
			}
			case ZoneHUD_Stage:
			{
				FormatEx(sLine, 32, "In Stage %d Start Zone", data.iStage);
			}
		}

		if(sLine[0])
		{
			AddHUDLine(buffer, maxlen, sLine, iLines);

			iLines++;
		}

		if((gI_HUD2Settings[client] & HUD2_TIME) == 0 && data.fTime != 0.0)
		{
			char sTime[32];
			FormatHUDSeconds(data.fTime, sTime, 32);

			// TODO: expected rank

			if(data.iStyle == 0)
			{
				FormatEx(sLine, 128, "Time: %s", sTime);
			}
			else
			{
				char sStyle[8];
				Shavit_GetStyleStrings(data.iStyle, sShortName, sStyle, 8);
				FormatEx(sLine, 128, "%s: %s", sStyle, sTime);
			}

			AddHUDLine(buffer, maxlen, sLine, iLines);

			if(data.iCheckpoint > 0 && data.iStyle >= 0 && !data.bStageTimer && data.iTimerStatus == Timer_Running)
			{
				FormatEx(sLine, 128, " [CP%d %s]", data.iCheckpoint, data.sDiff);

				AddHUDLine(buffer, maxlen, sLine, iLines);
			}

			if(data.bPractice)
			{
				FormatEx(sLine, 128, " [Practice]");
				AddHUDLine(buffer, maxlen, sLine, iLines);
			}
			else if(data.iTimerStatus == Timer_Paused)
			{
				FormatEx(sLine, 128, " [Paused]");
				AddHUDLine(buffer, maxlen, sLine, iLines);
			}

			iLines++;
		}

		if((gI_HUD2Settings[client] & HUD2_SPEED) == 0)
		{
			FormatEx(sLine, 128, "Speed: %d", data.iSpeed);

			AddHUDLine(buffer, maxlen, sLine, iLines);

			iLines++;
		}
	}

	return iLines;
}



// =====[ PRIVATE]=====

static void AddHUDLine(char[] buffer, int maxlen, const char[] line, int lines)
{
	if(lines > 0)
	{
		Format(buffer, maxlen, "%s\n%s", buffer, line);
	}
	else
	{
		StrCat(buffer, maxlen, line);
	}
}