// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {console} from "forge-std/console.sol";

contract HelperConfig {
    struct NetworkConfig {
        uint8 lqFee;
        uint8 devFee;
        uint8 marketingFee;
        uint8 burnFee;
        uint8 charityFee;
    }

    NetworkConfig public activeNetworkConfig;

    error UnknownChain();

    constructor() {
        if (block.chainid == 11155111) {
            // Sepolia
            console.log("Using sepolia chain");
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            // Mainnet
            console.log("Using mainnet chain");
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == 56) {
            // BNB
            console.log("Using binance chain");
            activeNetworkConfig = getMainnetBnbConfig();
        } else if (block.chainid == 42161) {
            // Arbitrum
            console.log("Using arbitrum chain");
            activeNetworkConfig = getMainnetArbitrumConfig();
        } else {
            revert UnknownChain();
        }
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({lqFee: 10, devFee: 10, marketingFee: 10, burnFee: 5, charityFee: 15});
    }

    function getMainnetEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({lqFee: 10, devFee: 10, marketingFee: 10, burnFee: 5, charityFee: 15});
    }

    function getMainnetBnbConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({lqFee: 10, devFee: 10, marketingFee: 10, burnFee: 5, charityFee: 15});
    }

    function getMainnetArbitrumConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({lqFee: 10, devFee: 10, marketingFee: 10, burnFee: 5, charityFee: 15});
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
