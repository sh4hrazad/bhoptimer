/*
	timelimit Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_timelimit_included_
#endinput
#endif
#define _shavit_timelimit_included_


// =====[ FORWARDS ]=====

/**
 * Called from shavit-timelimit when the 5 second map change countdown starts.
 *
 * @noreturn
 */
forward void Shavit_OnCountdownStart();



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_timelimit = 
{
	name = "shavit-timelimit", 
	file = "shavit-timelimit.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};