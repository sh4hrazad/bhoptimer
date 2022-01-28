// stolen from cs_shareddefs.cpp
const float CS_PLAYER_DUCK_SPEED_IDEAL = 8.0;



// ======[ EVENTS ]======

void Shavit_OnUserCmdPre_FixDuck(int client, int buttons)
{
	if (gCV_CSGOFixDuckTime.BoolValue && (buttons & IN_DUCK))
	{
		SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", CS_PLAYER_DUCK_SPEED_IDEAL);
	}
}