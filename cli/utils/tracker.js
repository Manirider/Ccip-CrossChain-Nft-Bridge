const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");

const DATA_DIR = path.resolve(__dirname, "../../data");
const TRANSFERS_FILE = path.join(DATA_DIR, "nft_transfers.json");

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

function loadTransfers() {
  if (!fs.existsSync(TRANSFERS_FILE)) {
    return [];
  }
  try {
    const raw = fs.readFileSync(TRANSFERS_FILE, "utf-8");
    return JSON.parse(raw);
  } catch {

    console.error(`[WARN] Could not parse ${TRANSFERS_FILE}, starting fresh.`);
    return [];
  }
}

function saveTransfers(transfers) {
  fs.writeFileSync(TRANSFERS_FILE, JSON.stringify(transfers, null, 2), "utf-8");
}

function extractMetadata(tokenURI) {
  const empty = { name: "", description: "", image: "" };

  if (!tokenURI) return empty;

  try {

    if (tokenURI.startsWith("data:application/json;base64,")) {
      const base64Data = tokenURI.replace("data:application/json;base64,", "");
      const decoded = Buffer.from(base64Data, "base64").toString("utf-8");
      const parsed = JSON.parse(decoded);
      return {
        name: parsed.name || "",
        description: parsed.description || "",
        image: parsed.image || "",
      };
    }

    const parsed = JSON.parse(tokenURI);
    return {
      name: parsed.name || "",
      description: parsed.description || "",
      image: parsed.image || "",
    };
  } catch {

    return { name: "", description: "", image: tokenURI };
  }
}

function recordTransfer({
  tokenId,
  sourceChain,
  destinationChain,
  sender,
  receiver,
  ccipMessageId,
  sourceTxHash,
  tokenURI,
}) {
  const transfers = loadTransfers();

  const record = {
    transferId: uuidv4(),
    tokenId: String(tokenId),
    sourceChain,
    destinationChain,
    sender,
    receiver,
    ccipMessageId,
    sourceTxHash,
    destinationTxHash: null,
    status: "initiated",
    metadata: extractMetadata(tokenURI),
    timestamp: new Date().toISOString(),
  };

  transfers.push(record);
  saveTransfers(transfers);

  return record;
}

function updateTransfer(transferId, updates) {
  const transfers = loadTransfers();
  const index = transfers.findIndex((t) => t.transferId === transferId);

  if (index === -1) {
    console.error(`[WARN] Transfer ${transferId} not found in tracking file.`);
    return;
  }

  transfers[index] = { ...transfers[index], ...updates };
  saveTransfers(transfers);
}

module.exports = { recordTransfer, updateTransfer, loadTransfers };
