/*
 * shavit's Timer - stage
 * by: Ciallo
*/

#define PLUGIN_NAME           "[shavit] Stage"
#define PLUGIN_AUTHOR         "Ciallo"
#define PLUGIN_DESCRIPTION    "A modified Stage plugin for fork's surf timer."
#define PLUGIN_VERSION        "0.4"
#define PLUGIN_URL            "https://github.com/Ciallo-Ani/surftimer"

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

#define gS_None "N/A"

Database2 gH_SQL = null;
bool gB_Connected = false;

enum struct cp_t
{
	float fStageTime;
	float fCheckpointTime;
	float fPrespeed;
	float fStagePostspeed;
	float fCPPostspeed;
	char sName[MAX_NAME_LENGTH];
}

int gI_Styles = 0;
char gS_Map[160];
int gI_Steamid[101];//this is a mysql index, i dont have any better implementation

float gF_LeaveStageTime[MAXPLAYERS+1];
float gF_DiffTime[MAXPLAYERS+1];

cp_t gA_WRCP[MAX_STAGES+1][STYLE_LIMIT];
cp_t gA_PRCP[MAXPLAYERS+1][MAX_STAGES+1][STYLE_LIMIT];
ArrayList gA_StageLeaderboard[STYLE_LIMIT][MAX_STAGES+1];

int gI_StyleChoice[MAXPLAYERS+1];
int gI_StageChoice[MAXPLAYERS+1];
char gS_MapChoice[MAXPLAYERS+1][160];
bool gB_DeleteMaptop[MAXPLAYERS+1];
bool gB_DeleteWRCP[MAXPLAYERS+1];

// misc cache
bool gB_Late = false;

// table prefix
char gS_MySQLPrefix[32];

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
chatstrings_t gS_ChatStrings;

