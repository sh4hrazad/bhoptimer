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
int gI_Styles;
int gI_Stages;

int gI_LastStage[MAXPLAYERS + 1];
float gF_EnterStageTime[MAXPLAYERS + 1];
float gF_LeaveStageTime[MAXPLAYERS + 1];
float gF_StageTime[MAXPLAYERS + 1];

float gF_WrcpTime[MAX_ZONES - 2][STYLE_LIMIT];
char gS_WrcpName[MAX_ZONES - 2][STYLE_LIMIT][MAX_NAME_LENGTH];
float gF_PrStageTime[MAXPLAYERS + 1][MAX_ZONES - 2][STYLE_LIMIT];

int gI_StyleChoice[MAXPLAYERS + 1];
int gI_StageChoice[MAXPLAYERS + 1];
bool gB_Maptop[MAXPLAYERS + 1];

// misc cache
bool gB_Late = false;

// table prefix
char gS_MySQLPrefix[32];

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
chatstrings_t gS_ChatStrings;

Handle gH_Forwards_EnterStage = null;
Handle gH_Forwards_LeaveStage = null;
Handle gH_Forwards_OnWRCP = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-wrcp");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-wrcp.phrases");

	HookEvent("player_death", Player_Death);

	RegConsoleCmd("sm_wrcp", Command_WRCP, "Show WRCP menu, Select a style and a stage");
	RegConsoleCmd("sm_wrcps", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcp", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcps", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_mtop", Command_Maptop, "Actually it's alias of sm_wrcp");

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
	for(int i = 1; i <= gI_Stages; i++)//init
	{
		for(int j = 0; j < gI_Styles; j++)
		{
			gF_PrStageTime[client][i][j] = 0.0;
		}
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

	gI_Stages = Shavit_GetMapStages();
	
	for(int i = 1; i <= gI_Stages; i++)//init
	{
		for(int j = 0; j < gI_Styles; j++)
		{
			gF_WrcpTime[i][j] = 0.0;
			gS_WrcpName[i][j] = "N/A";
		}
	}

	LoadWrcp();

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(-1);
		Shavit_OnChatConfigLoaded();
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
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	gI_Styles = styles;

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
		Shavit_GetStyleStrings(i, sHTMLColor, gS_StyleStrings[i].sHTMLColor, sizeof(stylestrings_t::sHTMLColor));
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

public Action Command_Maptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_Maptop[client] = true;
	FakeClientCommand(client, "sm_wrcp");

	return Plugin_Handled;
}

public Action Command_WRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(WRCPMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sInfo[8];
		IntToString(i, sInfo, 8);

		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem(sInfo, sDisplay);
	}

	menu.ExitButton = false;
	menu.Display(client, -1);

	return Plugin_Handled;
}

public int WRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		Menu stagemenu = new Menu(WRCPMenu2_Handler);
		stagemenu.SetTitle("%T", "WrcpMenuTitle-Stage", param1);

		for(int i = 1; i < gI_Stages; i++)
		{
			char sInfo[8];
			IntToString(i, sInfo, 8);

			char sDisplay[64];
			FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", param1, i);

			stagemenu.AddItem(sInfo, sDisplay);
		}

		stagemenu.ExitButton = false;
		stagemenu.Display(param1, -1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int WRCPMenu2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;
		
		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];
		float time = gF_WrcpTime[stage][style];
		char sName[MAX_NAME_LENGTH];
		sName = gS_WrcpName[stage][style];

		if(!gB_Maptop[param1])
		{
			char sMessage[255];
			FormatEx(sMessage, 255, "%T", "Chat-WRCP", param1, 
				gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
				gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
				gS_ChatStrings.sVariable2, time, gS_ChatStrings.sText);
			Shavit_PrintToChat(param1, "%s", sMessage);
		}
		else
		{
			MaptopMenu(param1, stage, style, gS_Map);
		}
		gB_Maptop[param1] = false;
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void MaptopMenu(int client, int stage, int style, const char[] map)
{
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(stage);
	dp.WriteCell(style);
	dp.WriteString(map);

	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.auth, p1.time, p1.completions, p2.name FROM %sstage p1 " ...
			"JOIN (SELECT auth, name FROM %susers) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE (stage = '%d' AND style = '%d') AND map = '%s';", 
			gS_MySQLPrefix, gS_MySQLPrefix, stage, style, map);
	gH_SQL.Query(SQL_Maptop_Callback, sQuery, dp);
}

