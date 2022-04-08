/**
 * bhoptimer-sfork - Teleport Destination Finder
 * Original plugin by: marcowmadeira
 *
 * https://github.com/surftimer/Surftimer-Official
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <shavit/core>

#pragma semicolon 1
#pragma newdecls required

Handle g_hEntity;
Handle g_hTMEntity;

public Plugin myinfo = 
{
	name = "Teleport Destination Finder",
	author = "marcowmadeira",
	description = "Shows a list of info_teleport_destination entities.",
	version = SHAVIT_VERSION ... "-sfork",
	url = "http://marcowmadeira.com/"
};

public void OnPluginStart()
{
	EngineVersion eGame = GetEngineVersion();
	
	if(eGame != Engine_CSGO && eGame != Engine_CSS)
	{
		SetFailState("[TDF] This plugin is for CSGO/CSS only.");	
	}
	
	RegAdminCmd("sm_itd", ShowTeleportDestinations, ADMFLAG_ROOT, "Shows a menu with all info_teleport_destination entities");
	RegAdminCmd("sm_tl", ShowTriggersLocations, ADMFLAG_ROOT, "Shows a menu with all trigger_multiple locations");

}

public void OnMapStart()
{
	int iEnt;
	g_hEntity = CreateArray(12);
	g_hTMEntity = CreateArray(12);

	while ((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
		PushArrayCell(g_hEntity, iEnt);

	while ((iEnt = FindEntityByClassname(iEnt, "trigger_multiple")) != -1)
	{
		char target_name[32];
		GetEntPropString(iEnt, Prop_Data, "m_iName", target_name, sizeof(target_name));

		if (strlen(target_name) > 0 && StrContains(target_name, "sm_ckZone") == -1)
			PushArrayCell(g_hTMEntity, iEnt);
	}

}

public void OnMapEnd()
{
	delete g_hEntity;
	delete g_hTMEntity;
}


public Action ShowTeleportDestinations(int client, int args)
{
	Menu menu = new Menu(TD_MenuHandler);

	menu.SetTitle("Teleport Destinations");



	for (int i = 0; i < GetArraySize(g_hEntity); i++) 
	{
		// Get entity
		int entity = GetArrayCell(g_hEntity, i);

		// Get targetname
		char target_name[32];
		GetEntPropString(entity, Prop_Data, "m_iName", target_name, sizeof(target_name));

		menu.AddItem(target_name, target_name);
	} 

	menu.Display(client, 30);

	return Plugin_Handled;
}


public int TD_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		int entity = GetArrayCell(g_hEntity, param2);

		float position[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);

		SafeTeleport(param1, position, NULL_VECTOR, NULL_VECTOR, true);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}


public Action ShowTriggersLocations(int client, int args)
{
	Menu menu = new Menu(TM_MenuHandler);

	menu.SetTitle("trigger_multiple entities");

	for (int i = 0; i < GetArraySize(g_hTMEntity); i++)
	{
		// Get entity
		int entity = GetArrayCell(g_hTMEntity, i);

		// Get targetname
		char target_name[32];
		GetEntPropString(entity, Prop_Data, "m_iName", target_name, sizeof(target_name));

		menu.AddItem(target_name, target_name);
	}

	menu.Display(client, 30);

	return Plugin_Handled;
}


public int TM_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{

		int entity = GetArrayCell(g_hTMEntity, param2);

		float position[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);

		SafeTeleport(param1, position, NULL_VECTOR, NULL_VECTOR, true);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SafeTeleport(int client, float fDestination[3], float fAngles[3], float fVelocity[3], bool stopTimer)
{
	if (stopTimer)
		Shavit_StopTimer(client);

	// Teleport
	TeleportEntity(client, fDestination, fAngles, fVelocity);
}