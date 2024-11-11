// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TTK") {
        _mint(msg.sender, 1000000 * 10 ** 18);  // 1,000,000 tokens
    }
}
