/*
 * shavit's Timer - stage
 * by: Ciallo
*/

#define PLUGIN_NAME           "[shavit] Stage"
#define PLUGIN_AUTHOR         "Ciallo"
#define PLUGIN_DESCRIPTION    "A modified Stage plugin for fork's surf timer."
#define PLUGIN_VERSION        "0.5"
#define PLUGIN_URL            "https://github.com/Ciallo-Ani/surftimer"

#include <sourcemod>
#include <regex>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

// plugin cache
Database2 gH_SQL = null;
bool gB_Connected = false;

// table prefix
char gS_MySQLPrefix[32];

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];

enum struct cp_t
{
	int iDate;
	float fTime;
	float fPrespeed;
	float fPostspeed;
}

enum struct stage_t
{
	int iSteamid;
	int iDate;
	int iCompletions;
	float fTime;
	float fPostspeed;
	char sName[MAX_NAME_LENGTH];
}

int gI_Styles = 0;
char gS_Map[160];

// cp info
ArrayList gA_StageLeaderboard[STYLE_LIMIT][MAX_STAGES+1];
ArrayList gA_StageInfo[MAXPLAYERS+1][STYLE_LIMIT];
ArrayList gA_CheckpointInfo[MAXPLAYERS+1][STYLE_LIMIT];

// current wr stats
stage_t gA_WRStageInfo[STYLE_LIMIT][MAX_STAGES+1];
cp_t gA_WRCPInfo[STYLE_LIMIT][MAX_STAGES+1];

// current player stats
float gF_CPTime[MAXPLAYERS+1][MAX_STAGES+1];
float gF_PreSpeed[MAXPLAYERS+1][MAX_STAGES+1];
float gF_PostSpeed[MAXPLAYERS+1][MAX_STAGES+1];
float gF_LeaveStageTime[MAXPLAYERS+1];
float gF_DiffTime[MAXPLAYERS+1];

// menu
int gI_StyleChoice[MAXPLAYERS+1];
int gI_StageChoice[MAXPLAYERS+1];
char gS_MapChoice[MAXPLAYERS+1][160];
bool gB_DeleteMaptop[MAXPLAYERS+1];
bool gB_DeleteWRCP[MAXPLAYERS+1];

// forwards
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
	CreateNative("Shavit_ReloadWRStages", Native_ReloadWRStages);
	CreateNative("Shavit_ReloadWRCPs", Native_ReloadWRCPs);
	CreateNative("Shavit_GetStageRecordAmount", Native_GetStageRecordAmount);
	CreateNative("Shavit_GetStageRankForTime", Native_GetStageRankForTime);
	CreateNative("Shavit_GetWRStageDate", Native_GetWRStageDate);
	CreateNative("Shavit_GetWRStageTime", Native_GetWRStageTime);
	CreateNative("Shavit_GetWRStagePostspeed", Native_GetWRStagePostspeed);
	CreateNative("Shavit_GetWRStageName", Native_GetWRStageName);
	CreateNative("Shavit_GetWRCPTime", Native_GetWRCPTime);
	CreateNative("Shavit_GetWRCPPrespeed", Native_GetWRCPPrespeed);
	CreateNative("Shavit_GetWRCPPostspeed", Native_GetWRCPPostspeed);
	CreateNative("Shavit_GetWRCPDiffTime", Native_GetWRCPDiffTime);
	CreateNative("Shavit_FinishStage", Native_FinishStage);
	CreateNative("Shavit_FinishCheckpoint", Native_FinishCheckpoint);
	CreateNative("Shavit_GetClientStageStayTime", Native_GetClientStageStayTime);

	RegPluginLibrary("shavit-stage");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-stage.phrases");

	// wrcp
	RegConsoleCmd("sm_wrcp", Command_WRCP, "Show WRCP menu, select a style and a stage");
	RegConsoleCmd("sm_wrcps", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcp", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcps", Command_WRCP, "Alias of sm_wrcp");

	// maptop
	RegConsoleCmd("sm_mtop", Command_Maptop, "Show stage tops menu, select a style and a stage");
	RegConsoleCmd("sm_maptop", Command_Maptop, "Alias of sm_mtop");

	// cpr(compare personal records)
	RegConsoleCmd("sm_cpr", Command_CPR, "Show personal map/stages/checkpoints records comparations");

	// ccp(compare checkpoint informations)
	RegConsoleCmd("sm_ccp", Command_CCP, "Show checkpoints information comparations");

	// delete
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

	gH_Forwards_EnterStage = CreateGlobalForward("Shavit_OnEnterStage", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
	gH_Forwards_EnterCheckpoint = CreateGlobalForward("Shavit_OnEnterCheckpoint", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float);
	gH_Forwards_LeaveStage = CreateGlobalForward("Shavit_OnLeaveStage", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
	gH_Forwards_LeaveCheckpoint = CreateGlobalForward("Shavit_OnLeaveCheckpoint", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float);
	gH_Forwards_OnWRCP = CreateGlobalForward("Shavit_OnWRCP", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_String);
	gH_Forwards_OnWRCPDeleted = CreateGlobalForward("Shavit_OnWRCPDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_String);
	gH_Forwards_OnFinishStagePre = CreateGlobalForward("Shavit_OnFinishStagePre", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnFinishStage = CreateGlobalForward("Shavit_OnFinishStage", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Cell);
	gH_Forwards_OnFinishCheckpointPre = CreateGlobalForward("Shavit_OnFinishCheckpointPre", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnFinishCheckpoint = CreateGlobalForward("Shavit_OnFinishCheckpoint", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Float);

	Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
	SQL_DBConnect();
}

public void OnClientPutInServer(int client)
{
	if(gB_Connected && !IsFakeClient(client))
	{
		ResetPlayerStatus(client);
		ReloadStageInfo(client);
		ReloadCPInfo(client);
	}
}

void ResetPlayerStatus(int client)
{
	for(int i = 0; i <= MAX_STAGES; i++)
	{
		gF_CPTime[client][i] = -1.0;
		gF_PreSpeed[client][i] = -1.0;
		gF_PostSpeed[client][i] = -1.0;
	}

	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		if(gA_CheckpointInfo[client][i] != null)
		{
			delete gA_CheckpointInfo[client][i];
		}

		if(gA_StageInfo[client][i] != null)
		{
			delete gA_StageInfo[client][i];
		}

		gA_CheckpointInfo[client][i] = new ArrayList(sizeof(cp_t), MAX_STAGES+1);
		gA_StageInfo[client][i] = new ArrayList(sizeof(cp_t), MAX_STAGES+1);
	}
}

public void OnClientDisconnect(int client)
{
	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		delete gA_CheckpointInfo[client][i];
		delete gA_StageInfo[client][i];
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

	ResetWRStages();
	ResetWRCPs();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-zones"))
	{
		SetFailState("shavit-zones is required for the plugin to work.");
	}

	if(!LibraryExists("shavit-wr"))
	{
		SetFailState("shavit-wr is required for the plugin to work.");
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
			gA_StageLeaderboard[i][j].Clear();
		}
	}

	gI_Styles = styles;
}

void ResetStageLeaderboards()
{
	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 1; j <= MAX_STAGES; j++)
		{
			gA_StageLeaderboard[i][j].Clear();
		}
	}
}