Handle gH_Forwards_EnterStage = null;
Handle gH_Forwards_EnterCheckpoint = null;
Handle gH_Forwards_LeaveStage = null;
Handle gH_Forwards_LeaveCheckpoint = null;
Handle gH_Forwards_OnWRCP = null;
Handle gH_Forwards_OnWRCPDeleted = null;
Handle gH_Forwards_OnFinishStagePre = null;
Handle gH_Forwards_OnFinishStage = null;
Handle gH_Forwards_OnFinishCheckpointPre = null;
Handle gH_Forwards_OnFinishCheckpoint = null;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_ReloadWRCPs", Native_ReloadWRCPs);
	CreateNative("Shavit_ReloadWRCheckpoints", Native_ReloadWRCheckpoints);
	CreateNative("Shavit_GetStageRecordAmount", Native_GetStageRecordAmount);
	CreateNative("Shavit_GetStageRankForTime", Native_GetStageRankForTime);
	CreateNative("Shavit_GetWRCPName", Native_GetWRCPName);
	CreateNative("Shavit_GetWRCPTime", Native_GetWRCPTime);
	CreateNative("Shavit_GetWRCPPostspeed", Native_GetWRCPPostspeed);
	CreateNative("Shavit_GetWRCheckpointTime", Native_GetWRCheckpointTime);
	CreateNative("Shavit_GetWRCheckpointDiffTime", Native_GetWRCheckpointDiffTime);
	CreateNative("Shavit_GetWRCheckpointPreSpeed", Native_GetWRCheckpointPreSpeed);
	CreateNative("Shavit_GetWRCheckpointPostSpeed", Native_GetWRCheckpointPostSpeed);
	CreateNative("Shavit_GetPRCPTime", Native_GetPRCPTime);
	CreateNative("Shavit_FinishStage", Native_FinishStage);
	CreateNative("Shavit_FinishCheckpoint", Native_FinishCheckpoint);
	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-stage");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-stage.phrases");

	HookEvent("player_death", Player_Death);

	//wrcp
	RegConsoleCmd("sm_wrcp", Command_WRCP, "Show WRCP menu, Select a style and a stage");
	RegConsoleCmd("sm_wrcps", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcp", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcps", Command_WRCP, "Alias of sm_wrcp");
	//maptop
	RegConsoleCmd("sm_mtop", Command_Maptop, "Actually it's alias of sm_wrcp");
	RegConsoleCmd("sm_maptop", Command_Maptop, "Alias of sm_mtop");

	//delete
	RegAdminCmd("sm_delwrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Delete a WRCP. Actually it's alias of sm_wrcp");
	RegAdminCmd("sm_delwrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_delsrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_delsrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletewrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletewrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletesrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletesrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");

	RegAdminCmd("sm_delmtop", Command_DeleteMaptop, ADMFLAG_RCON, "Delete a stage record. Actually it's alias of sm_delwrcp");
	RegAdminCmd("sm_delmaptop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	RegAdminCmd("sm_deletemtop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	RegAdminCmd("sm_deletemaptop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");

	gH_Forwards_EnterStage = CreateGlobalForward("Shavit_OnEnterStage", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_EnterCheckpoint = CreateGlobalForward("Shavit_OnEnterCheckpoint", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_LeaveStage = CreateGlobalForward("Shavit_OnLeaveStage", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_LeaveCheckpoint = CreateGlobalForward("Shavit_OnLeaveCheckpoint", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_OnWRCP = CreateGlobalForward("Shavit_OnWRCP", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_String);
	gH_Forwards_OnWRCPDeleted = CreateGlobalForward("Shavit_OnWRCPDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_String);
	gH_Forwards_OnFinishStagePre = CreateGlobalForward("Shavit_OnFinishStagePre", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnFinishStage = CreateGlobalForward("Shavit_OnFinishStage", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	gH_Forwards_OnFinishCheckpointPre = CreateGlobalForward("Shavit_OnFinishCheckpointPre", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnFinishCheckpoint = CreateGlobalForward("Shavit_OnFinishCheckpoint", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Float);

	if(gB_Late)
	{
		Shavit_OnChatConfigLoaded();
		Shavit_OnDatabaseLoaded();
	}
}

public void OnClientPutInServer(int client)
{
	for(int i = 1; i <= MAX_STAGES; i++)//init
	{
		for(int j = 0; j < gI_Styles; j++)
		{
			gA_PRCP[client][i][j].fStageTime = 0.0;
			gA_PRCP[client][i][j].fCheckpointTime = 0.0;
		}
	}

	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}

	if(!Shavit_IsLinearMap())
	{
		LoadPR(client);
	}
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	ResetStage(MAX_STAGES, STYLE_LIMIT, true);
	ResetCPs(MAX_CPZONES, STYLE_LIMIT, true);

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
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
		for(int j = 1; j <= MAX_STAGES; j++)
		{
			if(i < styles)
			{
				if(gA_StageLeaderboard[i][j] == null)
				{
					gA_StageLeaderboard[i][j] = new ArrayList();
				}

				gA_StageLeaderboard[i][j].Clear();
			}

			else
			{
				delete gA_StageLeaderboard[i][j];
			}
		}
	}

	gI_Styles = styles;
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStringsStruct(gS_ChatStrings);
}

void ResetStage(int stage, int style, bool all = false)
{
	if(all)
	{
		for(int i = 1; i <= stage; i++)
		{
			for(int j = 0; j < style; j++)
			{
				gA_WRCP[i][j].fStageTime = -1.0;
				gA_WRCP[i][j].fPrespeed = 0.0;
				gA_WRCP[i][j].fStagePostspeed = 0.0;
				gA_WRCP[i][j].fCPPostspeed = 0.0;
				strcopy(gA_WRCP[i][j].sName, 16, gS_None);
			}
		}
	}

	else
	{
		gA_WRCP[stage][style].fStageTime = -1.0;
		strcopy(gA_WRCP[stage][style].sName, 16, gS_None);
	}

	LoadWRCP();
}

void ResetCPs(int cpnum, int style, bool all = false)
{
	if(all)
	{
		for(int i = 1; i <= cpnum; i++)
		{
			for(int j = 0; j < style; j++)
			{
				gA_WRCP[i][j].fCheckpointTime = -1.0;
				gA_WRCP[i][j].fPrespeed = 0.0;
				gA_WRCP[i][j].fCPPostspeed = 0.0;
			}
		}
	}

	else
	{
		gA_WRCP[cpnum][style].fCheckpointTime = -1.0;
	}

	LoadWRCheckpoints();
}

public Action Command_WRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = false;

	if(args == 0)
	{
		if(Shavit_IsLinearMap())
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenWRCPMenu(client, gS_Map);
	}

	else
	{
		char sMap[160];
		GetCmdArg(1, sMap, 160);
		OpenWRCPMenu(client, sMap);
	}

	return Plugin_Handled;
}

public Action Command_DeleteWRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = true;

	if(args == 0)
	{
		if(Shavit_IsLinearMap())
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenWRCPMenu(client, gS_Map);
	}

	else
	{
		char sMap[160];
		GetCmdArg(1, sMap, 160);
		OpenWRCPMenu(client, sMap);
	}

	return Plugin_Handled;
}

void OpenWRCPMenu(int client, const char[] map)
{
	strcopy(gS_MapChoice[client], 160, map);

	Menu menu = new Menu(WRCPMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem("", sDisplay);
	}

	menu.Display(client, -1);
}

public int WRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		WRCP_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void WRCP_StageMenu(int client)
{
	Menu stagemenu = new Menu(WRCPMenu2_Handler);
	stagemenu.SetTitle("%T", "WrcpMenuTitle-Stage", client);

	for(int i = 1; i <= Shavit_GetMapStages(); i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", client, i);

		stagemenu.AddItem("", sDisplay);
	}

	stagemenu.ExitBackButton = true;
	stagemenu.Display(client, -1);
}

public int WRCPMenu2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;
		
		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];
		float time = gA_WRCP[stage][style].fStageTime;
		char sName[MAX_NAME_LENGTH];
		strcopy(sName, MAX_NAME_LENGTH, gA_WRCP[stage][style].sName);

		if(gB_DeleteWRCP[param1])
		{
			DeleteWRCPConfirm(param1);
		}

		else
		{
			char sMessage[255];
			if(time > 0.0)
			{
				char sTime[32];
				FormatHUDSeconds(time, sTime, 32);

				FormatEx(sMessage, 255, "%T", "Chat-WRCP", param1, 
					gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
					gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
					gS_ChatStrings.sVariable3, gS_StyleStrings[style].sStyleName, gS_ChatStrings.sText, 
					gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText);
			}
			else
			{
				FormatEx(sMessage, 255, "%T", "Chat-WRCP-NoRecord", param1, 
				gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
				gS_ChatStrings.sVariable3, gS_StyleStrings[style].sStyleName, gS_ChatStrings.sText);
			}
			Shavit_PrintToChat(param1, "%s", sMessage);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenWRCPMenu(param1, gS_MapChoice[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void DeleteWRCPConfirm(int client)
{
	Menu menu = new Menu(DeleteWRCPMenu_Handler);

	char sTitle[64];
	FormatEx(sTitle, 64, "%T", "DeleteWrcpMenuTitle-Confirm", client, gI_StageChoice[client], gS_StyleStrings[gI_StyleChoice[client]].sStyleName);
	menu.SetTitle(sTitle);

	menu.AddItem("", "Yes");
	menu.AddItem("", "No");

	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int DeleteWRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			char sQuery[256];//i write 2 callbacks in order to find wrcp auth index, but seems to have a better implementation(mysql syntax)
			FormatEx(sQuery, 256, 
					"SELECT auth, time FROM `%sstage` " ...
					"WHERE (stage = '%d' AND style = '%d') AND map = '%s' " ...
					"ORDER BY time ASC " ...
					"LIMIT 1;", 
			gS_MySQLPrefix, stage, style, gS_Map);

			gH_SQL.Query(SQL_DeleteWRCP_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		WRCP_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if(results == null)
	{
		LogError("Timer (single WRCP delete) SQL query failed. Reason: %s", error);

		return;
	}

	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];
	int index = -1;
	if(results.FetchRow())
	{
		index = results.FetchInt(0);
	}

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(index);

	char sQuery[256];
	FormatEx(sQuery, 256, "DELETE FROM `%sstage` WHERE (stage = '%d' AND style = '%d') AND (auth = '%d' AND map = '%s');", 
			gS_MySQLPrefix, stage, style, index, gS_Map);
	
	gH_SQL.Query(SQL_DeleteWRCP_Callback2, sQuery, dp, DBPrio_High);
}

public void SQL_DeleteWRCP_Callback2(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int steamid = dp.ReadCell();

	delete dp;

	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];

	if(results == null)
	{
		LogError("Timer (single WRCP delete2) SQL query failed. Reason: %s", error);

		return;
	}

	ResetStage(stage, style);

	Call_StartForward(gH_Forwards_OnWRCPDeleted);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushCell(steamid);
	Call_PushString(gS_Map);
	Call_Finish();

	Shavit_PrintToChat(client, "%T", "WRCPDeleteSuccessful", client, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable, stage, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable3, gS_StyleStrings[style].sStyleName, gS_ChatStrings.sText);
}

public Action Command_Maptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteMaptop[client] = false;

	if(args == 0)
	{
		if(Shavit_IsLinearMap())
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenMaptopMenu(client, gS_Map);
	}

	else
	{
		char sMap[128];
		GetCmdArg(1, sMap, 128);
		OpenMaptopMenu(client, sMap);
	}

	return Plugin_Handled;
}

public Action Command_DeleteMaptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteMaptop[client] = true;

	if(args == 0)
	{
		if(Shavit_IsLinearMap())
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}
		
		OpenMaptopMenu(client, gS_Map);
	}

	else
	{
		char sMap[128];
		GetCmdArg(1, sMap, 128);
		OpenMaptopMenu(client, sMap);
	}

	return Plugin_Handled;
}

void OpenMaptopMenu(int client, const char[] map)
{
	strcopy(gS_MapChoice[client], 160, map);

	Menu menu = new Menu(MaptopMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem("", sDisplay);
	}

	menu.Display(client, -1);
}

public int MaptopMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		Maptop_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void Maptop_StageMenu(int client)
{
	Menu stagemenu = new Menu(MaptopMenu2_Handler);
	stagemenu.SetTitle("%T", "WrcpMenuTitle-Stage", client);

	for(int i = 1; i <= Shavit_GetMapStages(); i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", client, i);

		stagemenu.AddItem("", sDisplay);
	}

	stagemenu.ExitBackButton = true;
	stagemenu.Display(client, -1);
}

public int MaptopMenu2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;
		
		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];

		DataPack dp = new DataPack();
		dp.WriteCell(GetClientSerial(param1));
		dp.WriteCell(stage);
		dp.WriteCell(style);
		dp.WriteString(gS_MapChoice[param1]);

		char sQuery[512];
		FormatEx(sQuery, 512, 
				"SELECT p1.auth, p1.time, p1.completions, p2.name FROM `%sstage` p1 " ...
				"JOIN (SELECT auth, name FROM `%susers`) p2 " ...
				"ON p1.auth = p2.auth " ...
				"WHERE (stage = '%d' AND style = '%d') AND map = '%s' " ...
				"ORDER BY p1.time ASC " ...
				"LIMIT 100;", 
				gS_MySQLPrefix, gS_MySQLPrefix, stage, style, gS_MapChoice[param1]);
		gH_SQL.Query(SQL_Maptop_Callback, sQuery, dp, DBPrio_High);
	}

	else if(action == MenuAction_Cancel)
	{
		OpenMaptopMenu(param1, gS_MapChoice[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_Maptop_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	char sMap[160];
	dp.ReadString(sMap, 160);

	delete dp;

	if(results == null)
	{
		LogError("Timer (GetWrcp) SQL query failed. Reason: %s", error);
		return;
	}

	Menu maptopmenu = new Menu(MaptopMenu3_Handler);

	char sTitle[128];
	if(gB_DeleteMaptop[client])
	{
		FormatEx(sTitle, 128, "%T", "DeleteMaptopMenuTitle-Maptop", client, sMap, stage);
	}
	else
	{
		FormatEx(sTitle, 128, "%T", "WrcpMenuTitle-Maptop", client, sMap, stage);
	}

	maptopmenu.SetTitle(sTitle);

	int iCount = 0;

	while(results.FetchRow())
	{
		if(++iCount <= 100)
		{
			// 0 - steamid (mysql delete index)
			gI_Steamid[iCount] = results.FetchInt(0);

			// 1 - time
			float time = results.FetchFloat(1);
			char sTime[32];
			FormatHUDSeconds(time, sTime, 32);

			// compareTime
			float compareTime = time - gA_WRCP[stage][style].fStageTime;
			char sCompareTime[32];
			FormatHUDSeconds(compareTime, sCompareTime, 32);

			// 2 - completions
			int completions = results.FetchInt(2);

			// 3 - name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(3, sName, MAX_NAME_LENGTH);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "#%d | %s (+%s) - %s (%d)", iCount, sTime, sCompareTime, sName, completions, client);
			maptopmenu.AddItem("", sDisplay, ITEMDRAW_DEFAULT);
		}
	}

	if(maptopmenu.ItemCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%t", "WrcpMenuItem-NoRecord", client);

		maptopmenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
	}

	maptopmenu.ExitBackButton = true;
	maptopmenu.Display(client, -1);
}

public int MaptopMenu3_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(gB_DeleteMaptop[param1])
		{
			gB_DeleteMaptop[param1] = false;

			int index = gI_Steamid[param2 + 1];
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			char sQuery[256];
			FormatEx(sQuery, 256, "DELETE FROM `%sstage` WHERE (stage = '%d' AND style = '%d') AND (auth = '%d' AND map = '%s');", 
					gS_MySQLPrefix, stage, style, index, gS_MapChoice[param1]);

			DataPack dp = new DataPack();
			dp.WriteCell(GetClientSerial(param1));
			dp.WriteCell(stage);
			dp.WriteCell(style);

			gH_SQL.Query(SQL_DeleteMaptop_Callback, sQuery, dp);
		}
		else
		{
			return 0;//do stuff here
		}
	}

	else if(action == MenuAction_Cancel)
	{
		Maptop_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteMaptop_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int client = GetClientFromSerial(data.ReadCell());
	int stage = data.ReadCell();
	int style = data.ReadCell();

	delete data;

	if(results == null)
	{
		LogError("Timer (single stage record delete) SQL query failed. Reason: %s", error);

		return;
	}

	ResetStage(stage, style);

	Shavit_PrintToChat(client, "%T", "StageRecordDeleteSuccessful", client, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable, stage, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable3, gS_StyleStrings[style].sStyleName, gS_ChatStrings.sText);
}

public void Shavit_OnRestart(int client, int track)
{
	gF_DiffTime[client] = 0.0;
}

public void Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	gF_DiffTime[client] = 0.0;
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(track != Track_Main)
	{
		return;
	}

	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
	float fPrespeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

	if(type == Zone_End)
	{
		int cpnum = (Shavit_IsLinearMap()) ? Shavit_GetClientCheckpoint(client) : Shavit_GetClientStage(client);
		int style = Shavit_GetBhopStyle(client);
		gA_PRCP[client][cpnum][style].fPrespeed = fPrespeed;
	}

	if((type == Zone_Stage || type == Zone_Start || type == Zone_End) && !Shavit_IsLinearMap())
	{
		if(type == Zone_Stage || type == Zone_Start)
		{
			int stage = Shavit_GetClientStage(client);
			int style = Shavit_GetBhopStyle(client);
			gA_PRCP[client][stage][style].fPrespeed = fPrespeed;

			Call_StartForward(gH_Forwards_EnterStage);
			Call_PushCell(client);
			Call_PushCell(stage);
			Call_PushCell(style);
			Call_PushFloat(fPrespeed);
			Call_Finish();
		}

		if(type == Zone_End && Shavit_IsClientStageTimer(client))
		{
			Shavit_StopTimer(client);
		}
	}

	else if(type == Zone_Checkpoint)
	{
		int cpnum = Shavit_GetClientCheckpoint(client);
		int style = Shavit_GetBhopStyle(client);
		gA_PRCP[client][cpnum][style].fPrespeed = fPrespeed;

		Call_StartForward(gH_Forwards_EnterCheckpoint);
		Call_PushCell(client);
		Call_PushCell(cpnum);
		Call_PushCell(style);
		Call_PushFloat(fPrespeed);
		Call_Finish();
	}
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	if(track != Track_Main)
	{
		return;
	}

	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
	float fPostspeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

	if(type == Zone_Stage || type == Zone_Start)
	{
		gF_LeaveStageTime[client] = Shavit_GetClientTime(client);

		int stage = Shavit_GetClientStage(client);
		int style = Shavit_GetBhopStyle(client);
		bool bLinear = Shavit_IsLinearMap();
	
		if(bLinear)
		{
			gA_PRCP[client][0][style].fCPPostspeed = fPostspeed;
		}
		else
		{
			gA_PRCP[client][stage][style].fStagePostspeed = fPostspeed;
			gA_PRCP[client][stage][style].fCPPostspeed = fPostspeed;
		}

		Call_StartForward(gH_Forwards_LeaveStage);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_PushFloat(fPostspeed);
		Call_Finish();
	}

	else if(type == Zone_Checkpoint)
	{
		int cpnum = Shavit_GetClientCheckpoint(client);
		int style = Shavit_GetBhopStyle(client);
		gA_PRCP[client][cpnum][style].fCPPostspeed = fPostspeed;

		Call_StartForward(gH_Forwards_LeaveCheckpoint);
		Call_PushCell(client);
		Call_PushCell(cpnum);
		Call_PushCell(style);
		Call_PushFloat(fPostspeed);
		Call_Finish();
	}
}

