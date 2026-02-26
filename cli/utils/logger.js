const fs = require("fs");
const path = require("path");

const LOG_DIR = path.resolve(__dirname, "../../logs");
const LOG_FILE = path.join(LOG_DIR, "transfers.log");

if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

function logTransfer(entry) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    ...entry,
  };

  const line = JSON.stringify(logEntry) + "\n";

  try {
    fs.appendFileSync(LOG_FILE, line, "utf-8");
  } catch (err) {

    console.error(`[WARN] Failed to write to ${LOG_FILE}:`, err.message);
  }
}

function consoleLog(level, message) {
  const prefixes = {
    info: "\x1b[36m[INFO]\x1b[0m",
    success: "\x1b[32m[OK]\x1b[0m",
    warn: "\x1b[33m[WARN]\x1b[0m",
    error: "\x1b[31m[ERROR]\x1b[0m",
  };
  const prefix = prefixes[level] || "[LOG]";
  console.log(`${prefix} ${message}`);
}

module.exports = { logTransfer, consoleLog };
