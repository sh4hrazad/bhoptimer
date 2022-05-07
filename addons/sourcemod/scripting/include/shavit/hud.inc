/*
	hud Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_hud_included_
#endinput
#endif
#define _shavit_hud_included_



// =====[ DEFINES ]=====

// HUD2 - these settings will *disable* elements for the main hud
#define HUD2_NONE				0
#define HUD2_TIME				(1 << 0)
#define HUD2_SPEED				(1 << 1)
#define HUD2_WRPB				(1 << 2)// 0 pb | 1 WR
#define HUD2_PRESTRAFE			(1 << 3)

#define HUD_DEFAULT				(HUD_MASTER|HUD_CENTER|HUD_ZONEHUD|HUD_OBSERVE|HUD_TOPLEFT|HUD_SYNC|HUD_TIMELEFT|HUD_2DVEL|HUD_SPECTATORS|HUD_MAPTIER)
#define HUD_DEFAULT2			(HUD2_NONE)



// =====[ ENUMS ]=====

enum ZoneHUD
{
	ZoneHUD_None,
	ZoneHUD_Start,
	ZoneHUD_End,
	ZoneHUD_Stage
};



// =====[ ENUM STRUCTS ]=====

enum struct huddata_t
{
	int iTarget;
	float fTime;
	int iSpeed;
	int iStyle;
	int iTrack;
	int iStage;
	int iCheckpoint;
	int iJumps;
	int iStrafes;
	int iRank;
	float fSync;
	float fPB;
	float fWR;
	bool bReplay;
	bool bPractice;
	TimerStatus iTimerStatus;
	ZoneHUD iZoneHUD;
	int iFinishNum;
	bool bStageTimer;
	char sDiff[64];
	char sPreStrafe[64];
}



// =====[ NATIVE ]=====

/**
 * Force an HUD update for a player. Requires shavit-hud.
 *
 * @param client					Client index.
 * @param spectators                Should also update it for the player's spectators?
 * @error                           Error code 200 if client isn't valid.
 * @return                          Amount of players that had their HUD updated (client + spectators) or -1 on error.
 */
native int Shavit_ForceHUDUpdate(int client, bool spectators);

/**
 * Gets the HUD settings of a player.
 * See the HUD_* defines for information.
 *
 * @param client					Client index.
 * @return                          HUD settings.
 */
native int Shavit_GetHUDSettings(int client);



// =====[ STOCK ]=====

stock void SendMessageToSpectator(int client, const char[] message, any ..., bool translate = false)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && (IsValidClient(i) && GetSpectatorTarget(i, i) == client))
		{
			if(!translate)
			{
				Shavit_PrintToChat(i, message);
			}
			else
			{
				SetGlobalTransTarget(i);

				char sBuffer[256];
				VFormat(sBuffer, sizeof(sBuffer), message, 3);
				Shavit_PrintToChat(i, sBuffer);
			}
		}
	}
}

// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_hud = 
{
	name = "shavit-hud", 
	file = "shavit-hud.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_hud_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_ForceHUDUpdate");
	MarkNativeAsOptional("Shavit_GetHUDSettings");
}
#endif