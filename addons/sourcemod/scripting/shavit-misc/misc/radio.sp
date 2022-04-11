char gS_RadioCommands[][] = 
{ 
	"coverme", 
	"takepoint", 
	"holdpos", 
	"regroup", 
	"followme", 
	"takingfire", 
	"go", 
	"fallback", 
	"sticktog",
	"getinpos", 
	"stormfront", 
	"report", 
	"roger", 
	"enemyspot", 
	"needbackup", 
	"sectorclear", 
	"inposition", 
	"reportingin",
	"getout", 
	"negative", 
	"enemydown", 
	"compliment", 
	"thanks", 
	"cheer", 
	"go_a", 
	"go_b", 
	"sorry", 
	"needrop", 
	"playerradio", 
	"playerchatwheel", 
	"player_ping", 
	"chatwheel_ping" 
};



// ======[ EVENTS ]======

void AddCommandListeners_Radios()
{
    for(int i = 0; i < sizeof(gS_RadioCommands); i++)
	{
		AddCommandListener(Command_Radio, gS_RadioCommands[i]);
	}
}

public Action Command_Radio(int client, const char[] command, int args)
{
	if(gCV_DisableRadio.BoolValue)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}