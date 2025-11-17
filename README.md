# ShareTerminal

ShareTerminal is a small shell utility that makes it easier to share a tmux session with other users on the same machine.

It wraps tmux in a simple command (`shareterminal`) and sets up a shared socket under `/tmp/shared_tmux`, plus a `detach` helper so people can leave the shared session without killing it for everyone.

The goal is to make “look at my terminal and type with me” as low-friction as possible, especially for pair programming, code reviews, or 42-style training setups.

---

## Features

- One command to start or join a shared tmux session:
  - `shareterminal` (default session name: `naier`)
- Shared tmux socket at `/tmp/shared_tmux` so multiple users can attach to the same session
- `detach` helper command:
  - Lets you leave the session cleanly without closing it for others
- Join/leave notifications:
  - Existing clients see a `[JOIN] …` message when someone new attaches
  - Remaining clients see a `[LEAVE] …` message when someone detaches using `detach`
- Forces tmux `display-time` to 5 seconds so notifications are actually readable
- Works on Linux and macOS (as long as tmux is installed)

This project does not try to replace tmux. It just automates a few repetitive steps and adds small quality-of-life behavior on top.

---

## Requirements

- A Unix-like environment (Linux or macOS)
- `bash` or `zsh` as a login shell
- `tmux` available in your PATH
  - The installer can try to install `tmux` for you using your package manager if you have `sudo` access.

---

## Installation

You can install ShareTerminal with a single command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/install.sh)"