public void Shavit_OnWRDeleted(int style, int id, int track, int accountid, const char[] mapname)
{
	if(track != Track_Main)
	{
		return;
	}

	char sQuery[255];
	FormatEx(sQuery, sizeof(sQuery),
		"DELETE FROM %scp WHERE auth = %d AND map = '%s' AND style = %d;",
		gS_MySQLPrefix, accountid, mapname, style);
	gH_SQL.Query(SQL_DeleteWRCheckpoint_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_DeleteWRCheckpoint_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WRCheckpoint Delete) SQL query failed. Reason: %s", error);
		return;
	}

	PrintToChatAll("管理员删除了WR记录");

	ResetStage(MAX_STAGES, STYLE_LIMIT, true);
	ResetCPs(MAX_CPZONES, STYLE_LIMIT, true);
}

public void Shavit_OnFinish_Post(int client, int style, float time, int jumps, int strafes, float sync, int rank, int overwrite, int track, float oldtime, float perfs, float avgvel, float maxvel, int timestamp)
{
	if(track != Track_Main)
	{
		return;
	}

	bool bLinear = Shavit_IsLinearMap();

	// overwrite
	// 0 - no query
	// 1 - insert
	// 2 - update
	int maxCPs;

	if(bLinear)
	{
		maxCPs = Shavit_GetMapCheckpoints();
	}

	else
	{
		maxCPs = Shavit_GetMapStages();
	}

	if(overwrite > 0)
	{
		Transaction hTransaction = new Transaction();
		char sQuery[512];

		int cpnum = (bLinear)? 0 : 1;

		if(overwrite == 1) // insert
		{
			for(int i = cpnum; i <= maxCPs; i++)
			{
				float prespeed = gA_PRCP[client][i][style].fPrespeed;
				float postspeed = (bLinear)? gA_PRCP[client][i][style].fCPPostspeed : gA_PRCP[client][i][style].fStagePostspeed;

				FormatEx(sQuery, 512,
					"REPLACE INTO `%scp` (auth, map, time, style, cp, prespeed, postspeed, date) VALUES (%d, '%s', %f, %d, %d, %f, %f, %d);",
					gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, gA_PRCP[client][i][style].fCheckpointTime, style, i, prespeed, postspeed, GetTime());
				
				hTransaction.AddQuery(sQuery);
			}
		}

		else // update
		{
			for(int i = cpnum; i <= maxCPs; i++)
			{
				float prespeed = gA_PRCP[client][i][style].fPrespeed;
				float postspeed = (bLinear)? gA_PRCP[client][i][style].fCPPostspeed : gA_PRCP[client][i][style].fStagePostspeed;

				FormatEx(sQuery, 512,
					"UPDATE `%scp` SET time = %f, style = %d, prespeed = %f, postspeed = %f, date = %d WHERE (auth = %d AND cp = %d ) AND map = '%s';",
					gS_MySQLPrefix, gA_PRCP[client][i][style].fCheckpointTime, style, prespeed, postspeed, GetTime(), GetSteamAccountID(client), i, gS_Map);
				
				hTransaction.AddQuery(sQuery);
			}
		}

		gH_SQL.Execute(hTransaction, Trans_InsertCP_PR_Success, Trans_InsertCP_PR_Failed);
	}
}

