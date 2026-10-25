# Scope of v2.7.0 beta

Implemented launcher configuration for existing SoH 9.3.1 Anchor: random shared room code, same team, host name Sen, joining player Ivan/red, item/flag sharing enabled, PvP disabled, save backup before entering session, solo reset, controller defaults on every Play. Uses upstream public relay anchor.hm64.org:43383; this relay has not been provisioned or controlled by SENZ.

Not implemented: strict two-player limit, complete host-authoritative world replication, shared boss/enemy simulation and synchronized cutscene timeline. No end-to-end Windows or two-PC test has occurred. Room configuration is not proof of a connected session. Native Anchor merges supported item/flag state rather than implementing the requested all-state host ownership.

For a full implementation, engine-side authority, actor IDs/ownership, reliable scene snapshots, reconnect restore, cutscene barriers, and an enforceable two-slot room protocol are still needed, followed by two-PC playtesting. Do not label this beta as full co-op.
