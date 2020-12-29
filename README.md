# Installer

Build installer iso using `make build/out/installer.iso`.

You can try the image using `make qemu`.

## Testing

```
# Create ssh-key
$ ssh-keygen -t ed25519
# Start the fake deplyoment infra and register your pubkey
# If you do not have one, you have to generate one first
$ python3 fake-infra.py
# Build the installer and start a local VM
$ make qemu
# Register the SSH key
$ curl \
  'http://127.0.0.1:7707/v1/machines/00000000-0000-0000-0000-000000000001/boot-installer' \
  --data "{\"ssh_pub_key\": \"$(<${HOME}/.ssh/id_ed25519.pub)\"}"
# In a new terminal, ssh to the installer
$ ssh root@localhost -p 5555 -i ~/.ssh/id_ed25519
```
