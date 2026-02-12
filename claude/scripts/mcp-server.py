#!/usr/bin/env python3
"""doxx.net MCP server (HTTP) for Claude Code.

Provides tools for managing doxx.net private networks:
tunnels, domains, DNS, firewall, DNS blocking, and stats.

Reads DOXXNET_TOKEN from environment for authentication.
No external dependencies — uses only Python 3 stdlib.

Usage:
    python3 mcp-server.py           # foreground on port 19533
    python3 mcp-server.py --daemon  # background daemon
    python3 mcp-server.py --stop    # stop running daemon
"""

import json
import sys
import os
import signal
import socket
import urllib.request
import urllib.parse
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timedelta, timezone

PORT = int(os.environ.get("DOXXNET_MCP_PORT", "19533"))
PID_FILE = os.path.expanduser("~/.doxxnet-mcp.pid")

CONFIG_API = "https://config.doxx.net/v1/"
STATS_API = "https://secure-wss.doxx.net/api/stats/"
NO_AUTH = {"servers", "dns_get_options", "dns_blocklist_stats", "generate_qr",
           "version_check", "doxxpow_challenge", "doxxpow_verify"}

# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

TOOLS = [
    # -- Servers --
    {
        "name": "doxx_servers",
        "description": "List available WireGuard servers with locations and continents. No auth required.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    # -- Account --
    {
        "name": "doxx_auth",
        "description": "Validate an auth token. Returns success/error status.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "token": {"type": "string", "description": "Auth token to validate (uses env token if omitted)"}
            }
        }
    },
    {
        "name": "doxx_account_recovery",
        "description": "Generate account recovery codes. Save these — they're the only way to recover a lost token.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    # -- Tunnels --
    {
        "name": "doxx_list_tunnels",
        "description": "List all tunnels on the account with IPs, servers, connection status, and settings.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "doxx_create_tunnel",
        "description": "Create a new tunnel (device) on the network.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "server": {"type": "string", "description": "Server hostname (e.g. wireguard.mia.us.doxx.net)"},
                "name": {"type": "string", "description": "Device name (optional)"},
                "device_type": {"type": "string", "description": "Device type: mobile, desktop, server, web (optional, for mobile tunnels)"}
            },
            "required": ["server"]
        }
    },
    {
        "name": "doxx_update_tunnel",
        "description": "Update tunnel settings: rename, move to different server, toggle firewall/IPv6/DNS protection.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "name": {"type": "string", "description": "New name (optional)"},
                "server": {"type": "string", "description": "New server hostname (optional)"},
                "firewall": {"type": "string", "description": "Enable firewall: 1 or 0 (optional)"},
                "ipv6_enabled": {"type": "string", "description": "Enable IPv6: 1 or 0 (optional)"},
                "block_bad_dns": {"type": "string", "description": "Block bad DNS: 1 or 0 (optional)"}
            },
            "required": ["tunnel_token"]
        }
    },
    {
        "name": "doxx_delete_tunnel",
        "description": "Delete a tunnel. This is permanent.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token to delete"}
            },
            "required": ["tunnel_token"]
        }
    },
    {
        "name": "doxx_wireguard_config",
        "description": "Get WireGuard configuration for a tunnel (interface + peer settings).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"}
            },
            "required": ["tunnel_token"]
        }
    },
    {
        "name": "doxx_disconnect_peer",
        "description": "Force-disconnect a tunnel's WireGuard peer.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"}
            },
            "required": ["tunnel_token"]
        }
    },
    # -- Domains --
    {
        "name": "doxx_list_domains",
        "description": "List all registered domains on the account.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "doxx_create_domain",
        "description": "Register a new domain. 196 TLDs available (.lan, .vpn, .mesh, .home, .wg, etc). Defaults to .doxx if no TLD specified.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name (e.g. mysite.doxx, app.lan)"}
            },
            "required": ["domain"]
        }
    },
    {
        "name": "doxx_delete_domain",
        "description": "Delete a registered domain. This is permanent.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain to delete"}
            },
            "required": ["domain"]
        }
    },
    {
        "name": "doxx_domain_validation",
        "description": "Get TXT verification code for importing an external domain (.com, .net, etc).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "External domain to import"}
            },
            "required": ["domain"]
        }
    },
    {
        "name": "doxx_import_domain",
        "description": "Import an external domain after TXT verification. User must set nameservers to a.root-dx.net/com/org after import.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain to import"}
            },
            "required": ["domain"]
        }
    },
    # -- DNS Records --
    {
        "name": "doxx_list_dns",
        "description": "List DNS records for a domain.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name"}
            },
            "required": ["domain"]
        }
    },
    {
        "name": "doxx_create_dns_record",
        "description": "Create a DNS record. Supported types: A, AAAA, CNAME, MX, TXT, NS, SRV, PTR.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name"},
                "name": {"type": "string", "description": "Record FQDN (e.g. app.mysite.doxx)"},
                "type": {"type": "string", "description": "Record type: A, AAAA, CNAME, MX, TXT, NS, SRV, PTR"},
                "content": {"type": "string", "description": "Record value (IP address, hostname, etc)"},
                "ttl": {"type": "string", "description": "TTL in seconds (default 3600)"},
                "prio": {"type": "string", "description": "Priority (for MX records)"}
            },
            "required": ["domain", "name", "type", "content"]
        }
    },
    {
        "name": "doxx_update_dns_record",
        "description": "Update an existing DNS record. Must specify old values to identify the record.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name"},
                "old_name": {"type": "string", "description": "Current record FQDN"},
                "old_type": {"type": "string", "description": "Current record type"},
                "old_content": {"type": "string", "description": "Current record value"},
                "name": {"type": "string", "description": "New record FQDN"},
                "content": {"type": "string", "description": "New record value"},
                "ttl": {"type": "string", "description": "New TTL in seconds"}
            },
            "required": ["domain", "old_name", "old_type", "old_content", "name", "content"]
        }
    },
    {
        "name": "doxx_delete_dns_record",
        "description": "Delete a DNS record.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name"},
                "name": {"type": "string", "description": "Record FQDN"},
                "type": {"type": "string", "description": "Record type"},
                "content": {"type": "string", "description": "Record value"}
            },
            "required": ["domain", "name", "type", "content"]
        }
    },
    # -- Certificates --
    {
        "name": "doxx_sign_certificate",
        "description": "Sign a CSR with doxx.net root CA. Auto-wildcards to *.domain + domain. Valid 365 days. Returns PEM certificate.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name (must be registered)"},
                "csr": {"type": "string", "description": "PEM-encoded Certificate Signing Request"}
            },
            "required": ["domain", "csr"]
        }
    },
    # -- Firewall --
    {
        "name": "doxx_firewall_list",
        "description": "List firewall rules. Shows mesh networking status, rules, and count.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Filter by tunnel (optional)"}
            }
        }
    },
    {
        "name": "doxx_firewall_add",
        "description": "Add a firewall rule to open a port or allow tunnel-to-tunnel access.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "protocol": {"type": "string", "description": "TCP, UDP, ICMP, or ALL"},
                "src_ip": {"type": "string", "description": "Source IP/CIDR (0.0.0.0/0 for any)"},
                "src_port": {"type": "string", "description": "Source port or ALL"},
                "dst_ip": {"type": "string", "description": "Destination IP (tunnel's assigned IP)"},
                "dst_port": {"type": "string", "description": "Destination port or ALL"}
            },
            "required": ["tunnel_token", "protocol", "src_ip", "src_port", "dst_ip", "dst_port"]
        }
    },
    {
        "name": "doxx_firewall_delete",
        "description": "Delete a firewall rule. Same parameters as add.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "protocol": {"type": "string", "description": "TCP, UDP, ICMP, or ALL"},
                "src_ip": {"type": "string", "description": "Source IP/CIDR"},
                "src_port": {"type": "string", "description": "Source port or ALL"},
                "dst_ip": {"type": "string", "description": "Destination IP"},
                "dst_port": {"type": "string", "description": "Destination port or ALL"}
            },
            "required": ["tunnel_token", "protocol", "src_ip", "src_port", "dst_ip", "dst_port"]
        }
    },
    {
        "name": "doxx_firewall_link_all",
        "description": "Toggle mesh networking: link all tunnels so they can reach each other.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "enabled": {"type": "string", "description": "1 to enable, 0 to disable"}
            },
            "required": ["enabled"]
        }
    },
    {
        "name": "doxx_firewall_link_status",
        "description": "Check if mesh networking (link-all) is enabled.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    # -- DNS Blocking --
    {
        "name": "doxx_dns_options",
        "description": "List available DNS blocklists with names, descriptions, categories, and domain counts. No auth required.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "doxx_dns_tunnel_config",
        "description": "Get a tunnel's DNS blocking config: enabled blocklists, whitelists, blacklists.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"}
            },
            "required": ["tunnel_token"]
        }
    },
    {
        "name": "doxx_dns_set_subscription",
        "description": "Enable or disable a DNS blocklist on a tunnel.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "subscription": {"type": "string", "description": "Blocklist name"},
                "enabled": {"type": "string", "description": "1 to enable, 0 to disable"},
                "apply_to_all": {"type": "string", "description": "1 to apply to all tunnels (optional)"}
            },
            "required": ["tunnel_token", "subscription", "enabled"]
        }
    },
    {
        "name": "doxx_dns_whitelist_add",
        "description": "Add a domain to the whitelist (stop blocking it).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "domain": {"type": "string", "description": "Domain to whitelist"},
                "apply_to_all": {"type": "string", "description": "1 to apply to all tunnels (optional)"}
            },
            "required": ["tunnel_token", "domain"]
        }
    },
    {
        "name": "doxx_dns_whitelist_remove",
        "description": "Remove a domain from the whitelist.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "domain": {"type": "string", "description": "Domain to remove from whitelist"}
            },
            "required": ["tunnel_token", "domain"]
        }
    },
    {
        "name": "doxx_dns_blacklist_add",
        "description": "Add a domain to the blacklist (force block it).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "domain": {"type": "string", "description": "Domain to blacklist"},
                "apply_to_all": {"type": "string", "description": "1 to apply to all tunnels (optional)"}
            },
            "required": ["tunnel_token", "domain"]
        }
    },
    {
        "name": "doxx_dns_blacklist_remove",
        "description": "Remove a domain from the blacklist.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"},
                "domain": {"type": "string", "description": "Domain to remove from blacklist"}
            },
            "required": ["tunnel_token", "domain"]
        }
    },
    {
        "name": "doxx_dns_blocklist_stats",
        "description": "Get DNS blocklist statistics: total domains blocked, per-list counts.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    # -- Secure DNS --
    {
        "name": "doxx_secure_dns_create",
        "description": "Create a Secure DNS hash for DoH/DoT access to tunnel's DNS blocking without a VPN tunnel.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Tunnel token"}
            },
            "required": ["tunnel_token"]
        }
    },
    {
        "name": "doxx_secure_dns_list",
        "description": "List all Secure DNS hashes with DoH URLs and DoT hostnames.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "doxx_secure_dns_delete",
        "description": "Delete a Secure DNS hash.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "host_hash": {"type": "string", "description": "Hash to delete"}
            },
            "required": ["host_hash"]
        }
    },
    # -- QR Code --
    {
        "name": "doxx_generate_qr",
        "description": "Generate a QR code PNG from text data. Saves to specified path. No auth required.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "data": {"type": "string", "description": "Text to encode in QR code"},
                "output_path": {"type": "string", "description": "File path to save PNG (default: doxx-qr.png)"},
                "size": {"type": "string", "description": "Image size in pixels, 100-2048 (default: 512)"}
            },
            "required": ["data"]
        }
    },
    # -- Stats --
    {
        "name": "doxx_bandwidth",
        "description": "Get bandwidth statistics. Defaults to last hour.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Filter by tunnel (optional)"},
                "start": {"type": "string", "description": "Start time ISO 8601 (optional)"},
                "end": {"type": "string", "description": "End time ISO 8601 (optional)"},
                "hours": {"type": "string", "description": "Hours of history (default: 1, alternative to start/end)"}
            }
        }
    },
    {
        "name": "doxx_alerts",
        "description": "Get security alerts: DNS blocks, port scans, bypass attempts. Types: dns_block, security_event, dangerous_port, dns_bypass, doh_bypass, port_scan, dns_nxdomain.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tunnel_token": {"type": "string", "description": "Filter by tunnel (optional)"},
                "last": {"type": "string", "description": "Time range: session, 1m, 1h, 1d, 7d, 30d (default: 1d)"},
                "type": {"type": "string", "description": "Filter by alert type (optional)"}
            }
        }
    },
    {
        "name": "doxx_summary",
        "description": "Get network summary statistics.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "days": {"type": "string", "description": "Number of days (default: 30)"}
            }
        }
    },
    {
        "name": "doxx_global_stats",
        "description": "Get the global threat counter (total threats blocked across all doxx.net users). No auth required.",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
    },
]

