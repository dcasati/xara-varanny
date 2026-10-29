# xara-varanny

A small wrapper that lets [varanny](https://github.com/islandmagic/varanny) start
and stop [xara](https://github.com/x0rro/xara) without cutting off the end of a
Winlink session.

## The problem

When a session ends, RadioMail (and other varanny clients) send the modem
`DISCONNECT` and then, a fraction of a second later, tell varanny to `stop` the
modem. varanny stops it with SIGTERM, and xara shuts down on that first signal
without finishing an open link.

So xara stops while the disconnect handshake is still on the air. The RMS
never sees the link close and keeps answering in a loop until its own timeout
expires, tying up the gateway frequency.

Seen in varanny's log, about 0.3 s apart:

```
Received command: stop
Shutdown modem process gracefully
```

## The fix

`xara-varanny` runs xara, passes its output through, and watches it for
`< CONNECTED` and `< DISCONNECTED`. When SIGTERM arrives:

- **No link open:** xara is stopped immediately.
- **Link open:** the wrapper logs
  `xara-varanny: waiting for the link to disconnect`, waits until xara reports
  `< DISCONNECTED` (at most 20 s), and then forwards SIGTERM to xara.

varanny waits for the modem process to exit after signalling it, so it ends up
waiting for the link to close.
The wrapper is plain POSIX `sh` and runs on FreeBSD and Linux.

Tested on air with RadioMail → varanny → xara FM → VE6FAR: the gateway now sees
the disconnect and stops calling.

## Install

```sh
install -m 755 xara-varanny /usr/local/libexec/xara-varanny
install -m 755 examples/xara-varahf examples/xara-varafm /usr/local/bin/
```

Edit the config paths in the two wrappers in `/usr/local/bin`, then point
varanny's `Cmd` at them (see `examples/varanny.json`):

```json
{
  "Name": "FT818ND xara FM",
  "Type": "fm",
  "Cmd": "/usr/local/bin/xara-varafm",
  "DefaultConfig": "/usr/local/etc/varanny/xara-fm.ini",
  "CatCtrl": { "Port": 4533, "Dialect": "hamlib" }
}
```

varanny passes VARA's `Args` to the modem, which xara doesn't use, so the
wrappers ignore them. Each wrapper runs:

```sh
xara-varanny /path/to/xara.conf
```

## Usage

```
xara-varanny CONFIG
```

| Variable | Default | Meaning |
|---|---|---|
| `XARA` | `/usr/local/bin/xara` | xara binary |
| `XARA_ARGS` | `--addr 0.0.0.0 --registered` | Extra xara arguments, after `--config CONFIG` |
| `XARA_STOP_TIMEOUT` | `20` | Longest wait, in seconds, for `DISCONNECTED` after SIGTERM |

`--addr 0.0.0.0` makes xara listen on all interfaces so varanny clients on
other machines can reach it. Drop `--registered` if your xara build doesn't
have that feature.

## Files

| Path | Purpose |
|---|---|
| `xara-varanny` | The wrapper |
| `examples/xara-varahf`, `examples/xara-varafm` | varanny `Cmd` scripts, one per xara config |
| `examples/varanny.json` | varanny config with an HF and an FM xara modem |
| `examples/xara-fm.ini` | VARA-style ini varanny reads for the command port |
| `tests/run.sh` | Checks the stop behaviour against a fake xara |

## Testing

```sh
sh tests/run.sh
```

```
ok   idle stops at once (0s)
ok   open link waits for DISCONNECTED (3s)
ok   timeout caps the wait (2s)
```

## A better long-term fix

The wrapper works around a sequencing problem between the client and the
modem. Better places to fix it:

- **xara:** on the first SIGTERM, xara sets a stop flag and its audio loop ends
  on the next block, whether or not a link is open. It could instead finish an
  open link (with a timeout) before exiting, much like it already waits for PTT
  release on a second signal.
- **The client (RadioMail):** it could wait for `DISCONNECTED` before telling
  varanny to `stop`.

varanny can't do this itself: clients talk to the modem's command port
directly, so varanny never sees `DISCONNECTED`. The most it could do is wait a
fixed grace period before signalling the modem.

## License

MIT
