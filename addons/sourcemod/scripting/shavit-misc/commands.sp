void RegisterCommands()
{
	RegisterCommands_ChatColors();
	RegisterCommands_Spectators();
	RegisterCommands_Hide();
	RegisterCommands_Teleport();
	RegisterCommands_Weapon();
	RegisterCommands_Advs();
}

void AddCommandListeners()
{
	AddCommandListeners_Noclip();
	AddCommandListeners_Drop();
	AddCommandListeners_Radios();
}