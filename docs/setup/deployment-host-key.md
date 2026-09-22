# Pin the deployment server's SSH host key

Use this guide from Windows PowerShell on the computer where you already log in
to the selected deployment server with OpenSSH. It transfers the server identity
trusted by that computer into one GitHub environment's deployment configuration.
Staging and production may use the same server or different servers; complete
this guide separately for each environment. The normal path needs no root
password, password reset, server restart, or SSH configuration change.

## What we are doing

SSH authenticates both ends of the connection. Your personal SSH private key
proves your identity to the server; GitHub's `DEPLOY_SSH_KEY` does the same for
the deployment account. The server has its own host key, which proves its
identity to SSH clients. The public half of that key is safe to copy.

Your computer normally remembers accepted server keys in `known_hosts`. A fresh
GitHub runner does not have that history. `DEPLOY_KNOWN_HOSTS` supplies it with a
reviewed host-and-public-key entry so deployment fails if a different server
answers. Previously, the workflow used `ssh-keyscan` during every deployment,
which discovered a key without independently checking whose key it was.

The commands below require an existing trusted SSH host entry. This preserves
your earlier trust decision. If you originally accepted the first fingerprint
without checking it, this is continuity from that first connection, not new
independent verification of it. If the saved key is unknown, changed, or not
trusted, use the verification fallback at the end before proceeding.
[OpenSSH documents strict checking and saved host keys](https://man.openbsd.org/ssh_config#StrictHostKeyChecking).

## 1. Open Windows PowerShell and check the tools

Run every PowerShell block below in the **same local terminal**, from any folder.
Commands containing `ssh` run the quoted Linux command remotely and then return
to PowerShell; there is no separate server-terminal step.

```powershell
ssh -V
gh --version
gh auth status
```

If GitHub CLI is missing, install it with `winget install --id GitHub.cli -e`,
then open a fresh PowerShell window. If `gh auth status` says you are not signed
in, run `gh auth login --hostname github.com --web`. Use the GitHub account that
can administer this repository's deployment environments.

These instructions assume Windows OpenSSH. If your usual client is PuTTY or
WSL, its saved server keys may be in a different store. An unknown-host error
from Windows OpenSSH does not justify accepting a new key; verify or transfer
the existing trusted entry first.

## 2. Select one environment and supply its existing connection details

```powershell
$repo = 'OpenGameBuilder/opengamebuilder'
$deploymentEnvironment = (Read-Host 'Deployment environment to configure (staging or production)').Trim().ToLowerInvariant()
if ($deploymentEnvironment -notin @('staging', 'production')) {
    throw 'Select staging or production. This run configures only that environment.'
}

$sshTarget = Read-Host 'Your usual SSH destination (for example root@SERVER_IP or an SSH config alias)'
$sshIdentity = Read-Host 'Private-key file path if you normally use ssh -i (otherwise press Enter)'
$deployHost = Read-Host "Exact DEPLOY_HOST value for $deploymentEnvironment in GitHub (server IP or DNS name)"

if ($deployHost -notmatch '^[a-zA-Z0-9.-]+$') {
    throw 'Enter only the deployment server IP or DNS name, without user, URL scheme, path, or port.'
}

$sshOptions = @(
    '-o', 'StrictHostKeyChecking=yes',
    '-o', 'UpdateHostKeys=no',
    '-o', 'ControlPath=none'
)
if ($sshIdentity) {
    $sshOptions += @('-i', $sshIdentity)
}
```

For example, if your normal command is `ssh -i C:\Keys\hetzner root@203.0.113.10`,
enter `root@203.0.113.10` for the SSH destination and `C:\Keys\hetzner` for the key path.
If you normally type `ssh ogb`, enter `ogb` and leave the key path empty. Enter
paths without surrounding quotation marks. Use your existing administrative
login; you do not need GitHub's private deployment key.

`DEPLOY_HOST` is the SSH server address configured in the selected GitHub
environment, which may differ from the public website address or a local SSH
alias. GitHub cannot reveal an existing secret value; use your deployment setup
records. The workflow currently uses SSH port 22. The server reached by
`$sshTarget` must be the same server as `$deployHost`; check the IP in Hetzner's
server overview if necessary. Do not reuse the other environment's connection
details unless you have confirmed that they identify the intended server.

## 3. Read the public key through the existing trusted connection

```powershell
$hostKeyOutput = @(& ssh @sshOptions $sshTarget 'cat /etc/ssh/ssh_host_ed25519_key.pub')
if ($LASTEXITCODE -ne 0) {
    throw 'SSH or the public-key read failed. Resolve the error before continuing.'
}

$keyParts = (($hostKeyOutput -join "`n").Trim() -split '\s+')
if ($keyParts.Count -lt 2 -or $keyParts[0] -ne 'ssh-ed25519') {
    throw 'Expected an Ed25519 public host key. Do not continue with this output.'
}

$deployKnownHosts = "$deployHost $($keyParts[0]) $($keyParts[1])"
$deployKnownHosts
$deployKnownHosts | ssh-keygen -E sha256 -lf -
if ($LASTEXITCODE -ne 0) {
    throw 'The constructed public-key entry is invalid.'
}
```

SSH may ask for your private key's passphrase. That unlocks your local key; it
does not require a root password. With strict checking enabled, SSH must already
recognize the server. Stop on `Host key verification failed` or
`REMOTE HOST IDENTIFICATION HAS CHANGED`; do not remove the saved entry or change
strict checking to get past it.

The command reads only the `.pub` file, which normally needs no `sudo` because
it is public. It creates no key and changes nothing on the server. If the file is
missing or unreadable, inspect the server's host-key configuration before
continuing; do not generate a replacement key for this task.

The first output has this shape (the example is deliberately incomplete):

```text
203.0.113.10 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
```

That complete line is the GitHub variable value. The second output includes its
`SHA256:...` fingerprint, a short identifier to retain for later comparison.
The fingerprint alone is not a usable `known_hosts` entry.

## 4. Save the entry only in the selected GitHub environment

This command changes only the environment selected in step 2:

```powershell
gh variable set DEPLOY_KNOWN_HOSTS --repo $repo --env $deploymentEnvironment --body $deployKnownHosts
if ($LASTEXITCODE -ne 0) { throw "Could not save the $deploymentEnvironment variable." }
```

This creates or updates an **environment variable**, as required by the
workflow's `vars.DEPLOY_KNOWN_HOSTS` reference. It does not deploy anything.
[GitHub CLI documents the environment and value flags](https://cli.github.com/manual/gh_variable_set).

After completing step 5, repeat steps 2-5 for the other environment with its own
connection details. If both environments intentionally use the same physical
server, they may have the same public host key and fingerprint. The host field
in each entry must still match that environment's exact `DEPLOY_HOST`, including
when two DNS names identify the same server. Separate servers must each have
their own host key read and trusted; do not copy one server's entry to the other.

For a browser-based alternative, copy `$deployKnownHosts` and use repository
**Settings → Environments → the environment selected in step 2 → Environment
variables → Add variable**, with name `DEPLOY_KNOWN_HOSTS`. Do not update the
other environment during this run.
[GitHub documents this settings path](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables#creating-configuration-variables-for-an-environment).

## 5. Read back what GitHub stored

```powershell
$savedKnownHosts = gh api "repos/$repo/environments/$deploymentEnvironment/variables/DEPLOY_KNOWN_HOSTS" --jq .value
if ($LASTEXITCODE -ne 0) { throw "Could not read the $deploymentEnvironment variable." }
if ($savedKnownHosts -ne $deployKnownHosts) {
    throw 'The saved entry does not match the reviewed entry from step 3.'
}

$savedKnownHosts
$savedKnownHosts | ssh-keygen -E sha256 -lf -
if ($LASTEXITCODE -ne 0) { throw "Invalid $deploymentEnvironment host-key entry." }
```

Check the hostname against the selected environment's `DEPLOY_HOST` and the
fingerprint against step 3. This verifies that this environment's public
configuration was transferred correctly; it does not prove a deployment login
or change the other environment's configuration.

Verify the deployment login during the next authorized deployment to this
environment, using GitHub's existing deployment secret. A push to `main`
normally triggers CD Staging; production deployment is separately dispatched
and approved. Do not dispatch a production release solely to save a host key.
In the selected environment's run, **Set up SSH** should print the same
fingerprint, and subsequent remote steps must pass strict SSH checking and the
deployment smoke test. Record acceptance separately for each environment; a
passing staging run does not verify production's SSH configuration.

## If the existing SSH host key is not trusted

A successful strict connection establishes continuity with an existing trusted
key. It cannot establish whether your original first connection was intercepted.
For a first connection, an unexplained key change, or an untrusted local entry,
obtain the fingerprint through an authenticated independent channel before
pinning it. Merely accepting the current network response would reintroduce the
problem this change fixes.

Hetzner's web console is one such channel. For an SSH-key-created Cloud server,
Hetzner documents **Rescue → Root Password → Reset Root Password**, then login
through the VNC console as root. This is a fallback that changes a login
credential, not a prerequisite for the existing-trust procedure above. Do not
enable Rescue or rebuild the server for this task.
[Hetzner console instructions](https://docs.hetzner.com/cloud/servers/getting-started/vnc-console/).

Through that console, the read-only commands are:

```bash
ssh-keygen -E sha256 -lf /etc/ssh/ssh_host_ed25519_key.pub
cat /etc/ssh/ssh_host_ed25519_key.pub
```

A password reset, host-key rotation, or account-locking command is not part of
the normal guide. Record whether the pin came from an independently verified
fingerprint or the administrator's established trusted SSH connection; do not
describe one as the other.
