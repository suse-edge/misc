# Using combustion

The script here runs all the scripts in order where the script name needs to be `??_*.sh`

The execution of scripts is wrapped via tukit so the usual way doesn't work:

```bash
for i in ./*.sh; do
	${i}
done
```

That's why they are copied and then appended to the `script` file.

## How to add a new script

The procedure is really straightforward. You just need to drop the script in this folder and it will be used at combustion phase. The order can be explicitely be set with the script name `??_foobar.sh`

### Considerations

* The combustion procedure happens at initrd timing... and unfortunately there is not much there, so you need to be a little bit creative. A usual _trick_ is to create a script that performs the deployment of the feature itself and then a systemd unit that executes that script. The systemd unit is a regular systemd unit and it will be executed at boot time. Something like:

```
cat <<- "EOF" > /usr/local/bin/myawesomefeature-installer.sh
#!/bin/bash
set -euo pipefail
# do whatever is needed
EOF

chmod a+x /usr/local/bin/myawesomefeature-installer.sh

cat <<- EOF > /etc/systemd/system/myaweseomefeature-installer.service
[Unit]
Description=Run my awesome feature
Wants=network-online.target
After=network.target network-online.target
ConditionPathExists=/usr/local/bin/myawesomefeature-installer.sh
ConditionPathExists=!/usr/local/bin/myawesomefeature

[Service]
User=root
Type=forking
TimeoutStartSec=600
Environment="FOO=bar"
ExecStart=/usr/local/bin/myawesomefeature-installer.sh
RemainAfterExit=yes
KillMode=process
# Disable & delete everything
ExecStartPost=rm -f /usr/local/bin/myawesomefeature-installer.sh
ExecStartPost=/bin/sh -c "systemctl disable myaweseomefeature-installer"
ExecStartPost=rm -f /etc/systemd/system/myaweseomefeature-installer.service

[Install]
WantedBy=multi-user.target
EOF

systemctl enable myawesomefeature-installer.service
```

* If you want to be able to enable/disable the feature or the script content, you can use an if at the beginning of the script as:

```
if [ "${MYAWESOMEFEATURE}" == true ]; then
	# Do what was explained above
fi
```
