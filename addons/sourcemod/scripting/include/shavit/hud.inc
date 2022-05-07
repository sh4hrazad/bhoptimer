/*
	hud Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_hud_included_
#endinput
#endif
#define _shavit_hud_included_



// =====[ DEFINES ]=====

// HUD
#define HUD_NONE				0
#define HUD_MASTER				(1 << 0) // master setting
#define HUD_CENTER				(1 << 1) // show hud as hint text
#define HUD_ZONEHUD				(1 << 2) // show start/end zone hud
#define HUD_OBSERVE				(1 << 3) // show the HUD of the player you spectate
#define HUD_SPECTATORS			(1 << 4) // show list of spectators
#define HUD_KEYOVERLAY			(1 << 5) // show a key overlay
#define HUD_HIDEWEAPON			(1 << 6) // hide the player's weapon
#define HUD_TOPLEFT				(1 << 7) // show top left white HUD with WR/PB times
#define HUD_SYNC				(1 << 8) // shows sync at right side of the screen (css only)
#define HUD_TIMELEFT			(1 << 9) // shows time left at right tside of the screen (css only)
#define HUD_2DVEL				(1 << 10) // shows 2d velocity
#define HUD_NOSOUNDS			(1 << 11) // disables sounds on personal best, world record etc
#define HUD_MAPTIER			(1 << 12)

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



/* -- Forwards -- */

/**
 * Called when top left HUD updates.
 *
 * @param client					Client index that recieves the hud.
 * @param target					Target entity that is either the client or what the client is spectating.
 * @param topleft					Reference to the HUD buffer.
 * @param topleftlength				Max length of the topleft buffer.
 * @return							Plugin_Handled or Plugin_Stop to block the HUD message from appearing. Anything else to pass along new values.
 */
forward Action Shavit_OnTopLeftHUD(int client, int target, char[] topleft, int topleftlength);


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