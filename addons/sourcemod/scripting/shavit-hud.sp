/*
 * shavit's Timer - HUD
 * by: shavit
 *
 * This file is part of shavit's Timer.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <convar_class>
#include <dhooks>
#include <shavit>
#include <shavit/colors>
#include <shavit/wr>
#include <shavit/replay-playback>

#undef REQUIRE_PLUGIN
#include <shavit/hud>

#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name = "[shavit] HUD",
	author = "shavit",
	description = "HUD for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}


#define MAX_HINT_SIZE 1024

// modules
bool gB_Replay = false;
bool gB_Zones = false;
bool gB_Sounds = false;

// cache
int gI_Styles = 0;


int gI_HUDSettings[MAXPLAYERS+1];
int gI_HUD2Settings[MAXPLAYERS+1];
int gI_Buttons[MAXPLAYERS+1];
int gI_PreviousSpeed[MAXPLAYERS+1];
float gF_Angle[MAXPLAYERS+1];
float gF_PreviousAngle[MAXPLAYERS+1];
float gF_AngleDiff[MAXPLAYERS+1];

bool gB_Late = false;
char gS_HintPadding[MAX_HINT_SIZE+1];

// plugin cvars
Convar gCV_TicksPerUpdate = null;
Convar gCV_SpectatorList = null;
Convar gCV_SpecNameSymbolLength = null;
Convar gCV_PrestrafeMessage = null;
Convar gCV_DefaultHUD = null;
Convar gCV_DefaultHUD2 = null;

// cookies
Cookie gH_HUDCookie = null;
Cookie gH_HUDCookieMain = null;

// sync hud text
Handle gH_SyncTextHud;

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// stuff
char gS_PreStrafeDiff[MAXPLAYERS+1][64];
char gS_DiffTime[MAXPLAYERS+1][64];
char gS_Map[160];
int gI_BotLastStage[MAXPLAYERS+1];


#include "shavit-hud/hud/hint.sp"
#include "shavit-hud/hud/panel.sp"
#include "shavit-hud/hud/synctext.sp"

#include "shavit-hud/api.sp"
#include "shavit-hud/commands.sp"
#include "shavit-hud/cookie.sp"
#include "shavit-hud/menu.sp"
//#include "shavit-hud/messages.sp"



// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin is only support for CS:GO");
		return APLRes_Failure;
	}

	CreateNatives();

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-hud");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-hud.phrases");

	CreateConVars();
	RegisterCommands();
	InitHintSize();
	InitCookies();

	gH_SyncTextHud = CreateHudSynchronizer();

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());

		ForceAllClientsCached();
	}

	// prevent errors in case the replay bot isn't loaded
	gB_Replay = LibraryExists("shavit-replay-playback");
	gB_Zones = LibraryExists("shavit-zones");
	gB_Sounds = LibraryExists("shavit-sounds");
}

public void OnMapStart()
{
	GetCurrentMap(gS_Map, sizeof(gS_Map));
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-replay-playback"))
	{
		gB_Replay = true;
	}
	else if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = true;
	}
	else if(StrEqual(name, "shavit-sounds"))
	{
		gB_Sounds = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-replay-playback"))
	{
		gB_Replay = false;
	}
	else if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = false;
	}
	else if(StrEqual(name, "shavit-sounds"))
	{
		gB_Sounds = false;
	}
}

public void OnConfigsExecuted()
{
	ConVar sv_hudhint_sound = FindConVar("sv_hudhint_sound");

	if(sv_hudhint_sound != null)
	{
		sv_hudhint_sound.BoolValue = false;
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	gI_Styles = styles;

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	gI_Buttons[client] = buttons;
	MakeAngleDiff(client, angles[1]);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client || (IsValidClient(i) && GetSpectatorTarget(i, i) == client))
		{
			UpdatePanelHud(i);
			UpdateSyncTextHud(i);
		}
	}

	return Plugin_Continue;
}

public void Shavit_OnStop(int client, int track)
{
	ResetPrestrafeDiff(client);
}

public Action Shavit_OnStart(int client, int track)
{
	ResetPrestrafeDiff(client);

	return Plugin_Continue;
}

public Action Shavit_OnStage(int client, int stage)
{
	ResetPrestrafeDiff(client);

	return Plugin_Continue;
}

public void Shavit_OnStartTimer_Post(int client, int style, int track, float speed)
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

public void Shavit_OnStageTimer_Post(int client, int style, int stage, float speed)
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

public void Shavit_OnWRCP(int client, int stage, int style, int steamid, int records, float oldtime, float time, float leavespeed, const char[] mapname)
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

public void Shavit_OnFinishStage_Post(int client, int stage, int style, float time, float diff, int overwrite, int records, int rank, bool wrcp, float leavespeed)
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

public void Shavit_OnFinishCheckpoint(int client, int cpnum, int style, float time, float wrdiff, float pbdiff, float prespeed)
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

public void Shavit_OnLeaveStage(int client, int stage, int style, float leavespeed, float time, bool stagetimer)
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

public void Shavit_OnEnterCheckpoint(int client, int cp, int style, float enterspeed, float time)
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

void FormatDiffPreStrafeSpeed(char[] buffer, float originSpeed, float wrSpeed)
{
	float diff = originSpeed - wrSpeed;

	if(wrSpeed <= 0.0)
	{
		strcopy(buffer, 64, "N/A");
	}
	else
	{
		if(diff > 0.0)
		{
			FormatEx(buffer, 64, "%t", "PrestrafeIncrease", RoundToFloor(diff));
		}
		else if(diff == 0.0)
		{
			FormatEx(buffer, 64, "%t", "PrestrafeNochange", RoundToFloor(diff));
		}
		else
		{
			FormatEx(buffer, 64, "%t", "PrestrafeDecrease", RoundToFloor(diff));
		}
	}
}

public void Shavit_OnEnterStageZone_Bot(int bot, int stage)
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

public void Shavit_OnLeaveStartZone_Bot(int bot, int track, float speed)
{
	if(Shavit_GetReplayBotTrack(bot) != track)
	{
		return;
	}

	SendMessageToSpectator(bot, "%t", "BotPrestrafe", RoundToFloor(speed), true);
}

public void Shavit_OnLeaveStageZone_Bot(int bot, int stage, float speed)
{
	if(Shavit_GetReplayBotTrack(bot) != Track_Main || 
		(Shavit_GetReplayBotStage(bot) != 0 && Shavit_GetReplayBotStage(bot) != stage))
	{
		return;
	}

	SendMessageToSpectator(bot, "%t", "BotPrestrafe", RoundToFloor(speed), true);
}

public void Shavit_OnLeaveCheckpointZone_Bot(int bot, int cp, float speed)
{
	if(Shavit_GetReplayBotTrack(bot) != Track_Main)
	{
		return;
	}

	SendMessageToSpectator(bot, "%t", "BotPrestrafe", RoundToFloor(speed), true);
}

public void OnClientPutInServer(int client)
{
	ResetPrestrafeDiff(client);

	if(IsFakeClient(client))
	{
		SDKHook(client, SDKHook_PostThinkPost, PostThinkPost);
	}
}

public void PostThinkPost(int client)
{
	int buttons = GetClientButtons(client);

	float ang[3];
	GetClientEyeAngles(client, ang);

	if(gI_Buttons[client] != buttons || ang[1] != gF_Angle[client])
	{
		gI_Buttons[client] = buttons;

		if (ang[1] != gF_Angle[client])
		{
			MakeAngleDiff(client, ang[1]);
		}

		for(int i = 1; i <= MaxClients; i++)
		{
			if(i != client && (IsValidClient(i) && GetSpectatorTarget(i, i) == client))
			{
				UpdatePanelHud(i);
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	OnClientCookiesCached_HUDMain(client);
	OnClientCookiesCached_HUD2(client);
}

public void OnGameFrame()
{
	if((GetGameTickCount() % gCV_TicksPerUpdate.IntValue) == 0)
	{
		Cron();
	}
}

void Cron()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || (gI_HUDSettings[i] & HUD_MASTER) == 0)
		{
			continue;
		}

		UpdateHintHud(i);
		UpdatePanelHud(i);

		float fSpeed[3];
		GetEntPropVector(GetSpectatorTarget(i, i), Prop_Data, "m_vecAbsVelocity", fSpeed);
		gI_PreviousSpeed[i] = RoundToNearest(((gI_HUDSettings[i] & HUD_2DVEL) == 0)? GetVectorLength(fSpeed):(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0))));
	}
}

// =====[ PUBLIC ]=====

void ResetPrestrafeDiff(int client)
{
	strcopy(gS_PreStrafeDiff[client], sizeof(gS_PreStrafeDiff[]), "None");
}

void MakeAngleDiff(int client, float newAngle)
{
	gF_PreviousAngle[client] = gF_Angle[client];
	gF_Angle[client] = newAngle;
	gF_AngleDiff[client] = GetAngleDiff(newAngle, gF_PreviousAngle[client]);
}



// =====[ PRIVATE] =====

static void CreateConVars()
{
	gCV_TicksPerUpdate = new Convar("shavit_hud_ticksperupdate", "5", "How often (in ticks) should the HUD update?\nPlay around with this value until you find the best for your server.\nThe maximum value is your tickrate.", 0, true, 1.0, true, (1.0 / GetTickInterval()));
	gCV_SpectatorList = new Convar("shavit_hud_speclist", "0", "Who to show in the specators list?\n0 - everyone\n1 - all admins (admin_speclisthide override to bypass)\n2 - players you can target", 0, true, 0.0, true, 2.0);
	gCV_SpecNameSymbolLength = new Convar("shavit_hud_specnamesymbollength", "32", "Maximum player name length that should be displayed in spectators panel", 0, true, 0.0, true, float(MAX_NAME_LENGTH));
	gCV_PrestrafeMessage = new Convar("shavit_misc_prestrafemessage", "1", "Enable prestrafe message. Only works when player leave start/stage/checkpoint zone.", 0, true, 0.0, true, 1.0);

	char defaultHUD[8];
	IntToString(HUD_DEFAULT, defaultHUD, sizeof(defaultHUD));
	gCV_DefaultHUD = new Convar("shavit_hud_default", defaultHUD, "Default HUD settings as a bitflag\n"
		..."HUD_MASTER				1\n"
		..."HUD_CENTER				2\n"
		..."HUD_ZONEHUD				4\n"
		..."HUD_OBSERVE				8\n"
		..."HUD_SPECTATORS			16\n"
		..."HUD_KEYOVERLAY			32\n"
		..."HUD_HIDEWEAPON			64\n"
		..."HUD_TOPLEFT				128\n"
		..."HUD_SYNC					256\n"
		..."HUD_TIMELEFT				512\n"
		..."HUD_2DVEL				1024\n"
		..."HUD_NOSOUNDS				2048\n");

	IntToString(HUD_DEFAULT2, defaultHUD, sizeof(defaultHUD));
	gCV_DefaultHUD2 = new Convar("shavit_hud2_default", defaultHUD, "Default HUD2 settings as a bitflag of what to remove\n"
		..."HUD2_TIME				1\n"
		..."HUD2_SPEED				2\n"
		..."HUD2_WRPB				4\n"
		..."HUD2_PRESTRAFE			8\n");

	Convar.AutoExecConfig();
}

static void InitHintSize()
{
	for (int i = 0; i < MAX_HINT_SIZE; i++)
	{
		gS_HintPadding[i] = ' ';
	}

	gS_HintPadding[MAX_HINT_SIZE] = '\0';
}

static void ForceAllClientsCached()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);

			if(AreClientCookiesCached(i) && !IsFakeClient(i))
			{
				OnClientCookiesCached(i);
			}
		}
	}
}