public void Trans_InsertCP_PR_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	ResetCPs(MAX_CPZONES, STYLE_LIMIT, true);
}

public void Trans_InsertCP_PR_Failed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Insert CP error! cp %d failed , failIndex: %d. Reason: %s", numQueries, failIndex, error);
}

void OnWRCPCheck(int client, int stage, int style, float time)
{
	float wrcpTime = gA_WRCP[stage][style].fStageTime;
	if(time < wrcpTime || wrcpTime == -1.0)// check if wrcp
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		char sTime[32];
		FormatHUDSeconds(time, sTime, 32);

		char sDiffTime[32];
		char sRank[32];
		if(wrcpTime == -1.0)
		{
			FormatEx(sDiffTime, 32, "N/A");
			FormatEx(sRank, 32, "1/1");
		}
		else
		{
			FormatHUDSeconds(time - wrcpTime, sDiffTime, 32);
			FormatEx(sRank, 32, "%d/%d", GetStageRankForTime(style, time, stage), GetStageRecordAmount(style, stage));
		}

		char sMessage[255];
		FormatEx(sMessage, 255, "%T", "OnWRCP", client, 
			gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable3, gS_StyleStrings[style].sStyleName, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable10, sDiffTime, gS_ChatStrings.sText, 
			gS_ChatStrings.sTeam, sRank, gS_ChatStrings.sText);
		Shavit_PrintToChatAll("%s", sMessage);


		Call_StartForward(gH_Forwards_OnWRCP);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_PushCell(GetSteamAccountID(client));
		Call_PushFloat(time);
		Call_PushFloat(gA_PRCP[client][stage][style].fStagePostspeed);
		Call_PushString(gS_Map);
		Call_Finish();
	}
}

