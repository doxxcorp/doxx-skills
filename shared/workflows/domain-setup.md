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
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain to register: ')

data = urllib.parse.urlencode({'create_domain': '1', 'token': TOKEN, 'domain': DOMAIN}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

### Step 3: Add DNS records

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain: ')
NAME = input('Record name (FQDN): ')
TYPE = input('Record type (A/AAAA/CNAME/MX/TXT): ')
CONTENT = input('Content (IP or value): ')

data = urllib.parse.urlencode({'create_dns_record': '1', 'token': TOKEN, 'domain': DOMAIN, 'name': NAME, 'type': TYPE, 'content': CONTENT, 'ttl': '300'}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

### Step 4: Verify DNS

```bash
dig A $DOMAIN @a.root-dx.net +short
```

---

## Importing an External Domain (.com, .net, etc.)

### Step 1: Get verification code

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('External domain to import: ')

data = urllib.parse.urlencode({'get_domain_validation': '1', 'token': TOKEN, 'domain': DOMAIN}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
result = json.loads(resp.read())
print('Validation code:', result.get('validation_code', json.dumps(result, indent=2)))
"
```

### Step 2: Set TXT record at current DNS provider

Create a TXT record: `_doxx-verify.mysite.com` with the validation code.

### Step 3: Import

```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain to import: ')

data = urllib.parse.urlencode({'import_domain': '1', 'token': TOKEN, 'domain': DOMAIN}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
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
python3 -c "
import urllib.request, urllib.parse, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain: ')

csr = open(f'{DOMAIN}.csr').read()
data = urllib.parse.urlencode({'sign_certificate': '1', 'token': TOKEN, 'domain': DOMAIN, 'csr': csr}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
open(f'{DOMAIN}.crt', 'wb').write(resp.read())
print(f'Certificate written to {DOMAIN}.crt')
"
```

The certificate is automatically wildcarded: `*.domain` + `domain`. Valid for 365 days.

### Step 3: Verify

```bash
openssl x509 -in $DOMAIN.crt -noout -subject -ext subjectAltName
```

### Step 4: Install root CA on clients

Clients need the doxx.net root CA to trust these certificates:

```bash
python3 -c "import urllib.request; urllib.request.urlretrieve('https://a0x13.doxx.net/assets/doxx-root-ca.crt', 'doxx-root-ca.crt')"
```

- **macOS:** `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain doxx-root-ca.crt`
- **Linux:** `sudo cp doxx-root-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`
- **Windows:** `certutil -addstore root doxx-root-ca.crt`
- **Firefox:** Settings → Privacy & Security → Certificates → Import

---

## Managing DNS Records

**List all records:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain: ')

data = urllib.parse.urlencode({'list_dns': '1', 'token': TOKEN, 'domain': DOMAIN}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
result = json.loads(resp.read())
print(json.dumps(result.get('records', result), indent=2))
"
```

**Update a record:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain: ')

data = urllib.parse.urlencode({
    'update_dns_record': '1', 'token': TOKEN, 'domain': DOMAIN,
    'old_name': input('Old FQDN: '), 'old_type': input('Old type: '), 'old_content': input('Old content: '),
    'name': input('New FQDN: '), 'content': input('New content: '), 'ttl': '300'
}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

**Delete a record:**
```bash
python3 -c "
import urllib.request, urllib.parse, json, os

API = 'https://config.doxx.net/v1/'
TOKEN = os.environ['DOXXNET_TOKEN']
DOMAIN = input('Domain: ')

data = urllib.parse.urlencode({
    'delete_dns_record': '1', 'token': TOKEN, 'domain': DOMAIN,
    'name': input('FQDN: '), 'type': input('Type: '), 'content': input('Content: ')
}).encode()
resp = urllib.request.urlopen(urllib.request.Request(API, data=data, method='POST'))
print(json.dumps(json.loads(resp.read()), indent=2))
"
```

Supported types: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SRV`, `PTR`.
