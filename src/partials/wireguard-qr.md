**Get the config without exposing the key.** The `wireguard` response holds the tunnel private key, so it must never reach the conversation. Keep the response in a shell variable, print only its status, and build `doxx.conf` with `jq` inside a private temp directory (mode 700, never the current directory: it could be a git repo). This needs `jq` (`command -v jq`; if missing: `brew install jq` on macOS or `sudo apt install jq` on Debian/Ubuntu). Run it as one command, with `NAME` replaced by the tunnel's name: the first two lines find the tunnel's token by name inside the shell, without printing it.

```
<!-- include: tunnel-by-name -->
d=$(mktemp -d "${TMPDIR:-/tmp}/doxx-wg.XXXXXX") || exit 1; chmod 700 "$d"; echo "dir: $d"
r=$(printf 'url=https://config.doxx.net/v1/\ndata-urlencode=token=%s\ndata-urlencode=tunnel_token=%s\n' "${DOXX_TOKEN:-$(grep -m1 -s . ~/.config/doxx/token || printf %s "${DOXXNET_TOKEN:-$(grep -m1 -s . ~/.config/doxxnet/token)}")}" "$tt" | awk -v n=3 '{s = ""; for (i = 1; i <= length($0); i++) {c = substr($0, i, 1); s = s (c == "\\" || c == "\"" ? "\\" : "") c}; k = index(s, "="); o = o substr(s, 1, k - 1) " = \"" substr(s, k + 1) "\"\n"} END {if (NR == n) printf "%s", o}' | curl -s -K - -X POST -d "wireguard=1")
if [ "$(printf %s "$r" | jq -r .status)" = success ]; then
  (umask 077 && printf %s "$r" | jq -r '.config | "[Interface]\nPrivateKey = \(.interface.private_key)\nAddress = \(.interface.address)\n\(if (.interface.dns // "") != "" then "DNS = \(.interface.dns)\n" else "" end)\n[Peer]\nPublicKey = \(.peer.public_key)\nAllowedIPs = \(.peer.allowed_ips)\nEndpoint = \(.peer.endpoint)\nPersistentKeepalive = \(.peer.persistent_keepalive)"' > "$d/doxx.conf")
  printf %s "$r" | jq -r 'if .requires_reconnect then "success (requires_reconnect)" else "success" end'
else
  printf %s "$r" | jq -r '"error: " + (.message // "no message")'
  rmdir "$d"
fi
```

The config is built only when `status` is `success`; on an error, show the user the printed `message`. A mesh-only tunnel (an account without internet access through doxx.net) gets an empty `dns`: the config then has no `DNS =` line, and the device keeps its own DNS. The command prints the directory path: below it is called `DIR`; use the printed path literally in later commands. Never `cat` `DIR/doxx.conf`, and never print the private key or the full config in the chat. If you create a key-bearing file with an editor tool (such as Write) instead of the shell, `umask` does not apply: run `chmod 600` on it right after writing.

**macOS or Linux, this machine:** `sudo install -m 600 DIR/doxx.conf /etc/wireguard/doxx.conf && sudo wg-quick up doxx`. To disconnect: `sudo wg-quick down doxx`. Always use the interface name `doxx` (the file `/etc/wireguard/doxx.conf`). The WireGuard tools are optional: they are needed only for this step. Check with `command -v wg-quick`; if missing, give the install command (`brew install wireguard-tools` on macOS, `sudo apt install wireguard-tools` on Debian/Ubuntu) or offer the other options below.

**Phone with the WireGuard app (generic tunnel, not the doxx.net app):** offer the user the options that are available here, in this order (there is no server-side QR: never send the config anywhere to render it):

1. **Local QR code** (preferred: nothing leaves this machine). Check with `command -v qrencode`. If it is missing, give the install command: `brew install qrencode` (macOS) or `sudo apt install qrencode` (Debian/Ubuntu). Then write an image and open it for the user:
   `(umask 077 && qrencode -o DIR/doxx-qr.png < DIR/doxx.conf)`, then `open DIR/doxx-qr.png` (macOS) or `xdg-open DIR/doxx-qr.png` (Linux).
   Never run `qrencode -t ansiutf8` yourself: its output would put the config into the conversation. If the user wants the code in a terminal, give them `qrencode -t ansiutf8 < DIR/doxx.conf` to run in their own terminal. They scan it in the WireGuard app (Add tunnel > Scan from QR code).
2. **The file itself.** The user moves `DIR/doxx.conf` to the phone over a channel they trust and imports it in the WireGuard app (Add tunnel > Import from file).

**Clean up** once the device has imported the tunnel: `rm -f DIR/doxx.conf DIR/doxx-qr.png && rmdir DIR`. If you cannot run it (for example the user denies the command), tell the user that `DIR` holds the tunnel private key and that they should delete it themselves.