# Map tool names to API endpoint names and types
TOOL_MAP = {
    # Config API (POST)
    "doxx_servers":             {"endpoint": "servers", "no_auth": True},
    "doxx_auth":                {"endpoint": "auth"},
    "doxx_account_recovery":    {"endpoint": "create_account_recovery"},
    "doxx_list_tunnels":        {"endpoint": "list_tunnels"},
    "doxx_create_tunnel":       {"endpoint": None},  # special handling
    "doxx_update_tunnel":       {"endpoint": "update_tunnel"},
    "doxx_delete_tunnel":       {"endpoint": "delete_tunnel"},
    "doxx_wireguard_config":    {"endpoint": "wireguard"},
    "doxx_disconnect_peer":     {"endpoint": "disconnect_peer"},
    "doxx_list_domains":        {"endpoint": "list_domains"},
    "doxx_create_domain":       {"endpoint": "create_domain"},
    "doxx_delete_domain":       {"endpoint": "delete_domain"},
    "doxx_domain_validation":   {"endpoint": "get_domain_validation"},
    "doxx_import_domain":       {"endpoint": "import_domain"},
    "doxx_list_dns":            {"endpoint": "list_dns"},
    "doxx_create_dns_record":   {"endpoint": "create_dns_record"},
    "doxx_update_dns_record":   {"endpoint": "update_dns_record"},
    "doxx_delete_dns_record":   {"endpoint": "delete_dns_record"},
    "doxx_sign_certificate":    {"endpoint": "sign_certificate", "raw": True},
    "doxx_firewall_list":       {"endpoint": "firewall_rule_list"},
    "doxx_firewall_add":        {"endpoint": "firewall_rule_add"},
    "doxx_firewall_delete":     {"endpoint": "firewall_rule_delete"},
    "doxx_firewall_link_all":   {"endpoint": "firewall_link_all_toggle"},
    "doxx_firewall_link_status":{"endpoint": "firewall_link_all_status"},
    "doxx_dns_options":         {"endpoint": "dns_get_options", "no_auth": True},
    "doxx_dns_tunnel_config":   {"endpoint": "dns_get_tunnel_config"},
    "doxx_dns_set_subscription":{"endpoint": "dns_set_subscription"},
    "doxx_dns_whitelist_add":   {"endpoint": "dns_add_whitelist"},
    "doxx_dns_whitelist_remove":{"endpoint": "dns_remove_whitelist"},
    "doxx_dns_blacklist_add":   {"endpoint": "dns_add_blacklist"},
    "doxx_dns_blacklist_remove":{"endpoint": "dns_remove_blacklist"},
    "doxx_dns_blocklist_stats": {"endpoint": "dns_blocklist_stats"},
    "doxx_secure_dns_create":   {"endpoint": "public_dns_create_hash"},
    "doxx_secure_dns_list":     {"endpoint": "public_dns_list_hashes"},
    "doxx_secure_dns_delete":   {"endpoint": "public_dns_delete_hash"},
    "doxx_generate_qr":        {"endpoint": "generate_qr", "no_auth": True, "binary": True},
    # Stats API (GET)
    "doxx_bandwidth":           {"stats": "bandwidth"},
    "doxx_alerts":              {"stats": "alerts"},
    "doxx_summary":             {"stats": "summary"},
    "doxx_global_stats":        {"stats": "global", "no_auth": True},
}


