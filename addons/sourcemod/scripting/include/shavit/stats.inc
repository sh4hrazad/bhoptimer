/*
	stats Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_stats_included_
#endinput
#endif
#define _shavit_stats_included_



// ======[ ENUMS ]======

enum // macros
{
	MAPSDONE,
	MAPSLEFT
};



// =====[ NATIVES ]=====

/**
 * Opens the stats menu for a client.
 *
 * @param client					Client index.
 * @param steamid					Target Steam account ID to use.
 * @noreturn
 */
native void Shavit_OpenStatsMenu(int client, int steamid);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_stats = 
{
	name = "shavit-stats", 
	file = "shavit-stats.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_stats_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_OpenStatsMenu");
}
#endif