void ResetWRStages(int styles = STYLE_LIMIT, int stages = MAX_STAGES)
{
	for(int i = 0; i < styles; i++)
	{
		for(int j = 1; j <= stages; j++)
		{
			gA_WRStageInfo[i][j].iSteamid = -1;
			gA_WRStageInfo[i][j].fTime = -1.0;
			gA_WRStageInfo[i][j].fPostspeed = -1.0;
			strcopy(gA_WRStageInfo[i][j].sName, MAX_NAME_LENGTH, "N/A");
		}
	}

	ReloadWRStages();
}

void ResetWRCPs(int styles = STYLE_LIMIT, int maxcp = MAX_STAGES)
{
	for(int i = 0; i < styles; i++)
	{
		for(int j = 0; j <= maxcp; j++)
		{
			gA_WRCPInfo[i][j].fTime = -1.0;
			gA_WRCPInfo[i][j].fPrespeed = -1.0;
			gA_WRCPInfo[i][j].fPostspeed = -1.0;
		}
	}

	ReloadWRCPs();
}

public Action Command_WRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = false;

	OpenWRCPMenu(client);

	return Plugin_Handled;
}

public Action Command_DeleteWRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = true;

	OpenWRCPMenu(client);

	return Plugin_Handled;
}

void OpenWRCPMenu(int client)
{
	strcopy(gS_MapChoice[client], 160, gS_Map);

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

		OpenStageMenu(param1, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenStageMenu(int client, bool wrcp)
{
	char sQuery[128];
	FormatEx(sQuery, 128, "SELECT data FROM `%smapzones` WHERE map = '%s' AND type = '%d' AND track = '%d' ORDER BY data DESC;", gS_MySQLPrefix, gS_MapChoice[client], Zone_Stage, Track_Main);
	
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(wrcp?1:0);

	gH_SQL.Query(SQL_OpenStageMenu_Callback, sQuery, dp);
}

public void SQL_OpenStageMenu_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	bool wrcp = (dp.ReadCell() == 1);

	delete dp;

	if(results == null)
	{
		LogError("Timer (GetStageMenu) SQL query failed. Reason: %s", error);
		return;
	}

	Menu submenu = new Menu(wrcp?WRCP_StageMenu_Handler:Maptop_StageMenu_Handler);
	submenu.SetTitle("%T", "WrcpMenuTitle-Stage", client);

	int stages = Shavit_GetMapStages();

	if(results.FetchRow())
	{
		stages = results.FetchInt(0);
	}

	for(int i = 1; i <= stages; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", client, i);

		submenu.AddItem("", sDisplay);
	}

	submenu.ExitBackButton = true;
	submenu.Display(client, -1);
}

public int WRCP_StageMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;

		int style = gI_StyleChoice[param1];
		int stage = gI_StageChoice[param1];
		float time = gA_WRStageInfo[style][stage].fTime;
		char sName[MAX_NAME_LENGTH];
		strcopy(sName, MAX_NAME_LENGTH, gA_WRStageInfo[style][stage].sName);

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
				FormatEx(sMessage, 255, "%T", "Chat-WRCP", param1, sName, stage, gS_StyleStrings[style].sStyleName, sTime);
			}
			else
			{
				FormatEx(sMessage, 255, "%T", "Chat-WRCP-NoRecord", param1, stage, gS_StyleStrings[style].sStyleName);
			}

			Shavit_PrintToChat(param1, "%s", sMessage);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenWRCPMenu(param1);
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

			Transaction hTransaction = new Transaction();
			char sQuery[512];

			FormatEx(sQuery, 512, 
				"SELECT auth FROM `%sstagetimes` "...
				"WHERE stage = %d AND style = %d AND map = '%s' "...
				"ORDER BY time ASC "...
				"LIMIT 1;", 
				gS_MySQLPrefix, stage, style, gS_Map);
			hTransaction.AddQuery(sQuery);

			FormatEx(sQuery, 512, 
				"DELETE FROM `%sstagetimes` WHERE stage = %d AND style = %d AND map = '%s' AND auth IN "...
    			"(SELECT auth FROM "...
    			"(SELECT auth FROM `%sstagetimes` WHERE stage = %d AND style = %d AND map = '%s') AS temp);", 
				gS_MySQLPrefix, stage, style, gS_Map, 
				gS_MySQLPrefix, stage, style, gS_Map);
			hTransaction.AddQuery(sQuery);

			gH_SQL.Execute(hTransaction, Trans_DeleteWRCP_Success, Trans_DeleteWRCP_Failed, GetClientSerial(param1));
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenStageMenu(param1, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void Trans_DeleteWRCP_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = GetClientFromSerial(data);
	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];
	int steamid = -1;
	if(results[0].FetchRow())
	{
		steamid = results[0].FetchInt(0);
	}

	if(StrEqual(gS_MapChoice[client], gS_Map))
	{
		ResetWRStages();
	}

	Call_StartForward(gH_Forwards_OnWRCPDeleted);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushCell(steamid);
	Call_PushString(gS_Map);
	Call_Finish();

	Shavit_PrintToChat(client, "%T", "WRCPDeleteSuccessful", client, stage, gS_StyleStrings[style].sStyleName, steamid);

	OpenStageMenu(client, true);
}

