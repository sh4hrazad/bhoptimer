/**
 * Include file for shavit-sounds.sp
 *
 * Original plugin website: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
 */

#if defined _shavit_sounds_included_
#endinput
#endif
#define _shavit_sounds_included_



// =====[ FORWARDS ]=====

/**
 * Called before a sound is played by shavit-sounds.
 *
 * @param client					Index of the client that triggered the sound event.
 * @param sound						Reference to the sound that will be played.
 * @param maxlength					Length of the sound buffer, always PLATFORM_MAX_PATH.
 * @param clients					Reference to the array of clients to receive the sound, maxsize of MaxClients.
 * @param count						Reference to the number of clients to receive the sound.
 * @return							Plugin_Handled or Plugin_Stop to block the sound from being played. Anything else to continue the operation.
 */
forward Action Shavit_OnPlaySound(int client, char[] sound, int maxlength, int[] clients, int &count);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_sounds = 
{
	name = "shavit-sounds", 
	file = "shavit-sounds.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};