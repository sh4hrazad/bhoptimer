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
	
	StrCat(sBuffer, sizeof(sBuffer), "<pre>");
	int iLines = AddHUDToBuffer(client, huddata, sBuffer, sizeof(sBuffer));
	StrCat(sBuffer, sizeof(sBuffer), "</pre>");

	if(iLines > 0)
	{
		PrintCSGOHUDText(client, sBuffer);
	}
}

static int AddHUDToBuffer(int client, huddata_t data, char[] buffer, int maxlen)
{
	int iLines = 0;
	char sLine[256];

	char sTransTime[8];
	FormatEx(sTransTime, 8, "%T", "Time", client);

	char sSpeed[8];
	FormatEx(sSpeed, 8, "%T", "Speed", client);

	StrCat(buffer, MAX_HINT_SIZE, "<span class='fontSize-m'>");
	StrCat(buffer, MAX_HINT_SIZE, "<span class='fontWeight-Light'>");

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
			
			FormatEx(sLine, 128, "[<span color='#00FF00'>%s - %s</span>]", sTrack, gS_StyleStrings[data.iStyle].sStyleName);
			AddHUDLine(buffer, maxlen, sLine, iLines);

			iLines++;

			if((gI_HUD2Settings[client] & HUD2_TIME) == 0)
			{
				char sTime[32];
				FormatSeconds(data.fTime, sTime, 32, false);

				char sPlayerName[16]; // shouldn't too long bytes.
				Shavit_GetReplayName(data.iStyle, data.iTrack, sPlayerName, sizeof(sPlayerName), data.iStage);

				FormatEx(sLine, 128, "%s: <span color='#FFFF00'>%s</span> (%s)", sTransTime, sTime, sPlayerName);
				AddHUDLine(buffer, maxlen, sLine, iLines);
				iLines++;
			}

			if((gI_HUD2Settings[client] & HUD2_SPEED) == 0)
			{
				int iColor = 0x66BCFF;

				if(data.iSpeed < gI_PreviousSpeed[client])
				{
					iColor = 0xFF6767;
				}

				FormatEx(sLine, 128, "%s: <span color='#%06X'>%d</span>", sSpeed, iColor, data.iSpeed);
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
		bool bLinearMap = Shavit_IsLinearMap();

		if((gI_HUD2Settings[client] & HUD2_TIME) == 0)
		{
			char sTime[32];

			if(data.fTime == 0.0)
			{
				FormatEx(sTime, 32, "Stopped");
			}
			else
			{
				FormatHUDSeconds(data.fTime, sTime, 32);
			}

			int iColor = 0xFF0000;

			if(data.fTime == 0.0)
			{
				// 不计时 | 起点 红色
			}
			else if(data.bPractice || data.iTimerStatus == Timer_Paused)
			{
				iColor = 0xE066FF; // 暂停 中兰紫
			}
			else if(data.fTime < data.fWR || data.fWR == 0.0) 
			{
				iColor = 0x00FA9A; // 小于WR 青绿
			}
			else if(data.fTime < data.fPB || data.fPB == 0.0)
			{
				iColor = 0xFFFACD; // 小于PB 黄色
			}

			if(data.iStyle == 0)
			{
				FormatEx(sLine, 128, "Time: <span color='#%06X'>%s </span>", iColor, sTime);
			}
			else
			{
				char sStyle[32];
				Shavit_GetStyleStrings(data.iStyle, sStyleName, sStyle, 32);
				FormatEx(sLine, 128, "Time: <span color='#%06X'>%s </span>[%s] ", iColor, sTime, sStyle);
			}

			AddHUDLine(buffer, maxlen, sLine, iLines);

			if(data.iCheckpoint > 0 && data.iStyle >= 0 && !data.bStageTimer && data.iTimerStatus == Timer_Running)
			{
				int iDiffColor;
				if(Shavit_GetWRCPTime(data.iCheckpoint, data.iStyle) == -1.0)
				{
					iDiffColor = 0xFFFF00;
				}
				else if(Shavit_GetWRCPDiffTime(data.iTarget) > 0.0)
				{
					iDiffColor = 0xFF0000;
				}
				else
				{
					iDiffColor = 0x00FF00;
				}

				FormatEx(sLine, 128, "[CP%d <span color='#%06X'>%s</span>]", data.iCheckpoint, iDiffColor, data.sDiff);

				AddHUDLine(buffer, maxlen, sLine, iLines);
			}

			if(data.bPractice)
			{
				FormatEx(sLine, 128, "[练习模式]");
				AddHUDLine(buffer, maxlen, sLine, iLines);
			}
			else if(data.iTimerStatus == Timer_Paused)
			{
				FormatEx(sLine, 128, "[暂停中]");
				AddHUDLine(buffer, maxlen, sLine, iLines);
			}

			iLines++;
		}

		if((gI_HUD2Settings[client] & HUD2_WRPB) == 0)
		{
			char sTargetSR[64];

			if(data.iFinishNum == 0)
			{
				FormatEx(sTargetSR, 64, "None");
			}
			else
			{
				FormatHUDSeconds(data.fWR, sTargetSR, 64);
			}

			FormatEx(sLine, 64, "SR: %s", sTargetSR);
			AddHUDLine(buffer, maxlen, sLine, iLines);
		}
		else
		{
			char sTargetPB[64];

			if(data.fPB == 0)
			{
				FormatEx(sTargetPB, 64, "None");
			}
			else
			{
				FormatHUDSeconds(data.fPB, sTargetPB, 64);
			}

			FormatEx(sLine, 128, "PB: %s", sTargetPB);
			AddHUDLine(buffer, maxlen, sLine, iLines);
		}

		iLines = 0;

		switch(data.iZoneHUD)
		{
			case ZoneHUD_None:
			{
				if(data.iTrack == 0)
				{
					if(bLinearMap)
					{
						FormatEx(sLine, 32, " | Linear Map");
					}
					else
					{
						FormatEx(sLine, 32, " | Stage %d / %d", data.iStage, Shavit_GetMapStages());
					}
				}
				else
				{
					FormatEx(sLine, 32, " | Bonus %d", data.iTrack);
				}
			}
			case ZoneHUD_Start:
			{
				if(data.iTrack == 0)
				{
					FormatEx(sLine, 32, " | Map Start");
				}
				else
				{
					FormatEx(sLine, 32, " | Bonus %d Start", data.iTrack);
				}
			}
			case ZoneHUD_End:
			{
				if(data.iTrack == 0)
				{
					FormatEx(sLine, 32, " | Map End");
				}
				else
				{
					FormatEx(sLine, 32, " | Bonus %d End", data.iTrack);
				}
			}
			case ZoneHUD_Stage:
			{
				FormatEx(sLine, 32, " | Stage %d Start", data.iStage);
			}
		}

		AddHUDLine(buffer, maxlen, sLine, iLines);

		iLines++;

		if((gI_HUD2Settings[client] & HUD2_SPEED) == 0)
		{
			int iColor = 0x66BCFF;

			if(data.iSpeed < gI_PreviousSpeed[client])
			{
				iColor = 0xFF6767;
			}

			FormatEx(sLine, 128, "Speed: <span color='#%06X'>%d</span>", iColor, data.iSpeed);

			AddHUDLine(buffer, maxlen, sLine, iLines);

			iLines++;
		}
	}

	StrCat(buffer, MAX_HINT_SIZE, "</span></span>");

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

static void PrintCSGOHUDText(int client, const char[] str)
{
	char buff[2048];
	FormatEx(buff, 2048, "</font>%s%s", str, gS_HintPadding);

	Protobuf pb = view_as<Protobuf>(StartMessageOne("TextMsg", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS));
	pb.SetInt("msg_dst", 4);
	pb.AddString("params", "#SFUI_ContractKillStart");
	pb.AddString("params", buff);
	pb.AddString("params", NULL_STRING);
	pb.AddString("params", NULL_STRING);
	pb.AddString("params", NULL_STRING);
	pb.AddString("params", NULL_STRING);

	EndMessage();
}