public void Trans_DeleteWRCP_Failed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Delete WRCP error! Reason: %s", error);
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

		OpenStageMenu(param1, false);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int Maptop_StageMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;

		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];

		char sQuery[512];
		FormatEx(sQuery, 512, 
				"SELECT p1.auth, p1.time, p1.completions, p2.name FROM `%sstagetimes` p1 "...
				"JOIN `%susers` p2 "...
				"ON p1.auth = p2.auth "...
				"WHERE (stage = '%d' AND style = '%d') AND map = '%s' "...
				"ORDER BY p1.time ASC "...
				"LIMIT 100;", 
				gS_MySQLPrefix, gS_MySQLPrefix, stage, style, gS_MapChoice[param1]);
		gH_SQL.Query(SQL_Maptop_Callback, sQuery, GetClientSerial(param1));
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

public void SQL_Maptop_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];

	if(results == null)
	{
		LogError("Timer (GetWrcp) SQL query failed. Reason: %s", error);
		return;
	}

	Menu finalMenu = new Menu(Maptop_FinalMenu_Handler);

	char sTitle[128];
	if(gB_DeleteMaptop[client])
	{
		FormatEx(sTitle, 128, "%T", "DeleteMaptopMenuTitle-Maptop", client, gS_MapChoice[client], stage);
	}
	else
	{
		FormatEx(sTitle, 128, "%T", "WrcpMenuTitle-Maptop", client, gS_MapChoice[client], stage);
	}

	finalMenu.SetTitle(sTitle);

	int iCount = 0;

	while(results.FetchRow())
	{
		if(++iCount <= 100)
		{
			// 0 - steamid (mysql delete index)
			char sSteamid[32];
			IntToString(results.FetchInt(0), sSteamid, 32);

			// 1 - time
			float time = results.FetchFloat(1);
			char sTime[32];
			FormatHUDSeconds(time, sTime, 32);

			// compareTime
			float compareTime = time - gA_WRStageInfo[style][stage].fTime;
			char sCompareTime[32];
			FormatHUDSeconds(compareTime, sCompareTime, 32);

			// 2 - completions
			int completions = results.FetchInt(2);

			// 3 - name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(3, sName, MAX_NAME_LENGTH);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "#%d | %s (+%s) - %s (%d)", iCount, sTime, sCompareTime, sName, completions, client);
			finalMenu.AddItem(sSteamid, sDisplay, ITEMDRAW_DEFAULT);
		}
	}

	if(finalMenu.ItemCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "WrcpMenuItem-NoRecord", client);

		finalMenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
	}

	finalMenu.ExitBackButton = true;
	finalMenu.Display(client, -1);
}

