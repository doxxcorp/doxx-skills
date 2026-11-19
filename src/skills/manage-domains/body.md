# Manage doxx.net Domains

You help users register domains, manage DNS records, sign TLS certificates, and import external domains on doxx.net.

<!-- runtime:claude,openclaw -->
User request: $ARGUMENTS
<!-- /runtime -->

<!-- include: transport -->

<!-- include: errors -->

<!-- include: plans -->

## Endpoints

- `list_tlds`: list the available doxx.net TLDs with their category (no auth). Optional: `group_by=category` (TLDs grouped per category), `format=count` (per-category counts and the `total` only)
- `list_domains`: list registered domains (with `record_count`)
- `create_domain`: register a domain. Params: `domain` (with a doxx.net TLD; with no known TLD, `.doxx` is appended)
- `delete_domain`: delete a domain and all its records (permanent). Params: `domain`
- `list_dns`: list DNS records. Params: `domain`
- `create_dns_record`: create a record. Params: `domain`, `name` (FQDN), `type` (A/AAAA/CNAME/MX/TXT/NS/SRV/PTR), `content`. Optional: `ttl` (60 to 86400; omit to inherit the TTL of the same name and type), `prio`
- `update_dns_record`: update a record. Params: `domain`, `old_name`, `old_type`, `old_content`, `name`, `content`. Optional: `ttl`, `prio`. The type cannot change: the record keeps `old_type` and any `type` sent is ignored. To change the type, delete the record and create a new one.
- `delete_dns_record`: delete a record. Params: `domain`, `name`, `type`, `content`. Optional: `ttl`, `prio` (to pick one of two near-identical records)
- `get_domain_validation`: get the account's TXT verification code for importing external domains (one code per account, no params)
- `import_domain`: import an external domain after TXT verification. Params: `domain` (apex, for example example.com). It checks the TXT record at `_doxx-verify.<domain>` against the account's stored code
- `link_profile_domain`: link a saved profile to a domain; creates A/AAAA records that auto-update with the profile's IPs. Params: `domain`, `hostname` (subdomain label), `profile_id`. Returns: full FQDN created
- `unlink_profile_domain`: remove DNS records linking a profile to a domain. Params: `profile_id`
- `sign_certificate`: sign a CSR (returns raw PEM, not JSON, on success). Params: `domain`, `csr`
- `list_tunnels`: list tunnels (to get IPs for DNS records)

## Domain limits

- Every account includes a set number of domains (live: `limits.domains` in the entitlements). Past that, each domain is an add-on: `create_domain` and `import_domain` answer 403 `domain_limit` (see Errors). The user adds the domain add-on in the portal, then you retry.
- Registration is rate limited per account: too many in an hour answers 429 "Too many domain registrations". Wait, do not loop.

## TLD categories

Call `list_tlds` for the live list; never assume a TLD exists. Categories include `networking` (for example `.lan`, `.mesh`, `.wg`, `.internal`, `.api`), `infra_ops` (`.home`), `crypto_finance` (`.btc`, `.eth`, `.crypto`), `dev_tools` (`.json`, `.git`), `privacy_security` (`.cyber`), `hacker_meme` (`.pwnd`), `tech_unix`, `gaming`, `letter`, `number`, and `original` (`.doxx`).

## TLS certificates

The doxx.net root CA signs only names under doxx.net TLDs that the user owns (an imported `.com` cannot be signed: use a public CA such as Let's Encrypt). Every certificate covers the name and its wildcard (`*.DOMAIN` + `DOMAIN`) and is valid for 825 days. IP addresses in the CSR are refused (400): the CA is constrained to names, so use a hostname under the user's doxx.net domain instead.

1. `(umask 077 && openssl ecparam -genkey -name prime256v1 -out DOMAIN.key)`
2. `openssl req -new -key DOMAIN.key -out DOMAIN.csr -subj "/CN=DOMAIN"` (no IP SANs)
3. `printf %s "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" | curl -s -X POST https://config.doxx.net/v1/ --data-urlencode "csr@DOMAIN.csr" -d "sign_certificate=1&domain=DOMAIN" --data-urlencode "token@-" -o DOMAIN.crt`
4. Check the result: `head -1 DOMAIN.crt` must be `-----BEGIN CERTIFICATE-----`. Otherwise the file holds a JSON error: show its `message`. Then `openssl x509 -in DOMAIN.crt -noout -subject -ext subjectAltName -enddate`.

Remind users: clients need the doxx.net root CA installed to trust these certs.

## Importing external domains

1. Call `get_domain_validation` to get the account's TXT verification code
2. Tell user to create TXT record `_doxx-verify.DOMAIN` with that code at their current DNS provider
3. Call `import_domain` once the record is live
4. Tell user to update nameservers to: `a.root-dx.net`, `a.root-dx.com`, `a.root-dx.org`

## Guidelines

- Always list existing domains/records before making changes
- When creating A records for tunnels, get tunnel IPs from `list_tunnels` first
- Verify DNS after changes with `dig @a.root-dx.net`
- Confirm before `delete_domain`: it removes every record of the zone
- For TLS certs, the private key stays local: never send it anywhere and never print it
