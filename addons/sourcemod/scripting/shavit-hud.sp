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
#include <shavit/wr>
#include <shavit/replay-playback>

#pragma newdecls required
#pragma semicolon 1

// HUD2 - these settings will *disable* elements for the main hud
#define HUD2_NONE				0
#define HUD2_TIME				(1 << 0)
#define HUD2_SPEED				(1 << 1)
#define HUD2_WRPB				(1 << 2)// 0 pb | 1 WR
#define HUD2_PRESTRAFE			(1 << 3)

#define HUD_DEFAULT				(HUD_MASTER|HUD_CENTER|HUD_ZONEHUD|HUD_OBSERVE|HUD_TOPLEFT|HUD_SYNC|HUD_TIMELEFT|HUD_2DVEL|HUD_SPECTATORS)
#define HUD_DEFAULT2			(HUD2_NONE)

#define MAX_HINT_SIZE 1024

enum ZoneHUD
{
	ZoneHUD_None,
	ZoneHUD_Start,
	ZoneHUD_End,
	ZoneHUD_Stage
};

enum struct huddata_t
{
	int iTarget;
	float fTime;
	int iSpeed;
	int iStyle;
	int iTrack;
	int iStage;
	int iCheckpoint;
	int iJumps;
	int iStrafes;
	int iRank;
	float fSync;
	float fPB;
	float fWR;
	bool bReplay;
	bool bPractice;
	TimerStatus iTimerStatus;
	ZoneHUD iZoneHUD;
	int iFinishNum;
	bool bStageTimer;
	char sDiff[64];
	char sPreStrafe[64];
}

char gS_GlobalColorNames[][] =
{
	"{default}",
	"{team}",
	"{green}"
};

char gS_CSGOColorNames[][] =
{
	"{blue}",
	"{bluegrey}",
	"{darkblue}",
	"{darkred}",
	"{gold}",
	"{grey}",
	"{grey2}",
	"{lightgreen}",
	"{lightred}",
	"{lime}",
	"{orchid}",
	"{yellow}",
	"{palered}"
};

// modules
bool gB_Replay = false;
bool gB_Zones = false;
bool gB_Sounds = false;

// cache
int gI_Styles = 0;

