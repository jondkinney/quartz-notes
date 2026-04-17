---
publish: true
created: 2026-04-13T15:25:54.899-05:00
modified: 2026-04-16T17:29:56.327-05:00
cssclasses: ""
---

# Keyd Remap

System-level key remapping via [keyd](https://github.com/rvaiya/keyd).

## Config

`/etc/keyd/default.conf`:

```
[ids]
*

[main]
# Remap physical Esc to Pause (for compose key)
esc = pause

# CapsLock acts as Escape on tap, Right Control on hold
capslock = overloadt(control, esc, 150)
```

## How `overloadt` works

`overloadt(control, esc, 150)` means:
- Hold capslock **longer than 150ms** → acts as Control
- Release within **150ms** → sends Esc

### Timeout tradeoffs
- **500ms** (default): Very forgiving Esc taps, but Ctrl chords feel laggy (half-second wait before Ctrl engages).
- **100ms**: Ctrl chords feel instant, but fast typists may get stray Ctrls if they linger on Esc.
- **150ms** (current): Sweet spot — snappy Ctrl with enough grace for clean Esc taps.

## Apply changes

```bash
sudo keyd reload
```

---
*Part of [[index|Jonokasten]]*
