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
`curl -sSL https://raw.githubusercontent.com/vienneraphael/remote-ship/main/setup.sh | bash -s -- -n "Your Name" -e "github-email@example.com -u "rpi-user-name" -i "Your.Tailscale.RPI.IP"`

The script should finish by the terminal prompt launched by `gh auth login`

Select “Github.com” > “SSH” > Select your SSH key > name your key > Login with a web browser

This should fail: open the URL on your computer browser and paste the code.

### Clone your working repos

For each of the repos you wish to work in, clone it at RPI root:

`git clone git@github.com:<your-handle>/<your-repo.git>

For each repo you clone, you can add a `worktree_init/repo-name.sh` script that will be launched whenever your start shipping a new feature in the newly-created worktree.

### Login to codex

Run this command:
`codex`

In ChatGPT settings > “Security” > “Enable device code authorization for Codex”

Select “Login with Device Code”

Then quit codex

### Connect phone to RPI

Run this command:
`happy --auth`

Scan the QR code using your phone to link it to your RPI.

## Using remote-ship

### Classic User Flow

1. Activate Tailscale VPN on your phone
2. Open a Termux session
3. launch the `connect` command
4. Enter RPI password
5. launch a thread using `ship -n <thread-name> -p <project-name> -b <base-branch>
6. Open the Happy phone app, ship from your phone
7. Once done, go back to Termux, terminate happy session and run `unship`, it will automatically cleanup the worktree and tmux session.

### Open Concurrent Threads
If you want to open a second thread while one processes:
1. quit the tmux session using Ctrl + B + D
2. re-run `ship -n <name> -p <project-name> -b <base-branch>, ship from there

### Cleanup a thread from root
To cleanup a thread from root, use `unship -n <name>`