Handle gH_HUDCookie = null;
Handle gH_HUDCookieMain = null;
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

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// stuff
char gS_PreStrafeDiff[MAXPLAYERS+1][64];
char gS_DiffTime[MAXPLAYERS+1][64];
char gS_Map[160];
int gI_BotLastStage[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[shavit] HUD",
	author = "shavit",
	description = "HUD for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// natives
	CreateNative("Shavit_ForceHUDUpdate", Native_ForceHUDUpdate);
	CreateNative("Shavit_GetHUDSettings", Native_GetHUDSettings);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-hud");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-hud.phrases");

	// game-specific
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin is only support for CS:GO");
		return;
	}

	// prevent errors in case the replay bot isn't loaded
	gB_Replay = LibraryExists("shavit-replay-playback");
	gB_Zones = LibraryExists("shavit-zones");
	gB_Sounds = LibraryExists("shavit-sounds");

	// plugin convars
	gCV_TicksPerUpdate = new Convar("shavit_hud_ticksperupdate", "5", "How often (in ticks) should the HUD update?\nPlay around with this value until you find the best for your server.\nThe maximum value is your tickrate.", 0, true, 1.0, true, (1.0 / GetTickInterval()));
	gCV_SpectatorList = new Convar("shavit_hud_speclist", "0", "Who to show in the specators list?\n0 - everyone\n1 - all admins (admin_speclisthide override to bypass)\n2 - players you can target", 0, true, 0.0, true, 2.0);
	gCV_SpecNameSymbolLength = new Convar("shavit_hud_specnamesymbollength", "32", "Maximum player name length that should be displayed in spectators panel", 0, true, 0.0, true, float(MAX_NAME_LENGTH));
	gCV_PrestrafeMessage = new Convar("shavit_misc_prestrafemessage", "1", "Enable prestrafe message. Only works when player leave start/stage/checkpoint zone.", 0, true, 0.0, true, 1.0);

	char defaultHUD[8];
	IntToString(HUD_DEFAULT, defaultHUD, 8);
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

	IntToString(HUD_DEFAULT2, defaultHUD, 8);
	gCV_DefaultHUD2 = new Convar("shavit_hud2_default", defaultHUD, "Default HUD2 settings as a bitflag of what to remove\n"
		..."HUD2_TIME				1\n"
		..."HUD2_SPEED				2\n"
		..."HUD2_WRPB				4\n"
		..."HUD2_PRESTRAFE			8\n");

	Convar.AutoExecConfig();

	for (int i = 0; i < MAX_HINT_SIZE; i++)
	{
		gS_HintPadding[i] = ' ';
	}
	gS_HintPadding[MAX_HINT_SIZE] = '\0';

	// commands
	RegConsoleCmd("sm_hud", Command_HUD, "Opens the HUD settings menu.");
	RegConsoleCmd("sm_options", Command_HUD, "Opens the HUD settings menu. (alias for sm_hud)");

	// hud togglers
	RegConsoleCmd("sm_keys", Command_Keys, "Toggles key display.");
	RegConsoleCmd("sm_showkeys", Command_Keys, "Toggles key display. (alias for sm_keys)");
	RegConsoleCmd("sm_showmykeys", Command_Keys, "Toggles key display. (alias for sm_keys)");

	RegConsoleCmd("sm_master", Command_Master, "Toggles HUD.");
	RegConsoleCmd("sm_masterhud", Command_Master, "Toggles HUD. (alias for sm_master)");

	RegConsoleCmd("sm_center", Command_Center, "Toggles center text HUD.");
	RegConsoleCmd("sm_centerhud", Command_Center, "Toggles center text HUD. (alias for sm_center)");

	RegConsoleCmd("sm_zonehud", Command_ZoneHUD, "Toggles zone HUD.");

	RegConsoleCmd("sm_hideweapon", Command_HideWeapon, "Toggles weapon hiding.");
	RegConsoleCmd("sm_hideweap", Command_HideWeapon, "Toggles weapon hiding. (alias for sm_hideweapon)");
	RegConsoleCmd("sm_hidewep", Command_HideWeapon, "Toggles weapon hiding. (alias for sm_hideweapon)");

	RegConsoleCmd("sm_truevel", Command_TrueVel, "Toggles 2D ('true') velocity.");
	RegConsoleCmd("sm_truvel", Command_TrueVel, "Toggles 2D ('true') velocity. (alias for sm_truevel)");
	RegConsoleCmd("sm_2dvel", Command_TrueVel, "Toggles 2D ('true') velocity. (alias for sm_truevel)");

	// cookies
	gH_HUDCookie = RegClientCookie("shavit_hud_setting", "HUD settings", CookieAccess_Protected);
	gH_HUDCookieMain = RegClientCookie("shavit_hud_settingmain", "HUD settings for hint text.", CookieAccess_Protected);

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());

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
}

public void OnMapStart()
{
	GetCurrentMap(gS_Map, 160);
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

void MakeAngleDiff(int client, float newAngle)
{
	gF_PreviousAngle[client] = gF_Angle[client];
	gF_Angle[client] = newAngle;
	gF_AngleDiff[client] = GetAngleDiff(newAngle, gF_PreviousAngle[client]);
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	gI_Buttons[client] = buttons;
	MakeAngleDiff(client, angles[1]);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client || (IsValidClient(i) && GetSpectatorTarget(i, i) == client))
		{
			TriggerHUDUpdate(i, true);
		}
	}

	return Plugin_Continue;
}

void ResetPrestrafeDiff(int client)
{
	strcopy(gS_PreStrafeDiff[client], sizeof(gS_PreStrafeDiff[]), "None");
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
				TriggerHUDUpdate(i, true);
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sHUDSettings[8];
	GetClientCookie(client, gH_HUDCookie, sHUDSettings, 8);

	if(strlen(sHUDSettings) == 0)
	{
		gCV_DefaultHUD.GetString(sHUDSettings, 8);

		SetClientCookie(client, gH_HUDCookie, sHUDSettings);
		gI_HUDSettings[client] = gCV_DefaultHUD.IntValue;
	}

	else
	{
		gI_HUDSettings[client] = StringToInt(sHUDSettings);
	}

	GetClientCookie(client, gH_HUDCookieMain, sHUDSettings, 8);

	if(strlen(sHUDSettings) == 0)
	{
		gCV_DefaultHUD2.GetString(sHUDSettings, 8);

		SetClientCookie(client, gH_HUDCookieMain, sHUDSettings);
		gI_HUD2Settings[client] = gCV_DefaultHUD2.IntValue;
	}

	else
	{
		gI_HUD2Settings[client] = StringToInt(sHUDSettings);
	}
}

