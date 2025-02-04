// // SPDX-License-Identifier: UNLICENSED
// pragma solidity >=0.8.19 <0.9.0;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import {Vault} from "../../src/protocol/Vault.sol";

// import {Fork_Test} from "./Fork.t.sol";

// contract WethForkTest is Fork_Test {
//     address public guardian = makeAddr("guardian");
//     address public user = makeAddr("user");

//     Vault public wethVault;

//     uint256 guardianAndDaoCut;
//     uint256 stakePrice;
//     uint256 mintAmount = 100 ether;

//     // 500 hold, 250 uniswap, 250 aave
//     AllocationData allocationData = AllocationData(500, 250, 250);
//     AllocationData newAllocationData = AllocationData(0, 500, 500);

//     function setUp() public virtual override {
//         Fork_Test.setUp();
//     }

//     modifier hasGuardian() {
//         weth.mint(mintAmount, guardian);
//         vm.startPrank(guardian);
//         weth.approve(address(Guard), mintAmount);
//         address wethVault = Guard.becomeGuardian(allocationData);
//         wethVault = Vault(wethVault);
//         vm.stopPrank();
//         _;
//     }

//     function testDepositAndWithdraw() public {}
// }
