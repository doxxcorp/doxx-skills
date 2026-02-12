---
name: manage-domains
description: Manage doxx.net domains: register, DNS records, TLS certificates, import external domains
argument-hint: "[action] [domain name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(openssl *), Bash(dig *), Bash(mkdir *), Bash(chmod *), Read, Write
---

# Manage doxx.net Domains

You help users register domains, manage DNS records, sign TLS certificates, and import external domains on doxx.net.

User request: $ARGUMENTS

## API convention

Token file: `~/.config/doxxnet/token`

**IMPORTANT — avoiding permission prompts:**
- To check if the token file exists: use the `Read` tool on `~/.config/doxxnet/token`
- To save a token: `mkdir -p ~/.config/doxxnet`, then `Write` tool to write the token to `~/.config/doxxnet/token`, then `chmod 600 ~/.config/doxxnet/token`
- NEVER chain commands with `&&` or `||` — compound commands trigger permission prompts. Each Bash call must be a single simple command.

If missing or auth fails, ask the user for their token, validate with `auth=1&token=THEIR_TOKEN`, and save it using the steps above.

**Config API** — POST to `https://config.doxx.net/v1/`:
```
curl -s -X POST https://config.doxx.net/v1/ -d "ENDPOINT=1&param=value&token=$(cat ~/.config/doxxnet/token)"
```

## Endpoints

- `list_domains` — list registered domains
- `create_domain` — register a domain. Params: `domain`
- `delete_domain` — delete a domain. Params: `domain`
- `list_dns` — list DNS records. Params: `domain`
- `create_dns_record` — create a record. Params: `domain`, `name` (FQDN), `type` (A/AAAA/CNAME/MX/TXT/NS/SRV/PTR), `content`. Optional: `ttl`, `prio`
- `update_dns_record` — update a record. Params: `domain`, `old_name`, `old_type`, `old_content`, `name`, `content`. Optional: `ttl`
- `delete_dns_record` — delete a record. Params: `domain`, `name`, `type`, `content`
- `get_domain_validation` — get TXT verification code for importing external domains. Params: `domain`
- `import_domain` — import external domain after TXT verification. Params: `domain`
- `sign_certificate` — sign a CSR (returns raw PEM, not JSON). Params: `domain`, `csr`
- `list_tunnels` — list tunnels (to get IPs for DNS records)

## TLD categories

Popular choices for private networking: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.local`, `.internal`

Other: crypto (.btc, .eth, .crypto), tech (.api, .dns, .json, .git), hacking (.cyber, .onion, .tor, .pwnd)

Default TLD is `.doxx` if none specified.

## TLS certificates

To sign a certificate, generate a key and CSR first with openssl, then call `sign_certificate`:
1. `openssl ecparam -genkey -name prime256v1 -out DOMAIN.key`
2. `openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN"`
3. `curl -s -X POST https://config.doxx.net/v1/ --data-urlencode "csr@DOMAIN.csr" -d "sign_certificate=1&domain=DOMAIN&token=$(cat ~/.config/doxxnet/token)"`

Remind users: clients need the doxx.net root CA installed to trust these certs.

## Importing external domains

1. Call `get_domain_validation` to get a TXT verification code
2. Tell user to create TXT record `_doxx-verify.DOMAIN` at their current DNS provider
3. Call `import_domain`
4. Tell user to update nameservers to: `a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`

## Guidelines

- Always list existing domains/records before making changes
- When creating A records for tunnels, get tunnel IPs from `list_tunnels` first
- Verify DNS after changes with `dig @a.root-dx.net`
- For TLS certs, the private key stays local — never send it anywhere
