#if defined _sfork_trikz_included
	#endinput
#endif
#define _sfork_trikz_included

enum {
	// we will use Bonus 1 - 4 for trikz bonus and Bonus 5 - 8 for solo bonus
	Track_Trikz_Count = 5,
	Track_Solobonus = 5,
};

enum {
	No_Waiting,
	Waiting_For_Partner,
	Waiting_For_Client,
};

enum struct finish_info_t {
	int iJumps;
	int iFlashes;	// TODO
	float fOldTime; // Personal Best
}

enum struct trikz_finish_info_t {
	finish_info_t aInfoP1;
	finish_info_t aInfoP2;
	float fTime;
	float fOldTime;	// Partner Best
	int iStyle;
	int iTrack;
	int iTimestamp;
}

stock void MyCopyArray(any[] from, any[] to, int size) {
	for (int i = 0; i < size; i++) {
		to[i] = from[i];
	}
}

native int sFork_IsWaitingInEnd(int client, int track);

forward void sFork_OnPartner(int client1, int client2);

forward void sFork_OnNtrPartner(int client, int partner, int target);

forward void sFork_OnBreakup(int client, int partner);

forward void sFork_OnFinishTrikz(int client1, int client2, trikz_finish_info_t info, bool isWr);

public SharedPlugin __pl_sfork_trikz = {
	name = "sfork-trikz",
	file = "sfork-trikz.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_sfork_trikz_SetNTVOptional() {
	MarkNativeAsOptional("sFork_IsWaitingInEnd");
}
#endif