void ToggleHUD(int client, int hud, bool chat)
{
	if(!(1 <= client <= MaxClients))
	{
		return;
	}

	char sCookie[16];
	gI_HUDSettings[client] ^= hud;
	IntToString(gI_HUDSettings[client], sCookie, 16);
	SetClientCookie(client, gH_HUDCookie, sCookie);

	if(chat)
	{
		char sHUDSetting[64];

		switch(hud)
		{
			case HUD_MASTER: FormatEx(sHUDSetting, 64, "%T", "HudMaster", client);
			case HUD_CENTER: FormatEx(sHUDSetting, 64, "%T", "HudCenter", client);
			case HUD_ZONEHUD: FormatEx(sHUDSetting, 64, "%T", "HudZoneHud", client);
			case HUD_OBSERVE: FormatEx(sHUDSetting, 64, "%T", "HudObserve", client);
			case HUD_SPECTATORS: FormatEx(sHUDSetting, 64, "%T", "HudSpectators", client);
			case HUD_KEYOVERLAY: FormatEx(sHUDSetting, 64, "%T", "HudKeyOverlay", client);
			case HUD_HIDEWEAPON: FormatEx(sHUDSetting, 64, "%T", "HudHideWeapon", client);
			case HUD_TOPLEFT: FormatEx(sHUDSetting, 64, "%T", "HudTopLeft", client);
			case HUD_SYNC: FormatEx(sHUDSetting, 64, "%T", "HudSync", client);
			case HUD_TIMELEFT: FormatEx(sHUDSetting, 64, "%T", "HudTimeLeft", client);
			case HUD_2DVEL: FormatEx(sHUDSetting, 64, "%T", "Hud2dVel", client);
			case HUD_NOSOUNDS: FormatEx(sHUDSetting, 64, "%T", "HudNoRecordSounds", client);
		}

		if((gI_HUDSettings[client] & hud) > 0)
		{
			Shavit_PrintToChat(client, "%T", "HudEnabledComponent", client, sHUDSetting);
		}

		else
		{
			Shavit_PrintToChat(client, "%T", "HudDisabledComponent", client, sHUDSetting);
		}
	}
}

public Action Command_Master(int client, int args)
{
	ToggleHUD(client, HUD_MASTER, true);

	return Plugin_Handled;
}

public Action Command_Center(int client, int args)
{
	ToggleHUD(client, HUD_CENTER, true);

	return Plugin_Handled;
}

public Action Command_ZoneHUD(int client, int args)
{
	ToggleHUD(client, HUD_ZONEHUD, true);

	return Plugin_Handled;
}

public Action Command_HideWeapon(int client, int args)
{
	ToggleHUD(client, HUD_HIDEWEAPON, true);

	return Plugin_Handled;
}

public Action Command_TrueVel(int client, int args)
{
	ToggleHUD(client, HUD_2DVEL, true);

	return Plugin_Handled;
}

public Action Command_Keys(int client, int args)
{
	ToggleHUD(client, HUD_KEYOVERLAY, true);

	return Plugin_Handled;
}

public Action Command_HUD(int client, int args)
{
	return ShowHUDMenu(client, 0);
}

