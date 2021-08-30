/*
 * =============================================================================
 * File:		  zr_random_overlay.sp
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C) $CURRENT_YEAR  Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */
#define PLUGIN_NAME           "Zr Randon Round End Overlay"
#define PLUGIN_AUTHOR         "Anubis"
#define PLUGIN_DESCRIPTION    "Zr Randon Round End Overlay"
#define PLUGIN_VERSION        "1.1"
#define PLUGIN_URL            "https://github.com/Stewart-Anubis"
#define CVARS_ZR_ROUNDEND_OVERLAY_LOCKED 0

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma newdecls required

ConVar g_CvarEnable =null,
	g_CvarZr_Roundend_Overlay = null,
	g_CvarConfig_FilePath = null;

ArrayList g_smOverlayPathH;
ArrayList g_smOverlayPathZ;

bool g_bEnable = true,
	g_bRoundEnd = false;

char g_sConfig_FilePath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	int iArraySizePath = ByteCountToCells(PLATFORM_MAX_PATH);
	g_smOverlayPathH = new ArrayList(iArraySizePath);
	g_smOverlayPathZ = new ArrayList(iArraySizePath);

	g_CvarEnable = CreateConVar("zr_menu_overlay_enable", "1", "Menu Overlay Enable = 1/Disable = 0");
	g_CvarConfig_FilePath = CreateConVar("zr_menu_overlay_config_path", "configs/zr/zr_random_overlay.txt", "Location of configuration file.");
	g_CvarZr_Roundend_Overlay = FindConVar("zr_roundend_overlay");

	g_CvarEnable.AddChangeHook(OnConVarChanged);
	g_CvarConfig_FilePath.AddChangeHook(OnConVarChanged);
	g_CvarZr_Roundend_Overlay.AddChangeHook(OnConVarChanged);

	OnConVarChanged(null, "", "");
	AutoExecConfig(true, "zombiereloaded/zr_random_overlay");
	if (g_bEnable) SetConVarInt(g_CvarZr_Roundend_Overlay, CVARS_ZR_ROUNDEND_OVERLAY_LOCKED);

	RegAdminCmd("sm_overlayreload", Command_Reload, ADMFLAG_ROOT, "Descrição");
	
	// Hook events
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	File_ReadDownloadList();
}

public void OnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_bEnable = g_CvarEnable.BoolValue;
	g_CvarConfig_FilePath.GetString(g_sConfig_FilePath ,sizeof(g_sConfig_FilePath));
	if (convar == g_CvarZr_Roundend_Overlay)
	{
		if (!g_bEnable || StringToInt(newValue) == CVARS_ZR_ROUNDEND_OVERLAY_LOCKED) return;
		SetConVarInt(g_CvarZr_Roundend_Overlay, CVARS_ZR_ROUNDEND_OVERLAY_LOCKED);
	}
}

public void OnPluginEnd()
{
	g_smOverlayPathH.Clear();
	g_smOverlayPathZ.Clear();
}

public Action Command_Reload(int client, int arg)
{
	File_ReadDownloadList();

	return Plugin_Handled;
}

void File_ReadDownloadList()
{
	KeyValues g_hKvOverlay;

	g_smOverlayPathH.Clear();
	g_smOverlayPathZ.Clear();

	char sBuffer_temp[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, sBuffer_temp, sizeof(sBuffer_temp), g_sConfig_FilePath);

	g_hKvOverlay = new KeyValues("Overlay");

	if(!FileExists(sBuffer_temp))
	{
		SetFailState("Could not find config: \"%s\"", sBuffer_temp);
		return;
	}
	else FileToKeyValues(g_hKvOverlay, sBuffer_temp);

	KvRewind(g_hKvOverlay);
	if(KvJumpToKey(g_hKvOverlay, "Overlay_Humans"))
	{
		if(KvGotoFirstSubKey(g_hKvOverlay))
		{
			do
			{
				KvGetString(g_hKvOverlay, "Overlay", sBuffer_temp, sizeof(sBuffer_temp), "MISSING");
				g_smOverlayPathH.PushString(sBuffer_temp);
				Format(sBuffer_temp, sizeof(sBuffer_temp), "materials/%s.vmt", sBuffer_temp);
				AddFileToDownloadsTable(sBuffer_temp);
				ReplaceString(sBuffer_temp, sizeof(sBuffer_temp), ".vmt", ".vtf");
				AddFileToDownloadsTable(sBuffer_temp);
			} while (KvGotoNextKey(g_hKvOverlay));
		}
	}
	KvRewind(g_hKvOverlay);
	if(KvJumpToKey(g_hKvOverlay, "Overlay_Zombies"))
	{
		if(KvGotoFirstSubKey(g_hKvOverlay))
		{
			do
			{
				KvGetString(g_hKvOverlay, "Overlay", sBuffer_temp, sizeof(sBuffer_temp), "MISSING");
				g_smOverlayPathZ.PushString(sBuffer_temp);
				Format(sBuffer_temp, sizeof(sBuffer_temp), "materials/%s.vmt", sBuffer_temp);
				AddFileToDownloadsTable(sBuffer_temp);
				ReplaceString(sBuffer_temp, sizeof(sBuffer_temp), ".vmt", ".vtf");
				AddFileToDownloadsTable(sBuffer_temp);
			} while (KvGotoNextKey(g_hKvOverlay));
		}
	}
	KvRewind(g_hKvOverlay);
	delete g_hKvOverlay;
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = false;
	if(g_bEnable) ShowOverlayToAll("");
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundEnd)
	{
		g_bRoundEnd = true;
		// Get all required event info.
		int winner = GetEventInt(event, "winner");

		// Display the overlay to all clients.
		if(g_bEnable) CreateTimer(0.2, Event_RoundEndPost, winner, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Event_RoundEndPost(Handle time, int winner)
{
	RoundEndOverlayStart(winner);
	return Plugin_Stop;
}

void RoundEndOverlayStart(int winner)
{
	char sBuffer_temp[PLATFORM_MAX_PATH];
	
	switch(winner)
	{
		// Show "zombies win" overlay.
		case CS_TEAM_T:
		{
			int randoverlay = GetRandomInt(0, (g_smOverlayPathZ.Length - 1));

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					g_smOverlayPathZ.GetString(randoverlay, sBuffer_temp, sizeof(sBuffer_temp));
					ShowOverlayToClient(i, sBuffer_temp);
				}
			}
		}
		// Show "humans win" overlay.
		case CS_TEAM_CT:
		{
			int randoverlay = GetRandomInt(0, (g_smOverlayPathH.Length - 1));

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					g_smOverlayPathH.GetString(randoverlay, sBuffer_temp, sizeof(sBuffer_temp));
					ShowOverlayToClient(i, sBuffer_temp);
				}
			}
		}
		// Show no overlay.
		default:
		{
			ShowOverlayToAll("");
		}
	}
}

void ShowOverlayToAll(const char[] overlaypath)
{
	// x = client index.
	for (int x = 1; x <= MaxClients; x++)
	{
		// If client isn't in-game, then stop.
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			ShowOverlayToClient(x, overlaypath);
		}
	}
}

void ShowOverlayToClient(int client, const char[] overlaypath)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}