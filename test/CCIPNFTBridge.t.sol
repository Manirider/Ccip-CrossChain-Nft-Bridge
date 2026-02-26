pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CrossChainNFT} from "../src/CrossChainNFT.sol";
import {CCIPNFTBridge} from "../src/CCIPNFTBridge.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MockRouter {
    uint256 public constant MOCK_FEE = 0.1 ether;
    bytes32 public lastMessageId;
    uint256 private _nonce;

    function getFee(
        uint64 ,
        Client.EVM2AnyMessage memory
    ) external pure returns (uint256) {
        return MOCK_FEE;
    }

    function ccipSend(
        uint64 ,
        Client.EVM2AnyMessage calldata
    ) external returns (bytes32) {
        _nonce++;
        lastMessageId = keccak256(abi.encodePacked(_nonce, block.timestamp));
        return lastMessageId;
    }
}

contract MockLINK {
    string public name = "ChainLink Token";
    string public symbol = "LINK";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(
            allowance[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract TestBridge is CCIPNFTBridge {
    constructor(
        address _router,
        address _linkToken,
        address _nft
    ) CCIPNFTBridge(_router, _linkToken, _nft) {}

    function testCcipReceive(Client.Any2EVMMessage memory message) external {
        _ccipReceive(message);
    }
}

contract CCIPNFTBridgeTest is Test {

    CrossChainNFT public nft;
    TestBridge public bridge;
    MockRouter public router;
    MockLINK public linkToken;

    CrossChainNFT public peerNft;
    TestBridge public peerBridge;
    MockRouter public peerRouter;

    address public deployer = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint64 public constant FUJI_SELECTOR = 14767482510784806043;
    uint64 public constant ARB_SEPOLIA_SELECTOR = 3478487238524512106;

    string public constant TOKEN_URI =
        '{"name":"CrossChain Explorer #1","description":"Test NFT","image":"https://example.com/1.png"}';

    function setUp() public {

        router = new MockRouter();
        linkToken = new MockLINK();

        nft = new CrossChainNFT("CrossChain Explorer", "CCXNFT");
        bridge = new TestBridge(
            address(router),
            address(linkToken),
            address(nft)
        );
        nft.setBridge(address(bridge));

        peerRouter = new MockRouter();
        peerNft = new CrossChainNFT("CrossChain Explorer", "CCXNFT");
        peerBridge = new TestBridge(
            address(peerRouter),
            address(linkToken),
            address(peerNft)
        );
        peerNft.setBridge(address(peerBridge));

        bridge.setTrustedBridge(ARB_SEPOLIA_SELECTOR, address(peerBridge));
        peerBridge.setTrustedBridge(FUJI_SELECTOR, address(bridge));

        nft.ownerMint(deployer, 1, TOKEN_URI);

        linkToken.mint(address(bridge), 10 ether);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function test_NFT_InitialState() public view {
        assertEq(nft.name(), "CrossChain Explorer");
        assertEq(nft.symbol(), "CCXNFT");
        assertEq(nft.bridge(), address(bridge));
        assertEq(nft.ownerOf(1), deployer);
    }

    function test_NFT_TokenURI() public view {
        string memory uri = nft.tokenURI(1);
        assertEq(uri, TOKEN_URI);
    }

    function test_NFT_Exists() public view {
        assertTrue(nft.exists(1));
        assertFalse(nft.exists(999));
    }

    function test_NFT_OwnerMint() public {
        nft.ownerMint(alice, 2, "ipfs://token2");
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.tokenURI(2), "ipfs://token2");
    }

    function test_NFT_OwnerMint_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.ownerMint(alice, 3, "ipfs://token3");
    }

    function test_NFT_BridgeMint() public {
        vm.prank(address(bridge));
        nft.mint(bob, 10, "ipfs://token10");
        assertEq(nft.ownerOf(10), bob);
    }

    function test_NFT_Mint_RevertIfNotBridge() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainNFT.CallerIsNotBridge.selector,
                alice
            )
        );
        nft.mint(bob, 10, "ipfs://token10");
    }

    function test_NFT_BurnByOwner() public {
        nft.burn(1);
        assertFalse(nft.exists(1));
    }

    function test_NFT_BurnByBridge() public {
        vm.prank(address(bridge));
        nft.burn(1);
        assertFalse(nft.exists(1));
    }

    function test_NFT_Burn_RevertIfNotOwnerOrBridge() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainNFT.CallerIsNotOwnerOfToken.selector,
                alice,
                1
            )
        );
        nft.burn(1);
    }

    function test_NFT_SetBridge() public {
        address newBridge = makeAddr("newBridge");
        nft.setBridge(newBridge);
        assertEq(nft.bridge(), newBridge);
    }

    function test_NFT_SetBridge_RevertZeroAddress() public {
        vm.expectRevert(CrossChainNFT.BridgeAddressZero.selector);
        nft.setBridge(address(0));
    }

    function test_NFT_SetBridge_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setBridge(alice);
    }

    function test_Bridge_InitialState() public view {
        assertEq(address(bridge.nft()), address(nft));
        assertEq(address(bridge.linkToken()), address(linkToken));
        assertTrue(bridge.allowedChains(ARB_SEPOLIA_SELECTOR));
        assertEq(
            bridge.trustedBridges(ARB_SEPOLIA_SELECTOR),
            address(peerBridge)
        );
    }

    function test_Bridge_SetTrustedBridge() public {
        uint64 newSelector = 12345;
        address newPeer = makeAddr("newPeer");

        bridge.setTrustedBridge(newSelector, newPeer);

        assertTrue(bridge.allowedChains(newSelector));
        assertEq(bridge.trustedBridges(newSelector), newPeer);
    }

    function test_Bridge_RemoveChain() public {
        bridge.removeChain(ARB_SEPOLIA_SELECTOR);

        assertFalse(bridge.allowedChains(ARB_SEPOLIA_SELECTOR));
        assertEq(bridge.trustedBridges(ARB_SEPOLIA_SELECTOR), address(0));
    }

    function test_Bridge_SetTrustedBridge_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        bridge.setTrustedBridge(12345, alice);
    }

    function test_SendNFT_Success() public {
        bytes32 messageId = bridge.sendNFT(ARB_SEPOLIA_SELECTOR, bob, 1);

        assertFalse(nft.exists(1));

        assertTrue(messageId != bytes32(0));
    }

    function test_SendNFT_EmitsEvent() public {

        bytes32 messageId = bridge.sendNFT(ARB_SEPOLIA_SELECTOR, bob, 1);
        assertTrue(messageId != bytes32(0));
    }

    function test_SendNFT_RevertIfChainNotAllowed() public {
        uint64 badChain = 99999;

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPNFTBridge.ChainNotAllowed.selector,
                badChain
            )
        );
        bridge.sendNFT(badChain, bob, 1);
    }

    function test_SendNFT_RevertIfNotTokenOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPNFTBridge.CallerDoesNotOwnToken.selector,
                alice,
                1
            )
        );
        bridge.sendNFT(ARB_SEPOLIA_SELECTOR, bob, 1);
    }

    function test_SendNFT_RevertIfReceiverIsZero() public {
        vm.expectRevert(CCIPNFTBridge.InvalidReceiverAddress.selector);
        bridge.sendNFT(ARB_SEPOLIA_SELECTOR, address(0), 1);
    }

    function test_SendNFT_RevertIfInsufficientLink() public {

        CrossChainNFT nft2 = new CrossChainNFT("Test", "TST");
        TestBridge bridge2 = new TestBridge(
            address(router),
            address(linkToken),
            address(nft2)
        );
        nft2.setBridge(address(bridge2));
        bridge2.setTrustedBridge(ARB_SEPOLIA_SELECTOR, address(peerBridge));
        nft2.ownerMint(deployer, 1, TOKEN_URI);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPNFTBridge.InsufficientLinkBalance.selector,
                router.MOCK_FEE(),
                0
            )
        );
        bridge2.sendNFT(ARB_SEPOLIA_SELECTOR, bob, 1);
    }

    function test_CcipReceive_MintsNFT() public {

        bytes memory payload = abi.encode(alice, uint256(42), "ipfs://token42");

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("test-message-1"),
            sourceChainSelector: FUJI_SELECTOR,
            sender: abi.encode(address(bridge)),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        peerBridge.testCcipReceive(message);

        assertEq(peerNft.ownerOf(42), alice);
        assertEq(peerNft.tokenURI(42), "ipfs://token42");
    }

    function test_CcipReceive_IdempotentMinting() public {
        bytes memory payload = abi.encode(alice, uint256(42), "ipfs://token42");

        Client.Any2EVMMessage memory message1 = Client.Any2EVMMessage({
            messageId: keccak256("msg-1"),
            sourceChainSelector: FUJI_SELECTOR,
            sender: abi.encode(address(bridge)),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        peerBridge.testCcipReceive(message1);
        assertEq(peerNft.ownerOf(42), alice);

        Client.Any2EVMMessage memory message2 = Client.Any2EVMMessage({
            messageId: keccak256("msg-2"),
            sourceChainSelector: FUJI_SELECTOR,
            sender: abi.encode(address(bridge)),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        peerBridge.testCcipReceive(message2);
        assertEq(peerNft.ownerOf(42), alice);
    }

    function test_CcipReceive_RevertIfChainNotAllowed() public {
        bytes memory payload = abi.encode(alice, uint256(42), "ipfs://token42");
        uint64 unknownChain = 99999;

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("bad-chain"),
            sourceChainSelector: unknownChain,
            sender: abi.encode(address(bridge)),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPNFTBridge.ChainNotAllowed.selector,
                unknownChain
            )
        );
        peerBridge.testCcipReceive(message);
    }

    function test_CcipReceive_RevertIfSenderNotTrusted() public {
        bytes memory payload = abi.encode(alice, uint256(42), "ipfs://token42");
        address fakeSender = makeAddr("fakeBridge");

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("bad-sender"),
            sourceChainSelector: FUJI_SELECTOR,
            sender: abi.encode(fakeSender),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPNFTBridge.SenderNotTrusted.selector,
                FUJI_SELECTOR,
                fakeSender
            )
        );
        peerBridge.testCcipReceive(message);
    }

    function test_CcipReceive_RevertIfMessageAlreadyProcessed() public {
        bytes memory payload = abi.encode(alice, uint256(42), "ipfs://token42");
        bytes32 msgId = keccak256("replay-msg");

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: msgId,
            sourceChainSelector: FUJI_SELECTOR,
            sender: abi.encode(address(bridge)),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        peerBridge.testCcipReceive(message);

        vm.prank(address(peerBridge));
        peerNft.burn(42);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPNFTBridge.MessageAlreadyProcessed.selector,
                msgId
            )
        );
        peerBridge.testCcipReceive(message);
    }

    function test_EstimateTransferCost() public view {
        uint256 fee = bridge.estimateTransferCost(
            ARB_SEPOLIA_SELECTOR,
            bob,
            1,
            TOKEN_URI
        );
        assertEq(fee, router.MOCK_FEE());
    }

    function test_WithdrawLink() public {
        uint256 balanceBefore = linkToken.balanceOf(deployer);
        bridge.withdrawLink(deployer, 1 ether);
        uint256 balanceAfter = linkToken.balanceOf(deployer);
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    function test_WithdrawLink_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        bridge.withdrawLink(alice, 1 ether);
    }

    function test_E2E_BurnOnSourceMintOnDest() public {

        assertTrue(nft.exists(1));
        assertEq(nft.ownerOf(1), deployer);

        bytes32 messageId = bridge.sendNFT(ARB_SEPOLIA_SELECTOR, alice, 1);
        assertTrue(messageId != bytes32(0));

        assertFalse(nft.exists(1));

        bytes memory payload = abi.encode(alice, uint256(1), TOKEN_URI);
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: FUJI_SELECTOR,
            sender: abi.encode(address(bridge)),
            data: payload,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        peerBridge.testCcipReceive(message);

        assertTrue(peerNft.exists(1));
        assertEq(peerNft.ownerOf(1), alice);
        assertEq(peerNft.tokenURI(1), TOKEN_URI);
    }
}
