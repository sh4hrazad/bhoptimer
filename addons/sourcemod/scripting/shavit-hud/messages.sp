void Shavit_OnStartTimer_Post_Message(int client, int style, int track, float speed)
{
	if(gCV_PrestrafeMessage.IntValue != 1 || (gI_HUD2Settings[client] & HUD2_PRESTRAFE) != 0 || (gI_HUDSettings[client] & HUD_MASTER) == 0)
	{
		return;
	}

	FormatDiffPreStrafeSpeed(gS_PreStrafeDiff[client], speed, Shavit_GetPrestrafeForRank(style, 1, track));

	char sPBDiff[64];
	FormatDiffPreStrafeSpeed(sPBDiff, speed, Shavit_GetClientPrestrafe(client, style, track));

	char sPrestrafe[256];
	FormatEx(sPrestrafe, sizeof(sPrestrafe), "%T", "StartPrestrafe", client, RoundToFloor(speed), gS_PreStrafeDiff[client], sPBDiff);

	Shavit_PrintToChat(client, sPrestrafe);
	SendMessageToSpectator(client, sPrestrafe);

	if(!Shavit_IsLinearMap() && track == Track_Main)
	{
		char sStageWRDiff[64];
		FormatDiffPreStrafeSpeed(sStageWRDiff, speed, Shavit_GetWRStagePostspeed(1, style));

		char sStagePBDiff[64];
		stage_t pb;
		Shavit_GetStagePB(client, style, 1, pb);
		FormatDiffPreStrafeSpeed(sStagePBDiff, speed, pb.fPostspeed);

		FormatEx(sPrestrafe, sizeof(sPrestrafe), "%T", "StagePrestrafe", client, 1, RoundToFloor(speed), sStageWRDiff, sStagePBDiff);

		Shavit_PrintToChat(client, sPrestrafe);
		SendMessageToSpectator(client, sPrestrafe);
	}
}

void Shavit_OnStageTimer_Post_Message(int client, int style, int stage, float speed)
{
	if(gCV_PrestrafeMessage.IntValue != 1 || (gI_HUD2Settings[client] & HUD2_PRESTRAFE) != 0 || (gI_HUDSettings[client] & HUD_MASTER) == 0)
	{
		return;
	}

	FormatDiffPreStrafeSpeed(gS_PreStrafeDiff[client], speed, Shavit_GetWRStagePostspeed(stage, style));

	stage_t pb;
	Shavit_GetStagePB(client, style, stage, pb);

	char sPBDiff[64];
	FormatDiffPreStrafeSpeed(sPBDiff, speed, pb.fPostspeed);

	char sPrestrafe[256];
	FormatEx(sPrestrafe, sizeof(sPrestrafe), "%T", "StagePrestrafe", client, stage, RoundToFloor(speed), gS_PreStrafeDiff[client], sPBDiff);
	Shavit_PrintToChat(client, sPrestrafe);
	SendMessageToSpectator(client, sPrestrafe);
}

void Shavit_OnWRCP_Message(int client, int style, int stage, int records, float time, float oldtime)
{
	char sTime[32];
	FormatSeconds(time, sTime, sizeof(sTime));

	char sDiffTime[32];
	char sRank[32];

	if(oldtime == -1.0)
	{
		FormatEx(sDiffTime, sizeof(sDiffTime), "N/A");
		FormatEx(sRank, sizeof(sRank), "1/1");
	}
	else
	{
		FormatSeconds(time - oldtime, sDiffTime, sizeof(sDiffTime));
		FormatEx(sRank, sizeof(sRank), "1/%d", records == 0 ? 1 : records);
	}

	Shavit_PrintToChatAll("%t", "OnWRCP", client, stage, gS_StyleStrings[style].sStyleName, sTime, sDiffTime, sRank);
}

void Shavit_OnFinishStage_Post_Message(int client, int stage, int style, float time, float diff, int overwrite, int records, int rank)
{
	float wrcpTime = Shavit_GetWRStageTime(stage, style);
	float wrcpDiff = time - wrcpTime;

	char sWRDifftime[32];
	char sPBDifftime[32];

	if(wrcpTime == -1.0)
	{
		FormatEx(sWRDifftime, sizeof(sWRDifftime), "N/A");
	}
	else
	{
		FormatSeconds(wrcpDiff, sWRDifftime, sizeof(sWRDifftime));

		if(wrcpDiff > 0)
		{
			Format(sWRDifftime, sizeof(sWRDifftime), "+%s", sWRDifftime);
		}
	}

	if(diff == time)
	{
		FormatEx(sPBDifftime, sizeof(sPBDifftime), "N/A");
	}
	else
	{
		FormatSeconds(diff, sPBDifftime, sizeof(sPBDifftime));

		if(diff > 0)
		{
			Format(sPBDifftime, sizeof(sPBDifftime), "+%s", sPBDifftime);
		}
	}

	char sMessage[255];

	char sTime[32];
	FormatSeconds(time, sTime, sizeof(sTime));

	switch(overwrite)
	{
		case PB_Insert, PB_Update:
		{
			char sRank[32];
			FormatEx(sRank, sizeof(sRank), "%d/%d", rank, overwrite == PB_Insert ? records + 1 : records);
			FormatEx(sMessage, sizeof(sMessage), "%T", "ZoneStageTime-Improved", client, stage, sTime, sWRDifftime, sPBDifftime, sRank);
		}
		case PB_NoQuery:
		{
			FormatEx(sMessage, sizeof(sMessage), "%T", "ZoneStageTime-Noimproved", client, stage, sTime, sWRDifftime, sPBDifftime);
		}
		case PB_UnRanked:
		{
			FormatEx(sMessage, sizeof(sMessage), 
				"{darkred}[未排名]{default} | {grey}关卡{default} [{orchid}%d{default}] | {grey2}%s{default} | {palered}WRCP{default} {yellow}%s{default} | {darkblue}PB{default} {yellow}%s{default}", 
				stage, sTime, sWRDifftime, sPBDifftime);
		}
	}

	Shavit_PrintToChat(client, sMessage);
	SendMessageToSpectator(client, sMessage);
}

