---
name: manage-domains
description: Manage doxx.net domains: register, DNS records, TLS certificates, import external domains
argument-hint: "[action] [domain name]"
user-invocable: true
allowed-tools: Bash(openssl *), Bash(dig *)
---

# Manage doxx.net Domains

You help users register domains, manage DNS records, sign TLS certificates, and import external domains on doxx.net.

Use the doxxnet MCP tools for all API calls. If the token is not configured, ask the user for their auth token.

User request: $ARGUMENTS

## Available MCP tools

- `doxx_list_domains` — list registered domains
- `doxx_create_domain` — register a new domain (196 TLDs available)
- `doxx_delete_domain` — delete a domain
- `doxx_list_dns` — list DNS records for a domain
- `doxx_create_dns_record` — create a DNS record (A, AAAA, CNAME, MX, TXT, NS, SRV, PTR)
- `doxx_update_dns_record` — update a DNS record
- `doxx_delete_dns_record` — delete a DNS record
- `doxx_domain_validation` — get verification code for importing external domains
- `doxx_import_domain` — import an external domain after TXT verification
- `doxx_sign_certificate` — sign a CSR with doxx.net root CA (auto-wildcarded, 365 days)
- `doxx_list_tunnels` — list tunnels (to get IPs for DNS records)

## TLD categories

Popular choices for private networking: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.local`, `.internal`

Other: crypto (.btc, .eth, .crypto), tech (.api, .dns, .json, .git), hacking (.cyber, .onion, .tor, .pwnd)

Default TLD is `.doxx` if none specified.

## TLS certificates

To sign a certificate, generate a key and CSR first with openssl, then use `doxx_sign_certificate`:
1. `openssl ecparam -genkey -name prime256v1 -out DOMAIN.key`
2. `openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN"`
3. Call `doxx_sign_certificate` with the CSR content

Remind users: clients need the doxx.net root CA installed to trust these certs.

## Importing external domains

1. Call `doxx_domain_validation` to get a TXT verification code
2. Tell user to create TXT record `_doxx-verify.DOMAIN` at their current DNS provider
3. Call `doxx_import_domain`
4. Tell user to update nameservers to: `a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`

## Guidelines

- Always list existing domains/records before making changes
- When creating A records for tunnels, get tunnel IPs from `doxx_list_tunnels` first
- Verify DNS after changes with `dig @a.root-dx.net`
- For TLS certs, the private key stays local — never send it anywhere
