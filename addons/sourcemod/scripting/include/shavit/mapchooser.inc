/**
 * Include file for shavit-mapchooser.sp
 *
 * Original plugin website: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
 */

#if defined _shavit_mapchooser_included
	#endinput
#endif
#define _shavit_mapchooser_included

/**
 * Called when a player RTV's.
 * Requires shavit-mapchooser.
 *
 * @param client					Client index.
 * @noreturn
 */
forward void Shavit_OnRTV(int client);

/**
 * Called when a player UNRTV's.
 * Requires shavit-mapchooser.
 *
 * @param client					Client index.
 * @noreturn
 */
forward void Shavit_OnUnRTV(int client);

/**
 * Called when the map changes from an RTV.
 * Requires shavit-mapchooser.
 *
 * @noreturn
 */
forward void Shavit_OnSuccesfulRTV();

public SharedPlugin __pl_shavit_mapchooser =
{
	name = "shavit-mapchooser",
	
	file = "shavit-mapchooser.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};