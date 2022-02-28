/*
	chat Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_chat_included_
#endinput
#endif
#define _shavit_chat_included_



// =====[ DEFINES ]=====

#define MAGIC_NUMBER 2147483648.0
#define MAXLENGTH_NAME 128
#define MAXLENGTH_TEXT 128
#define MAXLENGTH_MESSAGE 255
#define MAXLENGTH_DISPLAY 192
#define MAXLENGTH_CMESSAGE 16
#define MAXLENGTH_BUFFER 255



// =====[ ENUMS ]=====

enum
{
	Require_Rank,
	Require_Points,
	Require_WR_Count,
	Require_WR_Rank,
}



// =====[ ENUM STRUCTS ]=====

enum struct chatranks_cache_t
{
	int iRequire;
	float fFrom;
	float fTo;
	bool bFree;
	bool bEasterEgg;
	bool bRanged;
	bool bPercent;
	char sAdminFlag[32];
	char sName[MAXLENGTH_NAME];
	char sMessage[MAXLENGTH_MESSAGE];
	char sDisplay[MAXLENGTH_DISPLAY];
}

// =====[ NATIVES]=====

/**
 * Retrieves the player's chatrank trimmed and without colors.
 *
 * @param client					Client index
 * @param buf						Buffer to put the put the chatrank into
 * @param buflen					Size of buf
 * @param includename				Include {name} in result.
 * @noreturn
 */
native void Shavit_GetPlainChatrank(int client, char[] buf, int buflen, bool includename=false);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_chat = 
{
	name = "shavit-chat", 
	file = "shavit-chat.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_chat_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_GetPlainChatrank");
}
#endif