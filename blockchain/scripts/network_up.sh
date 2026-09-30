#!/usr/bin/env bash
# Bring up the ScrapChain Fabric network (requires fabric-samples binaries in PATH).
set -euo pipefail
cd "$(dirname "$0")/../network"

echo "1/5 Generating crypto material..."
cryptogen generate --config=crypto-config.yaml --output=crypto-config

echo "2/5 Creating genesis block..."
configtxgen -profile ScrapChainGenesis -channelID system-channel -outputBlock orderer.genesis.block

echo "3/5 Creating channel tx..."
configtxgen -profile ScrapChainChannel -channelID scrapchain-channel -outputCreateChannelTx scrapchain-channel.tx

echo "4/5 Starting orderer + peer (docker compose)..."
docker compose -f ../../docker/docker-compose.yaml up -d orderer peer0

echo "5/5 Creating + joining channel, deploying chaincode..."
export CORE_PEER_LOCALMSPID=ScrapChainMSP
export CORE_PEER_MSPCONFIGPATH=$PWD/crypto-config/peerOrganizations/scrapchain.org/users/Admin@scrapchain.org/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel create -o localhost:7050 -c scrapchain-channel -f scrapchain-channel.tx
peer channel join -b scrapchain-channel.block

peer lifecycle chaincode package receipt.tar.gz --path ../chaincode --lang golang --label receipt_1
peer lifecycle chaincode install receipt.tar.gz
PKG_ID=$(peer lifecycle chaincode queryinstalled | grep receipt_1 | sed 's/.*Package ID: \(.*\), Label.*/\1/')
peer lifecycle chaincode approveformyorg -o localhost:7050 --channelID scrapchain-channel \
  --name receipt-chaincode --version 1.0 --package-id "$PKG_ID" --sequence 1
peer lifecycle chaincode commit -o localhost:7050 --channelID scrapchain-channel \
  --name receipt-chaincode --version 1.0 --sequence 1

echo "✅ Fabric network up. Set FABRIC_MODE=live in backend/.env"
