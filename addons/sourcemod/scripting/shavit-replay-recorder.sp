/*
 * shavit's Timer - Replay Recorder
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
#include <convar_class>
#include <shavit>
#include <shavit/replay-shared>
#include <shavit/replay-recorder>


#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo =
{
	name = "[shavit] Replay Recorder",
	author = "shavit",
	description = "A replay recorder for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

bool gB_Late = false;
char gS_Map[PLATFORM_MAX_PATH];
float gF_Tickrate = 0.0;

// timer settings
int gI_Styles = 0;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
char gS_ReplayFolder[PLATFORM_MAX_PATH];

Convar gCV_Enabled = null;
Convar gCV_PlaybackPreRunTime = null;
Convar gCV_PlaybackPostRunTime = null;
Convar gCV_StagePlaybackPreRunTime = null;
Convar gCV_StagePlaybackPostRunTime = null;
Convar gCV_PreRunAlways = null;
Convar gCV_TimeLimit = null;

enum struct finished_run_info
{
	int iSteamID;
	int style;
	float time;
	int jumps;
	int strafes;
	float sync;
	int track;
	float oldtime;
	float avgvel;
	float maxvel;
	int timestamp;
	float fZoneOffset[2];
}

enum struct wrcp_run_info
{
	int iStage;
	int iStyle;
	int iSteamid;
	float fTime;
}

finished_run_info gA_FinishedRunInfo[MAXPLAYERS+1];
wrcp_run_info gA_WRCPRunInfo[MAXPLAYERS+1];

// we use gI_PlayerFrames instead of grabbing gA_PlayerFrames.Length 
// because the ArrayList is resized to handle 2s worth of extra frames to reduce how often we have to resize it
ArrayList gA_PlayerFrames[MAXPLAYERS+1];
int gI_PlayerFrames[MAXPLAYERS+1];

// stuff related to preframes
int gI_PlayerPrerunFrames[MAXPLAYERS+1];
int gI_PlayerPrerunFrames_Stage[MAXPLAYERS+1];

// stuff related to postframes
bool gB_GrabbingPostFrames[MAXPLAYERS+1];
bool gB_GrabbingPostFrames_Stage[MAXPLAYERS+1];

int gI_HijackFrames[MAXPLAYERS+1];
float gF_HijackedAngles[MAXPLAYERS+1][2];
bool gB_HijackFramesKeepOnStart[MAXPLAYERS+1];

#include "shavit-replay-shared/file.sp"
#include "shavit-replay-shared/stocks.sp"

#include "shavit-replay-recorder/api.sp"
#include "shavit-replay-recorder/recording.sp"

// =====[ PLUGIN EVENTS ]=====

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();

	if (!FileExists("cfg/sourcemod/plugin.shavit-replay-recorder.cfg") && FileExists("cfg/sourcemod/plugin.shavit-replay.cfg"))
	{
		File source = OpenFile("cfg/sourcemod/plugin.shavit-replay.cfg", "r");
		File destination = OpenFile("cfg/sourcemod/plugin.shavit-replay-recorder.cfg", "w");

		if (source && destination)
		{
			char line[512];

			while (!source.EndOfFile() && source.ReadLine(line, sizeof(line)))
			{
				destination.WriteLine("%s", line);
			}
		}

		delete destination;
		delete source;
	}

	RegPluginLibrary("shavit-replay-recorder");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin only support for CSGO!");
		return;
	}

	CreateGlobalForwards();
	CreateConVars();

	gF_Tickrate = (1.0 / GetTickInterval());

	if(gB_Late)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsFakeClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnMapStart()
{
	if (!LoadReplayConfig())
	{
		SetFailState("Could not load the replay bots' configuration file. Make sure it exists (addons/sourcemod/configs/shavit-replay.cfg) and follows the proper syntax!");
	}

	GetLowercaseMapName(gS_Map);

	Replay_CreateDirectories(gS_ReplayFolder, gI_Styles);
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}

	gI_Styles = styles;
}

public void OnClientPutInServer(int client)
{
	OnClientPutInServer_Recording(client);
}

public void OnClientDisconnect(int client)
{
	OnClientDisconnect_StopRecording(client);
}

public void OnClientDisconnect_Post(int client)
{
	OnClientDisconnect_Post_StopRecording(client);
}

public Action Shavit_OnStart(int client)
{
	Shavit_OnStart_Recording(client);

	return Plugin_Continue;
}

public void Shavit_OnEnterStage(int client, int stage, int style, float enterspeed, float time, bool stagetimer)
{
	Shavit_OnEnterStage_Recording(client, stage, style, stagetimer);
}

public void Shavit_OnTeleportBackStagePost(int client, int stage, int style, bool stagetimer)
{
	Shavit_OnEnterStage_Recording(client, stage, style, stagetimer);
}

public void Shavit_OnLeaveStage(int client, int stage, int style, float leavespeed, float time, bool stagetimer)
{
	Shavit_OnLeaveStage_Recording(client, style);
}

public void Shavit_OnStop(int client)
{
	Shavit_OnTimerStop_Recording(client);
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float& oldtime, float avgvel, float maxvel, int timestamp)
{
	Shavit_OnFinish_Recording(client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp);
}

public void Shavit_OnWRCP(int client, int stage, int style, int steamid, int records, float oldtime, float time, float leavespeed, const char[] mapname)
{
	Shavit_OnWRCP_Recording(client, stage, style, steamid, time);
}

public void Shavit_OnTimescaleChanged(int client, float oldtimescale, float newtimescale)
{
	Shavit_OnTimescaleChanged_Recording(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsFakeClient(client) || !IsPlayerAlive(client))
	{
		return;
	}

	OnPlayerRunCmdPost_Recording(client, buttons, vel, mouse);
}



// =====[ PRIVATE ]=====

static void CreateConVars()
{
	gCV_Enabled = new Convar("shavit_replay_enabled", "1", "Enable replay bot functionality?", 0, true, 0.0, true, 1.0);
	gCV_TimeLimit = new Convar("shavit_replay_timelimit", "7200.0", "Maximum amount of time (in seconds) to allow saving to disk.\nDefault is 7200 (2 hours)\n0 - Disabled");
	gCV_PlaybackPreRunTime = new Convar("shavit_replay_preruntime", "1.5", "Time (in seconds) to record before a player leaves start zone.", 0, true, 0.0, true, 2.0);
	gCV_PlaybackPostRunTime = new Convar("shavit_replay_postruntime", "2.0", "Time (in seconds) to record after a player enters the end zone.", 0, true, 0.0, true, 2.0);
	gCV_StagePlaybackPreRunTime = new Convar("shavit_stage_replay_preruntime", "1.5", "Time (in seconds) to record before a player leaves stage zone.", 0, true, 0.0, true, 2.0);
	gCV_StagePlaybackPostRunTime = new Convar("shavit_stage_replay_postruntime", "1.5", "Time (in seconds) to record after a player finished a stage.", 0, true, 0.0, true, 2.0);
	gCV_PreRunAlways = new Convar("shavit_replay_prerun_always", "1", "Record prerun frames outside the start zone?", 0, true, 0.0, true, 1.0);

	Convar.AutoExecConfig();
}

static bool LoadReplayConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-replay.cfg");

	KeyValues kv = new KeyValues("shavit-replay");

	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	char sFolder[PLATFORM_MAX_PATH];
	kv.GetString("replayfolder", sFolder, PLATFORM_MAX_PATH, "{SM}/data/replaybot");

	if(StrContains(sFolder, "{SM}") != -1)
	{
		ReplaceString(sFolder, PLATFORM_MAX_PATH, "{SM}/", "");
		BuildPath(Path_SM, sFolder, PLATFORM_MAX_PATH, "%s", sFolder);
	}

	strcopy(gS_ReplayFolder, PLATFORM_MAX_PATH, sFolder);

	delete kv;

	return true;
}