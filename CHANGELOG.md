# Changelog

## 1.0.0

Public release. OpenClaw support, complete API reference, CI validation.

- Added OpenClaw skill ports for all 11 skills
- Added CONTRIBUTING.md, issue templates, PR template
- Completed API reference with Devices, IP Addresses, Saved Profiles, and Account endpoints
- Updated install instructions for public marketplace
- Narrowed sudo permissions to `sudo wg-quick *` only
- Full CI validation for both Claude and OpenClaw skills

## 0.4.0

- Added manage-devices, manage-addresses, manage-account skills
- Added evals for all 11 skills
- Added API consistency checks to CI
- Synced marketplace.json with plugin.json

## 0.3.0

- Added network-stats, network-status skills
- Added Stats API documentation

## 0.2.0

- Added manage-domains, manage-firewall, manage-dns-blocking skills
- Added DNS, Firewall, and Domain API documentation

## 0.1.0

Initial release.

- doxxnet (general-purpose skill)
- network-wizard (guided setup)
- manage-tunnels (tunnel CRUD + WireGuard configs)
- API reference with core endpoints
