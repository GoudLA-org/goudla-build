#!bin/bash
set -e
export CHAIN_ID=${CHAIN_ID:-"goudla-testnet"}
export MONIKER="goudla-node"
export HOME_DIR=$(eval echo "${HOME_DIR:-"~/.goudla"}")
export RPC=${RPC:-"26657"}
export KEYRING=${KEYRING:-"test"}

sudo apt-get update
sudo apt install pkg-config build-essential libssl-dev curl jq git libleveldb-dev -y
sudo apt-get install manpages-dev -y

curl -O https://dl.google.com/go/go1.19.linux-amd64.tar.gz
sudo tar -C /usr/local -zxvf go1.19.linux-amd64.tar.gz

cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF

source $HOME/.profile
go version  

git clone https://github.com/GoudLA-org/goudla-build.git
cd goudla-build
sudo mv ./build/goudlad /usr/bin
sudo mkdir -p $GOPATH/bin
sudo cp ./cosmovisor/cosmovisor $GOPATH/bin/cosmovisor
whereis cosmovisor

export DAEMON_HOME=$HOME/.goudla
source ~/.profile
mkdir -p $DAEMON_HOME/cosmovisor/genesis/bin
mkdir -p $DAEMON_HOME/cosmovisor/upgrades

which goudlad

goudlad init $MONIKER --chain-id $CHAIN_ID

rm -rf ~/.goudla/config/genesis.json && mv genesis.json ~/.goudla/config/
# Opens the RPC endpoint to outside connections
sed -i 's/laddr = "tcp:\/\/127\.0\.0\.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' $HOME_DIR/config/config.toml
sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $HOME_DIR/config/config.toml

cp $(which goudlad) $DAEMON_HOME/cosmovisor/genesis/bin

sudo chmod 777 /etc/systemd/system
COSMOVISOR_HOME=`whereis cosmovisor | grep cosmovisor | cut -c13`
echo '
[Unit]
Description=Goudla Daemon
#After=network.target
StartLimitInterval=350
StartLimitBurst=10
[Service]
Type=simple
User='$USER'
ExecStart='$COSMOVISOR_HOME' start 30a65af4d15a208eef50ddc508cd003669967633@34.194.129.29:26656, d4affc3e1d1c8d9c33791b1468b6318fed23f781@54.209.76.163:26656
Restart=on-abort
RestartSec=30
[Install]
WantedBy=multi-user.target
[Service]
LimitNOFILE=1048576
' >> /etc/systemd/system/goudla.service

sudo chmod 755 /etc/systemd/system

