# SSH access to the Windows VM

For any agent that needs to build or test the **Windows** installer for EarWitness.

**What it is:** a UTM Windows 11 **ARM64** VM running on the developer's Mac, used
for building/testing the Windows build. Windows **x64** binaries (what CI ships)
run on it via emulation.

## Connect

```sh
ssh "John Davenport@192.168.64.2"        # keep the quotes — the username has a space
```

- **Auth is key-based and already set up:** the Mac's `~/.ssh/id_ed25519` is
  authorized on the VM (in `C:\ProgramData\ssh\administrators_authorized_keys`).
  From that Mac it just works, no password. Password auth is also enabled as a
  fallback.
- **From a different machine:** copy that Mac's `~/.ssh/id_ed25519`, or append a
  new public key to `C:\ProgramData\ssh\administrators_authorized_keys` on the VM
  (admin users authenticate via *that* file, not `%USERPROFILE%\.ssh` — a Windows
  OpenSSH quirk).

## For automation (non-interactive)

```sh
VM='John Davenport@192.168.64.2'
# strip the harmless SSH banner noise (post-quantum + host-key warnings)
clean() { grep -iv "WARNING\|quantum\|vulnerable\|openssh"; }

ssh -o BatchMode=yes "$VM" 'whoami & ver' 2>&1 | clean
```

- `-o BatchMode=yes` fails instead of hanging if no key is offered.
- The `** WARNING: ...post-quantum...` lines are cosmetic — ignore/filter them.

## Gotchas (learned the hard way)

- **Pipes run in the *local* shell unless nested.** `ssh $VM 'cmd' | tail` runs
  `tail` on the Mac (fine); `ssh $VM 'cmd | tail'` needs `tail` on Windows. Put
  pipes inside `bash -lc "..."` (msys2) or use PowerShell.
- **Spaces in paths break cmd quoting.** Prefer PowerShell:
  `ssh "$VM" 'powershell -NoProfile -Command "..."'`. For file copies, target a
  **space-free** path: `scp file "$VM:C:/foo.exe"` (not the home dir, which has a
  space).
- **Long installs/builds die on disconnect.** Windows OpenSSH kills child
  processes when the SSH session closes, so a 15-min install won't survive a
  backgrounded SSH. Use a long foreground timeout, or run it on the VM's console.
- **You can't see the GUI.** SSH runs in session 0 with no desktop, so the wx
  window won't render (and may not init). Validate the app **headlessly** via
  `eval` (below); a human double-clicks on the VM desktop to eyeball the window.

## Environment already installed

- **OTP 29 + Elixir 1.20** (native Windows), **with a working wx** (`wx:new()` → ok).
- **msys2** at `C:\msys64` — CLANGARM64 toolchain (`clang`, `make`, `cmake`). Use:
  `C:\msys64\usr\bin\bash.exe -lc "export PATH=/clangarm64/bin:/usr/bin:$PATH; clang --version"`.
- **Rust** (MSVC linker via VS Build Tools); **cmake / Node / NSIS** (winget).
- **App installed:** `C:\Program Files\The EarWitness\` (launchers `run.vbs` / `run.bat`).
- **App log** (release-safe file logging): `%LOCALAPPDATA%\EarWitness\Logs\ear_witness.log`.

## Useful commands

**Headless boot / miniaudio capture smoke test** (returns real WASAPI devices +
`loopback_available? => true`, no GUI needed — `run.bat eval "<expr>"` boots the
release and runs Elixir; keep the expr free of nested quotes):

```sh
ssh -o BatchMode=yes "$VM" 'cd /d "C:\Program Files\The EarWitness" & run.bat eval "IO.inspect({EarWitness.Audio.Miniaudio.list_devices(), EarWitness.Audio.Miniaudio.loopback_available?()}, label: :MINIAUDIO)"' 2>&1 | clean
```

**Copy an installer over and install it** (bundled vcredist/WebView2 make it slow
— use a large timeout):

```sh
scp "$LOCAL_EXE" "$VM:C:/ewsetup.exe"
ssh -o BatchMode=yes "$VM" 'powershell -NoProfile -Command "Start-Process -FilePath C:\ewsetup.exe -ArgumentList /S -Wait"'
```

**Kill a stuck release** (heart can relaunch it):

```sh
ssh -o BatchMode=yes "$VM" 'taskkill /f /im heart.exe & taskkill /f /im epmd.exe & taskkill /f /im EarWitness.exe'
```

## Caveats

- **IP is DHCP** (`192.168.64.2` at time of writing). If it changes after a
  reboot, re-check on the VM with `ipconfig`, or try hostname `WIN-VLBHCJTCM10`.
  Ping is blocked by the Windows firewall (normal); SSH still works.
- **ARM64 VM, x64 target:** the shipped installer is x64 and runs here under
  emulation. Native win-arm64 is a separate, harder target and not what CI ships.
