native int Shavit_GetMapTier(const char[] map = "");

void UpdateKeyHint(int client)
{
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

		int target = GetSpectatorTarget(client, client);
		bool bReplay = (gB_Replay && Shavit_IsReplayEntity(target));

		// SR and PB
		huddata_t huddata;

		huddata.iTarget = target;
		huddata.iStyle = (bReplay) ? Shavit_GetReplayBotStyle(target) : Shavit_GetBhopStyle(target);
		huddata.iTrack = (bReplay) ? Shavit_GetReplayBotTrack(target) : Shavit_GetClientTrack(target);

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

static bool TrimTrailingInvalidUnicode(char[] outstr)
{
	static int masks[3] = {0xC0, 0xE0, 0xF0};

	int maxidx = strlen(outstr)-1;

	for (int i = 0; (maxidx-i >= 0) && (i < 3); i++)
	{
		if ((outstr[maxidx-i] & masks[i]) == masks[i])
		{
			outstr[maxidx-i] = 0;
			return true;
		}
	}

	return false;
}

void UpdateCenterKeys(int client)
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