public int Maptop_FinalMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sSteamid[32];
		menu.GetItem(param2, sSteamid, 32);
		int steamid = StringToInt(sSteamid);

		if(gB_DeleteMaptop[param1])
		{
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			char sQuery[256];
			FormatEx(sQuery, 256, "DELETE FROM `%sstagetimes` WHERE (stage = '%d' AND style = '%d') AND (auth = '%d' AND map = '%s');", 
					gS_MySQLPrefix, stage, style, steamid, gS_MapChoice[param1]);
			
			DataPack dp = new DataPack();
			dp.WriteCell(GetClientSerial(param1));
			dp.WriteCell(param2 + 1);
			dp.WriteCell(steamid);

			gH_SQL.Query(SQL_DeleteMaptop_Callback, sQuery, dp);
		}
		else
		{
			FormatEx(sSteamid, 32, "U:1:%d", steamid);
			FakeClientCommand(param1, "sm_p %s", sSteamid);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenStageMenu(param1, false);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteMaptop_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int rank = dp.ReadCell();
	int steamid = dp.ReadCell();

	delete dp;

	if(results == null)
	{
		LogError("Timer (single stage record delete) SQL query failed. Reason: %s", error);

		return;
	}

	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];

	if(StrEqual(gS_MapChoice[client], gS_Map))
	{
		ResetWRStages();
	}

	if(rank == 1)
	{
		Call_StartForward(gH_Forwards_OnWRCPDeleted);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_PushCell(steamid);
		Call_PushString(gS_Map);
		Call_Finish();
	}

	Shavit_PrintToChat(client, "%T", "StageRecordDeleteSuccessful", client, stage, gS_StyleStrings[style].sStyleName, steamid);

	OpenStageMenu(client, false);
}

public Action Command_CPR(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(args == 0)
	{
		OpenCPRMenu(client, 1);
	}

	else
	{
		char sArg[16];
		GetCmdArg(1, sArg, 16);

		Regex sRegex = new Regex("[0-9]{1,}");
		bool bMatch = (sRegex.Match(sArg) > 0);

		if(!bMatch)
		{
			Shavit_PrintToChat(client, "Invalid expression or missing numbers");
		}

		else
		{
			char sRank[16];
			sRegex.GetSubString(0, sRank, 16);
			OpenCPRMenu(client, StringToInt(sRank));
		}

		delete sRegex;
	}

	return Plugin_Handled;
}

void OpenCPRMenu(int client, int rank)
{
	int steamid = Shavit_GetSteamidForRank(0, rank, 0);
	if(steamid == -1)
	{
		Shavit_PrintToChat(client, "No records info");
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, 512, 
		"SELECT p1.time, p1.cp, p1.postspeed, p1.auth, p2.name FROM `%scptimes` p1 "...
		"JOIN `%susers` p2 "...
		"ON p1.auth = p2.auth "...
		"WHERE map = '%s' AND style = 0 AND p1.auth = %d "...
		"ORDER BY p1.cp ASC;", 
		gS_MySQLPrefix, gS_MySQLPrefix, gS_Map, steamid);

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(steamid);

	gH_SQL.Query(SQL_GetWRCPsInfomation_Callback, sQuery, dp);
}

