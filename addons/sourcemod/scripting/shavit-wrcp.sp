/*
 * shavit's Timer - wrcp
 * by: Ciallo
*/

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

/* Database gH_SQL = null;
bool gB_Connected = false;
bool gB_MySQL = false; */

/* char gS_Map[160]; */

int gI_LastStage[MAXPLAYERS + 1];
float gF_EnterStageTime[MAXPLAYERS + 1];
float gF_LeaveStageTime[MAXPLAYERS + 1];
float gF_StageTime[MAXPLAYERS + 1];

// misc cache
//bool gB_Late = false;

// table prefix
/* char gS_MySQLPrefix[32]; */

// chat settings
chatstrings_t gS_ChatStrings;

Handle gH_Forwards_EnterStage = null;
Handle gH_Forwards_LeaveStage = null;

public void OnPluginStart()
{
	LoadTranslations("shavit-wrcp.phrases");
	gH_Forwards_EnterStage = CreateGlobalForward("Shavit_OnEnterStage", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_LeaveStage = CreateGlobalForward("Shavit_OnLeaveStage", ET_Event, Param_Cell, Param_Cell);
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-zones"))
	{
		SetFailState("shavit-zones is required for the plugin to work.");
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessagePrefix, gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
}

public void Shavit_OnRestart(int client, int track)
{
	gI_LastStage[client] = 1;
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(!IsValidClient(client) || IsFakeClient(client) || track != Track_Main || Shavit_GetTimerStatus(client) == Timer_Stopped)
	{
		return;
	}

	if(type == Zone_Stage)
	{
		//do stuff
		gF_EnterStageTime[client] = Shavit_GetClientTime(client);

		Action aResult = Plugin_Continue;
		Call_StartForward(gH_Forwards_EnterStage);
		Call_PushCell(client);
		Call_PushCell(Shavit_GetClientStage(client));
		Call_Finish(aResult);
	}
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	if(!IsValidClient(client) || IsFakeClient(client) || track != Track_Main || Shavit_GetTimerStatus(client) == Timer_Stopped)
	{
		return;
	}

	if(type == Zone_Stage)
	{
		//do stuff
		gF_LeaveStageTime[client] = Shavit_GetClientTime(client);

		Action aResult = Plugin_Continue;
		Call_StartForward(gH_Forwards_LeaveStage);
		Call_PushCell(client);
		Call_PushCell(Shavit_GetClientStage(client));
		Call_Finish(aResult);
	}
}

public Action Shavit_OnEnterStage(int client, int stage)
{
	char sMessage[255];
	char sTime[32];

	if(stage > gI_LastStage[client] && stage - gI_LastStage[client] == 1)//1--->2 2--->3 ... n--->n+1
	{
		if(stage == 2)
		{
			gF_StageTime[client] = Shavit_GetClientTime(client);
		}

		else
		{
			gF_StageTime[client] = gF_EnterStageTime[client] - gF_LeaveStageTime[client];
		}

		FormatSeconds(gF_StageTime[client], sTime, 32, true);
		FormatEx(sMessage, 255, "%T", "ZoneStageTime", client, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText);
	}

	else if(stage == gI_LastStage[client])
	{
		return Plugin_Continue; 
	}

	else
	{
		FormatEx(sMessage, 255, "%T", "ZoneStageAvoidSkip", client, gS_ChatStrings.sWarning, gS_ChatStrings.sWarning);
	}

	Shavit_PrintToChat(client, "%s", sMessage);
	gI_LastStage[client] = stage;

	//total time
	FormatSeconds(Shavit_GetClientTime(client), sTime, 32, true);
	FormatEx(sMessage, 255, "%T", "ZoneStageEnterTotalTime", 
		client, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText);
	Shavit_PrintToChat(client, "%s", sMessage);

	return Plugin_Continue;
}

public Action Shavit_OnLeaveStage(int client, int stage)
{
	//TODO:prestrafe
	bool onGround = false;
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		onGround = true;
	}

	if(!onGround)
	{
		float fVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
		float prespeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

		char sMessage[64];
		FormatEx(sMessage, 255, "%T", "ZoneStagePrestrafe", client, gS_ChatStrings.sText, gS_ChatStrings.sVariable, prespeed, gS_ChatStrings.sText);
		Shavit_PrintToChat(client, "%s", sMessage);
	}

	return Plugin_Continue;
}