native int Shavit_GetMapTier(const char[] map = "");

// keysonly because CS:S lags when you send too many usermessages
void TriggerHUDUpdate(int client, bool keysonly = false)
{
	if ((gI_HUDSettings[client] & HUD_KEYOVERLAY) != 0)
	{
		// key hud
		DrawCenterKeys(client);
	}

	if (keysonly)
	{
		return;
	}

	huddata_t huddata;
	int target = GetSpectatorTarget(client, client);
	bool bReplay = (gB_Replay && Shavit_IsReplayEntity(target));
	huddata.iTarget = target;
	huddata.iStyle = (bReplay) ? Shavit_GetReplayBotStyle(target) : Shavit_GetBhopStyle(target);
	huddata.iTrack = (bReplay) ? Shavit_GetReplayBotTrack(target) : Shavit_GetClientTrack(target);
	huddata.iStage = (bReplay) ? Shavit_GetReplayBotStage(target) : Shavit_GetCurrentStage(target);

	DrawCenterHintHUD(client, target, huddata, bReplay);
	SetEntProp(client, Prop_Data, "m_bDrawViewmodel", ((gI_HUDSettings[client] & HUD_HIDEWEAPON) > 0)? 0:1);

	if(gI_Cycle % 10 ==0)
	{
		DrawSidebarHintHUD(client, target, huddata, bReplay);
	}
}

