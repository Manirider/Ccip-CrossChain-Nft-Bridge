const path = require("path");
const fs = require("fs");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });

const DEPLOYMENT_PATH = path.resolve(__dirname, "../../deployment.json");

function loadDeployment() {
  if (!fs.existsSync(DEPLOYMENT_PATH)) {
    throw new Error(
      `deployment.json not found at ${DEPLOYMENT_PATH}. ` +
        "Run the Foundry deployment scripts first."
    );
  }
  return JSON.parse(fs.readFileSync(DEPLOYMENT_PATH, "utf-8"));
}

const CHAIN_SELECTORS = {
  avalancheFuji: "14767482510784806043",
  arbitrumSepolia: "3478487238524512106",
};

function getChainConfig() {
  const deployment = loadDeployment();

  return {
    avalancheFuji: {
      name: "Avalanche Fuji",
      chainId: 43113,
      ccipSelector: CHAIN_SELECTORS.avalancheFuji,
      rpcUrl: process.env.FUJI_RPC_URL,
      ccipRouter: process.env.CCIP_ROUTER_FUJI,
      linkToken: process.env.LINK_TOKEN_FUJI,
      nftContract: deployment.avalancheFuji.nftContractAddress,
      bridgeContract: deployment.avalancheFuji.bridgeContractAddress,
      explorerUrl: "https://testnet.snowtrace.io",
    },
    arbitrumSepolia: {
      name: "Arbitrum Sepolia",
      chainId: 421614,
      ccipSelector: CHAIN_SELECTORS.arbitrumSepolia,
      rpcUrl: process.env.ARBITRUM_SEPOLIA_RPC_URL,
      ccipRouter: process.env.CCIP_ROUTER_ARBITRUM_SEPOLIA,
      linkToken: process.env.LINK_TOKEN_ARBITRUM_SEPOLIA,
      nftContract: deployment.arbitrumSepolia.nftContractAddress,
      bridgeContract: deployment.arbitrumSepolia.bridgeContractAddress,
      explorerUrl: "https://sepolia.arbiscan.io",
    },
  };
}

module.exports = { getChainConfig, CHAIN_SELECTORS };
