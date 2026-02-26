const { ethers } = require("ethers");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");
const { getChainConfig } = require("./config/chains");
const { BRIDGE_ABI, NFT_ABI } = require("./config/abis");
const { logTransfer, consoleLog } = require("./utils/logger");
const { recordTransfer } = require("./utils/tracker");

const CHAIN_ALIASES = {
  "avalanche-fuji": "avalancheFuji",
  "arbitrum-sepolia": "arbitrumSepolia",
  avalancheFuji: "avalancheFuji",
  arbitrumSepolia: "arbitrumSepolia",
};

function normalizeChain(name) {
  return CHAIN_ALIASES[name] || name;
}

const VALID_CHAINS = Object.keys(CHAIN_ALIASES);

const argv = yargs(hideBin(process.argv))
  .usage("Usage: npm run transfer -- --tokenId=<id> --from=<chain> --to=<chain> --receiver=<address>")
  .option("tokenId", {
    type: "number",
    demandOption: true,
    describe: "NFT token ID to transfer",
  })
  .option("from", {
    type: "string",
    demandOption: true,
    choices: VALID_CHAINS,
    describe: "Source chain identifier",
  })
  .option("to", {
    type: "string",
    demandOption: true,
    choices: VALID_CHAINS,
    describe: "Destination chain identifier",
  })
  .option("receiver", {
    type: "string",
    demandOption: true,
    describe: "Receiver address on the destination chain",
  })
  .check((argv) => {
    if (normalizeChain(argv.from) === normalizeChain(argv.to)) {
      throw new Error("Source and destination chains must be different.");
    }
    if (!ethers.isAddress(argv.receiver)) {
      throw new Error(`Invalid receiver address: ${argv.receiver}`);
    }
    return true;
  })
  .strict()
  .help()
  .parseSync();

argv.from = normalizeChain(argv.from);
argv.to = normalizeChain(argv.to);

