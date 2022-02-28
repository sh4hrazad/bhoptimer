/*
 * shavit's Timer - Checkpoints
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
#include <clientprefs>
#include <convar_class>
#include <shavit>
#include <shavit/replay-recorder>
#include <shavit/replay-playback>

#undef REQUIRE_PLUGIN
#include <shavit/checkpoints>



#pragma newdecls required
#pragma semicolon 1
#pragma dynamic 524288

public Plugin myinfo =
{
	name = "[shavit] Checkpoints",
	author = "shavit",
	description = "Checkpoints for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}



bool gB_Late = false;
char gS_Map[PLATFORM_MAX_PATH];
char gS_PreviousMap[PLATFORM_MAX_PATH];

int gI_Style[MAXPLAYERS+1];

ArrayList gA_Checkpoints[MAXPLAYERS+1];
int gI_CurrentCheckpoint[MAXPLAYERS+1];
int gI_TimesTeleported[MAXPLAYERS+1];
bool gB_InCheckpointMenu[MAXPLAYERS+1];

int gI_CheckpointsSettings[MAXPLAYERS+1];

// save states
bool gB_SaveStates[MAXPLAYERS+1]; // whether we have data for when player rejoins from spec
ArrayList gA_PersistentData = null;

// cookies
Cookie gH_CheckpointsCookie = null;

// cvars
Convar gCV_Checkpoints = null;
Convar gCV_RestoreStates = null;
Convar gCV_MaxCP = null;
Convar gCV_MaxCP_Segmented = null;
Convar gCV_PersistData = null;
Convar gCV_StopTimerWarning = null;
Convar gCV_ExperimentalSegmentedEyeAngleFix = null;

// modules
bool gB_Replay = false;

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

// other client's checkpoint
int gI_OtherClientIndex[MAXPLAYERS+1];
int gI_OtherCurrentCheckpoint[MAXPLAYERS+1];
bool gB_UsingOtherCheckpoint[MAXPLAYERS+1];


#include "shavit-checkpoints/cache/checkpoint.sp"
#include "shavit-checkpoints/cache/persistdata.sp"

#include "shavit-checkpoints/menu/cp_myself.sp"
#include "shavit-checkpoints/menu/cp_other.sp"

#include "shavit-checkpoints/api.sp"
#include "shavit-checkpoints/cookies.sp"
#include "shavit-checkpoints/commands.sp"



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin only support for CSGO!");
		return APLRes_Failure;
	}

	CreateNatives();

	RegPluginLibrary("shavit-checkpoints");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-misc.phrases");

	CreateGlobalForwards();
	CreateConVars();
	HookEvents();
	RegisterCommands();
	InitCaches();
	InitCookies();

	CreateTimer(10.0, Timer_Cron, 0, TIMER_REPEAT);

	gB_Replay = LibraryExists("shavit-replay-recorder");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-replay-recorder"))
	{
		gB_Replay = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-replay-recorder"))
	{
		gB_Replay = false;
	}
}

public void OnMapStart()
{
	GetLowercaseMapName(gS_Map);

	if (gB_Late)
	{
		gB_Late = false;
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());

		ForceAllClientsCached();
	}

	OnMapStart_ShouldClearCache();
}

public void OnMapEnd()
{
	gS_PreviousMap = gS_Map;
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	OnClientCookiesCached_Checkpoints(client);

	gI_Style[client] = Shavit_GetBhopStyle(client);
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	gI_Style[client] = newstyle;

	if(gB_SaveStates[client] && manual)
	{
		DeletePersistentDataFromClient(client);
	}

	if(StrContains(gS_StyleStrings[newstyle].sSpecialString, "segments") != -1)
	{
		// Gammacase somehow had this callback fire before OnClientPutInServer.
		// OnClientPutInServer will still fire but we need a valid arraylist in the mean time.
		if(gA_Checkpoints[client] == null)
		{
			gA_Checkpoints[client] = new ArrayList(sizeof(cp_cache_t));	
		}

		OpenCheckpointsMenu(client);
		Shavit_PrintToChat(client, "%T", "MiscSegmentedCommand", client);
	}
}

public void OnClientPutInServer(int client)
{
	if(!AreClientCookiesCached(client))
	{
		gI_Style[client] = Shavit_GetBhopStyle(client);
		gI_CheckpointsSettings[client] = CP_DEFAULT;
	}

	if(gA_Checkpoints[client] == null)
	{
		gA_Checkpoints[client] = new ArrayList(sizeof(cp_cache_t));	
	}
	else 
	{
		ResetCheckpoints(client);
	}

	gB_SaveStates[client] = false;
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	PersistData(client, true);

	// if data wasn't persisted, then we have checkpoints to reset...
	ResetCheckpoints(client);
	delete gA_Checkpoints[client];
}

public void Shavit_OnPause(int client, int track)
{
	Shavit_OnPause_PersistData(client);
}

public void Shavit_OnResume(int client, int track)
{
	Shavit_OnResume_LoadPersistentData(client);
}

public void Shavit_OnStop(int client, int track)
{
	Shavit_OnStop_DeletePersistentDataFromClient(client);
}

public void Shavit_OnRestart(int client, int track)
{
	gB_UsingOtherCheckpoint[client] = false;
}

public Action Shavit_OnFinishPre(int client, timer_snapshot_t snapshot)
{
	if(gB_UsingOtherCheckpoint[client])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public bool Shavit_OnStopPre(int client, int track)
{
	return Shavit_OnStopPre_Checkpoint(client);
}

public Action Shavit_OnStart(int client)
{
	gI_TimesTeleported[client] = 0;

	return Plugin_Continue;
}

public void Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsFakeClient(client))
	{
		int serial = GetClientSerial(client);

		if(gB_SaveStates[client])
		{
			if(gCV_RestoreStates.BoolValue)
			{
				// events&outputs won't work properly unless we do this next frame...
				RequestFrame(LoadPersistentData, serial);
			}
			else
			{
				ResetStageStatus(client);
			}
		}
		else
		{
			persistent_data_t aData;
			int iIndex = FindPersistentData(client, aData);

			if (iIndex != -1)
			{
				gB_SaveStates[client] = true;
				// events&outputs won't work properly unless we do this next frame...
				RequestFrame(LoadPersistentData, serial);
			}
			else
			{
				ResetStageStatus(client);
			}
		}
	}
}

public Action Player_Notifications(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsFakeClient(client))
	{
		if(!gB_SaveStates[client])
		{
			PersistData(client, false);
		}
	}

	return Plugin_Continue;
}

public Action Timer_Cron(Handle timer)
{
	if (gCV_PersistData.IntValue < 0)
	{
		return Plugin_Continue;
	}

	int iTime = GetTime();
	int iLength = gA_PersistentData.Length;

	for(int i = iLength - 1; i >= 0; i--)
	{
		persistent_data_t aData;
		gA_PersistentData.GetArray(i, aData);

		if(aData.iDisconnectTime && (iTime - aData.iDisconnectTime >= gCV_PersistData.IntValue))
		{
			DeletePersistentData(i, aData);
		}
	}

	return Plugin_Continue;
}

// ======[ PUBLIC ]======

bool CanSegment(int client)
{
	return StrContains(gS_StyleStrings[gI_Style[client]].sSpecialString, "segments") != -1;
}

int GetMaxCPs(int client)
{
	return CanSegment(client)? gCV_MaxCP_Segmented.IntValue:gCV_MaxCP.IntValue;
}

void ResetStageStatus(int client)
{
	Shavit_SetCurrentStage(client, 0);
	Shavit_SetCurrentCP(client, 0);
	Shavit_SetLastStage(client, 0);
	Shavit_SetLastCP(client, 0);
}



// ======[ PRIVATE ]======

static void CreateConVars()
{
	gCV_Checkpoints = new Convar("shavit_misc_checkpoints", "1", "Allow players to save and teleport to checkpoints.", 0, true, 0.0, true, 1.0);
	gCV_RestoreStates = new Convar("shavit_misc_restorestates", "1", "Save the players' timer/position etc.. when they die/change teams,\nand load the data when they spawn?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_MaxCP = new Convar("shavit_misc_maxcp", "1000", "Maximum amount of checkpoints.\nNote: Very high values will result in high memory usage!", 0, true, 1.0, true, 10000.0);
	gCV_MaxCP_Segmented = new Convar("shavit_misc_maxcp_seg", "100", "Maximum amount of segmented checkpoints. Make this less or equal to shavit_misc_maxcp.\nNote: Very high values will result in HUGE memory usage! Segmented checkpoints contain frame data!", 0, true, 10.0);
	gCV_PersistData = new Convar("shavit_misc_persistdata", "-1", "How long to persist timer data for disconnected users in seconds?\n-1 - Until map change\n0 - Disabled");
	gCV_StopTimerWarning = new Convar("shavit_misc_stoptimerwarning", "180", "Time in seconds to display a warning before stopping the timer with noclip or !stop.\n0 - Disabled");
	gCV_ExperimentalSegmentedEyeAngleFix = new Convar("shavit_misc_experimental_segmented_eyeangle_fix", "1", "When teleporting to a segmented checkpoint, the player's old eye-angles persist in replay-frames for as many ticks they're behind the server in latency. This applies the teleport-position angles to the replay-frame for that many ticks.", 0, true, 0.0, true, 1.0);

	Convar.AutoExecConfig();
}

static void HookEvents()
{
	HookEvent("player_spawn", Player_Spawn);
	HookEvent("player_team", Player_Notifications, EventHookMode_Pre);
	HookEvent("player_death", Player_Notifications, EventHookMode_Pre);
}

static void InitCaches()
{
	gA_PersistentData = new ArrayList(sizeof(persistent_data_t));
}

static void ForceAllClientsCached()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);

			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
				Shavit_OnStyleChanged(i, 0, Shavit_GetBhopStyle(i), Shavit_GetClientTrack(i), false);
			}
		}
	}
}