public void SQL_Maptop_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack dp = view_as<DataPack>(data);
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

	Menu wrcpmenu = new Menu(WRCPMenu3_Handler);

	char sTitle[128];
	FormatEx(sTitle, 128, "%T", "WrcpMenuTitle-Maptop", client, sMap, stage);
	wrcpmenu.SetTitle(sTitle);

	int iCount = 0;

	while(results.FetchRow())
	{
		if(++iCount <= 100)
		{
			// 1 - time
			float time = results.FetchFloat(1);
			char sTime[32];
			FormatSeconds(time, sTime, 32, true);

			// compareTime
			float compareTime = time - gF_WrcpTime[stage][style];
			char sCompareTime[32];
			FormatSeconds(compareTime, sCompareTime, 32, true);

			// 2 - completions
			int completions = results.FetchInt(2);

			// 3 - name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(3, sName, MAX_NAME_LENGTH);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "#%d | %s (+%s) - %s (%d)", iCount, sTime, sCompareTime, sName, completions, client);
			wrcpmenu.AddItem("", sDisplay, ITEMDRAW_DEFAULT);
		}
	}

	if(wrcpmenu.ItemCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%t", "WrcpMenuItem-NoRecord", client);

		wrcpmenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
	}

	wrcpmenu.ExitButton = true;
	wrcpmenu.Display(client, -1);
}

public int WRCPMenu3_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);//TODO
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
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

		OnWRCPCheck(client, stage - 1, style, gF_StageTime[client]);//check if wrcp,and insert or update
		OnPrCheck(client, stage - 1, style, gF_StageTime[client]);//check if pr insert or update

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

void OnWRCPCheck(int client, int stage, int style, float time)
{
	if(gF_StageTime[client] < gF_WrcpTime[stage][style] || gF_WrcpTime[stage][style] == 0.0)//check if wrcp
	{
		char sMessage[255];
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		FormatEx(sMessage, 255, "%T", "OnWRCP", client, 
			gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable2, time, gS_ChatStrings.sText);
		Shavit_PrintToChatAll("%s", sMessage);

		InsertWRCP(client, stage, style, time);


		Call_StartForward(gH_Forwards_OnWRCP);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_PushFloat(time);
		Call_Finish();
	}
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

	gH_SQL.Query(SQL_InsertWRCP_Callback, sQuery, dp, DBPrio_High);
}

public void SQL_InsertWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
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

	gH_SQL.Query(SQL_InsertWRCP_Callback2, sQuery, 0, DBPrio_High);
}

public void SQL_InsertWRCP_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Insert InsertWRCP2 error! Reason: %s", error);

		return;
	}

	LoadWrcp();
}

void LoadWrcp()
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.auth, p1.stage, p1.style, p1.time, p2.name FROM %swrcp p1 " ...
			"JOIN (SELECT auth, name FROM %susers) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s';", 
		gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_LoadWrcp_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_LoadWrcp_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWrcp) SQL query failed. Reason: %s", error);
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

void OnPrCheck(int client, int stage, int style, float time)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT stage FROM %sstage WHERE (stage = '%d' AND auth = '%d') AND map = '%s';", gS_MySQLPrefix, stage, GetSteamAccountID(client), gS_Map);

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(stage);
	dp.WriteCell(style);
	dp.WriteFloat(time);

	gH_SQL.Query(SQL_PrCheck_Callback, sQuery, dp, DBPrio_High);
}

public void SQL_PrCheck_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack dp = view_as<DataPack>(data);
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

	char sQuery[512];

	if(results.FetchRow())
	{
		float prTime = gF_PrStageTime[client][stage][style];
		if(time < prTime || prTime == 0.0)
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstage` SET time = %f, date = %d, completions = completions + 1 WHERE (stage = '%d' AND auth = '%d') AND map = '%s';", 
			gS_MySQLPrefix, time, GetTime(), stage, GetSteamAccountID(client), gS_Map);
		}
		else
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstage` SET completions = completions + 1 WHERE (stage = '%d' AND auth = '%d') AND map = '%s';", 
			gS_MySQLPrefix, stage, GetSteamAccountID(client), gS_Map);
		}
	}
	else
	{
		FormatEx(sQuery, 512,
		"INSERT INTO `%sstage` (auth, map, time, style, stage, date, completions) VALUES (%d, '%s', %f, %d, %d, %d, 1);",
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, time, style, stage, GetTime());
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
}

void LoadPR(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.auth, p1.stage, p1.style, p1.time FROM %sstage p1 " ...
			"JOIN (SELECT auth FROM %susers) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s';", 
		gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

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
		int stage = results.FetchInt(1);
		int style = results.FetchInt(2);
		float time = results.FetchFloat(3);
		gF_PrStageTime[client][stage][style] = time;
	}
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	Transaction hTransaction = new Transaction();

	char sQuery[1024];
	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%swrcp` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `stage` INT, `date` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (gB_MySQL) ? " ENGINE=INNODB" : "");

	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%sstage` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `stage` INT, `date` INT, `completions` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (gB_MySQL) ? " ENGINE=INNODB" : "");

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
	LogError("Timer (wrcp module) error! table creation failed %d/%d. Reason: %s", failIndex, numQueries, error);
}