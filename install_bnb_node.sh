#!/bin/bash

# install tools
sudo apt update
sudo apt-get install -y wget curl unzip

# create user and group
USERNAME="geth"
GROUPNAME="geth"

# Check if the group exists
if ! grep -q "^$GROUPNAME:" /etc/group; then
    echo "Group $GROUPNAME does not exist. Creating..."
    sudo groupadd $GROUPNAME
else
    echo "Group $GROUPNAME already exists."
fi

# Check if the user exists
if ! id -u $USERNAME > /dev/null 2>&1; then
    echo "User $USERNAME does not exist. Creating..."
    sudo useradd -m -g $GROUPNAME $USERNAME
else
    echo "User $USERNAME already exists."
fi

# Download the latest pre-build binaries
sudo -u geth wget $(curl -s https://api.github.com/repos/bnb-chain/bsc/releases/latest |grep browser_ |grep geth_linux |cut -d\" -f4) -O /home/geth/geth
sudo chmod +x /home/geth/geth

# Download the config files
sudo -u geth wget $(curl -s https://api.github.com/repos/bnb-chain/bsc/releases/latest |grep browser_ |grep mainnet |cut -d\" -f4) -O /home/geth/mainnet.zip
sudo -u geth unzip -o /home/geth/mainnet.zip -d /home/geth


# mount volume for node data
sudo mkfs.ext4 /dev/sdb
sudo mkdir /node-data
echo "/dev/sdb    /node-data    ext4    errors=remount-ro    0 0" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown geth:geth /node-data

# create node directory
sudo -u geth mkdir /home/geth/node

# Create geth service file
cat <<EOF | sudo tee /usr/lib/systemd/system/geth.service
[Unit]
Description=BNB geth client
After=syslog.target network.target

[Service]
User=geth
Group=geth
Environment=HOME=/home/geth
Type=simple
ExecStart=/home/geth/geth --config /home/geth/config.toml --datadir /node-data --cache 8000 --rpc.allow-unprotected-txs --txlookuplimit 0
KillMode=process
KillSignal=SIGINT
TimeoutStopSec=90
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# Enable service
sudo systemctl enable geth

# start service
sudo systemctl start geth
