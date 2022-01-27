/*
	sounds Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
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