public void SQL_GetWRCPsInfomation_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int steamid = dp.ReadCell();

	delete dp;

	if(results == null)
	{
		LogError("Timer (Stage GetWRCheckpointInfomation) SQL query failed. Reason: %s", error);

		return;
	}

	Menu menu = new Menu(CPRMenu_Handler);

	char sName[MAX_NAME_LENGTH];
	if(results.FetchRow())
	{
		results.FetchString(4, sName, MAX_NAME_LENGTH);
	}
	menu.SetTitle("Records Info [%s]", sName);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		char sTrack[32];
		GetTrackName(client, i, sTrack, 32);

		int rank = Shavit_GetRankForSteamid(0, steamid, i);
		if(rank == 0)
		{
			continue;
		}

		char sWRTime[32];
		float wrTime = Shavit_GetTimeForRank(0, rank, i);
		FormatHUDSeconds(wrTime, sWRTime, 32);

		char sDiff[32];
		float diff = Shavit_GetClientPB(client, 0, i) - wrTime;
		FormatHUDSeconds(diff, sDiff, 32);

		char sItem[64];
		FormatEx(sItem, 64, 
			"%s: %s (%s)\n"...
			"    Rank: %d/%d\n"...
			" ", 
			sTrack, sWRTime, sDiff, rank, Shavit_GetRecordAmount(0, 0));
		menu.AddItem("track", sItem);
	}

	bool bLinear = Shavit_IsLinearMap();

	char sCP[8];
	if(bLinear)
	{
		FormatEx(sCP, 8, "CP");
	}
	else
	{
		FormatEx(sCP, 8, "Stage");
	}

	while(results.FetchRow())
	{
		float time = results.FetchFloat(0);
		char sTime[32];
		FormatHUDSeconds(time, sTime, 32);

		int cp = results.FetchInt(1);
		float startSpeed = results.FetchFloat(2);

		char sItem[64];
		FormatEx(sItem, 64, 
			"%s %d: %s\n"...
			"    Start: %d u/s\n"...
			" ", 
			sCP, cp, sTime, RoundToFloor(startSpeed));
		menu.AddItem("cp", sItem);
	}

	menu.Display(client, -1);
}

public int CPRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{

	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_CCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Shavit_PrintToChat(client, "this feature haven't done yet");

	return Plugin_Handled;
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

	switch(type)
	{
		case Zone_Start:
		{
			// linear map hackfix
			gF_PreSpeed[client][0] = fPrespeed;
			gF_CPTime[client][0] = 0.0;

			// stage map hackfix
			gF_PreSpeed[client][1] = fPrespeed;
			gF_CPTime[client][1] = 0.0;

			gF_DiffTime[client] = 0.0;
		}

		case Zone_Stage:
		{
			gF_PreSpeed[client][data] = fPrespeed;

			Call_StartForward(gH_Forwards_EnterStage);
			Call_PushCell(client);
			Call_PushCell(data);
			Call_PushCell(Shavit_GetBhopStyle(client));
			Call_PushFloat(fPrespeed);
			Call_PushFloat(Shavit_GetClientTime(client));
			Call_PushCell(Shavit_IsClientStageTimer(client));
			Call_Finish();
		}

		case Zone_Checkpoint:
		{
			gF_PreSpeed[client][data] = fPrespeed;

			Call_StartForward(gH_Forwards_EnterCheckpoint);
			Call_PushCell(client);
			Call_PushCell(data);
			Call_PushCell(Shavit_GetBhopStyle(client));
			Call_PushFloat(fPrespeed);
			Call_PushFloat(Shavit_GetClientTime(client));
			Call_Finish();
		}
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

	switch(type)
	{
		case Zone_Start:
		{
			gF_LeaveStageTime[client] = Shavit_GetClientTime(client);
			gF_PostSpeed[client][0] = fPostspeed; // linear map hackfix
			gF_PostSpeed[client][1] = fPostspeed; // stage map hackfix
		}

		case Zone_Stage:
		{
			gF_LeaveStageTime[client] = Shavit_GetClientTime(client);
			gF_PostSpeed[client][data] = fPostspeed;

			Call_StartForward(gH_Forwards_LeaveStage);
			Call_PushCell(client);
			Call_PushCell(data);
			Call_PushCell(Shavit_GetBhopStyle(client));
			Call_PushFloat(fPostspeed);
			Call_PushFloat(Shavit_GetClientTime(client));
			Call_PushCell(Shavit_IsClientStageTimer(client));
			Call_Finish();
		}

		case Zone_Checkpoint:
		{
			gF_PostSpeed[client][data] = fPostspeed;

			Call_StartForward(gH_Forwards_LeaveCheckpoint);
			Call_PushCell(client);
			Call_PushCell(data);
			Call_PushCell(Shavit_GetBhopStyle(client));
			Call_PushFloat(fPostspeed);
			Call_PushFloat(Shavit_GetClientTime(client));
			Call_Finish();
		}
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
		"DELETE FROM `%scptimes` WHERE auth = %d AND map = '%s' AND style = %d;",
		gS_MySQLPrefix, accountid, mapname, style);
	gH_SQL.Query(SQL_DeleteWRCPs_Callback, sQuery);
}

public void SQL_DeleteWRCPs_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WRCPs Delete) SQL query failed. Reason: %s", error);
		return;
	}

	Shavit_PrintToChatAll("管理员删除了WR记录");

	ResetWRCPs();
}

// This runs after got or delete map wr
void ReloadWRCPs()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT style, cp, time, prespeed, postspeed FROM `%scpwrs` WHERE map = '%s';", gS_MySQLPrefix, gS_Map);
	gH_SQL.Query(SQL_ReloadWRCPs_Callback, sQuery);
}

