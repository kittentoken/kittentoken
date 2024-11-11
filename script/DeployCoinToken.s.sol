// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Script} from "forge-std/Script.sol";
import {CoinToken} from "../src/CoinToken.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployCoinToken is Script {

    HelperConfig helperConfig;

    function run() external returns (CoinToken, HelperConfig.NetworkConfig memory) {
            helperConfig = new HelperConfig();
            HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
            vm.startBroadcast(config.initialOwner);
            CoinToken coinToken = new CoinToken(
                config.initialOwner,
                config.tokenSupply,
                config.routerAddress,
                config.lqFee,
                config.devFee,
                config.marketingFee,
                config.burnFee,
                config.charityFee,
                config.devWallet,
                config.marketingWallet,
                config.charityWallet
            );
            vm.stopBroadcast();
            return (coinToken, config);
    }
}
