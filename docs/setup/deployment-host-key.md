# Pin the deployment server's SSH host key

Use this guide from Windows PowerShell on the computer where you already log in
to the Hetzner server with OpenSSH. It transfers the server identity trusted by
that computer into GitHub's deployment configuration. The normal path needs no
root password, password reset, server restart, or SSH configuration change.

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

## 2. Supply your existing connection details

```powershell
$repo = 'OpenGameBuilder/opengamebuilder'
$sshTarget = Read-Host 'Your usual SSH destination (for example root@SERVER_IP or an SSH config alias)'
$sshIdentity = Read-Host 'Private-key file path if you normally use ssh -i (otherwise press Enter)'
$deployHost = Read-Host 'Exact DEPLOY_HOST value used by GitHub (server IP or DNS name)'

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
enter `root@203.0.113.10` at the first prompt and `C:\Keys\hetzner` at the second.
If you normally type `ssh ogb`, enter `ogb` and leave the key path empty. Enter
paths without surrounding quotation marks. Use your existing administrative
login; you do not need GitHub's private deployment key.

`DEPLOY_HOST` is the SSH server address you configured in GitHub, which may differ
from the public website address or a local SSH alias. GitHub cannot reveal an
existing secret value; use your deployment setup records. The workflow currently
uses SSH port 22. The server reached by `$sshTarget` must be the same server as
`$deployHost`; check the IP in Hetzner's server overview if necessary.

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

## 4. Save the entry in GitHub

The current hosting design puts staging and production on the same server.
If **both environments have the same `DEPLOY_HOST`**, run:

```powershell
gh variable set DEPLOY_KNOWN_HOSTS --repo $repo --env staging --body $deployKnownHosts
if ($LASTEXITCODE -ne 0) { throw 'Could not save the staging variable.' }

gh variable set DEPLOY_KNOWN_HOSTS --repo $repo --env production --body $deployKnownHosts
if ($LASTEXITCODE -ne 0) { throw 'Could not save the production variable.' }
```

These commands create or update **environment variables**, as required by the
workflow's `vars.DEPLOY_KNOWN_HOSTS` reference. They do not deploy anything.
[GitHub CLI documents the environment and value flags](https://cli.github.com/manual/gh_variable_set).

If production uses a different hostname for the **same server**, replace the
production command above with:

```powershell
$productionHost = Read-Host 'Exact production DEPLOY_HOST for this same server'
if ($productionHost -notmatch '^[a-zA-Z0-9.-]+$') { throw 'Invalid server address.' }
$productionKnownHosts = "$productionHost $($keyParts[0]) $($keyParts[1])"
gh variable set DEPLOY_KNOWN_HOSTS --repo $repo --env production --body $productionKnownHosts
if ($LASTEXITCODE -ne 0) { throw 'Could not save the production variable.' }
```

If the environments are on different servers, repeat steps 2-3 against the other
server and save that server's entry only to its own environment.

For a browser-based alternative, copy `$deployKnownHosts` and use repository
**Settings → Environments → staging → Environment variables → Add variable**,
with name `DEPLOY_KNOWN_HOSTS`. Repeat under production with its matching entry.
[GitHub documents this settings path](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables#creating-configuration-variables-for-an-environment).

## 5. Read back what GitHub stored

```powershell
$stagingSaved = gh api "repos/$repo/environments/staging/variables/DEPLOY_KNOWN_HOSTS" --jq .value
if ($LASTEXITCODE -ne 0) { throw 'Could not read the staging variable.' }
$productionSaved = gh api "repos/$repo/environments/production/variables/DEPLOY_KNOWN_HOSTS" --jq .value
if ($LASTEXITCODE -ne 0) { throw 'Could not read the production variable.' }

$stagingSaved
$stagingSaved | ssh-keygen -E sha256 -lf -
if ($LASTEXITCODE -ne 0) { throw 'Invalid staging host-key entry.' }
$productionSaved
$productionSaved | ssh-keygen -E sha256 -lf -
if ($LASTEXITCODE -ne 0) { throw 'Invalid production host-key entry.' }
```

Check each hostname against its environment's `DEPLOY_HOST`. For a shared server,
both fingerprints must equal the fingerprint from step 3. This verifies the
public configuration was transferred correctly. The deployment login itself is
verified by the later staging run, using GitHub's existing deployment secret.

The new workflow takes effect after this branch passes CI and is merged. A push
to `main` already triggers CD Staging, so no extra manual deployment command is
needed for this setup. In that run, **Set up SSH** should print the same
fingerprint and the deployment must pass strict SSH checking and its smoke test.
Keep the checklist's SSH/staging acceptance open until those checks pass.

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