# ---------------------------------------------------------------------------
# MCP logic (transport-independent)
# ---------------------------------------------------------------------------

class DoxxMCP:
    def __init__(self):
        self.token = os.environ.get("DOXXNET_TOKEN", "")

    def handle(self, msg):
        method = msg.get("method", "")
        msg_id = msg.get("id")
        params = msg.get("params", {})

        if method == "initialize":
            return self.rpc_result(msg_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "doxxnet", "version": "0.2.0"}
            })

        if method == "notifications/initialized":
            return None  # notification — no response

        if method == "tools/list":
            return self.rpc_result(msg_id, {"tools": TOOLS})

        if method == "tools/call":
            return self.call_tool(msg_id, params)

        if method == "ping":
            return self.rpc_result(msg_id, {})

        # Unknown method
        return self.rpc_error(msg_id, -32601, f"Unknown method: {method}")

    # -- Tool dispatch --

    def call_tool(self, msg_id, params):
        name = params.get("name", "")
        args = params.get("arguments", {})
        mapping = TOOL_MAP.get(name)

        if not mapping:
            return self.rpc_result(msg_id, self.tool_error(f"Unknown tool: {name}"))

        try:
            # Stats API
            if "stats" in mapping:
                result = self.stats_call(mapping["stats"], args, mapping.get("no_auth", False))
                return self.rpc_result(msg_id, self.tool_text(json.dumps(result, indent=2)))

            # Special: create_tunnel (desktop vs mobile)
            if name == "doxx_create_tunnel":
                result = self.create_tunnel(args)
                return self.rpc_result(msg_id, self.tool_text(json.dumps(result, indent=2)))

            # Special: generate_qr (binary response)
            if mapping.get("binary"):
                return self.rpc_result(msg_id, self.generate_qr(args))

            # Special: sign_certificate (raw PEM response)
            if mapping.get("raw"):
                result = self.raw_config_call(mapping["endpoint"], args)
                return self.rpc_result(msg_id, self.tool_text(result))

            # Standard Config API call
            result = self.config_call(mapping["endpoint"], args, mapping.get("no_auth", False))
            return self.rpc_result(msg_id, self.tool_text(json.dumps(result, indent=2)))

        except urllib.error.HTTPError as e:
            body = e.read().decode()
            try:
                err = json.dumps(json.loads(body), indent=2)
            except json.JSONDecodeError:
                err = body
            return self.rpc_result(msg_id, self.tool_error(f"HTTP {e.code}: {err}"))
        except urllib.error.URLError as e:
            return self.rpc_result(msg_id, self.tool_error(f"Connection error: {e.reason}"))
        except Exception as e:
            return self.rpc_result(msg_id, self.tool_error(str(e)))

    # -- API calls --

    def config_call(self, endpoint, args, no_auth=False):
        """POST to config.doxx.net/v1/ — returns parsed JSON."""
        params = {endpoint: "1"}
        for k, v in args.items():
            if v is not None and v != "":
                params[k] = str(v)
        if not no_auth and "token" not in params:
            if not self.token:
                raise ValueError("DOXXNET_TOKEN not set. Pass token parameter or set the environment variable.")
            params["token"] = self.token
        data = urllib.parse.urlencode(params).encode()
        req = urllib.request.Request(CONFIG_API, data=data, method="POST")
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())

    def raw_config_call(self, endpoint, args):
        """POST to config.doxx.net/v1/ — returns raw response body as text."""
        params = {endpoint: "1"}
        for k, v in args.items():
            if v is not None and v != "":
                params[k] = str(v)
        if "token" not in params:
            if not self.token:
                raise ValueError("DOXXNET_TOKEN not set.")
            params["token"] = self.token
        data = urllib.parse.urlencode(params).encode()
        req = urllib.request.Request(CONFIG_API, data=data, method="POST")
        resp = urllib.request.urlopen(req)
        return resp.read().decode()

    def stats_call(self, endpoint, args, no_auth=False):
        """GET to secure-wss.doxx.net/api/stats/ — returns parsed JSON."""
        params = {}
        if not no_auth:
            if not self.token:
                raise ValueError("DOXXNET_TOKEN not set.")
            params["token"] = self.token

        # Handle bandwidth defaults
        if endpoint == "bandwidth" and "start" not in args and "end" not in args:
            hours = int(args.pop("hours", "1"))
            now = datetime.now(timezone.utc)
            params["start"] = (now - timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
            params["end"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")

        for k, v in args.items():
            if v is not None and v != "":
                params[k] = str(v)

        # Default for alerts
        if endpoint == "alerts" and "last" not in params and "start" not in params:
            params["last"] = "1d"

        url = STATS_API + endpoint
        if params:
            url += "?" + urllib.parse.urlencode(params)
        resp = urllib.request.urlopen(url)
        return json.loads(resp.read())

    # -- Special handlers --

    def create_tunnel(self, args):
        """Create tunnel — picks desktop or mobile endpoint based on device_type."""
        device_type = args.pop("device_type", None)
        if device_type and device_type in ("mobile", "web"):
            endpoint = "create_tunnel_mobile"
            args["device_type"] = device_type
        else:
            endpoint = "create_tunnel"
        return self.config_call(endpoint, args)

    def generate_qr(self, args):
        """Generate QR code and save to file."""
        output_path = args.pop("output_path", "doxx-qr.png")
        params = {"generate_qr": "1"}
        for k, v in args.items():
            if v is not None and v != "":
                params[k] = str(v)
        data = urllib.parse.urlencode(params).encode()
        req = urllib.request.Request(CONFIG_API, data=data, method="POST")
        resp = urllib.request.urlopen(req)
        png_data = resp.read()
        with open(output_path, "wb") as f:
            f.write(png_data)
        return self.tool_text(f"QR code saved to {output_path} ({len(png_data)} bytes)")

    # -- JSON-RPC helpers --

    @staticmethod
    def rpc_result(msg_id, result):
        return {"jsonrpc": "2.0", "id": msg_id, "result": result}

    @staticmethod
    def rpc_error(msg_id, code, message):
        return {"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}}

    @staticmethod
    def tool_text(text):
        return {"content": [{"type": "text", "text": text}]}

    @staticmethod
    def tool_error(text):
        return {"content": [{"type": "text", "text": text}], "isError": True}


# ---------------------------------------------------------------------------
# HTTP transport (MCP Streamable HTTP)
# ---------------------------------------------------------------------------

class MCPHandler(BaseHTTPRequestHandler):
    """Handle MCP JSON-RPC over HTTP."""

    mcp = DoxxMCP()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            msg = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        resp = self.mcp.handle(msg)

        if resp is None:
            # Notification — no response body
            self.send_response(202)
            self.end_headers()
            return

        result = json.dumps(resp).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(result)))
        self.end_headers()
        self.wfile.write(result)

    def do_GET(self):
        # Health check
        body = json.dumps({"status": "ok", "server": "doxxnet", "version": "0.2.0"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # suppress per-request logging


# ---------------------------------------------------------------------------
# Lifecycle management
# ---------------------------------------------------------------------------

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


def read_pid():
    try:
        with open(PID_FILE) as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def write_pid(pid):
    with open(PID_FILE, "w") as f:
        f.write(str(pid))


def remove_pid():
    try:
        os.unlink(PID_FILE)
    except FileNotFoundError:
        pass


def stop_daemon():
    pid = read_pid()
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
            print(f"Stopped doxxnet MCP server (pid {pid})", file=sys.stderr)
        except ProcessLookupError:
            print("Server not running (stale pid file)", file=sys.stderr)
        remove_pid()
    else:
        print("No pid file found", file=sys.stderr)


def daemonize():
    """Double-fork to detach from terminal."""
    if os.fork() > 0:
        sys.exit(0)
    os.setsid()
    if os.fork() > 0:
        sys.exit(0)
    sys.stdin.close()
    sys.stdout.close()
    sys.stderr.close()
    devnull = os.open(os.devnull, os.O_RDWR)
    os.dup2(devnull, 0)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)


def run_server(daemon=False):
    if is_port_in_use(PORT):
        if daemon:
            sys.exit(0)  # already running, silent exit
        print(f"Port {PORT} already in use — server may already be running", file=sys.stderr)
        sys.exit(1)

    if daemon:
        daemonize()

    write_pid(os.getpid())

    def cleanup(signum, frame):
        remove_pid()
        sys.exit(0)
    signal.signal(signal.SIGTERM, cleanup)

    if not daemon:
        print(f"doxxnet MCP server listening on http://127.0.0.1:{PORT}/mcp", file=sys.stderr)

    server = HTTPServer(("127.0.0.1", PORT), MCPHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        remove_pid()


if __name__ == "__main__":
    if "--stop" in sys.argv:
        stop_daemon()
    elif "--daemon" in sys.argv:
        run_server(daemon=True)
    else:
        run_server(daemon=False)
