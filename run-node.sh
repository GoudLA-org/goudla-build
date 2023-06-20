#!bin/bash
set -e
export CHAIN_ID=${CHAIN_ID:-"goudla-testnet"}
export MONIKER="goudla-node"
export HOME_DIR=$(eval echo "${HOME_DIR:-"~/.goudla"}")
export RPC=${RPC:-"26657"}
export KEYRING=${KEYRING:-"test"}

# Prompt the user for input
read -p "Enter your GitHub username: " GIT_USERNAME
read -p "Enter your GitHub personal access token: " GIT_ACCESS_TOKEN
read -p "Enter Nodes address in format of node_address1@ip:26656,node_address2@ip:26656: " NODES_ADDRESS

sudo apt-get update
sudo apt install pkg-config build-essential libssl-dev curl jq git libleveldb-dev -y
sudo apt-get install manpages-dev -y
curl https://dl.google.com/go/go1.19.linux-amd64.tar.gz | sudo tar -C/usr/local -zxvf -
cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
source $HOME/.profile
go version  

# remove existing daemon.
rm -rf $HOME_DIR && echo "Removed $HOME_DIR"  
git clone https://$GIT_USERNAME:$GIT_ACCESS_TOKEN@github.com/GoudLA-org/goudla.git
cd goudla && git checkout v0.7
make clean
make build
sudo mv ./build/goudlad /usr/bin

cd cosmovisor
sudo mkdir -p $GOPATH/bin
make cosmovisor
sudo cp cosmovisor $GOPATH/bin/cosmovisor
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
sed -i 's/persistent_peers = ""/persistent_peers = "'"$peers"'"/' $HOME_DIR/config/config.toml
sed -i 's/enable = false/enable = true/; s/swagger = false/swagger = true/' $HOME_DIR/config/app.toml
sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "0.00001uGOUD"/' $HOME_DIR/config/app.toml

sudo cp $(which goudlad) $DAEMON_HOME/cosmovisor/genesis/bin
source ~/.profile
echo " -------------------- checking for cosmovisor ---------------------------- "
whereis cosmovisor 
sudo rm -rf /etc/systemd/system/goudlad.service
sudo chmod 777 /etc/systemd/system
COSMOVISOR_HOME=`whereis cosmovisor`
echo '
[Unit]
Description=Goudla Daemon
#After=network.target
StartLimitInterval=350
StartLimitBurst=10
[Service]
Type=simple
User='$USER'
ExecStart=/home/ubuntu/go/bin/cosmovisor start
Restart=on-abort
RestartSec=30
Environment="DAEMON_NAME=goudlad"
Environment="DAEMON_HOME='$HOME'sudo systemctl restart/.goudla"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_POLL_INTERVAL=300ms"
[Install]
WantedBy=multi-user.target
[Service]
LimitNOFILE=1048576
' >> /etc/systemd/system/goudlad.service

sudo chmod 755 /etc/systemd/system

# Start the chain
sudo systemctl daemon-reload
sudo systemctl enable goudlad

# Start the service
sudo systemctl start goudlad