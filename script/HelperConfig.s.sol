// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {console} from "forge-std/console.sol";

contract HelperConfig {
    uint256 private constant tokenSupply     = 1000000000 * 10 ** 18;
    uint256 private constant maxTxAmount     = tokenSupply / 100;

    struct NetworkConfig {
        address initialOwner;
        uint256 tokenSupply;
        address routerAddress;
        uint8   lqFee;
        uint8   devFee;
        uint8   marketingFee;
        uint8   burnFee;
        uint8   charityFee;
        uint256 maxTxAmount;
        address devWallet;
        address marketingWallet;
        address charityWallet;
    }

    NetworkConfig public activeNetworkConfig;

    error UnknownChain();

    constructor() {
        if (block.chainid == 11155111) { // Sepolia
            console.log('Using sepolia chain');
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) { // Mainnet
            console.log('Using mainnet chain');
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == 31337) { // Anvil
            console.log('Using anvil chain');
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert UnknownChain();
        }
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            initialOwner  :0x05D6320A78faE08aC2f06865C85076a99a8E7468,
            tokenSupply   :tokenSupply,
            routerAddress :0x8FFCFA0F77a391eD53e266F2E094170Fa479520d, //or 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
            lqFee          :10,
            devFee         :10,
            marketingFee   :10,
            burnFee        :5,
            charityFee     :15,
            maxTxAmount   :maxTxAmount,
            devWallet:address(0),
            marketingWallet:address(0),
            charityWallet:address(0)
        });
    }

    function getMainnetEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            initialOwner   :0x05D6320A78faE08aC2f06865C85076a99a8E7468,
            tokenSupply    :tokenSupply,
            routerAddress  :0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            lqFee          :10,
            devFee         :10,
            marketingFee   :10,
            burnFee        :5,
            charityFee     :15,
            maxTxAmount    :maxTxAmount,
            devWallet      :0x5AF825DFD9C2B6c61748b85974A9F175B35521fA,
            marketingWallet:0xE15910F41FC6e2351A2b914B627C6bE2a9FC4af2,
            charityWallet  :0x09F0B837624B16c709EFce38EeA23BAB872FCD9e
        });
    }

    function getOrCreateAnvilEthConfig() private view returns (NetworkConfig memory anvilNetworkConfig) {
        if (activeNetworkConfig.initialOwner!= address(0)) {
            return activeNetworkConfig;
        } else {
            // Create a new configuration for Anvil
            return NetworkConfig({
                initialOwner   :0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                tokenSupply    :tokenSupply,
                routerAddress  :address(0),
                lqFee         :30,
                devFee        :10,
                marketingFee  :10,
                burnFee       :5,
                charityFee    :1,
                maxTxAmount    :maxTxAmount,
                devWallet:address(0),
                marketingWallet:address(0),
                charityWallet:address(0)
            });
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

}