# 🌉 Chainlink CCIP Cross-Chain NFT Bridge

> Move your NFTs across blockchains — seamlessly, securely, and without duplicates.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?logo=ethereum)](https://book.getfoundry.sh/)
[![Chainlink CCIP](https://img.shields.io/badge/Powered%20by-Chainlink%20CCIP-375BD2?logo=chainlink)](https://chain.link/cross-chain)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What This Project Does

This is a **production-ready cross-chain NFT bridge** that lets you transfer ERC-721 tokens between **Avalanche Fuji** and **Arbitrum Sepolia** using [Chainlink CCIP](https://chain.link/cross-chain).

When you bridge an NFT:
1. The token is **burned** on the source chain
2. A CCIP message carries its identity and metadata across chains
3. An identical token is **minted** on the destination chain

The result? Your NFT — same `tokenId`, same `tokenURI`, same metadata — lives on a new chain. No duplicates, no wrapped tokens, no trust assumptions beyond Chainlink's battle-tested oracle network.

---

## Why Burn-and-Mint?

Most bridges use a "lock-and-mint" model, where your original NFT gets locked in a vault and a synthetic copy is minted on the other side. That works, but it introduces problems: liquidity fragmentation, vault risk, and the uncomfortable reality that your "bridged" token isn't really the same thing.

We chose **burn-and-mint** because it's simpler and more honest. There's always exactly one copy of your NFT in existence. When it moves, it really moves.

---

## Architecture

Here's how the pieces fit together:

```
  AVALANCHE FUJI                                         ARBITRUM SEPOLIA

  ┌─────────────────────┐                               ┌─────────────────────┐
  │   CrossChainNFT     │                               │   CrossChainNFT     │
  │   (ERC721)          │                               │   (ERC721)          │
  │                     │                               │                     │
  │   ownerMint()       │                               │   mint() ← bridge   │
  │   burn() ← bridge   │                               │   exists() guard    │
  └────────┬────────────┘                               └────────▲────────────┘
           │                                                      │
  ┌────────▼────────────┐     ┌─────────────────┐      ┌─────────┴───────────┐
  │   CCIPNFTBridge     │────►│  Chainlink CCIP  │────►│   CCIPNFTBridge     │
  │                     │     │  DON Network     │      │                     │
  │  sendNFT()          │     │                  │      │  _ccipReceive()     │
  │  - verify ownership │     │  Carries:        │      │  - validate source  │
  │  - read tokenURI    │     │  (receiver,      │      │  - validate sender  │
  │  - burn NFT         │     │   tokenId,       │      │  - check replay     │
  │  - encode & send    │     │   tokenURI)      │      │  - idempotent mint  │
  └─────────────────────┘     └─────────────────┘      └─────────────────────┘

                    ┌──────────────────────────────┐
                    │      CLI Tool (Node.js)       │
                    │                               │
                    │  npm run transfer             │
                    │    --tokenId=1                 │
                    │    --from=avalanche-fuji       │
                    │    --to=arbitrum-sepolia       │
                    │    --receiver=0x...            │
                    │                               │
                    │  ✓ Logs → logs/transfers.log  │
                    │  ✓ Data → data/nft_transfers  │
                    └──────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Solidity 0.8.24 · Foundry |
| Cross-Chain Messaging | Chainlink CCIP |
| Token Standard | ERC-721 (ERC721URIStorage) |
| CLI Backend | Node.js 18+ · ethers.js v6 · yargs |
| Containerization | Docker · Docker Compose |
| Dependencies | OpenZeppelin Contracts · Chainlink CCIP |

---

## Supported Chains

| Chain | Network | Chain ID | CCIP Selector |
|-------|---------|----------|---------------|
| Avalanche Fuji | Testnet | 43113 | `14767482510784806043` |
| Arbitrum Sepolia | Testnet | 421614 | `3478487238524512106` |

---

## Pre-Minted Test Token

Token **#1** is pre-minted on **Avalanche Fuji** during deployment. It's your ready-to-bridge test asset:

```json
{
  "name": "CrossChain Explorer #1",
  "description": "A pioneering NFT that travels across blockchains via Chainlink CCIP.",
  "image": "https://ipfs.io/ipfs/QmExampleHash/1.png",
  "attributes": [
    { "trait_type": "Origin Chain", "value": "Avalanche Fuji" },
    { "trait_type": "Bridge Protocol", "value": "Chainlink CCIP" },
    { "trait_type": "Edition", "value": "Genesis" }
  ]
}
```

---

## Project Structure

```
CCIP-Cross-Chain-NFT-Bridge/
├── src/
│   ├── CrossChainNFT.sol             ERC721 with bridge-controlled minting
│   └── CCIPNFTBridge.sol             CCIP sender + receiver logic
├── script/
│   ├── DeployFuji.s.sol              Deploy to Avalanche Fuji
│   ├── DeployArbitrumSepolia.s.sol   Deploy to Arbitrum Sepolia
│   └── ConfigureBridges.s.sol        Link bridges as trusted peers
├── test/
│   └── CCIPNFTBridge.t.sol           32 unit tests (Foundry)
├── cli/
│   ├── index.js                      Transfer command entry point
│   ├── status.js                     View transfer history
│   ├── config/
│   │   ├── chains.js                 Chain registry & config
│   │   └── abis.js                   Minimal contract ABIs
│   └── utils/
│       ├── logger.js                 Structured JSONL logger
│       └── tracker.js                Transfer record persistence
├── logs/                             Transfer logs (JSONL)
├── data/                             Transfer tracking (JSON)
├── deployment.json                   Deployed contract addresses
├── foundry.toml                      Foundry configuration
├── package.json                      Node.js dependencies
├── Dockerfile                        Multi-stage Docker image
├── docker-compose.yml                Container orchestration
├── .env.example                      Environment variable template
└── README.md
```

---

## Getting Started

### Prerequisites

You'll need:
- [**Foundry**](https://book.getfoundry.sh/getting-started/installation) — for compiling and deploying contracts
- [**Node.js 18+**](https://nodejs.org/) — for the CLI tool
- [**Docker**](https://docs.docker.com/get-docker/) *(optional)* — for containerized execution
- A wallet funded with **testnet AVAX**, **Sepolia ETH**, and **LINK** tokens
- Grab testnet LINK from the [Chainlink Faucet](https://faucets.chain.link/)

### 1. Clone & Install

```bash
git clone <repository-url>
cd CCIP-Cross-Chain-NFT-Bridge

forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install smartcontractkit/ccip --no-commit

npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Open `.env` and add your `PRIVATE_KEY` (without the `0x` prefix). The RPC endpoints, router addresses, and LINK token addresses are already pre-filled with correct values.

### 3. Fund Your Wallet

Make sure your deployer wallet has:
- **Testnet AVAX** on Fuji (for gas)
- **Testnet ETH** on Arbitrum Sepolia (for gas)
- **LINK tokens** on both chains (for CCIP fees)

---

## Deployment

### Step 1 → Deploy to Avalanche Fuji

```bash
source .env

forge script script/DeployFuji.s.sol:DeployFuji \
  --rpc-url $FUJI_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY \
  -vvvv
```

After deployment, update `deployment.json` with the printed addresses and set `BRIDGE_FUJI` in your `.env`.

### Step 2 → Deploy to Arbitrum Sepolia

```bash
forge script script/DeployArbitrumSepolia.s.sol:DeployArbitrumSepolia \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY \
  -vvvv
```

Same thing: update `deployment.json` and set `BRIDGE_ARBITRUM_SEPOLIA` in `.env`.

### Step 3 → Link the Bridges

Each bridge needs to know about and trust its counterpart on the other chain:

```bash
forge script script/ConfigureBridges.s.sol:ConfigureFuji \
  --rpc-url $FUJI_RPC_URL \
  --broadcast --private-key $PRIVATE_KEY -vvvv

forge script script/ConfigureBridges.s.sol:ConfigureArbitrumSepolia \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast --private-key $PRIVATE_KEY -vvvv
```

### Step 4 → Fund the Bridge with LINK

The bridge pays CCIP fees in LINK. Send some to each bridge contract:

```bash
cast send $LINK_TOKEN_FUJI \
  "transfer(address,uint256)" $BRIDGE_FUJI 2000000000000000000 \
  --rpc-url $FUJI_RPC_URL --private-key $PRIVATE_KEY
```

---

## Using the CLI

### Transfer an NFT

```bash
npm run transfer -- \
  --tokenId=1 \
  --from=avalanche-fuji \
  --to=arbitrum-sepolia \
  --receiver=0xYourReceiverAddress
```

The CLI walks you through every step with clear, color-coded output:

```
[INFO] ═══════════════════════════════════════════════════════════
[INFO]   Chainlink CCIP Cross-Chain NFT Bridge
[INFO] ═══════════════════════════════════════════════════════════
[INFO]
[INFO] Source chain:      Avalanche Fuji
[INFO] Destination chain: Arbitrum Sepolia
[INFO] Token ID:          1
[INFO] Receiver:          0xAbC123...
[OK]   Connected to Avalanche Fuji (chainId: 43113)
[OK]   Ownership confirmed: you own token #1
[OK]   Token URI loaded (312 chars)
[INFO]
[INFO] Initiating cross-chain transfer...
[OK]   Transaction submitted: 0xabc123...
[OK]   Transaction confirmed in block 29481023
[OK]   CCIP Message ID: 0xdef456...
[INFO]
[INFO] ═══════════════════════════════════════════════════════════
[OK]     Transfer initiated successfully!
[INFO] ═══════════════════════════════════════════════════════════
[INFO]   Track your transfer:
[INFO]   https://ccip.chain.link/msg/0xdef456...
[INFO]
[INFO]   The NFT will be minted on the destination chain once
[INFO]   the CCIP message is finalized (typically 15-20 minutes).
[INFO] ═══════════════════════════════════════════════════════════
```

### View Transfer History

```bash
npm run status
```

---

## Docker

If you prefer running things in a container:

```bash
docker-compose up -d --build

docker-compose exec bridge npm run transfer -- \
  --tokenId=1 \
  --from=avalanche-fuji \
  --to=arbitrum-sepolia \
  --receiver=0xYourAddress

docker-compose logs bridge

docker-compose down
```

Logs and transfer data are volume-mounted, so they persist across container restarts.

---

## Transfer Lifecycle

Here's what happens end-to-end when you bridge an NFT:

```
1. You run the CLI command
   └── npm run transfer -- --tokenId=1 --from=avalanche-fuji ...

2. CLI verifies you own the token and reads its metadata
   └── Calls ownerOf() and tokenURI() on the source chain

3. CLI calls sendNFT() on the source bridge
   ├── Bridge burns the NFT on the source chain
   ├── Encodes (receiver, tokenId, tokenURI) as the CCIP payload
   ├── Pays the CCIP fee in LINK
   └── Emits NFTSent event with the CCIP message ID

4. Chainlink's DON relays the message cross-chain
   └── This takes about 15-20 minutes for finality

5. Destination bridge receives the message via _ccipReceive()
   ├── Validates the source chain is allowed
   ├── Validates the sender is the trusted peer bridge
   ├── Checks the message hasn't been processed before
   ├── Verifies the tokenId doesn't already exist (idempotency)
   └── Mints the NFT to the receiver with the original metadata

6. Done — your NFT is on the new chain
   └── Same tokenId · Same tokenURI · New home
```

---

## Logging & Tracking

### Transfer Logs

Every transfer is appended to `logs/transfers.log` in JSONL format — one JSON object per line, easy to parse with `grep` or `jq`:

```json
{"timestamp":"2026-02-26T10:30:00.000Z","tokenId":"1","sourceChain":"avalancheFuji","destinationChain":"arbitrumSepolia","sourceTxHash":"0xabc...","ccipMessageId":"0xdef...","status":"initiated"}
```

```bash
cat logs/transfers.log | jq 'select(.status == "initiated")'
cat logs/transfers.log | jq 'select(.tokenId == "1")'
```

### Transfer Records

Detailed records live in `data/nft_transfers.json` with the full schema:

```json
[
  {
    "transferId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "tokenId": "1",
    "sourceChain": "avalancheFuji",
    "destinationChain": "arbitrumSepolia",
    "sender": "0x...",
    "receiver": "0x...",
    "ccipMessageId": "0x...",
    "sourceTxHash": "0x...",
    "destinationTxHash": null,
    "status": "initiated",
    "metadata": {
      "name": "CrossChain Explorer #1",
      "description": "A pioneering NFT that travels across blockchains via Chainlink CCIP.",
      "image": "https://ipfs.io/ipfs/QmExampleHash/1.png"
    },
    "timestamp": "2026-02-26T10:30:00.000Z"
  }
]
```

---

## Security

We take security seriously. Here's how the bridge protects your assets:

| Protection | How It Works |
|-----------|-------------|
| **Burn before send** | The NFT is destroyed *before* the CCIP message is sent. There's never a moment where two copies exist. |
| **Source chain validation** | `_ccipReceive` only accepts messages from chains in the `allowedChains` mapping. Everything else reverts. |
| **Trusted sender validation** | Each bridge only accepts messages from its registered peer bridge. Random contracts can't mint your tokens. |
| **Idempotent minting** | Before minting, the bridge checks `nft.exists(tokenId)`. If the token already exists, it skips silently instead of reverting. |
| **Replay protection** | Every processed CCIP message ID is recorded. Replayed messages are rejected. This is defense-in-depth on top of CCIP's own guarantees. |
| **Access control** | Admin functions are `onlyOwner`. Minting is `onlyBridge`. No shortcuts. |
| **LINK balance guard** | The bridge checks it has enough LINK to cover fees *before* attempting the CCIP call. Clear error message if not. |
| **Safe ERC20** | All LINK token interactions use OpenZeppelin's `SafeERC20` to handle edge cases gracefully. |

---

## Testing

The project includes **32 Foundry tests** covering:

- NFT minting, burning, and ownership
- Bridge configuration and access control
- Cross-chain send and receive flows
- Error cases: unauthorized callers, replay, insufficient LINK
- End-to-end burn-on-source → mint-on-destination simulation

```bash
forge test -vv
```

```
Suite result: ok. 32 passed; 0 failed; 0 skipped
```

---

## CCIP Explorer

After initiating a transfer, track your cross-chain message in real-time:

**🔗 [https://ccip.chain.link](https://ccip.chain.link)**

The CLI gives you a direct link:
```
https://ccip.chain.link/msg/<YOUR_MESSAGE_ID>
```

You'll see the source transaction, relay progress, destination execution, and timing — all in one place.

---

## Troubleshooting

| Problem | What's Happening | Fix |
|---------|-----------------|-----|
| `ChainNotAllowed` | Bridge isn't configured for that destination | Run `ConfigureBridges` script |
| `InsufficientLinkBalance` | Bridge contract needs more LINK | Transfer LINK to the bridge address |
| `CallerDoesNotOwnToken` | Your wallet doesn't own this tokenId | Double-check with `ownerOf()` |
| `Token does not exist` | Already bridged, or never minted | Verify on the block explorer |
| `RPC connection failed` | Bad URL or network issue | Check `.env`, try a different RPC provider |
| `PRIVATE_KEY not set` | Missing from `.env` | Add it (without the `0x` prefix) |

### Verifying Your Deployment

```bash
cast call <NFT_ADDRESS> "name()(string)" --rpc-url $FUJI_RPC_URL

cast call <BRIDGE_ADDRESS> "allowedChains(uint64)(bool)" 3478487238524512106 --rpc-url $FUJI_RPC_URL

cast call $LINK_TOKEN_FUJI "balanceOf(address)(uint256)" <BRIDGE_ADDRESS> --rpc-url $FUJI_RPC_URL
```

### Debugging a Failed Transfer

1. Check the source transaction on the block explorer
2. Look for revert reasons in the transaction trace
3. Verify CCIP status at [ccip.chain.link](https://ccip.chain.link)
4. Review `logs/transfers.log` for error entries
5. Check `data/nft_transfers.json` for the transfer record

---

## License

MIT — use it, learn from it, build on it.