public void SQL_ReloadWRCPs_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCheckpoint) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int cpnum = results.FetchInt(1);
		gA_WRCPInfo[style][cpnum].fTime = results.FetchFloat(2);
		gA_WRCPInfo[style][cpnum].fPrespeed = results.FetchFloat(3);
		gA_WRCPInfo[style][cpnum].fPostspeed = results.FetchFloat(4);
	}
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

		for(int i = cpnum; i <= maxCPs; i++)
		{
			float prespeed = gF_PreSpeed[client][i];
			float postspeed = gF_PostSpeed[client][i];

			if(overwrite == 1) // insert
			{
				FormatEx(sQuery, 512,
					"REPLACE INTO `%scptimes` (auth, map, time, style, cp, prespeed, postspeed, date) VALUES (%d, '%s', %f, %d, %d, %f, %f, %d);",
					gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, gF_CPTime[client][i], style, i, prespeed, postspeed, GetTime());
			}
			else // update
			{
				FormatEx(sQuery, 512,
					"UPDATE `%scptimes` SET time = %f, style = %d, prespeed = %f, postspeed = %f, date = %d WHERE (auth = %d AND cp = %d ) AND map = '%s';",
					gS_MySQLPrefix, gF_CPTime[client][i], style, prespeed, postspeed, GetTime(), GetSteamAccountID(client), i, gS_Map);
			}

			hTransaction.AddQuery(sQuery);
		}

		DataPack dp = new DataPack();
		dp.WriteCell(GetClientSerial(client));
		dp.WriteCell(rank);

		gH_SQL.Execute(hTransaction, Trans_InsertCP_PR_Success, Trans_InsertCP_PR_Failed, dp);
	}
}

public void Trans_InsertCP_PR_Success(Database db, DataPack dp, int numQueries, DBResultSet[] results, any[] queryData)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	bool bWR = (dp.ReadCell() == 1);
	delete dp;

	ReloadCPInfo(client);

	if(bWR)
	{
		ReloadWRCPs();
	}
}

public void Trans_InsertCP_PR_Failed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Insert CP error! cp %d failed , failIndex: %d. Reason: %s", numQueries, failIndex, error);
}

void OnWRCPCheck(int client, int stage, int style, float time)
{
	float wrcpTime = gA_WRStageInfo[style][stage].fTime;
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
		FormatEx(sMessage, 255, "%T", "OnWRCP", client, sName, stage, gS_StyleStrings[style].sStyleName, sTime, sDiffTime, sRank);
		Shavit_PrintToChatAll("%s", sMessage);


		Call_StartForward(gH_Forwards_OnWRCP);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_PushCell(GetSteamAccountID(client));
		Call_PushFloat(time);
		Call_PushFloat(gF_PostSpeed[client][stage]);
		Call_PushString(gS_Map);
		Call_Finish();
	}
}

void Insert_WRCP_PR(int client, int stage, int style, float time)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT completions FROM `%sstagetimes` WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, stage, style, gS_Map, GetSteamAccountID(client));

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(stage);
	dp.WriteCell(style);
	dp.WriteFloat(time);

	gH_SQL.Query(SQL_WRCP_PR_Check_Callback, sQuery, dp);
}

public void SQL_WRCP_PR_Check_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	float time = dp.ReadFloat();

	if(results == null)
	{
		delete dp;
		LogError("Timer SQL query failed. Reason: %s", error);

		return;
	}

	stage_t stagepr;
	gA_StageInfo[client][style].GetArray(stage, stagepr, sizeof(stage_t));
	float postSpeed = gF_PostSpeed[client][stage];
	int iOverwrite = 1;

	char sQuery[512];

	if(results.FetchRow())
	{
		if(time < stagepr.fTime || stagepr.fTime == 0.0)
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstagetimes` SET time = %f, date = %d, postspeed = %f, completions = completions + 1 WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, time, GetTime(), postSpeed, stage, style, gS_Map, GetSteamAccountID(client));
		}

		else
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstagetimes` SET completions = completions + 1 WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, stage, style, gS_Map, GetSteamAccountID(client));

			iOverwrite = 0;
		}
	}
	else
	{
		FormatEx(sQuery, 512,
		"REPLACE INTO `%sstagetimes` (auth, map, time, style, stage, postspeed, date, completions) VALUES (%d, '%s', %f, %d, %d, %f, %d, 1);",
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, time, style, stage, postSpeed, GetTime());
	}

	dp.WriteCell(iOverwrite);

	gH_SQL.Query(SQL_PrCheck_Callback, sQuery, dp);
}

