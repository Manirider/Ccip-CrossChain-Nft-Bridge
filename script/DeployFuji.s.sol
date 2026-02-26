pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CrossChainNFT} from "../src/CrossChainNFT.sol";
import {CCIPNFTBridge} from "../src/CCIPNFTBridge.sol";

contract DeployFuji is Script {
    function run() external {

        address ccipRouter = vm.envAddress("CCIP_ROUTER_FUJI");
        address linkToken  = vm.envAddress("LINK_TOKEN_FUJI");

        vm.startBroadcast();

        CrossChainNFT nft = new CrossChainNFT("CrossChain Explorer", "CCXNFT");
        console2.log("CrossChainNFT deployed at:", address(nft));

        CCIPNFTBridge bridge = new CCIPNFTBridge(ccipRouter, linkToken, address(nft));
        console2.log("CCIPNFTBridge deployed at:", address(bridge));

        nft.setBridge(address(bridge));
        console2.log("Bridge set in NFT contract");

        string memory tokenURI = '{"name":"CrossChain Explorer #1","description":"A pioneering NFT that travels across blockchains via Chainlink CCIP.","image":"https://ipfs.io/ipfs/QmExampleHash/1.png","attributes":[{"trait_type":"Origin Chain","value":"Avalanche Fuji"},{"trait_type":"Bridge Protocol","value":"Chainlink CCIP"},{"trait_type":"Edition","value":"Genesis"}]}';
        nft.ownerMint(msg.sender, 1, tokenURI);
        console2.log("Token #1 pre-minted to deployer:", msg.sender);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Avalanche Fuji Deployment Summary ===");
        console2.log("NFT Contract:    ", address(nft));
        console2.log("Bridge Contract: ", address(bridge));
        console2.log("CCIP Router:     ", ccipRouter);
        console2.log("LINK Token:      ", linkToken);
        console2.log("Pre-minted Token #1 to:", msg.sender);
    }
}
