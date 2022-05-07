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
#include <shavit/core>
#include <shavit/colors>
#include <shavit/hud>
#include <shavit/wr>
#include <shavit/stage>
#include <shavit/replay-playback>
#include <shavit/zones>


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
#define HUD_PRINTCENTER 4

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
UserMsg gI_HintText = view_as<UserMsg>(-1);
UserMsg gI_TextMsg = view_as<UserMsg>(-1);

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// stuff
char gS_PreStrafeDiff[MAXPLAYERS+1][64];
char gS_DiffTime[MAXPLAYERS+1][64];
char gS_Map[160];
int gI_BotLastStage[MAXPLAYERS+1];
int gI_Cycle;


#include "shavit-hud/draw.sp"

#include "shavit-hud/api.sp"
#include "shavit-hud/commands.sp"
#include "shavit-hud/cookie.sp"
#include "shavit-hud/menu.sp"
#include "shavit-hud/messages.sp"
#include "shavit-hud/stocks.sp"


// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSS)
	{
		SetFailState("This plugin is only support for CS:S");
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

	gI_HintText = GetUserMessageId("HintText");
	gI_TextMsg = GetUserMessageId("TextMsg");

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
			TriggerHUDUpdate(i, true);
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
	Shavit_OnStartTimer_Post_Message(client, style, track, speed);
}

public void Shavit_OnStageTimer_Post(int client, int style, int stage, float speed)
{
	Shavit_OnStageTimer_Post_Message(client, style, stage, speed);
}

public void Shavit_OnWRCP(int client, int stage, int style, int steamid, int records, float oldtime, float time, float leavespeed, const char[] mapname)
{
	Shavit_OnWRCP_Message(client, style, stage, records, time, oldtime);
}

public void Shavit_OnFinishStage_Post(int client, int stage, int style, float time, float diff, int overwrite, int records, int rank, bool wrcp, float leavespeed)
{
	Shavit_OnFinishStage_Post_Message(client, stage, style, time, diff, overwrite, records, rank);
}

public void Shavit_OnFinishCheckpoint(int client, int cpnum, int style, float time, float wrdiff, float pbdiff, float prespeed)
{
	Shavit_OnFinishCheckpoint_Message(client, cpnum, style, time, wrdiff, pbdiff);
}

public void Shavit_OnLeaveStage(int client, int stage, int style, float leavespeed, float time, bool stagetimer)
{
	Shavit_OnLeaveStage_Message(client, stage, style, leavespeed, stagetimer);
}

public void Shavit_OnEnterCheckpoint(int client, int cp, int style, float enterspeed, float time)
{
	Shavit_OnEnterCheckpoint_Message(client, cp, style, enterspeed);
}

public void Shavit_OnEnterStageZone_Bot(int bot, int stage)
{
	Shavit_OnEnterStageZone_Bot_Message(bot, stage);
}

public void Shavit_OnRestart(int client, int track)
{
	if(IsClientInGame(client))
	{
		TriggerHUDUpdate(client, false, true, true);
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if(IsClientInGame(client))
	{
		TriggerHUDUpdate(client, false, true, true);
	}
}

public void Shavit_OnTrackChanged(int client, int oldtrack, int newtrack)
{
	if(IsClientInGame(client))
	{
		TriggerHUDUpdate(client, false, true, true);
	}
}

public void Shavit_OnStageChanged(int client, int oldstage, int newstage)
{
	if(IsClientInGame(client))
	{
		TriggerHUDUpdate(client, false, true, true);
	}
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
	if(++gI_Cycle >= 65535)
	{
		gI_Cycle = 0;
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || (gI_HUDSettings[i] & HUD_MASTER) == 0)
		{
			continue;
		}

		if((gI_Cycle % 50) == 0)
		{
			float fSpeed[3];
			GetEntPropVector(GetSpectatorTarget(i, i), Prop_Data, "m_vecAbsVelocity", fSpeed);
			gI_PreviousSpeed[i] = RoundToNearest(((gI_HUDSettings[i] & HUD_2DVEL) == 0)? GetVectorLength(fSpeed):(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0))));
		}
	
		TriggerHUDUpdate(i);
	}
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
		..."HUD_UNUSED				128\n"
		..."HUD_SYNC					256\n"
		..."HUD_TIMELEFT				512\n"
		..."HUD_2DVEL				1024\n"
		..."HUD_NOSOUNDS				2048\n"
		..."HUD_MAPTIER				4096");

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