public void SQL_PrCheck_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	float time = dp.ReadFloat();
	bool bImproved = (dp.ReadCell() == 1);
	delete dp;

	if(results == null)
	{
		LogError("Insert PR error! Reason: %s", error);

		return;
	}

	Call_StartForward(gH_Forwards_OnFinishStage);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushFloat(time);
	Call_PushCell(bImproved);
	Call_Finish();

	ReloadStageInfo(client);
	ReloadWRStages();
}

void ReloadStageInfo(int client)
{
	if(!IsValidClient(client))
	{
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT style, stage, date, completions, time, postspeed FROM `%sstagetimes` WHERE auth = %d AND map = '%s';", 
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_ReloadStageInfo_Callback, sQuery, GetClientSerial(client));
}

public void SQL_ReloadStageInfo_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ReloadStageInfo) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);

		stage_t prstage;
		prstage.iDate = results.FetchInt(2);
		prstage.iCompletions = results.FetchInt(3);
		prstage.fTime = results.FetchFloat(4);
		prstage.fPostspeed = results.FetchFloat(5);

		gA_StageInfo[client][style].SetArray(stage, prstage, sizeof(stage_t));
	}
}

void ReloadCPInfo(int client)
{
	if(!IsValidClient(client))
	{
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT style, cp, date, time, prespeed, postspeed FROM `%scptimes` WHERE auth = %d AND map = '%s';", 
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_ReloadCPInfo_Callback, sQuery, GetClientSerial(client));
}

public void SQL_ReloadCPInfo_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ReloadCPInfo) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int cp = results.FetchInt(1);

		cp_t prcp;
		prcp.iDate = results.FetchInt(2);
		prcp.fTime = results.FetchFloat(3);
		prcp.fPrespeed = results.FetchFloat(4);
		prcp.fPostspeed = results.FetchFloat(5);

		gA_CheckpointInfo[client][style].SetArray(cp, prcp, sizeof(cp_t));
	}
}

// This runs after got wrcp
void ReloadWRStages()
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.style, p1.stage, p1.auth, p1.time, p1.postspeed, p2.name FROM `%sstagewrs` p1 " ...
			"JOIN `%susers` p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s'", 
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_ReloadWRCP_Callback, sQuery);

	UpdateStageLeaderboards();
}

public void SQL_ReloadWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCP) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);
		gA_WRStageInfo[style][stage].iSteamid = results.FetchInt(2);
		gA_WRStageInfo[style][stage].fTime = results.FetchFloat(3);
		gA_WRStageInfo[style][stage].fPostspeed = results.FetchFloat(4);
		results.FetchString(5, gA_WRStageInfo[style][stage].sName, MAX_NAME_LENGTH);
	}
}

void UpdateStageLeaderboards()
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.style, p1.stage, p1.auth, p1.date, p1.completions, p1.time, p1.postspeed, p2.name FROM `%sstagetimes` p1 "...
			"JOIN `%susers` p2 "...
			"ON p1.auth = p2.auth "...
			"WHERE map = '%s' "...
			"ORDER BY p1.time ASC;", 
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);
	gH_SQL.Query(SQL_UpdateStageLeaderboards_Callback, sQuery);
}

public void SQL_UpdateStageLeaderboards_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (Stage UpdateLeaderboards) SQL query failed. Reason: %s", error);

		return;
	}

	ResetStageLeaderboards();

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);

		if(style >= gI_Styles || Shavit_GetStyleSettingInt(style, "unranked") || stage > MAX_STAGES)
		{
			continue;
		}

		stage_t stagepb;
		stagepb.iSteamid = results.FetchInt(2);
		stagepb.iDate = results.FetchInt(3);
		stagepb.iCompletions = results.FetchInt(4);
		stagepb.fTime = results.FetchFloat(5);
		stagepb.fPostspeed = results.FetchFloat(6);
		results.FetchString(7, stagepb.sName, MAX_NAME_LENGTH);

		gA_StageLeaderboard[style][stage].PushArray(stagepb);
	}
}

public int Native_ReloadWRStages(Handle handler, int numParams)
{
	if(gB_Connected)
	{
		ResetWRStages();
	}
}

public int Native_ReloadWRCPs(Handle handler, int numParams)
{
	if(gB_Connected)
	{
		ResetWRCPs();
	}
}

//native float Shavit_GetWRStageDate(int stage, int style)
public int Native_GetWRStageDate(Handle handler, int numParams)
{
	// TODO
}

//native float Shavit_GetWRStageTime(int stage, int style)
public int Native_GetWRStageTime(Handle handler, int numParams)
{
	return view_as<int>(gA_WRStageInfo[GetNativeCell(2)][GetNativeCell(1)].fTime);
}

//native float Shavit_GetWRStagePostspeed(int stage, int style)
public int Native_GetWRStagePostspeed(Handle handler, int numParams)
{
	return view_as<int>(gA_WRStageInfo[GetNativeCell(2)][GetNativeCell(1)].fPostspeed);
}

