pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {CrossChainNFT} from "./CrossChainNFT.sol";

contract CCIPNFTBridge is CCIPReceiver, Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    CrossChainNFT public immutable nft;

    IERC20 public immutable linkToken;

    mapping(uint64 => address) public trustedBridges;

    mapping(uint64 => bool) public allowedChains;

    mapping(bytes32 => bool) public processedMessages;

    event NFTSent(
        bytes32 indexed ccipMessageId,
        uint64 indexed destinationChainSelector,
        address indexed sender,
        address receiver,
        uint256 tokenId,
        string tokenURI,
        uint256 ccipFee
    );

    event NFTReceived(
        bytes32 indexed ccipMessageId,
        uint64 indexed sourceChainSelector,
        address indexed receiver,
        uint256 tokenId,
        string tokenURI
    );

    event NFTMintSkipped(
        bytes32 indexed ccipMessageId,
        uint256 indexed tokenId,
        string reason
    );

    event ChainConfigured(
        uint64 indexed chainSelector,
        address indexed trustedBridge
    );
    event ChainRemoved(uint64 indexed chainSelector);

    error ChainNotAllowed(uint64 chainSelector);
    error SenderNotTrusted(uint64 chainSelector, address sender);
    error InsufficientLinkBalance(uint256 required, uint256 available);
    error CallerDoesNotOwnToken(address caller, uint256 tokenId);
    error InvalidReceiverAddress();
    error MessageAlreadyProcessed(bytes32 messageId);

    constructor(
        address _router,
        address _linkToken,
        address _nft
    ) CCIPReceiver(_router) Ownable() {
        linkToken = IERC20(_linkToken);
        nft = CrossChainNFT(_nft);
    }

    function setTrustedBridge(
        uint64 _chainSelector,
        address _trustedBridge
    ) external onlyOwner {
        allowedChains[_chainSelector] = true;
        trustedBridges[_chainSelector] = _trustedBridge;
        emit ChainConfigured(_chainSelector, _trustedBridge);
    }

    function removeChain(uint64 _chainSelector) external onlyOwner {
        allowedChains[_chainSelector] = false;
        delete trustedBridges[_chainSelector];
        emit ChainRemoved(_chainSelector);
    }

    function sendNFT(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _tokenId
    ) external returns (bytes32 messageId) {

        if (!allowedChains[_destinationChainSelector]) {
            revert ChainNotAllowed(_destinationChainSelector);
        }
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        if (nft.ownerOf(_tokenId) != msg.sender) {
            revert CallerDoesNotOwnToken(msg.sender, _tokenId);
        }

        string memory uri = nft.tokenURI(_tokenId);

        nft.burn(_tokenId);

        bytes memory payload = abi.encode(_receiver, _tokenId, uri);

        address peerBridge = trustedBridges[_destinationChainSelector];
        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPMessageWithFee(
            peerBridge,
            payload
        );

        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fee = router.getFee(_destinationChainSelector, ccipMessage);

        uint256 linkBalance = linkToken.balanceOf(address(this));
        if (linkBalance < fee) {
            revert InsufficientLinkBalance(fee, linkBalance);
        }

        linkToken.safeApprove(address(router), 0);
        linkToken.safeApprove(address(router), fee);

        messageId = router.ccipSend(_destinationChainSelector, ccipMessage);

        emit NFTSent(
            messageId,
            _destinationChainSelector,
            msg.sender,
            _receiver,
            _tokenId,
            uri,
            fee
        );
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        uint64 sourceChainSelector = message.sourceChainSelector;
        address sender = abi.decode(message.sender, (address));
        bytes32 msgId = message.messageId;

        if (!allowedChains[sourceChainSelector]) {
            revert ChainNotAllowed(sourceChainSelector);
        }

        if (sender != trustedBridges[sourceChainSelector]) {
            revert SenderNotTrusted(sourceChainSelector, sender);
        }

        if (processedMessages[msgId]) {
            revert MessageAlreadyProcessed(msgId);
        }
        processedMessages[msgId] = true;

        (address receiver, uint256 tokenId, string memory tokenURI) = abi
            .decode(message.data, (address, uint256, string));

        if (nft.exists(tokenId)) {
            emit NFTMintSkipped(msgId, tokenId, "Token already exists");
            return;
        }

        nft.mint(receiver, tokenId, tokenURI);

        emit NFTReceived(
            msgId,
            sourceChainSelector,
            receiver,
            tokenId,
            tokenURI
        );
    }

    function estimateTransferCost(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _tokenId,
        string calldata _tokenURI
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode(_receiver, _tokenId, _tokenURI);
        address peerBridge = trustedBridges[_destinationChainSelector];
        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPMessageWithFee(
            peerBridge,
            payload
        );

        IRouterClient router = IRouterClient(this.getRouter());
        fee = router.getFee(_destinationChainSelector, ccipMessage);
    }

    function estimateTransferCost(
        uint64 _destinationChainSelector
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode(address(0), uint256(0), "");
        address peerBridge = trustedBridges[_destinationChainSelector];
        Client.EVM2AnyMessage memory ccipMessage = _buildCCIPMessageWithFee(
            peerBridge,
            payload
        );

        IRouterClient router = IRouterClient(this.getRouter());
        fee = router.getFee(_destinationChainSelector, ccipMessage);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdrawLink(address _to, uint256 _amount) external onlyOwner {
        linkToken.safeTransfer(_to, _amount);
    }

    function _buildCCIPMessageWithFee(
        address _peerBridge,
        bytes memory _payload
    ) internal view returns (Client.EVM2AnyMessage memory) {
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_peerBridge),
                data: _payload,
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 500_000})
                ),
                feeToken: address(linkToken)
            });
    }
}