void Insert_WRCP_PR(int client, int stage, int style, float time)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT completions FROM `%sstage` WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, stage, style, gS_Map, GetSteamAccountID(client));

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(stage);
	dp.WriteCell(style);
	dp.WriteFloat(time);

	gH_SQL.Query(SQL_WRCP_PR_Check_Callback, sQuery, dp, DBPrio_High);
}

public void SQL_WRCP_PR_Check_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	float time = dp.ReadFloat();
	delete dp;

	if(results == null)
	{
		LogError("Timer SQL query failed. Reason: %s", error);

		return;
	}

	float prTime = gA_PRCP[client][stage][style].fStageTime;
	float postspeed = gA_PRCP[client][stage][style].fStagePostspeed;
	char sQuery[512];

	if(results.FetchRow())
	{
		if(time < prTime || prTime == 0.0)
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstage` SET time = %f, date = %d, postspeed = %f, completions = completions + 1 WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, time, GetTime(), postspeed, stage, style, gS_Map, GetSteamAccountID(client));
		}
		
		else
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstage` SET completions = completions + 1 WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, stage, style, gS_Map, GetSteamAccountID(client));
		}
	}
	else
	{
		FormatEx(sQuery, 512,
		"REPLACE INTO `%sstage` (auth, map, time, style, stage, postspeed, date, completions) VALUES (%d, '%s', %f, %d, %d, %f, %d, 1);",
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, time, style, stage, postspeed, GetTime());
	}

	gH_SQL.Query(SQL_PrCheck_Callback2, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_PrCheck_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Insert PR error! Reason: %s", error);

		return;
	}

	LoadPR(GetClientFromSerial(data));
	LoadWRCP();
}

