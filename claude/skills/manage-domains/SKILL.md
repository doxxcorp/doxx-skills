---
name: manage-domains
description: Manage doxx.net domains: register, DNS records, TLS certificates, import external domains
argument-hint: "[action] [domain name]"
user-invocable: true
allowed-tools: Bash(python3 *), Bash(openssl *), Bash(dig *), Read, Write
---

# Manage doxx.net Domains

You help users register domains, manage DNS records, sign TLS certificates, and import external domains on doxx.net.

## Setup

All API calls use the helper script. Locate it first:
```bash
DOXXNET_API=$(find ~/.claude/plugins -name "doxx-api.py" -path "*/doxxnet/*" 2>/dev/null | head -1)
```

If `$DOXXNET_TOKEN` is not set in the environment, ask the user for their auth token.

User request: $ARGUMENTS

## Available operations

### List domains
```bash
python3 $DOXXNET_API list_domains
```

### Register a domain
196 TLDs available. Popular choices:
- Private networking: `.lan`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.local`, `.internal`
- Crypto: `.btc`, `.eth`, `.crypto`, `.dao`, `.wallet`
- Tech: `.api`, `.dns`, `.json`, `.git`, `.core`
- Hacking: `.cyber`, `.onion`, `.tor`, `.pwnd`

Default TLD is `.doxx` if none specified.

```bash
python3 $DOXXNET_API create_domain domain=DOMAIN
```

### Delete a domain
```bash
python3 $DOXXNET_API delete_domain domain=DOMAIN
```

Confirm with user before deleting.

### List DNS records
```bash
python3 $DOXXNET_API list_dns domain=DOMAIN
```

### Create DNS record
Supported types: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, `PTR`.

```bash
python3 $DOXXNET_API create_dns_record domain=DOMAIN name=FQDN type=A content=IP ttl=300
```

For SRV records: add `srv_priority`, `srv_weight`, `srv_port`, `srv_target`.

### Update DNS record
```bash
python3 $DOXXNET_API update_dns_record domain=DOMAIN old_name=FQDN old_type=TYPE old_content=OLD_VALUE name=FQDN content=NEW_VALUE ttl=300
```

### Delete DNS record
```bash
python3 $DOXXNET_API delete_dns_record domain=DOMAIN name=FQDN type=TYPE content=VALUE
```

### Verify DNS
```bash
dig A DOMAIN @a.root-dx.net +short
```

### Sign TLS certificate
Certificates are signed by the doxx.net root CA. Auto-wildcarded (`*.domain` + `domain`). Valid 365 days.

**`sign_certificate` returns raw PEM, not JSON — use curl directly for this endpoint:**

```bash
openssl ecparam -genkey -name prime256v1 -out DOMAIN.key 2>/dev/null
openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN" 2>/dev/null
python3 -c "
import urllib.request, urllib.parse, os
token = os.environ['DOXXNET_TOKEN']
csr = open('DOMAIN.csr').read()
data = urllib.parse.urlencode({'sign_certificate': '1', 'token': token, 'domain': 'DOMAIN', 'csr': csr}).encode()
req = urllib.request.Request('https://config.doxx.net/v1/', data=data, method='POST')
resp = urllib.request.urlopen(req)
open('DOMAIN.crt', 'wb').write(resp.read())
"
openssl x509 -in DOMAIN.crt -noout -subject -ext subjectAltName
```

Remind users: clients need the doxx.net root CA installed to trust these certs.
Download: `python3 -c "import urllib.request; urllib.request.urlretrieve('https://a0x13.doxx.net/assets/doxx-root-ca.crt', 'doxx-root-ca.crt')"`

### Import external domain (.com, .net, etc.)

1. Get verification code:
   ```bash
   python3 $DOXXNET_API get_domain_validation domain=DOMAIN
   ```
2. Tell user to set TXT record `_doxx-verify.DOMAIN` at their current DNS provider
3. Import:
   ```bash
   python3 $DOXXNET_API import_domain domain=DOMAIN
   ```
4. Tell user to update nameservers to: `a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`

## Guidelines

- Always list existing domains/records before making changes
- When creating A records for tunnels, get tunnel IPs from `list_tunnels` first
- Verify DNS after changes with `dig @a.root-dx.net`
- For TLS certs, the private key stays local:never send it anywhere

For full API details, see [../../../api/reference.md](../../../api/reference.md).
