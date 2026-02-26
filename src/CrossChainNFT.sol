pragma solidity 0.8.24;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CrossChainNFT is ERC721URIStorage, Ownable {
    address public bridge;

    event BridgeSet(address indexed previousBridge, address indexed newBridge);
    event NFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        string tokenURI
    );
    event NFTBurned(uint256 indexed tokenId);

    error CallerIsNotBridge(address caller);
    error BridgeAddressZero();
    error TokenDoesNotExist(uint256 tokenId);
    error CallerIsNotOwnerOfToken(address caller, uint256 tokenId);

    modifier onlyBridge() {
        if (msg.sender != bridge) revert CallerIsNotBridge(msg.sender);
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable() {}

    function setBridge(address _bridge) external onlyOwner {
        if (_bridge == address(0)) revert BridgeAddressZero();
        emit BridgeSet(bridge, _bridge);
        bridge = _bridge;
    }

    function mint(
        address _to,
        uint256 _tokenId,
        string calldata _tokenURI
    ) external onlyBridge {
        _safeMint(_to, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        emit NFTMinted(_to, _tokenId, _tokenURI);
    }

    function burn(uint256 _tokenId) external {
        address tokenOwner = ownerOf(_tokenId);
        if (msg.sender != bridge && msg.sender != tokenOwner) {
            revert CallerIsNotOwnerOfToken(msg.sender, _tokenId);
        }
        _burn(_tokenId);
        emit NFTBurned(_tokenId);
    }

    function exists(uint256 _tokenId) external view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function ownerMint(
        address _to,
        uint256 _tokenId,
        string calldata _tokenURI
    ) external onlyOwner {
        _safeMint(_to, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        emit NFTMinted(_to, _tokenId, _tokenURI);
    }
}
