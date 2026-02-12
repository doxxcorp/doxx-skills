#!/usr/bin/env python3
"""doxx.net API helper. Reads DOXXNET_TOKEN from environment.

Usage:
    python3 doxx-api.py list_domains
    python3 doxx-api.py create_domain domain=test.doxx
    python3 doxx-api.py list_tunnels
    python3 doxx-api.py wireguard tunnel_token=abc123
    python3 doxx-api.py servers              # no auth needed
    python3 doxx-api.py dns_get_options      # no auth needed

Arguments are passed as key=value pairs. If no value is given,
the key is treated as an endpoint name with value "1".
Token is automatically included from $DOXXNET_TOKEN unless
the endpoint doesn't require auth.
"""
import urllib.request, urllib.parse, json, os, sys

API = "https://config.doxx.net/v1/"

NO_AUTH_ENDPOINTS = {"servers", "dns_get_options"}


def main():
    token = os.environ.get("DOXXNET_TOKEN", "")
    params = {}

    for arg in sys.argv[1:]:
        if "=" in arg:
            k, v = arg.split("=", 1)
            params[k] = v
        else:
            params[arg] = "1"

    endpoint = next((k for k in params if params[k] == "1" and k != "token"), None)
    if token and "token" not in params and endpoint not in NO_AUTH_ENDPOINTS:
        params["token"] = token

    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(API, data=data, method="POST")

    try:
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        print(json.dumps(result, indent=2))
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            print(json.dumps(json.loads(body), indent=2), file=sys.stderr)
        except json.JSONDecodeError:
            print(body, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
