# Radmin VPN multiplayer (first playable base)

This first multiplayer pass uses Godot's built-in ENet multiplayer over UDP. It is intended for friends on the same Radmin VPN network.

## Host

1. Everyone joins the same Radmin VPN network.
2. The host opens Shinobi Clash and selects **Multiplayer → Host World**.
3. Allow Shinobi Clash through Windows Firewall on private networks if Windows asks.
4. Share the host's Radmin VPN IPv4 address with the other players.
5. Keep the host game running.

## Join

1. Join the same Radmin VPN network as the host.
2. Select **Multiplayer**, enter the host's Radmin VPN IPv4 address, and press **Join World**.
3. Use port **7000** unless the host changed it.

## What is synchronized

- Player spawning and disconnect cleanup.
- Player position and character facing.
- Up to 8 players in one hosted session.

This is a networking foundation, not full co-op gameplay yet. Combat, enemy AI, NPC interactions, quests, inventory, progression, and ability effects are still local to each game instance and need server-authoritative synchronization in later steps.

## Troubleshooting

- Both players must be in the same Radmin VPN network.
- Use the host's **Radmin VPN IPv4 address**, not their public IP or home LAN address.
- Keep UDP port 7000 allowed through the host's firewall.
- If connection fails, verify that the Radmin connection shows the other player as reachable and that both builds use the same game version.
