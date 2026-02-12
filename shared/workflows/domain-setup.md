# Workflow: Domain Setup

Agent-neutral procedure for registering a domain, configuring DNS, and signing TLS certificates.

## Variables

- `API` = `https://config.doxx.net/v1/`
- `TOKEN` = user's auth token
- `DOMAIN` = chosen domain (e.g., `mysite.doxx`)

---

## Registering a doxx.net Domain

### Step 1: Choose a domain and TLD

196 TLDs available. Popular choices for private networking:
- `.lan`, `.local`, `.vpn`, `.mesh`, `.home`, `.wg`, `.wireguard`, `.internal`

Other categories: crypto (.btc, .eth, .crypto), hacking (.cyber, .onion), tech (.api, .dns), gaming (.gamer, .gta6).

If no TLD specified, defaults to `.doxx`.

### Step 2: Register

```bash
curl -s -X POST $API -d "create_domain=1&token=$TOKEN&domain=$DOMAIN"
```

### Step 3: Add DNS records

```bash
# A record (IPv4)
curl -s -X POST $API -d "create_dns_record=1&token=$TOKEN&domain=$DOMAIN&name=$DOMAIN&type=A&content=IP_ADDRESS&ttl=300"

# Wildcard
curl -s -X POST $API -d "create_dns_record=1&token=$TOKEN&domain=$DOMAIN&name=*.$DOMAIN&type=A&content=IP_ADDRESS&ttl=300"

# AAAA record (IPv6)
curl -s -X POST $API -d "create_dns_record=1&token=$TOKEN&domain=$DOMAIN&name=$DOMAIN&type=AAAA&content=IPV6_ADDRESS&ttl=300"
```

### Step 4: Verify DNS

```bash
dig A $DOMAIN @a.root-dx.net +short
```

---

## Importing an External Domain (.com, .net, etc.)

### Step 1: Get verification code

```bash
curl -s -X POST $API -d "get_domain_validation=1&token=$TOKEN&domain=mysite.com" | jq .validation_code
```

### Step 2: Set TXT record at current DNS provider

Create a TXT record: `_doxx-verify.mysite.com` with the validation code.

### Step 3: Import

```bash
curl -s -X POST $API -d "import_domain=1&token=$TOKEN&domain=mysite.com"
```

### Step 4: Update nameservers at registrar

Set nameservers to:
- `a.root-dx.net`
- `a.root-dx.com`
- `a.root-dx.org`

DNS propagation takes up to 48 hours.

---

## TLS Certificate

### Step 1: Generate key and CSR locally

```bash
openssl ecparam -genkey -name prime256v1 -out $DOMAIN.key 2>/dev/null
openssl req -new -key $DOMAIN.key -out $DOMAIN.csr -subj "/CN=$DOMAIN" 2>/dev/null
```

### Step 2: Sign with doxx.net root CA

```bash
curl -s -X POST $API -d "sign_certificate=1&token=$TOKEN&domain=$DOMAIN" --data-urlencode "csr=$(cat $DOMAIN.csr)" -o $DOMAIN.crt
```

The certificate is automatically wildcarded: `*.domain` + `domain`. Valid for 365 days.

### Step 3: Verify

```bash
openssl x509 -in $DOMAIN.crt -noout -subject -ext subjectAltName
```

### Step 4: Install root CA on clients

Clients need the doxx.net root CA to trust these certificates:

```bash
curl -o doxx-root-ca.crt https://a0x13.doxx.net/assets/doxx-root-ca.crt
```

- **macOS:** `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain doxx-root-ca.crt`
- **Linux:** `sudo cp doxx-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`
- **Windows:** `certutil -addstore root doxx-root-ca.crt`
- **Firefox:** Settings → Privacy & Security → Certificates → Import

---

## Managing DNS Records

**List all records:**
```bash
curl -s -X POST $API -d "list_dns=1&token=$TOKEN&domain=$DOMAIN" | jq .records
```

**Update a record:**
```bash
curl -s -X POST $API -d "update_dns_record=1&token=$TOKEN&domain=$DOMAIN&old_name=FQDN&old_type=A&old_content=OLD_IP&name=FQDN&content=NEW_IP&ttl=300"
```

**Delete a record:**
```bash
curl -s -X POST $API -d "delete_dns_record=1&token=$TOKEN&domain=$DOMAIN&name=FQDN&type=A&content=IP"
```

Supported types: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, `PTR`.
