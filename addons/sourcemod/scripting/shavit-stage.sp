/*
 * shavit's Timer - stage
 * by: Ciallo-Ani
*/

#include <sourcemod>
#include <regex>
#include <shavit>
#include <shavit/stage>
#include <shavit/wr>



#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo =
{
	name = "[shavit] Stage",
	author = "Ciallo-Ani",
	description = "A modified Stage plugin for fork's surf timer.",
	version = "0.5",
	url = "https://github.com/Ciallo-Ani/surftimer"
};



// plugin cache
Database2 gH_SQL = null;
bool gB_Connected = false;

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

int gI_Styles = 0;
char gS_Map[160];


ArrayList gA_StageLeaderboard[STYLE_LIMIT][MAX_STAGES+1];

// cp info
stage_t gA_StageInfo[MAXPLAYERS+1][STYLE_LIMIT][MAX_STAGES+1];
cp_t gA_CheckpointInfo[MAXPLAYERS+1][STYLE_LIMIT][MAX_STAGES+1];

// current wr stats
stage_t gA_WRStageInfo[STYLE_LIMIT][MAX_STAGES+1];
cp_t gA_WRCPInfo[STYLE_LIMIT][MAX_STAGES+1];

// current player stats
int gI_CPStageAttemps[MAXPLAYERS+1][MAX_STAGES+1];
float gF_CPTime[MAXPLAYERS+1][MAX_STAGES+1];
float gF_CPEnterStageTime[MAXPLAYERS+1][MAX_STAGES+1];
float gF_PreSpeed[MAXPLAYERS+1][MAX_STAGES+1];
float gF_PostSpeed[MAXPLAYERS+1][MAX_STAGES+1];
float gF_DiffTime[MAXPLAYERS+1];

// menu
int gI_StyleChoice[MAXPLAYERS+1];
int gI_StageChoice[MAXPLAYERS+1];
char gS_MapChoice[MAXPLAYERS+1][160];
bool gB_DeleteMaptop[MAXPLAYERS+1];
bool gB_DeleteWRCP[MAXPLAYERS+1];


#include "shavit-stage/db/sql.sp"
#include "shavit-stage/db/cache_leaderboards.sp"
#include "shavit-stage/db/cache_pbs.sp"
#include "shavit-stage/db/cache_wrcp.sp"
#include "shavit-stage/db/cache_wrstage.sp"
#include "shavit-stage/db/create_tables.sp"
#include "shavit-stage/db/setup_database.sp"
#include "shavit-stage/db/process.sp"

#include "shavit-stage/menu/cpr.sp"
#include "shavit-stage/menu/maptop.sp"
#include "shavit-stage/menu/wrcp.sp"


#include "shavit-stage/api.sp"
#include "shavit-stage/cache.sp"
#include "shavit-stage/commands.sp"
#include "shavit-stage/stocks.sp"




// ======[ PLUGIN EVENTS ]======

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();

	RegPluginLibrary("shavit-stage");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-stage.phrases");

	CreateGlobalForwards();
	RegisterCommands();

	Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
	SQL_DBConnect();
}

public void OnClientPutInServer(int client)
{
	if(gB_Connected && !IsFakeClient(client))
	{
		ReLoadPlayerStatus(client);
	}
}

public void OnClientDisconnect(int client)
{
	ResetClientCache(client);
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	ResetWRStages();
	ResetWRCPs();

	ForceAllClientsCached();
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-zones"))
	{
		SetFailState("shavit-zones is required for the plugin to work.");
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
	}

	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		for(int j = 0; j <= MAX_STAGES; j++)
		{
			if(gA_StageLeaderboard[i][j] != null)
			{
				delete gA_StageLeaderboard[i][j];
			}

			gA_StageLeaderboard[i][j] = new ArrayList(sizeof(stage_t));
		}
	}

	gI_Styles = styles;
}

public Action Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(track != Track_Main)
	{
		return Plugin_Continue;
	}

	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
	float fPrespeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

	switch(type)
	{
		case Zone_Start:
		{
			// linear map hackfix
			gF_CPTime[client][0] = 0.0;

			// stage map hackfix
			gF_CPTime[client][1] = 0.0;
			gF_CPEnterStageTime[client][0] = 0.0;
			gF_CPEnterStageTime[client][1] = 0.0;

			for(int i = 0; i <= Shavit_GetMapStages(); i++)
			{
				gI_CPStageAttemps[client][i] = 0;
			}

			gF_DiffTime[client] = 0.0;
		}

		case Zone_Stage:
		{
			gF_PreSpeed[client][data] = fPrespeed;
			if(!Shavit_IsStageTimer(client))
			{
				gI_CPStageAttemps[client][data]++;
				gF_CPEnterStageTime[client][data] = Shavit_GetClientTime(client);
			}

			Call_OnEnterStage(client, data, Shavit_GetBhopStyle(client), fPrespeed, Shavit_GetClientTime(client), Shavit_IsStageTimer(client));
		}

		case Zone_Checkpoint:
		{
			gF_PreSpeed[client][data] = fPrespeed;

			Call_OnEnterCheckpoint(client, data, Shavit_GetBhopStyle(client), fPrespeed, Shavit_GetClientTime(client));
		}
	}

	return Plugin_Continue;
}

public Action Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	if(track != Track_Main || Shavit_IsTeleporting(client))
	{
		return Plugin_Continue;
	}

	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
	float fPostspeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

	switch(type)
	{
		case Zone_Start:
		{
			Shavit_SetLeaveStageTime(client, Shavit_GetClientTime(client));
		}

		case Zone_Stage:
		{
			Shavit_SetLeaveStageTime(client, Shavit_GetClientTime(client));
			gF_PostSpeed[client][data] = fPostspeed;

			Call_OnLeaveStage(client, data, Shavit_GetBhopStyle(client), fPostspeed, Shavit_GetClientTime(client), Shavit_IsStageTimer(client));
		}

		case Zone_Checkpoint:
		{
			gF_PostSpeed[client][data] = fPostspeed;

			Call_OnLeaveCheckpoint(client, data, Shavit_GetBhopStyle(client), fPostspeed, Shavit_GetClientTime(client));
		}
	}

	return Plugin_Continue;
}

public void Shavit_OnWRDeleted(int style, int id, int track, int accountid, const char[] mapname)
{
	if(track != Track_Main)
	{
		return;
	}

	DB_DeleteWRCheckPoints(style, accountid, mapname);
}

public void Shavit_OnFinish_Post(int client, int style, float time, int jumps, int strafes, float sync, int rank, int overwrite, int track, float oldtime, float avgvel, float maxvel, int timestamp)
{
	Shavit_OnFinish_Post_DBProcess(client, style, track, overwrite, rank);
}



// ======[ PRIVATE ]======

static void ForceAllClientsCached()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}