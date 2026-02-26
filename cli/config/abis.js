const BRIDGE_ABI = [

  "function sendNFT(uint64 _destinationChainSelector, address _receiver, uint256 _tokenId) external returns (bytes32 messageId)",

  "function estimateTransferCost(uint64 _destinationChainSelector, address _receiver, uint256 _tokenId, string calldata _tokenURI) external view returns (uint256 fee)",

  "event NFTSent(bytes32 indexed ccipMessageId, uint64 indexed destinationChainSelector, address indexed sender, address receiver, uint256 tokenId, string tokenURI, uint256 ccipFee)",
  "event NFTReceived(bytes32 indexed ccipMessageId, uint64 indexed sourceChainSelector, address indexed receiver, uint256 tokenId, string tokenURI)",
];

const NFT_ABI = [
  "function tokenURI(uint256 tokenId) external view returns (string memory)",
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function exists(uint256 tokenId) external view returns (bool)",
  "function name() external view returns (string memory)",
  "function symbol() external view returns (string memory)",
];

const LINK_ABI = [
  "function balanceOf(address account) external view returns (uint256)",
  "function transfer(address to, uint256 amount) external returns (bool)",
  "function approve(address spender, uint256 amount) external returns (bool)",
];

module.exports = { BRIDGE_ABI, NFT_ABI, LINK_ABI };