Action ShowHUDMenu(int client, int item)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_HUD, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle("%T", "HUDMenuTitle", client);

	char sInfo[16];
	char sHudItem[64];
	FormatEx(sInfo, 16, "!%d", HUD_MASTER);
	FormatEx(sHudItem, 64, "%T", "HudMaster", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_CENTER);
	FormatEx(sHudItem, 64, "%T", "HudCenter", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_OBSERVE);
	FormatEx(sHudItem, 64, "%T", "HudObserve", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_SPECTATORS);
	FormatEx(sHudItem, 64, "%T", "HudSpectators", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_KEYOVERLAY);
	FormatEx(sHudItem, 64, "%T", "HudKeyOverlay", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_HIDEWEAPON);
	FormatEx(sHudItem, 64, "%T", "HudHideWeapon", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_2DVEL);
	FormatEx(sHudItem, 64, "%T", "Hud2dVel", client);
	menu.AddItem(sInfo, sHudItem);

	if(gB_Sounds)
	{
		FormatEx(sInfo, 16, "!%d", HUD_NOSOUNDS);
		FormatEx(sHudItem, 64, "%T", "HudNoRecordSounds", client);
		menu.AddItem(sInfo, sHudItem);
	}

	// HUD2 - disables selected elements
	FormatEx(sInfo, 16, "@%d", HUD2_TIME);
	FormatEx(sHudItem, 64, "%T", "HudTimeText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_SPEED);
	FormatEx(sHudItem, 64, "%T", "HudSpeedText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_WRPB);
	FormatEx(sHudItem, 64, "%T", "HudWRPBText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_PRESTRAFE);
	FormatEx(sHudItem, 64, "%T", "HudPrestrafeText", client);
	menu.AddItem(sInfo, sHudItem);

	menu.ExitButton = true;
	menu.DisplayAt(client, item, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_HUD(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sCookie[16];
		menu.GetItem(param2, sCookie, 16);

		int type = (sCookie[0] == '!')? 1:2;
		ReplaceString(sCookie, 16, "!", "");
		ReplaceString(sCookie, 16, "@", "");

		int iSelection = StringToInt(sCookie);

		if(type == 1)
		{
			gI_HUDSettings[param1] ^= iSelection;
			IntToString(gI_HUDSettings[param1], sCookie, 16);
			SetClientCookie(param1, gH_HUDCookie, sCookie);
		}

		else
		{
			gI_HUD2Settings[param1] ^= iSelection;
			IntToString(gI_HUD2Settings[param1], sCookie, 16);
			SetClientCookie(param1, gH_HUDCookieMain, sCookie);
		}

		ShowHUDMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_DisplayItem)
	{
		char sInfo[16];
		char sDisplay[64];
		int style = 0;
		menu.GetItem(param2, sInfo, 16, style, sDisplay, 64);

		int type = (sInfo[0] == '!')? 1:2;
		ReplaceString(sInfo, 16, "!", "");
		ReplaceString(sInfo, 16, "@", "");

		if(type == 1)
		{
			Format(sDisplay, 64, "[%s] %s", ((gI_HUDSettings[param1] & StringToInt(sInfo)) > 0)? "＋":"－", sDisplay);
		}

		else
		{
			Format(sDisplay, 64, "[%s] %s", ((gI_HUD2Settings[param1] & StringToInt(sInfo)) == 0)? "＋":"－", sDisplay);
		}

		return RedrawMenuItem(sDisplay);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
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

		TriggerHUDUpdate(i);

		float fSpeed[3];
		GetEntPropVector(GetSpectatorTarget(i, i), Prop_Data, "m_vecAbsVelocity", fSpeed);
		gI_PreviousSpeed[i] = RoundToNearest(((gI_HUDSettings[i] & HUD_2DVEL) == 0)? GetVectorLength(fSpeed):(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0))));
	}
}

void TriggerHUDUpdate(int client, bool keysonly = false) // keysonly because CS:S lags when you send too many usermessages
{
	if(!keysonly)
	{
		UpdateMainHUD(client);
		SetEntProp(client, Prop_Data, "m_bDrawViewmodel", ((gI_HUDSettings[client] & HUD_HIDEWEAPON) > 0)? 0:1);
	}

	if(((gI_HUDSettings[client] & HUD_KEYOVERLAY) > 0 || (gI_HUDSettings[client] & HUD_SPECTATORS) > 0) && (!gB_Zones || !Shavit_IsClientCreatingZone(client)) && (GetClientMenu(client, null) == MenuSource_None || GetClientMenu(client, null) == MenuSource_RawPanel))
	{
		bool bShouldDraw = false;
		Panel pHUD = new Panel();

		UpdateKeyOverlay(client, pHUD, bShouldDraw);
		pHUD.DrawItem("", ITEMDRAW_RAWLINE);

		UpdateSpectatorList(client, pHUD, bShouldDraw);

		if(bShouldDraw)
		{
			pHUD.Send(client, PanelHandler_Nothing, 1);
		}

		delete pHUD;
	}
}

void AddHUDLine(char[] buffer, int maxlen, const char[] line, int lines)
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

int AddHUDToBuffer(int client, huddata_t data, char[] buffer, int maxlen)
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

void UpdateMainHUD(int client)
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
	
	StrCat(sBuffer, 512, "<pre>");
	int iLines = AddHUDToBuffer(client, huddata, sBuffer, 512);
	StrCat(sBuffer, 512, "</pre>");

	if(iLines > 0)
	{
		PrintCSGOHUDText(client, sBuffer);
	}
}

