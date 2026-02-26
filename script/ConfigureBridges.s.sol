pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CCIPNFTBridge} from "../src/CCIPNFTBridge.sol";

uint64 constant FUJI_CHAIN_SELECTOR = 14767482510784806043;
uint64 constant ARBITRUM_SEPOLIA_CHAIN_SELECTOR = 3478487238524512106;

contract ConfigureFuji is Script {
    function run() external {
        address fujiBridge = vm.envAddress("BRIDGE_FUJI");
        address arbSepoliaBridge = vm.envAddress("BRIDGE_ARBITRUM_SEPOLIA");

        vm.startBroadcast();

        CCIPNFTBridge bridge = CCIPNFTBridge(fujiBridge);
        bridge.setTrustedBridge(ARBITRUM_SEPOLIA_CHAIN_SELECTOR, arbSepoliaBridge);

        console2.log("Fuji bridge configured to trust Arbitrum Sepolia bridge:", arbSepoliaBridge);
        console2.log("Chain selector:", ARBITRUM_SEPOLIA_CHAIN_SELECTOR);

        vm.stopBroadcast();
    }
}

contract ConfigureArbitrumSepolia is Script {
    function run() external {
        address fujiBridge = vm.envAddress("BRIDGE_FUJI");
        address arbSepoliaBridge = vm.envAddress("BRIDGE_ARBITRUM_SEPOLIA");

        vm.startBroadcast();

        CCIPNFTBridge bridge = CCIPNFTBridge(arbSepoliaBridge);
        bridge.setTrustedBridge(FUJI_CHAIN_SELECTOR, fujiBridge);

        console2.log("Arbitrum Sepolia bridge configured to trust Fuji bridge:", fujiBridge);
        console2.log("Chain selector:", FUJI_CHAIN_SELECTOR);

        vm.stopBroadcast();
    }
}
