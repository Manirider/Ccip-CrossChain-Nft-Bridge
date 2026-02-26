const { loadTransfers } = require("./utils/tracker");
const { consoleLog } = require("./utils/logger");

function main() {
  const transfers = loadTransfers();

  if (transfers.length === 0) {
    consoleLog("info", "No transfers recorded yet.");
    return;
  }

  consoleLog("info", `Found ${transfers.length} transfer(s):\n`);

  for (const t of transfers) {
    console.log("─".repeat(60));
    console.log(`  Transfer ID:      ${t.transferId}`);
    console.log(`  Token ID:         ${t.tokenId}`);
    console.log(`  Status:           ${t.status}`);
    console.log(`  Source:           ${t.sourceChain}`);
    console.log(`  Destination:      ${t.destinationChain}`);
    console.log(`  Sender:           ${t.sender}`);
    console.log(`  Receiver:         ${t.receiver}`);
    console.log(`  CCIP Message ID:  ${t.ccipMessageId}`);
    console.log(`  Source TX:        ${t.sourceTxHash}`);
    console.log(`  Dest TX:          ${t.destinationTxHash || "pending"}`);
    console.log(`  Timestamp:        ${t.timestamp}`);

    if (t.metadata?.name) {
      console.log(`  NFT Name:         ${t.metadata.name}`);
    }
    console.log("");
  }

  console.log("─".repeat(60));
}

main();
