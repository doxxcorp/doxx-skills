---
name: manage-domains
description: Manage doxx.net domains: register, DNS records, TLS certificates, import external domains
argument-hint: "[action] [domain name]"
user-invocable: true
allowed-tools: Bash(curl *), Bash(jq *), Bash(openssl *), Bash(dig *), Read, Write
---

# Manage doxx.net Domains

You help users register domains, manage DNS records, sign TLS certificates, and import external domains on doxx.net.

## Setup

```bash
API="https://config.doxx.net/v1/"
```

Use `$DOXX_TOKEN` if set, otherwise ask for the auth token.

User request: $ARGUMENTS

## Available operations

### List domains
```bash
curl -s -X POST $API -d "list_domains=1&token=$TOKEN" | jq .domains
```

### Register a domain
196 TLDs available. Popular choices:
- Private networking: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.local`, `.internal`
- Crypto: `.btc`, `.eth`, `.crypto`, `.dao`, `.wallet`
- Tech: `.api`, `.dns`, `.json`, `.git`, `.core`
- Hacking: `.cyber`, `.onion`, `.tor`, `.pwnd`

Default TLD is `.doxx` if none specified.

```bash
curl -s -X POST $API -d "create_domain=1&token=$TOKEN&domain=DOMAIN"
```

### Delete a domain
```bash
curl -s -X POST $API -d "delete_domain=1&token=$TOKEN&domain=DOMAIN"
```

Confirm with user before deleting.

### List DNS records
```bash
curl -s -X POST $API -d "list_dns=1&token=$TOKEN&domain=DOMAIN" | jq .records
```

### Create DNS record
Supported types: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, `PTR`.

```bash
curl -s -X POST $API -d "create_dns_record=1&token=$TOKEN&domain=DOMAIN&name=FQDN&type=A&content=IP&ttl=300"
```

For SRV records: add `srv_priority`, `srv_weight`, `srv_port`, `srv_target`.

### Update DNS record
```bash
curl -s -X POST $API -d "update_dns_record=1&token=$TOKEN&domain=DOMAIN&old_name=FQDN&old_type=TYPE&old_content=OLD_VALUE&name=FQDN&content=NEW_VALUE&ttl=300"
```

### Delete DNS record
```bash
curl -s -X POST $API -d "delete_dns_record=1&token=$TOKEN&domain=DOMAIN&name=FQDN&type=TYPE&content=VALUE"
```

### Verify DNS
```bash
dig A DOMAIN @a.root-dx.net +short
```

### Sign TLS certificate
Certificates are signed by the doxx.net root CA. Auto-wildcarded (`*.domain` + `domain`). Valid 365 days.

**Returns raw PEM, not JSON.**

```bash
openssl ecparam -genkey -name prime256v1 -out DOMAIN.key 2>/dev/null
openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN" 2>/dev/null
curl -s -X POST $API -d "sign_certificate=1&token=$TOKEN&domain=DOMAIN" --data-urlencode "csr=$(cat DOMAIN.csr)" -o DOMAIN.crt
openssl x509 -in DOMAIN.crt -noout -subject -ext subjectAltName
```

Remind users: clients need the doxx.net root CA installed to trust these certs.
Download: `curl -o doxx-root-ca.crt https://a0x13.doxx.net/assets/doxx-root-ca.crt`

### Import external domain (.com, .net, etc.)

1. Get verification code:
   ```bash
   curl -s -X POST $API -d "get_domain_validation=1&token=$TOKEN&domain=DOMAIN" | jq .validation_code
   ```
2. Tell user to set TXT record `_doxx-verify.DOMAIN` at their current DNS provider
3. Import:
   ```bash
   curl -s -X POST $API -d "import_domain=1&token=$TOKEN&domain=DOMAIN"
   ```
4. Tell user to update nameservers to: `a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`

## Guidelines

- Always list existing domains/records before making changes
- When creating A records for tunnels, get tunnel IPs from `list_tunnels` first
- Verify DNS after changes with `dig @a.root-dx.net`
- For TLS certs, the private key stays local:never send it anywhere

For full API details, see [../../../api/reference.md](../../../api/reference.md).
