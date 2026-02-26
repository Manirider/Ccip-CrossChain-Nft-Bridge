pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CrossChainNFT} from "../src/CrossChainNFT.sol";
import {CCIPNFTBridge} from "../src/CCIPNFTBridge.sol";

contract DeployArbitrumSepolia is Script {
    function run() external {

        address ccipRouter = vm.envAddress("CCIP_ROUTER_ARBITRUM_SEPOLIA");
        address linkToken  = vm.envAddress("LINK_TOKEN_ARBITRUM_SEPOLIA");

        vm.startBroadcast();

        CrossChainNFT nft = new CrossChainNFT("CrossChain Explorer", "CCXNFT");
        console2.log("CrossChainNFT deployed at:", address(nft));

        CCIPNFTBridge bridge = new CCIPNFTBridge(ccipRouter, linkToken, address(nft));
        console2.log("CCIPNFTBridge deployed at:", address(bridge));

        nft.setBridge(address(bridge));
        console2.log("Bridge set in NFT contract");

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Arbitrum Sepolia Deployment Summary ===");
        console2.log("NFT Contract:    ", address(nft));
        console2.log("Bridge Contract: ", address(bridge));
        console2.log("CCIP Router:     ", ccipRouter);
        console2.log("LINK Token:      ", linkToken);
    }
}
