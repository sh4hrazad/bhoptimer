static GlobalForward H_Forwards_OnCountdownStart = null;



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_Forwards_OnCountdownStart = new GlobalForward("Shavit_OnCountdownStart", ET_Event);
}

void Call_OnCountdownStart()
{
	Call_StartForward(H_Forwards_OnCountdownStart);
	Call_Finish();
}