void LoadPR(int client = -1)
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT stage, style, time, postspeed FROM `%sstage` WHERE auth = %d AND map = '%s';", 
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_LoadPR_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_LoadPR_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadPR) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int stage = results.FetchInt(0);
		int style = results.FetchInt(1);
		float time = results.FetchFloat(2);
		gA_PRCP[client][stage][style].fStageTime = time;
		gA_PRCP[client][stage][style].fStagePostspeed = results.FetchFloat(3);
	}
}

void LoadWRCP()
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.auth, p1.stage, p1.style, p1.time, p1.postspeed, p2.name FROM `%sstage` p1 " ...
			"JOIN (SELECT auth, name FROM `%susers`) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s' " ...
			"ORDER BY p1.time ASC;", 
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_LoadWRCP_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_LoadWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCP) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int stage = results.FetchInt(1);
		int style = results.FetchInt(2);
		float time = results.FetchFloat(3);
		gA_WRCP[stage][style].fStagePostspeed = results.FetchFloat(4);
		if(time < gA_WRCP[stage][style].fStageTime || gA_WRCP[stage][style].fStageTime == -1.0)
		{
			gA_WRCP[stage][style].fStageTime = time;

			results.FetchString(5, gA_WRCP[stage][style].sName, MAX_NAME_LENGTH);
		}
	}

	UpdateStageLeaderboards();
}

