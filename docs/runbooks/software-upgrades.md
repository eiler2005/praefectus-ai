# Software upgrade window

1. Read ownership and capture a private baseline for each host: package revisions,
   daemon version, running container definitions/health, listening surfaces,
   firewall and routing-owned systemd guard. Keep disabled workloads disabled.
2. Check upstream stable releases and official package candidates. Pin reviewed
   versions; a floating image tag is not evidence of a running upgrade.
3. Create consistent database snapshots for application migrations. Preserve old
   images, exact package files and configuration. Copy rollback material to the
   control machine, encrypt it and verify decryption/hash equality.
4. Run syntax/unit checks and `--check --diff`. Build application candidates in
   isolated contexts; test migrations against copies, never the live database.
   Compare client-visible credentials, transport, certificate trust and routing
   policy, not just process startup.
5. Obtain the required restart/reboot approval. Upgrade one host at a time with
   the other host reachable for diagnostics. Docker live restore helps preserve
   processes but does not replace an approved interruption boundary.
6. Use [software maintenance](../../modules/software-maintenance/README.md) for
   host packages. Application owners activate their images/binaries separately;
   preserve the routing resolver boot guard and all host-policy exceptions.
7. Run host verification and the application owner's full authenticated gate.
   For GhostRoute include protected anyT profiles, direct/managed/sensitive
   requests, native application handshakes, reverse service traffic and the
   restricted VPS-to-router management credential. Verify shared web delivery
   with desktop/mobile and real WebKit CSS checks when changing the edge.
8. Record observed versions, upgrade decisions, remaining reboot state and test
   boundaries in the software inventory. Commit sanitized records only. Keep
   actual endpoints, application mappings and detailed evidence private.

Stop and restore the previous reviewed runtime if a protected client import,
application probe, database integrity check, firewall boundary or recovery
contract regresses. Never turn off certificate checks or route sensitive traffic
directly to conceal an upgrade failure.
