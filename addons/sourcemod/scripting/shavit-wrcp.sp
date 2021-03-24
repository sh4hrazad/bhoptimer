/*
 * shavit's Timer - wrcp
 * by: Ciallo
*/

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

Database gH_SQL = null;
bool gB_Connected = false;
bool gB_MySQL = false;

char gS_Map[160];

int gI_LastStage[MAXPLAYERS + 1];
float gF_EnterStageTime[MAXPLAYERS + 1];
float gF_LeaveStageTime[MAXPLAYERS + 1];
float gF_StageTime[MAXPLAYERS + 1];

float gF_WrcpTime[MAX_ZONES - 2][STYLE_LIMIT];
char gS_WrcpName[MAX_ZONES - 2][STYLE_LIMIT][MAX_NAME_LENGTH];

// misc cache
//bool gB_Late = false;

// table prefix
char gS_MySQLPrefix[32];

// chat settings
chatstrings_t gS_ChatStrings;

Handle gH_Forwards_EnterStage = null;
Handle gH_Forwards_LeaveStage = null;
Handle gH_Forwards_OnWRCP = null;

public void OnPluginStart()
{
	LoadTranslations("shavit-wrcp.phrases");

	HookEvent("player_death", Player_Death);

	gH_Forwards_EnterStage = CreateGlobalForward("Shavit_OnEnterStage", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_LeaveStage = CreateGlobalForward("Shavit_OnLeaveStage", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnWRCP = CreateGlobalForward("Shavit_OnWRCP", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i))
		{
			OnClientPutInServer(i);
		}
	}

	SQL_DBConnect();
}

public void OnClientPutInServer(int client)
{
	gI_LastStage[client] = 1;
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	/* for(int i = 0; i < MAX_ZONES - 2; i++)
	{
		for(int i = 0; i < STYLE_LIMIT; i++)
		{
			gF_WrcpTime[MAX_ZONES - 2][STYLE_LIMIT] = -1.0;
		}
	} */

	LoadWrcp();

	/* if(gB_Late)
	{
		Shavit_OnChatConfigLoaded();
	} */
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

public void Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	gI_LastStage[client] = 1;
}

void LoadWrcp()
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
		"SELECT p1.auth, p1.stage, p1.style, p1.time, p1.map, p2.name FROM %swrcp p1 " ...
			"JOIN (SELECT auth, name FROM %susers) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s';", 
		gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_GetWrcp_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_GetWrcp_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (GetWrcp) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int stage = results.FetchInt(1);
		int style = results.FetchInt(2);
		float time = results.FetchFloat(3);
		gF_WrcpTime[stage][style] = time;

		char name[MAX_NAME_LENGTH];
		results.FetchString(4, name, sizeof(name));
		gS_WrcpName[stage][style] = name;
	}
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(!IsValidClient(client) || IsFakeClient(client) || track != Track_Main || Shavit_GetTimerStatus(client) == Timer_Stopped)
	{
		return;
	}

	if(type == Zone_Stage)
	{
		gF_EnterStageTime[client] = Shavit_GetClientTime(client);

		Call_StartForward(gH_Forwards_EnterStage);
		Call_PushCell(client);
		Call_PushCell(Shavit_GetClientStage(client));
		Call_PushCell(Shavit_GetBhopStyle(client));
		Call_Finish();
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
		gF_LeaveStageTime[client] = Shavit_GetClientTime(client);

		Call_StartForward(gH_Forwards_LeaveStage);
		Call_PushCell(client);
		Call_PushCell(Shavit_GetClientStage(client));
		Call_PushCell(Shavit_GetBhopStyle(client));
		Call_Finish();
	}
}

public void Shavit_OnEnterStage(int client, int stage, int style)
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

		if(gF_StageTime[client] < gF_WrcpTime[stage][style] || gF_WrcpTime[stage][style] == 0.0)//check if wrcp
		{
			gF_WrcpTime[stage][style] = gF_StageTime[client];
			OnWRCP(client, stage, style, gF_StageTime[client]);
		}

		FormatSeconds(gF_StageTime[client], sTime, 32, true);
		FormatEx(sMessage, 255, "%T", "ZoneStageTime", client, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText);
	}

	else if(stage == gI_LastStage[client])
	{
		return;
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
}

public void Shavit_OnLeaveStage(int client, int stage, int style)
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
}

void OnWRCP(int client, int stage, int style, float time)
{
	Call_StartForward(gH_Forwards_OnWRCP);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushFloat(time);
	Call_Finish();
}

public void Shavit_OnWRCP(int client, int stage, int style, float time)
{
	//do stuff
	char sMessage[255];
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	FormatEx(sMessage, 255, "%T", "OnWRCP", client, 
		gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable2, time, gS_ChatStrings.sText);
	Shavit_PrintToChatAll("%s", sMessage);

	InsertWRCP(client, stage, style, time);
}

void InsertWRCP(int client, int stage, int style, float time)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT stage FROM %swrcp WHERE stage = '%d' AND map = '%s';", gS_MySQLPrefix, stage, gS_Map);

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(stage);
	dp.WriteCell(style);
	dp.WriteFloat(time);

	gH_SQL.Query(SQL_WRCP_Callback, sQuery, dp, DBPrio_High);
}

public void SQL_WRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	PrintToChatAll("start wrcp callback");
	DataPack dp = view_as<DataPack>(data);
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	float time = dp.ReadFloat();
	delete dp;//i really dislike this, hope someone can have a better implementation

	if(results == null)
	{
		LogError("Insert WRCP error! Reason: %s", error);

		return;
	}

	char sQuery[512];
	if(results.FetchRow())//update
	{
		FormatEx(sQuery, 512,
			"UPDATE `wrcp` SET auth = %d, time = %f WHERE map = '%s' AND stage = '%d';", 
			GetSteamAccountID(client), time, gS_Map, stage);
	}
	else//insert
	{
		FormatEx(sQuery, 512,
			"INSERT INTO `wrcp` (auth, map, time, style, stage, date) VALUES ('%d', '%s', '%f', '%d', '%d', '%d');",
			GetSteamAccountID(client), gS_Map, time, style, stage, GetTime());
	}

	gH_SQL.Query(SQL_WRCP_Callback2, sQuery, 0, DBPrio_High);
}

public void SQL_WRCP_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Insert WRCP error! Reason: %s", error);

		return;
	}
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	char sQuery[1024];
	FormatEx(sQuery, 1024,
			"CREATE TABLE IF NOT EXISTS `%swrcp` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `stage` INT, `date` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (gB_MySQL) ? " ENGINE=INNODB" : "");

	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (wrcp module) error! 'wrcp' table creation failed. Reason: %s", error);

		return;
	}

	gB_Connected = true;

	OnMapStart();
}