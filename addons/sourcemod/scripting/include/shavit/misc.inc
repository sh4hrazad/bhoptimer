/*
	misc Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_misc_included_
#endinput
#endif
#define _shavit_misc_included_



// =====[ FORWARDS ]=====

/**
 * Called before clan tag variables are processed.
 *
 * @param client					Client index.
 * @param clantag					Reference to the clan tag buffer.
 * @param clantaglength				Max length of the customtag buffer.
 * @return							Plugin_Handled or Plugin_Stop to block the clan tag from changing. Anything else to pass along new values.
 */
forward Action Shavit_OnClanTagChangePre(int client, char[] clantag, int clantaglength);

/**
 * Called after clan tags are changed.
 *
 * @param client					Client index.
 * @param customtag					Reference to the custom clan tag buffer.
 * @param customtaglength			Max length of the customtag buffer.
 * @noreturn							
 */
forward void Shavit_OnClanTagChangePost(int client, char[] customtag, int customtaglength);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_misc = 
{
	name = "shavit-misc", 
	file = "shavit-misc.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};