async function main() {
  const startTime = Date.now();

  consoleLog("info", "═══════════════════════════════════════════════════════════");
  consoleLog("info", "  Chainlink CCIP Cross-Chain NFT Bridge");
  consoleLog("info", "═══════════════════════════════════════════════════════════");
  consoleLog("info", "");

  let chainConfig;
  try {
    chainConfig = getChainConfig();
  } catch (err) {
    consoleLog("error", `Configuration error: ${err.message}`);
    process.exit(1);
  }

  const sourceConfig = chainConfig[argv.from];
  const destConfig = chainConfig[argv.to];

  if (!sourceConfig.rpcUrl) {
    consoleLog("error", `Missing RPC URL for ${sourceConfig.name}. Check your .env file.`);
    process.exit(1);
  }

  consoleLog("info", `Source chain:      ${sourceConfig.name}`);
  consoleLog("info", `Destination chain: ${destConfig.name}`);
  consoleLog("info", `Token ID:          ${argv.tokenId}`);
  consoleLog("info", `Receiver:          ${argv.receiver}`);
  consoleLog("info", "");

  let provider, wallet;
  try {
    provider = new ethers.JsonRpcProvider(sourceConfig.rpcUrl);
    const network = await provider.getNetwork();
    consoleLog("success", `Connected to ${sourceConfig.name} (chainId: ${network.chainId})`);
  } catch (err) {
    consoleLog("error", `Failed to connect to RPC at ${sourceConfig.rpcUrl}`);
    consoleLog("error", `Details: ${err.message}`);
    process.exit(1);
  }

  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    consoleLog("error", "PRIVATE_KEY not set in .env file.");
    process.exit(1);
  }

  try {
    wallet = new ethers.Wallet(privateKey, provider);
    consoleLog("info", `Wallet address:    ${wallet.address}`);
  } catch (err) {
    consoleLog("error", `Invalid private key: ${err.message}`);
    process.exit(1);
  }

  const nftContract = new ethers.Contract(sourceConfig.nftContract, NFT_ABI, wallet);
  const bridgeContract = new ethers.Contract(sourceConfig.bridgeContract, BRIDGE_ABI, wallet);

  consoleLog("info", "");
  consoleLog("info", "Verifying token ownership...");

  let tokenOwner, tokenURI;
  try {
    tokenOwner = await nftContract.ownerOf(argv.tokenId);
  } catch (err) {
    consoleLog("error", `Token #${argv.tokenId} does not exist on ${sourceConfig.name}.`);
    consoleLog("error", `It may have already been bridged or was never minted on this chain.`);
    process.exit(1);
  }

  if (tokenOwner.toLowerCase() !== wallet.address.toLowerCase()) {
    consoleLog("error", `You do not own token #${argv.tokenId}.`);
    consoleLog("error", `Owner: ${tokenOwner}`);
    consoleLog("error", `Your wallet: ${wallet.address}`);
    process.exit(1);
  }
  consoleLog("success", `Ownership confirmed: you own token #${argv.tokenId}`);

  try {
    tokenURI = await nftContract.tokenURI(argv.tokenId);
    consoleLog("success", `Token URI loaded (${tokenURI.length} chars)`);
  } catch (err) {
    consoleLog("warn", `Could not read tokenURI: ${err.message}`);
    tokenURI = "";
  }

  consoleLog("info", "");
  consoleLog("info", "Initiating cross-chain transfer...");
  consoleLog("info", `Calling sendNFT() on bridge at ${sourceConfig.bridgeContract}`);

  let tx, receipt;
  try {
    tx = await bridgeContract.sendNFT(
      destConfig.ccipSelector,
      argv.receiver,
      argv.tokenId,
      { gasLimit: 800_000 }
    );
    consoleLog("success", `Transaction submitted: ${tx.hash}`);
    consoleLog("info", `Explorer: ${sourceConfig.explorerUrl}/tx/${tx.hash}`);
    consoleLog("info", "Waiting for confirmation...");
  } catch (err) {
    const errorMessage = parseContractError(err);
    consoleLog("error", `Transaction failed: ${errorMessage}`);

    logTransfer({
      tokenId: String(argv.tokenId),
      sourceChain: argv.from,
      destinationChain: argv.to,
      sourceTxHash: "",
      ccipMessageId: "",
      status: "failed",
      error: errorMessage,
    });

    process.exit(1);
  }

  try {
    receipt = await tx.wait(2);
    consoleLog("success", `Transaction confirmed in block ${receipt.blockNumber}`);
    consoleLog("info", `Gas used: ${receipt.gasUsed.toString()}`);
  } catch (err) {
    consoleLog("error", `Transaction may have failed: ${err.message}`);
    process.exit(1);
  }

  let ccipMessageId = "unknown";
  try {

    const bridgeInterface = new ethers.Interface(BRIDGE_ABI);
    for (const log of receipt.logs) {
      try {
        const parsed = bridgeInterface.parseLog({
          topics: log.topics,
          data: log.data,
        });
        if (parsed && parsed.name === "NFTSent") {
          ccipMessageId = parsed.args.ccipMessageId;
          break;
        }
      } catch {

      }
    }
    consoleLog("success", `CCIP Message ID: ${ccipMessageId}`);
  } catch (err) {
    consoleLog("warn", `Could not extract CCIP messageId: ${err.message}`);
  }

  const transferRecord = recordTransfer({
    tokenId: argv.tokenId,
    sourceChain: argv.from,
    destinationChain: argv.to,
    sender: wallet.address,
    receiver: argv.receiver,
    ccipMessageId,
    sourceTxHash: tx.hash,
    tokenURI,
  });

  logTransfer({
    tokenId: String(argv.tokenId),
    sourceChain: argv.from,
    destinationChain: argv.to,
    sourceTxHash: tx.hash,
    ccipMessageId,
    status: "initiated",
  });

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

  consoleLog("info", "");
  consoleLog("info", "═══════════════════════════════════════════════════════════");
  consoleLog("success", "  Transfer initiated successfully!");
  consoleLog("info", "═══════════════════════════════════════════════════════════");
  consoleLog("info", "");
  consoleLog("info", `  Transfer ID:      ${transferRecord.transferId}`);
  consoleLog("info", `  Token ID:         ${argv.tokenId}`);
  consoleLog("info", `  Source:           ${sourceConfig.name}`);
  consoleLog("info", `  Destination:      ${destConfig.name}`);
  consoleLog("info", `  Receiver:         ${argv.receiver}`);
  consoleLog("info", `  Source TX:        ${tx.hash}`);
  consoleLog("info", `  CCIP Message ID:  ${ccipMessageId}`);
  consoleLog("info", `  Time elapsed:     ${elapsed}s`);
  consoleLog("info", "");
  consoleLog("info", "  Track your transfer:");
  consoleLog("info", `  https://ccip.chain.link/msg/${ccipMessageId}`);
  consoleLog("info", "");
  consoleLog("info", "  The NFT will be minted on the destination chain once");
  consoleLog("info", "  the CCIP message is finalized (typically 15-20 minutes).");
  consoleLog("info", "═══════════════════════════════════════════════════════════");
}

function parseContractError(err) {

  if (err.code === "INSUFFICIENT_FUNDS") {
    return "Insufficient funds for gas. Please fund your wallet.";
  }
  if (err.code === "CALL_EXCEPTION") {
    const reason = err.reason || err.revert?.args?.[0] || "Unknown revert reason";
    return `Contract reverted: ${reason}`;
  }
  if (err.code === "NETWORK_ERROR") {
    return "Network error — check your RPC URL and internet connection.";
  }
  if (err.code === "NONCE_EXPIRED") {
    return "Nonce already used. A pending transaction may exist.";
  }
  if (err.message?.includes("InsufficientLinkBalance")) {
    return "Insufficient LINK balance in the bridge contract. Fund the bridge with LINK tokens.";
  }
  if (err.message?.includes("ChainNotAllowed")) {
    return "Destination chain is not configured. Run the ConfigureBridges script.";
  }
  if (err.message?.includes("CallerDoesNotOwnToken")) {
    return "You do not own this token.";
  }

  return err.shortMessage || err.message || "Unknown error";
}

main().catch((err) => {
  consoleLog("error", `Unexpected error: ${err.message}`);
  process.exit(1);
});
