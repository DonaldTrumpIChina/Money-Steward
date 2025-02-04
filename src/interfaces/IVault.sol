// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVaultData} from "./IVaultData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault is IERC4626, IVaultData {
    struct ConstructorData {
        IERC20 asset;
        string vaultName;
        string vaultSymbol;
        address guardian;
        AllocationData allocationData;
        address aavePool;
        address uniswapRouter;
        uint256 guardianAndDaoCut;
        address guard;
        address weth;
        address usdc;
    }

    function updateHoldingAllocation(AllocationData memory tokenAllocationData) external;

    function setNotActive() external;

    function divest() external;
}
