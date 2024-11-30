// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {CoinToken} from "../src/CoinToken.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployCoinToken is Script {
    HelperConfig helperConfig;

    function run() external returns (CoinToken, HelperConfig.NetworkConfig memory) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        vm.startBroadcast(0x05D6320A78faE08aC2f06865C85076a99a8E7468); // msg.sender will be owner address
        CoinToken coinToken =
            new CoinToken(config.lqFee, config.devFee, config.marketingFee, config.burnFee, config.charityFee);
        vm.stopBroadcast();
        return (coinToken, config);
    }
}
