# agscripts

A small collection of command-line utilities for Linux.

| Command     | Description                                                       |
|-------------|-------------------------------------------------------------------|
| `despace`   | Rename files replacing spaces with underscores (`despace *` for a whole folder) |
| `fanreport` | Report ThinkPad fan speeds, CPU/SSD/Wi-Fi temperatures and battery state; `-w N` refreshes every N seconds |
| `mktgz`     | Create a timestamped `.tgz` archive of each file or folder (`mydir_2026-11-21-10.30.00.tgz`) |
| `pdfcat`    | Merge PDF files into one using Ghostscript; `-h` for all options  |
| `svg2pdf`   | Convert SVG files to cropped PDF with Inkscape; `--eps` and `--png` add EPS and PNG output |
| `vol`       | Show or set the audio volume: `vol 50`, `vol 120%`, `vol +10`, `vol mute` (max 150%) |

## Installation

```bash
git clone https://github.com/<your-username>/agscripts.git
cd agscripts
./install.sh
```

The scripts are copied into `~/bin`, dropping the `.sh` extension: `scripts/fanreport.sh` becomes `fanreport`.  
To use another directory, pass it as an argument, for example `./install.sh ~/bin`.  
After modifying a script or running `git pull`, run `./install.sh` again to update the installed copies.

## Requirements

- `bash` 4.3 or newer
- `fanreport`: a ThinkPad with the `thinkpad_acpi` kernel module
- `pdfcat`: Ghostscript (`sudo apt install ghostscript`)
- `vol`: `pactl` (`sudo apt install pulseaudio-utils`); works with PulseAudio and PipeWire
- `svg2pdf`: Inkscape 1.x; optionally Ghostscript (PDF optimization) and
  `pdftops` from poppler-utils (EPS output)

## Adding a new script

Put it in `scripts/` with a `.sh` extension and run `./install.sh` again.

## Author

Andrea Giachero, <Andrea.Giachero@mib.infn.it>
