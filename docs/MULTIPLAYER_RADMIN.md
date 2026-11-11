# Radmin VPN multiplayer

Shinobi Clash uses Godot ENet over UDP for direct host-and-join sessions. The room supports **8 players total** (the host plus up to 7 clients).

## Host a session

1. All players join the same Radmin VPN network.
2. Open Shinobi Clash and choose **Multiplayer**.
3. Choose **Host Co-op World** or **Host PvP Arena**.
4. Allow the game through Windows Firewall on private networks.
5. Share the host's Radmin VPN IPv4 address. The default UDP port is **7000**.

## Join

1. Join the same Radmin VPN network.
2. Open **Multiplayer**, enter the host's Radmin VPN IPv4 address, and select **Join Host**.
3. Use the host's port (default **7000**).

Use the Radmin VPN IPv4 address, not the host's public IP or ordinary home-LAN address. Allow inbound UDP on the host's selected port.

## Current implementation scope

- ENet host/join, up to 8 peers total.
- Lobby name and host-selected Co-op or PvP session type.
- Remote player spawning, name tags, and smoothed position/facing replication.
- Basic server-validated close-range melee PvP damage.
- Disconnect cleanup.

## Known limitations of this first pass

- Co-op currently synchronizes players, not enemy AI, NPC state, quest progress, loot, or progression. Those systems still run locally on each game.
- PvP currently supports close-range melee hits only. Jutsu, projectiles, knockback replication, health UI, respawn flow, and anti-cheat hardening are not yet networked.
- The host is authoritative for player hit validation, but movement replication is a lightweight prototype and is not suitable for public/internet matchmaking.
- This implementation has not yet been run in Godot or tested between two Radmin VPN computers. Test it with two game instances before relying on it.
