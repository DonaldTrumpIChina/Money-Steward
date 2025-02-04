// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract AStaticWethData {
     IERC20 internal immutable i_weth;
    string internal constant WETH_VAULT_NAME = "Vault Guardian WETH";
    string internal constant WETH_VAULT_SYMBOL = "vgWETH";

    constructor(address weth) {
        i_weth = IERC20(weth);
    }
    function getWeth() external view returns (IERC20) {
        return i_weth;
    }
}
