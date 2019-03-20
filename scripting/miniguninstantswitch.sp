#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "v1.1"

public Plugin myinfo =
{
	name = "Minigun Instant Switch",
	author = "JugadorXEI",
	description = "Plugin that makes the minigun instantly switch to other weapons even while spunup.",
	url = "github.com/JugadorXEI",
	version = PLUGIN_VERSION,
}

ConVar g_bIsEnabled;
// SDKCalls
Handle hHasAnyAmmo;

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	g_bIsEnabled = CreateConVar("sm_minigun_enable", "1", "Enables/Disables the plugin. Default = 1");
	
	Handle hConfig = LoadGameConfigFile("miniguns.games");
	
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "HasAnyAmmo"))
	{
		SetFailState("Couldn't get HasAnyAmmo - offsets might be wrong or missing.");
		CloseHandle(hConfig);
	}
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	hHasAnyAmmo = EndPrepSDKCall();
}

public Action Event_PlayerSpawn(Handle hEvent, char[] cName, bool bDontBroadcast)
{
	if (g_bIsEnabled.BoolValue)
	{
		int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		TFClassType iClass = TF2_GetPlayerClass(iClient);
		
		if (iClient > 0 && iClass == TFClass_Heavy)
		{
			SDKHook(iClient, SDKHook_WeaponCanSwitchToPost, Hook_WeaponCanSwitchToPost);
		}
	}
}

void Hook_WeaponCanSwitchToPost (int iClient, int iWeaponToSwitchTo)
{
	if (iClient > 0 && IsPlayerAlive(iClient))
	{	
		TFClassType iClass = TF2_GetPlayerClass(iClient);
		if (iClass == TFClass_Heavy)
		{
			int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
			//PrintToChat(iClient, "%i", iActiveWeapon);
			
			if (IsValidEdict(iActiveWeapon))
			{
				char cWeaponMinigun[64];
				GetEntityClassname(iActiveWeapon, cWeaponMinigun, sizeof(cWeaponMinigun));
				
				if (StrEqual("tf_weapon_minigun", cWeaponMinigun))
				{
					int iMinigun = iActiveWeapon;
					int iWeaponState = GetEntProp(iMinigun, Prop_Send, "m_iWeaponState");
					
					if (iWeaponState > 0)
					{
						if (IsValidEntity(iWeaponToSwitchTo))
						{
							bool bHasAmmo = SDKCall(hHasAnyAmmo, iWeaponToSwitchTo);
							if (!bHasAmmo)
								return;
						}
						
						TF2_RemoveCondition(iClient, TFCond_Slowed);
						SetEntProp(iMinigun, Prop_Send, "m_iWeaponState", 0);
					}
					
					int iHeavyWeapons[3];
					for	(int i = 0; i < sizeof(iHeavyWeapons); i++)
						iHeavyWeapons[i] = GetPlayerWeaponSlot(iClient, i);
					
					for (int i = 0; i < sizeof(iHeavyWeapons); i++)
					{
						if (iHeavyWeapons[i] == iWeaponToSwitchTo)
						{
							// "slot[number]" commands are server_can_execute.
							// This is better than setting them though m_hActiveWeapon,
							// as it goes through the weapon's startup animation.
							ClientCommand(iClient, "slot%i", i + 1);
							// PrintToChat(iClient, "bep6");
						}
					}
				}
			}
				
		}
		else SDKUnhook(iClient, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchToPost);
	}
	else SDKUnhook(iClient, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchToPost);
}