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
curl -fsSL https://raw.githubusercontent.com/CurrenlyDying/shareterminal/refs/heads/main/install.sh | bash
```

What the install script does:

* Creates `~/bin` if it doesn’t exist
* Adds `~/bin` to your PATH in `~/.bashrc` and `~/.zshrc` (if needed)
* Checks if `tmux` is installed

  * If not, and if `sudo` is available, offers to install it using your distro’s package manager (or Homebrew on macOS)
* Installs two scripts into `~/bin`:

  * `shareterminal`
  * `detach`

If `shareterminal` is not found after installation, either:

```bash
source ~/.bashrc       # for bash
# or
source ~/.zshrc        # for zsh
```

or just open a new terminal.

---

## Basic usage

### Start or join a shared session

In a terminal:

```bash
shareterminal
```

You’ll be prompted for a session name:

```text
Enter tmux session name [default: naier]:
```

* Press **Enter** to use the default `naier`, or
* Type another name if you want multiple separate shared sessions.

If the session doesn’t exist yet:

* It is created as a detached tmux session.
* The tmux socket `/tmp/shared_tmux` is created and set to `chmod 777` so other users can join easily.
* Tmux `display-time` is set to 5000 ms, so notifications are visible for about 5 seconds.

If the session already exists:

* You will attach to it.

### Let someone else join

On the same machine (for example, another user SSHed into the box):

```bash
shareterminal
# then pick the SAME session name (e.g. "naier")
```

Everyone who runs `shareterminal` with the same session name on that host will share the same tmux session.

When a new client joins:

* Existing clients see a message like:

  ```text
  [JOIN] Another client is joining 'naier'
  ```

### Leave without breaking the session

Inside tmux, there are two safe ways to leave:

1. Native tmux detach:

   * Press: `Ctrl-b` then `d`

2. The helper command:

   ```bash
   detach
   ```

When someone runs `detach`:

* All remaining clients see:

  ```text
  [LEAVE] A client detached from 'naier'
  ```

The tmux session itself stays alive as long as at least one client remains (or until someone explicitly kills the session or closes the last shell).

---

## Things to avoid

* **Do not type `exit` in the last pane/window of the session**
  If you `exit` the last shell in the last window, tmux will end the session.
  That disconnects everyone who is attached to it.

* **Do not rely on this for untrusted multi-user machines**
  The shared socket is:

  ```text
  /tmp/shared_tmux
  ```

  and it is set to `chmod 777` for simplicity. That means any user on that machine can attach to the shared session if they know the session name.

On personal machines, WSL, or a shared dev box with people you trust, this is usually fine. On a system with untrusted users, you probably want a stricter permission setup instead of this script.

---

## How it works (high level)

* `shareterminal`:

  * Checks for `tmux`
  * Sets up a shared tmux socket at `/tmp/shared_tmux`
  * Creates or reuses a tmux session with the name you give it
  * Forces `display-time` to 5000 ms so `display-message` notifications are visible
  * Before attaching you, it asks tmux for the list of existing clients on that session and sends them a `[JOIN] …` message
  * Then attaches you to the session

* `detach`:

  * Runs inside tmux
  * Figures out the current session name
  * Sends a `[LEAVE] …` message to all other clients attached to that session
  * Calls `tmux detach` to detach your client

Everything else (splits, windows, programs, etc.) is standard tmux behavior.

---

## Typical use cases

* Pair programming on a remote box
* Walking someone through a build or debugging session
* Practising for C / shell exams where you want a teacher or friend to see and interact with your terminal in real time
* Quickly sharing a session with a friend without explaining tmux internals each time

---

## Uninstall

To remove the scripts:

```bash
rm -f ~/bin/shareterminal ~/bin/detach
```

You can also remove the `export PATH="$HOME/bin:$PATH"` line from your `~/.bashrc` / `~/.zshrc` if you don’t use `~/bin` for anything else.

---

## License

```text
code is just text – see LICENSE "do what you want with it i can't stop you from copy pasting"
```