void UpdateStageLeaderboards()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT style, stage, time FROM `%sstage` WHERE map = '%s' ORDER BY time ASC, date ASC;", gS_MySQLPrefix, gS_Map);
	gH_SQL.Query(SQL_UpdateStageLeaderboards_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_UpdateStageLeaderboards_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (Stage UpdateLeaderboards) SQL query failed. Reason: %s", error);

		return;
	}

	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 1; j <= MAX_STAGES; j++)
		{
			gA_StageLeaderboard[i][j].Clear();
		}
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);

		if(style >= gI_Styles || Shavit_GetStyleSettingInt(style, "unranked") || stage >= MAX_STAGES)
		{
			continue;
		}

		gA_StageLeaderboard[style][stage].Push(results.FetchFloat(2));
	}

	for(int i = 0; i < gI_Styles; i++)
	{
		if(i >= gI_Styles || Shavit_GetStyleSettingInt(i, "unranked"))
		{
			continue;
		}

		for(int j = 1; j <= MAX_STAGES; j++)
		{
			SortADTArray(gA_StageLeaderboard[i][j], Sort_Ascending, Sort_Float);
		}
	}
}

void LoadWRCheckpoints()
{
	char sQuery[512];

	FormatEx(sQuery, 512, 
			"SELECT p1.auth, p1.cp, p1.style, p1.time, p1.prespeed, p1.postspeed FROM `%scp` p1 " ...
			"JOIN (SELECT auth, name FROM `%susers`) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s' " ...
			"ORDER BY p1.time ASC;", 
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_LoadWRCheckpoint_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_LoadWRCheckpoint_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCheckpoint) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int cpnum = results.FetchInt(1);
		int style = results.FetchInt(2);
		float time = results.FetchFloat(3);
		gA_WRCP[cpnum][style].fPrespeed = results.FetchFloat(4);
		gA_WRCP[cpnum][style].fCPPostspeed = results.FetchFloat(5);
		if(time < gA_WRCP[cpnum][style].fCheckpointTime || gA_WRCP[cpnum][style].fCheckpointTime == -1.0)
		{
			gA_WRCP[cpnum][style].fCheckpointTime = time;
		}
	}
}

/* void LoadPRCheckpoints(int client)
{
	char sQuery[256];
	FormatEx(sQuery, 256, "SELECT cp, style, time, prespeed, postspeed FROM `%scp` WHERE auth = %d AND map = '%s' ORDER BY cp ASC;", gS_MySQLPrefix, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_LoadPRCheckpoint_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_LoadPRCheckpoint_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadPRCheckpoint) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	while(results.FetchRow())
	{
		int cpnum = results.FetchInt(0);
		int style = results.FetchInt(1);
		gA_PRCP[client][cpnum][style].fCheckpointTime = results.FetchFloat(2);
		gA_PRCP[client][cpnum][style].fPrespeed = results.FetchFloat(3);
		gA_PRCP[client][cpnum][style].fCPPostspeed = results.FetchFloat(4);
	}
} */

public int Native_ReloadWRCPs(Handle handler, int numParams)
{
	ResetStage(MAX_STAGES, STYLE_LIMIT, true);
}

public int Native_ReloadWRCheckpoints(Handle handler, int numParams)
{
	ResetCPs(MAX_CPZONES, STYLE_LIMIT, true);
}

public int Native_GetWRCPName(Handle handler, int numParams)
{
	SetNativeString(2, gA_WRCP[GetNativeCell(4)][GetNativeCell(1)].sName, GetNativeCell(3));
}

public int Native_GetWRCPTime(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCP[GetNativeCell(1)][GetNativeCell(2)].fStageTime);
}

public int Native_GetWRCPPostspeed(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCP[GetNativeCell(1)][GetNativeCell(2)].fStagePostspeed);
}