static void DrawCenterHintHUD(int client, int target, huddata_t huddata, bool bReplay)
{
	// center hint hud
	if(target < 1 || target > MaxClients ||
		(gI_HUDSettings[client] & HUD_CENTER) == 0 ||
		((gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target))
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", fSpeed);

	float fSpeedHUD = ((gI_HUDSettings[client] & HUD_2DVEL) == 0)? GetVectorLength(fSpeed):(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
	ZoneHUD iZoneHUD = ZoneHUD_None;
	float fReplayTime = 0.0;

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

	if(iReplayStyle != -1)
	{
		fReplayTime = Shavit_GetReplayTime(target);
		fSpeedHUD /= Shavit_GetStyleSettingFloat(huddata.iStyle, "speed") * Shavit_GetStyleSettingFloat(huddata.iStyle, "timescale");
	}

	huddata.iSpeed = RoundToNearest(fSpeedHUD);
	huddata.iZoneHUD = iZoneHUD;
	huddata.fTime = (bReplay)? fReplayTime:Shavit_GetClientTime(target);
	huddata.fSync = (bReplay)? 0.0:Shavit_GetSync(target);
	huddata.iTimerStatus = (bReplay)? Timer_Running:Shavit_GetTimerStatus(target);
	huddata.bReplay = bReplay;
	huddata.bPractice = (bReplay)? false:Shavit_IsPracticeMode(target);
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
		if(Shavit_GetClientTime(client) == 0.0)
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

static void DrawSidebarHintHUD(int client, int target, huddata_t huddata, bool bReplay)
{
	// sidebar hint hud
	// TODO: timeleft
	if((gI_HUDSettings[client] & HUD_MAPTIER) > 0)
	{
		char sMessage[256];

		if((gI_HUDSettings[client] & HUD_MAPTIER) > 0)
		{
			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			FormatEx(sMessage, sizeof(sMessage), "%sMap: %s [T%d]\n", sMessage,
				sMap, Shavit_GetMapTier());
		}

		// SR and PB
		char sWRName[32];
		char sWRTime[32];
		char sPBTime[32];

		if(huddata.iStyle != -1 && huddata.iTrack != -1 && !Shavit_IsStageTimer(target))
		{
			Shavit_GetWRName(huddata.iStyle, sWRName, sizeof(sWRName), huddata.iTrack);

			huddata.fPB = Shavit_GetClientPB((bReplay) ? client : target, huddata.iStyle, huddata.iTrack);
			huddata.fWR = Shavit_GetWorldRecord(huddata.iStyle, huddata.iTrack);

			FormatHUDSeconds(huddata.fWR, sWRTime, sizeof(sWRTime));
			FormatHUDSeconds(huddata.fPB, sPBTime, sizeof(sPBTime));

			huddata.iFinishNum = (huddata.iStyle == -1 || huddata.iTrack == -1) ? Shavit_GetRecordAmount(0, 0) : Shavit_GetRecordAmount(huddata.iStyle, huddata.iTrack);
			huddata.iRank = Shavit_GetRankForTime(huddata.iStyle, huddata.fPB, huddata.iTrack);

			if(huddata.iTrack > 0) // bonus
			{
				FormatEx(sMessage, sizeof(sMessage), "%s\n- Bonus %d/%d -\n", sMessage,
					huddata.iTrack, Shavit_GetMapBonuses());
			}

			if((gI_HUD2Settings[client] & HUD2_WRPB) == 0)
			{
				if(huddata.iFinishNum != 0)
					FormatEx(sMessage, sizeof(sMessage), "%sSR: %s (%s)\n", sMessage,
							sWRTime, sWRName);
				else
					FormatEx(sMessage, sizeof(sMessage), "%sSR: None\n", sMessage);
			}

			if(huddata.fPB != 0.0)
				FormatEx(sMessage, sizeof(sMessage), "%sPB: %s (#%d/%d)\n", sMessage,
					sPBTime, huddata.iRank, huddata.iFinishNum);
			else
				FormatEx(sMessage, sizeof(sMessage), "%sPB: None\n", sMessage);
		}

		// SRCP and PBCP
		huddata.iStage = (bReplay) ? Shavit_GetReplayBotStage(target) : Shavit_GetCurrentStage(target);

		if(huddata.iStage > Shavit_GetMapStages())
		{
			huddata.iStage = Shavit_GetMapStages();
		}

		if (huddata.iStage > 0 && huddata.iTrack == Track_Main)
		{
			Shavit_GetWRStageName(huddata.iStyle, huddata.iStage, sWRName, sizeof(sWRName));

			stage_t pb;
			Shavit_GetStagePB((bReplay) ? client : target, huddata.iStyle, huddata.iStage, pb, sizeof(stage_t));

			huddata.fPB = pb.fTime;
			huddata.fWR = Shavit_GetWRStageTime(huddata.iStage, huddata.iStyle);

			FormatHUDSeconds(huddata.fWR, sWRTime, sizeof(sWRTime));
			FormatHUDSeconds(huddata.fPB, sPBTime, sizeof(sPBTime));

			huddata.iFinishNum = (huddata.iStyle == -1 || huddata.iStage == -1) ? Shavit_GetStageRecordAmount(0, 0) : Shavit_GetStageRecordAmount(huddata.iStyle, huddata.iStage);
			huddata.iRank = Shavit_GetStageRankForTime(huddata.iStyle, huddata.fPB, huddata.iStage);

			FormatEx(sMessage, sizeof(sMessage), "%s\n- Stage %d/%d -\n", sMessage,
				huddata.iStage, Shavit_GetMapStages());

			if((gI_HUD2Settings[client] & HUD2_WRPB) == 0)
			{
				if(huddata.iFinishNum != 0)
					FormatEx(sMessage, sizeof(sMessage), "%sSRCP: %s (%s)\n", sMessage,
						sWRTime, sWRName);
				else
					FormatEx(sMessage, sizeof(sMessage), "%sSRCP: None\n", sMessage);
			}

			if(huddata.fPB != 0.0)
				FormatEx(sMessage, sizeof(sMessage), "%sPBCP: %s (#%d/%d)\n\n", sMessage,
					sPBTime, huddata.iRank, huddata.iFinishNum);
			else
				FormatEx(sMessage, sizeof(sMessage), "%sPBCP: None\n\n", sMessage);
		}

		// spec
		if(target == client || (gI_HUDSettings[client] & HUD_OBSERVE) > 0)
		{
			if((gI_HUDSettings[client] & HUD_SPECTATORS) > 0)
			{
				int iSpectatorClients[MAXPLAYERS+1];
				int iSpectators = 0;
				bool bIsAdmin = CheckCommandAccess(client, "admin_speclisthide", ADMFLAG_KICK);

				for(int i = 1; i <= MaxClients; i++)
				{
					if(i == client || !IsValidClient(i) || IsFakeClient(i) || !IsClientObserver(i) || GetClientTeam(i) < 1 || GetSpectatorTarget(i, i) != target)
					{
							continue;
					}

					if((gCV_SpectatorList.IntValue == 1 && !bIsAdmin && CheckCommandAccess(i, "admin_speclisthide", ADMFLAG_KICK)) ||
						(gCV_SpectatorList.IntValue == 2 && !CanUserTarget(client, i)))
					{
						continue;
					}

					iSpectatorClients[iSpectators++] = i;
				}

				if(iSpectators > 0)
				{
					Format(sMessage, 256, "%s%s%spectators (%d):", sMessage, (strlen(sMessage) > 0)? "\n\n":"", (client == target)? "S":"Other S", iSpectators);
					char sName[MAX_NAME_LENGTH];

					for(int i = 0; i < iSpectators; i++)
					{
						if(i == 7)
						{
							Format(sMessage, 256, "%s\n...", sMessage);

							break;
						}

						GetClientName(client, sName, sizeof(sName));
						TrimTrailingInvalidUnicode(sName);

						ReplaceString(sName, sizeof(sName), "#", "?");
						TrimDisplayString(sName, sName, sizeof(sName), gCV_SpecNameSymbolLength.IntValue);
						Format(sMessage, 256, "%s\n%s", sMessage, sName);
					}
				}
			}
		}

		if(strlen(sMessage) > 0)
		{
			Handle hKeyHintText = StartMessageOne("KeyHintText", client);
			BfWriteByte(hKeyHintText, 1);
			BfWriteString(hKeyHintText, sMessage);
			EndMessage();
		}
	}
}

static void DrawCenterKeys(int client)
{
	if((gI_HUDSettings[client] & HUD_KEYOVERLAY) == 0)
	{
		return;
	}

	int target = GetSpectatorTarget(client, client);

	if(((gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target))
	{
		return;
	}

	if (IsValidClient(target))
	{
		if (IsClientObserver(target))
		{
			return;
		}
	}
	else if (!(gB_Replay && Shavit_IsReplayEntity(target)))
	{
		return;
	}

	float fAngleDiff;
	int buttons;

	if (IsValidClient(target))
	{
		fAngleDiff = gF_AngleDiff[target];
		buttons = gI_Buttons[target];
	}
	else
	{
		buttons = Shavit_GetReplayButtons(target, fAngleDiff);
	}

	int style = (gB_Replay && Shavit_IsReplayEntity(target))? Shavit_GetReplayBotStyle(target):Shavit_GetBhopStyle(target);

	if(!(0 <= style < gI_Styles))
	{
		style = 0;
	}

	char sCenterText[254];

	FillCenterKeys(buttons, fAngleDiff, sCenterText, sizeof(sCenterText));
	UnreliablePrintCenterText(client, sCenterText);
}

static void FillCenterKeys(int buttons, float fAngleDiff, char[] buffer, int buflen)
{
	FormatEx(buffer, buflen, "　  %s　　%s\n  %s   %s   %s\n  %s　 %s 　%s\n　  %s　　%s",
		(buttons & IN_JUMP) > 0? "Ｊ":"ｰ", (buttons & IN_DUCK) > 0? "Ｃ":"ｰ",
		(fAngleDiff > 0) ? "<":"  ", (buttons & IN_FORWARD) > 0 ? "Ｗ":" ｰ", (fAngleDiff < 0) ? ">":"",
		(buttons & IN_MOVELEFT) > 0? "Ａ":"ｰ", (buttons & IN_BACK) > 0? "Ｓ":"ｰ", (buttons & IN_MOVERIGHT) > 0? "Ｄ":"ｰ",
		(buttons & IN_LEFT) > 0? "Ｌ":" ", (buttons & IN_RIGHT) > 0? "Ｒ":" ");
}

static void UnreliablePrintCenterText(int client, const char[] str)
{
	int clients[1];
	clients[0] = client;

	// Start our own message instead of using PrintCenterText so we can exclude USERMSG_RELIABLE.
	// This makes the HUD update visually faster.
	BfWrite msg = view_as<BfWrite>(StartMessageEx(gI_TextMsg, clients, 1, 0));
	msg.WriteByte(HUD_PRINTCENTER);
	msg.WriteString(str);
	msg.WriteString("");
	msg.WriteString("");
	msg.WriteString("");
	msg.WriteString("");
	EndMessage();
}

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