//native void Shavit_GetWRStageName(int style, int stage, char[] wrcpname, int wrcpmaxlength)
public int Native_GetWRStageName(Handle handler, int numParams)
{
	SetNativeString(3, gA_WRStageInfo[GetNativeCell(1)][GetNativeCell(2)].sName, GetNativeCell(4));
}

//native float Shavit_GetWRCPTime(int cp, int style)
public int Native_GetWRCPTime(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fTime);
}

//native float Shavit_GetWRCPPostspeed(int cp, int style)
public int Native_GetWRCPPrespeed(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fPrespeed);
}

//native float Shavit_GetWRCPPostspeed(int cp, int style)
public int Native_GetWRCPPostspeed(Handle handler, int numParams)
{
	return view_as<int>(gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fPostspeed);
}

public int Native_GetWRCPDiffTime(Handle handler, int numParams)
{
	return view_as<int>(gF_DiffTime[GetNativeCell(1)]);
}

public int Native_FinishStage(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	int stage = Shavit_GetClientStage(client);
	int style = Shavit_GetBhopStyle(client);

	if(Shavit_IsPracticeMode(client) || Shavit_GetStyleSettingBool(style, "unranked") || Shavit_GetClientTrack(client) != Track_Main)
	{
		return;
	}

	if(StrContains(gS_StyleStrings[style].sSpecialString, "segment") != -1)
	{
		Shavit_PrintToChat(client, "暂不支持关卡segments模式");
		return;
	}

	float time = Shavit_GetClientTime(client) - gF_LeaveStageTime[client];

	if(time > 0.0 && Shavit_GetTimerStatus(client) != Timer_Stopped)
	{
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

		OnWRCPCheck(client, stage - 1, style, time); // check if wrcp
		Insert_WRCP_PR(client, stage - 1, style, time); // check if wrcp and pr, insert or update
	}
}

public int Native_FinishCheckpoint(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	int cpnum = (Shavit_IsLinearMap()) ? Shavit_GetClientCheckpoint(client) : Shavit_GetClientStage(client);
	int style = Shavit_GetBhopStyle(client);
	if(Shavit_GetStyleSettingBool(style, "unranked") || Shavit_GetClientTrack(client) != Track_Main)
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

		gF_CPTime[client][cpnum] = time;

		float diff = time - gA_WRCPInfo[style][cpnum].fTime;
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

//native int Shavit_GetStageRecordAmount(int style, int stage)
public int Native_GetStageRecordAmount(Handle handler, int numParams)
{
	return GetStageRecordAmount(GetNativeCell(1), GetNativeCell(2));
}

//native int Shavit_GetStageRankForTime(int style, float time, int stage)
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

// TODO
//native int Shavit_GetClientStageStayTime(int client, int stage)
public int Native_GetClientStageStayTime(Handle handler, int numParams)
{
	return 0;
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle2(false);
	bool bMysql = IsMySQLDatabase(gH_SQL);

	Transaction2 hTransaction = new Transaction2();

	char sQuery[1024];

	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%sstagetimes` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `stage` INT, `postspeed` FLOAT, `date` INT, `completions` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (bMysql) ? " ENGINE=INNODB" : "");
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%scptimes` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `cp` INT, `prespeed` FLOAT, `postspeed` FLOAT, `date` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (bMysql) ? " ENGINE=INNODB" : "");
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, 1024, 
		"%s `%sstagewrs` "...
		"AS SELECT MIN(id) id, map, style, stage, MIN(time) time, MIN(postspeed) postspeed, MIN(auth) auth, MIN(date) date "...
		"FROM `%sstagetimes` "...
		"GROUP BY map, stage, style;",
		(bMysql) ? "CREATE OR REPLACE VIEW" : "CREATE VIEW IF NOT EXISTS",
		gS_MySQLPrefix, gS_MySQLPrefix);
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, 1024, 
		"%s `%scpwrs` "...
		"AS SELECT p.map, p.style, p.cp, p.time, p.prespeed, p.postspeed, p.auth, p.date "...
		"FROM `%scptimes` p "...
		"JOIN `%swrs` u "...
		"ON p.map = u.map AND p.auth = u.auth "...
		"WHERE u.track = 0;", 
		(bMysql) ? "CREATE OR REPLACE VIEW" : "CREATE VIEW IF NOT EXISTS", 
		gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
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

	if(time <= gA_WRStageInfo[style][stage].fTime || iRecords <= 0)
	{
		return 1;
	}

	if(gA_StageLeaderboard[style][stage] != null && gA_StageLeaderboard[style][stage].Length > 0)
	{
		for(int i = 0; i < iRecords; i++)
		{
			stage_t stagepb;
			gA_StageLeaderboard[style][stage].GetArray(i, stagepb, sizeof(stage_t));

			if(time <= stagepb.fTime)
			{
				return ++i;
			}
		}
	}

	return (iRecords + 1);
}