void UpdateKeyOverlay(int client, Panel panel, bool &draw)
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

	char sPanelLine[128];

	Format(sPanelLine, 128, "%s［%s］　［%s］\n%s  %s  %s\n%s　 %s 　%s\n　%s　　%s", sPanelLine,
		(buttons & IN_JUMP) > 0? "Ｊ":"ｰ", (buttons & IN_DUCK) > 0? "Ｃ":"ｰ",
		(fAngleDiff > 0) ? "←":"   ", (buttons & IN_FORWARD) > 0 ? "Ｗ":"ｰ", (fAngleDiff < 0) ? "→":"",
		(buttons & IN_MOVELEFT) > 0? "Ａ":"ｰ", (buttons & IN_BACK) > 0? "Ｓ":"ｰ", (buttons & IN_MOVERIGHT) > 0? "Ｄ":"ｰ",
		(buttons & IN_LEFT) > 0? "Ｌ":" ", (buttons & IN_RIGHT) > 0? "Ｒ":" ");

	panel.DrawItem(sPanelLine, ITEMDRAW_RAWLINE);

	draw = true;
}

void UpdateSpectatorList(int client, Panel panel, bool &draw)
{
	if((gI_HUDSettings[client] & HUD_SPECTATORS) == 0)
	{
		return;
	}

	int target = GetSpectatorTarget(client, client);

	if(((gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target))
	{
		return;
	}

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
		char sName[MAX_NAME_LENGTH];
		char sSpectators[32];
		FormatEx(sSpectators, sizeof(sSpectators), "%T (%d):",
			(client == target) ? "SpectatorPersonal" : "SpectatorWatching", client,
			iSpectators);
		panel.DrawItem(sSpectators, ITEMDRAW_RAWLINE);

		for(int i = 0; i < iSpectators; i++)
		{
			if(i == 7)
			{
				panel.DrawItem("...", ITEMDRAW_RAWLINE);

				break;
			}

			GetClientName(iSpectatorClients[i], sName, sizeof(sName));
			ReplaceString(sName, sizeof(sName), "#", "?");
			TrimDisplayString(sName, sName, sizeof(sName), gCV_SpecNameSymbolLength.IntValue);

			panel.DrawItem(sName, ITEMDRAW_RAWLINE);
		}

		draw = true;
	}
}

public int PanelHandler_Nothing(Menu m, MenuAction action, int param1, int param2)
{
	// i don't need anything here
	return 0;
}

public int Native_ForceHUDUpdate(Handle handler, int numParams)
{
	int clients[MAXPLAYERS+1];
	int count = 0;

	int client = GetNativeCell(1);

	if(!IsValidClient(client))
	{
		ThrowNativeError(200, "Invalid client index %d", client);

		return -1;
	}

	clients[count++] = client;

	if(view_as<bool>(GetNativeCell(2)))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(i == client || !IsValidClient(i) || GetSpectatorTarget(i, i) != client)
			{
				continue;
			}

			clients[count++] = client;
		}
	}

	for(int i = 0; i < count; i++)
	{
		TriggerHUDUpdate(clients[i]);
	}

	return count;
}

public int Native_GetHUDSettings(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	if(!IsValidClient(client))
	{
		ThrowNativeError(200, "Invalid client index %d", client);

		return -1;
	}

	return gI_HUDSettings[client];
}

void PrintCSGOHUDText(int client, const char[] str)
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

stock void RemoveColors(char[] string, int size)
{
	for(int x = 0; x < sizeof(gS_GlobalColorNames); x++)
	{
		ReplaceString(string, size, gS_GlobalColorNames[x], "");
	}

	for(int x = 0; x < sizeof(gS_CSGOColorNames); x++)
	{
		ReplaceString(string, size, gS_CSGOColorNames[x], "");
	}
}

stock void SendMessageToSpectator(int client, const char[] message, any ..., bool translate = false)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && (IsValidClient(i) && GetSpectatorTarget(i, i) == client))
		{
			if(!translate)
			{
				Shavit_PrintToChat(i, message);
			}
			else
			{
				SetGlobalTransTarget(i);

				char sBuffer[256];
				VFormat(sBuffer, sizeof(sBuffer), message, 3);
				Shavit_PrintToChat(i, sBuffer);
			}
		}
	}
}