void Shavit_OnFinishCheckpoint_Message(int client, int cpnum, int style, float time, float wrdiff, float pbdiff)
{
	int cpmax = (Shavit_IsLinearMap()) ? Shavit_GetMapCheckpoints() : Shavit_GetMapStages();

	if(cpnum > cpmax)
	{
		return;
	}

	char sTime[32];
	FormatSeconds(time, sTime, sizeof(sTime));

	char sWRDifftime[32];
	if(Shavit_GetWRCPTime(cpnum, style) == -1.0)
	{
		FormatEx(sWRDifftime, sizeof(sWRDifftime), "N/A");
		FormatEx(gS_DiffTime[client], sizeof(gS_DiffTime[]), "N/A");
	}
	else
	{
		FormatSeconds(wrdiff, sWRDifftime, sizeof(sWRDifftime));
		FormatHUDSeconds(wrdiff, gS_DiffTime[client], sizeof(gS_DiffTime[]));

		if(wrdiff > 0)
		{
			Format(sWRDifftime, sizeof(sWRDifftime), "+%s", sWRDifftime);
			Format(gS_DiffTime[client], sizeof(gS_DiffTime[]), "+%s", gS_DiffTime[client]);
		}
	}

	char sPBDifftime[32];
	if(pbdiff == time)
	{
		FormatEx(sPBDifftime, sizeof(sPBDifftime), "N/A");
	}
	else
	{
		FormatSeconds(pbdiff, sPBDifftime, sizeof(sPBDifftime));

		if(pbdiff > 0)
		{
			Format(sPBDifftime, sizeof(sPBDifftime), "+%s", sPBDifftime);
		}
	}

	char sMessage[255];
	FormatEx(sMessage, sizeof(sMessage), "%T", "ZoneCheckpointTime", client, cpnum, sTime, sWRDifftime, sPBDifftime);

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteString(sMessage);

	// make sure cpmessage is after stagemessage, in order to print cp prestrafe and get a smoother sight
	CreateTimer(0.1, Timer_CPTimeMessage, dp);
}

public Action Timer_CPTimeMessage(Handle timer, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	char sMessage[255];
	dp.ReadString(sMessage, sizeof(sMessage));

	delete dp;

	Shavit_PrintToChat(client, sMessage);
	SendMessageToSpectator(client, sMessage);

	return Plugin_Stop;
}

void Shavit_OnLeaveStage_Message(int client, int stage, int style, float leavespeed, bool stagetimer)
{
	if(stagetimer || Shavit_GetClientTime(client) == 0.0)
	{
		return;
	}

	FormatDiffPreStrafeSpeed(gS_PreStrafeDiff[client], leavespeed, Shavit_GetWRCPPostspeed(stage, style));

	cp_t pb;
	Shavit_GetCheckpointPB(client, style, stage, pb);

	char sPBDiff[64];
	FormatDiffPreStrafeSpeed(sPBDiff, leavespeed, pb.fPostspeed);

	char sPrestrafe[256];
	FormatEx(sPrestrafe, sizeof(sPrestrafe), "%T", "CPStagePrestrafe", client, stage, RoundToFloor(leavespeed), gS_PreStrafeDiff[client], sPBDiff);
	Shavit_PrintToChat(client, sPrestrafe);
	SendMessageToSpectator(client, sPrestrafe);
}

void Shavit_OnEnterCheckpoint_Message(int client, int cp, int style, float enterspeed)
{
	FormatDiffPreStrafeSpeed(gS_PreStrafeDiff[client], enterspeed, Shavit_GetWRCPPrespeed(cp, style));

	cp_t pb;
	Shavit_GetCheckpointPB(client, style, cp, pb);

	char sPBDiff[64];
	FormatDiffPreStrafeSpeed(sPBDiff, enterspeed, pb.fPrespeed);

	char sPrestrafe[256];
	FormatEx(sPrestrafe, sizeof(sPrestrafe), "%T", "CPLinearPrestrafe", client, cp, RoundToFloor(enterspeed), gS_PreStrafeDiff[client], sPBDiff);
	Shavit_PrintToChat(client, sPrestrafe);
	SendMessageToSpectator(client, sPrestrafe);
}

void Shavit_OnEnterStageZone_Bot_Message(int bot, int stage)
{
	if(Shavit_GetReplayBotStage(bot) != 0)
	{
		return;
	}

	int style = Shavit_GetReplayBotStyle(bot);
	if(style == -1 || Shavit_GetReplayBotTrack(bot) != Track_Main || gI_BotLastStage[bot] == stage) // invalid style or track or get into the same stage(dont print twice)
	{
		return;
	}

	gI_BotLastStage[bot] = stage;

	char sTime[32];
	float realtime = Shavit_GetWRCPRealTime(stage, style);
	float time = Shavit_GetWRCPTime(stage, style);
	int attemps = Shavit_GetWRCPAttemps(stage, style);
	bool failed = (attemps > 1);
	if(failed)
	{
		FormatHUDSeconds(realtime, sTime, 32);
	}
	else
	{
		FormatHUDSeconds(time, sTime, 32);
	}

	SendMessageToSpectator(bot, "%t", failed ? "EnterStageMessage_Bot_NoImproved" : "EnterStageMessage_Bot_Improved", stage, sTime, attemps, true);
}