public int Native_FinishStage(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	int stage = Shavit_GetClientStage(client);
	int style = Shavit_GetBhopStyle(client);

	if(Shavit_IsPracticeMode(client) || Shavit_GetStyleSettingBool(style, "unranked"))
	{
		return;
	}

	if(StrContains(gS_StyleStrings[style].sSpecialString, "segment") != -1)
	{
		Shavit_PrintToChat(client, "暂不支持关卡segments模式");
		return;
	}

	if(!bBypass)
	{
		bool bResult = true;
		Call_StartForward(gH_Forwards_OnFinishStagePre);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_Finish(bResult);

		if(!bResult)
		{
			return;
		}
	}

	float time = Shavit_GetClientTime(client) - gF_LeaveStageTime[client];

	if(time > 0.0 && Shavit_GetTimerStatus(client) != Timer_Stopped)
	{
		Call_StartForward(gH_Forwards_OnFinishStage);
		Call_PushCell(client);
		Call_PushCell(stage - 1);
		Call_PushCell(style);
		Call_PushFloat(time);
		Call_Finish();

		gA_PRCP[client][stage][style].fCheckpointTime = time;

		OnWRCPCheck(client, stage - 1, style, time);//check if wrcp
		Insert_WRCP_PR(client, stage - 1, style, time);//check if wrcp and pr, insert or update
	}
}

public int Native_FinishCheckpoint(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	int cpnum = (Shavit_IsLinearMap()) ? Shavit_GetClientCheckpoint(client) : Shavit_GetClientStage(client);
	int style = Shavit_GetBhopStyle(client);
	if(Shavit_GetStyleSettingBool(style, "unranked"))
	{
		return;
	}

	float time = Shavit_GetClientTime(client);

	if(time > 0.0 && Shavit_GetTimerStatus(client) != Timer_Stopped)
	{
		if(!bBypass)
		{
			bool bResult = true;
			Call_StartForward(gH_Forwards_OnFinishCheckpointPre);
			Call_PushCell(client);
			Call_PushCell(cpnum);
			Call_PushCell(style);
			Call_Finish(bResult);

			if(!bResult)
			{
				return;
			}
		}

		gA_PRCP[client][cpnum][style].fCheckpointTime = time;
		
		float diff = time - gA_WRCP[cpnum][style].fCheckpointTime;
		gF_DiffTime[client] = diff;

		float fVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
		float prespeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

		Call_StartForward(gH_Forwards_OnFinishCheckpoint);
		Call_PushCell(client);
		Call_PushCell(cpnum);
		Call_PushCell(style);
		Call_PushFloat(time);
		Call_PushFloat(diff);
		Call_PushFloat(prespeed);
		Call_Finish();
	}
}

public int Native_GetWRCheckpointTime(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCP[GetNativeCell(1)][GetNativeCell(2)].fCheckpointTime);
}

public int Native_GetWRCheckpointDiffTime(Handle handler, int numParams)
{
	return view_as<int>(gF_DiffTime[GetNativeCell(1)]);
}

public int Native_GetWRCheckpointPreSpeed(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCP[GetNativeCell(1)][GetNativeCell(2)].fPrespeed);
}

public int Native_GetWRCheckpointPostSpeed(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCP[GetNativeCell(1)][GetNativeCell(2)].fCPPostspeed);
}

public int Native_GetPRCPTime(Handle hander, int numParams)
{
	return view_as<int>(gA_PRCP[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)].fStageTime);
}

public int Native_GetStageRecordAmount(Handle handler, int numParams)
{
	return GetStageRecordAmount(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetStageRankForTime(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int stage = GetNativeCell(3);

	if(gA_StageLeaderboard[style][stage] == null || gA_StageLeaderboard[style][stage].Length == 0)
	{
		return 0;
	}

	return GetStageRankForTime(style, GetNativeCell(2), stage);
}

public void Shavit_OnDatabaseLoaded()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle2(false);

	Transaction hTransaction = new Transaction();

	char sQuery[1024];
	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%sstage` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `stage` INT, `postspeed` FLOAT, `date` INT, `completions` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (IsMySQLDatabase(gH_SQL)) ? " ENGINE=INNODB" : "");

	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%scp` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `cp` INT, `prespeed` FLOAT, `postspeed` FLOAT, `date` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (IsMySQLDatabase(gH_SQL)) ? " ENGINE=INNODB" : "");

	hTransaction.AddQuery(sQuery);

	gH_SQL.Execute(hTransaction, Trans_CreateTable_Success, Trans_CreateTable_Failed);
}

public void Trans_CreateTable_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	gB_Connected = true;
	OnMapStart();
}

public void Trans_CreateTable_Failed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (stage module) error! 'Map stage or cp' table creation failed %d/%d. Reason: %s", failIndex, numQueries, error);
}

int GetStageRecordAmount(int style, int stage)
{
	if(gA_StageLeaderboard[style][stage] == null)
	{
		return 0;
	}

	return gA_StageLeaderboard[style][stage].Length;
}

int GetStageRankForTime(int style, float time, int stage)
{
	int iRecords = GetStageRecordAmount(style, stage);

	if(time <= gA_WRCP[stage][style].fStageTime || iRecords <= 0)
	{
		return 1;
	}

	if(gA_StageLeaderboard[style][stage] != null && gA_StageLeaderboard[style][stage].Length > 0)
	{
		for(int i = 0; i < iRecords; i++)
		{
			if(time <= gA_StageLeaderboard[style][stage].Get(i))
			{
				return ++i;
			}
		}
	}

	return (iRecords + 1);
}