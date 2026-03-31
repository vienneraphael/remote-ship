# remote-ship

## Pre-requisites

### Install your RPI5 image in an SD Card
Download [RPI Imager](https://www.raspberrypi.com/software/)

During the installation:
- Select your RPI hardware version
- Select your OS (Ubuntu-Server recommended)
- Setup your wifi credentials
- Setup User and Password information (suggestion: pick a very simple password)

Then, launch the image build and wait for it to finish.

### Installing relevant phone apps

In the meantime, open your phone and download from the store:
- Termux
- Tailscale

Once done, setup your Tailscale account.


### Installing the RPI Image in your Pi
Your image should be ready to go. Insert the micro SD card in the RPI and power it on.
You should see a flashing green light. It should take a few minutes to install.

## Verify your installation
Once the green light stops flashing, try connecting to your RPI on same WiFi to verify setup, run:

`ssh user-name@pi-name`

If it does not work try:

- `ssh user-name@pi-name.local`
- `ssh user-name@pi-name.lan`

Then enter your password, you should be connected to your RPI.

## Setting up remote-ship

### Launch the setup script

Run this command:
`curl -sSL https://raw.githubusercontent.com/vienneraphael/remote-ship/main/setup.sh | bash -s -- -n "Your Name" -e "github-email@example.com" -u "rpi-user-name"`


Then run: `gh auth login`

Select “Github.com” > “SSH” > Select your SSH key > name your key > Login with a web browser

This should fail: open the URL on your computer browser and paste the code.

### Clone your working repos

For each of the repos you wish to work in, clone it at RPI root:

`git clone git@github.com:<your-handle>/<your-repo.git>`

For each repo you clone, you can add an init script at `~/worktree_init/repo-name.sh`.

Example for a repo cloned as `~/my-app`:
`~/worktree_init/my-app.sh`

When `ship` creates a new worktree for that repo, it will run the matching init script inside the new tmux session before launching Codex. If the init script exits non-zero, `ship` leaves the session open and does not launch Codex.

### Login to codex

Go to ChatGPT on your browser
In ChatGPT settings > “Security” > “Enable device code authorization for Codex”

Run this command:
`codex`

Select “Login with Device Code”

Then quit codex

### Setup phone connection

On your RPI, launch background tailscale:

`sudo tailscale up`

If it fails, try logging in first:

`sudo tailscale login`

Then re-run: `sudo tailscale up`

Then follow the url, connect to your tailscale account.
Once redirected, note the IP address of your RPI in the tailnet

To verify Tailscale installation, try pinging the RPI from your phone app.

Open Termux on your phone. Create an alias in `.bashrc` like so:
`alias connect="ssh user-name@tailscale-rpi-ip"`

Then run: `source .bashrc`

The setup script also installs:
- `tmux`
- `gh`
- `@openai/codex`
- the `ship` and `unship` helpers in `~/.bash_functions`

## Using remote-ship

### Classic User Flow

1. Activate Tailscale VPN on your phone
2. Open a Termux session
3. launch the `connect` command
4. Enter RPI password
5. launch a thread using `ship <thread-name> <project-path> <base-branch>`
6. Ship from your phone within termux
7. Once done, go back to Termux, terminate codex session with CTRL + C and run `unship`, it will automatically cleanup the worktree and tmux session.

Notes:
- `ship <thread-name> <project-path>` also works and defaults the base branch to `main`.
- `ship <thread-name>` works too if you are already inside the repo.
- `-p` can be the repo path or `.` if you are already inside the repo.
- Flag form still works: `ship -n <thread-name> -p <project-path> -b <base-branch>`.
- Worktrees are created under `~/worktrees/<repo-name>/<thread-name>`.
- Branches are created as `fly/<thread-name>`.

### Open Concurrent Threads
If you want to open a second thread while one processes:
1. quit the tmux session using Ctrl + B + D
2. re-run `ship <name> <project-path> <base-branch>`, then ship from there

### Cleanup a thread from root
To cleanup a thread from root, use `unship <name>`

Flag form still works: `unship -n <name>`.
