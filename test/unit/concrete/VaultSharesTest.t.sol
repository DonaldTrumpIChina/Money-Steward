// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Base_Test} from "../../Base.t.sol";
import {console} from "forge-std/console.sol";
import {Vault} from "../../../src/protocol/Vault.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Vault, IERC20} from "../../../src/protocol/Vault.sol";

import {console} from "forge-std/console.sol";

contract VaultTest is Base_Test {
    uint256 mintAmount = 100 ether;
    address guardian = makeAddr("guardian");
    address user = makeAddr("user");
    AllocationData allocationData = AllocationData(
        500, // hold
        250, // uniswap
        250 // aave
    );
    Vault public wethVault;
    uint256 public defaultGuardianAndDaoCut = 1000;

    AllocationData newAllocationData = AllocationData(
        0, // hold
        500, // uniswap
        500 // aave
    );

    function setUp() public override {
        Base_Test.setUp();
    }

    modifier hasGuardian() {
        weth.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        weth.approve(address(guard), mintAmount);
        address wethVault2 = guard.becomeGuardian(allocationData);
        wethVault = Vault(wethVault2);
        vm.stopPrank();
        _;
    }

    function testIfWecanMint() external hasGuardian{
    }
    function testPreviewDeposite() external hasGuardian{
        uint256 mintAmountr = 1 ether;
        uint256 supply = wethVault.totalSupply();
        uint256 totalAsset = wethVault.totalAssets();
        uint256 res = wethVault.previewDeposit(mintAmountr);
        console.log("res: ", res);
        res =  wethVault.previewRedeem(mintAmountr);
        console.log("res: ", res);
        console.log("supply: ", supply);
        console.log("totalAsset: ", totalAsset);
    }

    function testSetupVault() public hasGuardian {
        assertEq(wethVault.getGuardian(), guardian);
        assertEq(wethVault.getGuardianAndDaoCut(), defaultGuardianAndDaoCut);
        assertEq(wethVault.getGuard(), address(guard));
        assertEq(wethVault.getIsActive(), true);
        assertEq(wethVault.getAaveAToken(), address(awethTokenMock));
        assertEq(
            address(wethVault.getUniswapLiquidtyToken()), uniswapFactoryMock.getPair(address(weth), address(weth))
        );
    }

    function testSetNotActive() public hasGuardian {
        vm.prank(wethVault.getGuard());
        wethVault.setNotActive();
        assertEq(wethVault.getIsActive(), false);
    }

    function testOnlyGuardCanSetNotActive() public hasGuardian {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Vault.Vault__NotVaultGuardianContract.selector));
        wethVault.setNotActive();
    }

    function testOnlyCanSetNotActiveIfActive() public hasGuardian {
        vm.startPrank(wethVault.getGuard());
        wethVault.setNotActive();
        vm.expectRevert(abi.encodeWithSelector(Vault.Vault__NotActive.selector));
        wethVault.setNotActive();
        vm.stopPrank();
    }

    function testUpdateHoldingAllocation() public hasGuardian {
        vm.startPrank(wethVault.getGuard());
        wethVault.updateHoldingAllocation(newAllocationData);
        assertEq(wethVault.getAllocationData().holdAllocation, newAllocationData.holdAllocation);
        assertEq(wethVault.getAllocationData().uniswapAllocation, newAllocationData.uniswapAllocation);
        assertEq(wethVault.getAllocationData().aaveAllocation, newAllocationData.aaveAllocation);
    }

    function testOnlyGuardCanUpdateAllocationData() public hasGuardian {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Vault.Vault__NotVaultGuardianContract.selector));
        wethVault.updateHoldingAllocation(newAllocationData);
    }

    function testOnlyupdateAllocationDataWhenActive() public hasGuardian {
        vm.startPrank(wethVault.getGuard());
        wethVault.setNotActive();
        vm.expectRevert(abi.encodeWithSelector(Vault.Vault__NotActive.selector));
        wethVault.updateHoldingAllocation(newAllocationData);
        vm.stopPrank();
    }

    function testMustUpdateAllocationDataWithCorrectPrecision() public hasGuardian {
        AllocationData memory badAllocationData = AllocationData(0, 200, 500);
        uint256 totalBadAllocationData =
            badAllocationData.holdAllocation + badAllocationData.aaveAllocation + badAllocationData.uniswapAllocation;

        vm.startPrank(wethVault.getGuard());
        vm.expectRevert(
            abi.encodeWithSelector(Vault.Vault__AllocationNot100Percent.selector, totalBadAllocationData)
        );
        wethVault.updateHoldingAllocation(badAllocationData);
        vm.stopPrank();
    }

    function testUserCanDepositFunds() public hasGuardian {
        weth.mint(mintAmount, user);
        vm.startPrank(user);
        weth.approve(address(wethVault), mintAmount);
        wethVault.deposit(mintAmount, user);

        assert(wethVault.balanceOf(user) > 0);
    }

    function testUserDepositsFundsAndDaoAndGuardianGetShares() public hasGuardian {
        uint256 startingGuardianBalance = wethVault.balanceOf(guardian);
        uint256 startingDaoBalance = wethVault.balanceOf(address(guard));

        weth.mint(mintAmount, user);
        vm.startPrank(user);
        console.log(wethVault.totalSupply());
        weth.approve(address(wethVault), mintAmount);
        wethVault.deposit(mintAmount, user);

        assert(wethVault.balanceOf(guardian) > startingGuardianBalance);
        assert(wethVault.balanceOf(address(guard)) > startingDaoBalance);
    }

    modifier userIsInvested() {
        weth.mint(mintAmount, user);
        vm.startPrank(user);
        weth.approve(address(wethVault), mintAmount);
        wethVault.deposit(mintAmount, user);
        vm.stopPrank();
        _;
    }

    function testRebalanceResultsInTheSameOutcome() public hasGuardian userIsInvested {
        uint256 startingUniswapLiquidityTokensBalance =
            IERC20(wethVault.getUniswapLiquidtyToken()).balanceOf(address(wethVault));
        uint256 startingAaveAtokensBalance = IERC20(wethVault.getAaveAToken()).balanceOf(address(wethVault));

        wethVault.rebalanceFunds();

        assertEq(
            IERC20(wethVault.getUniswapLiquidtyToken()).balanceOf(address(wethVault)),
            startingUniswapLiquidityTokensBalance
        );
        assertEq(
            IERC20(wethVault.getAaveAToken()).balanceOf(address(wethVault)), startingAaveAtokensBalance
        );
    }

    function testWithdraw() public hasGuardian userIsInvested {
        uint256 startingBalance = weth.balanceOf(user);
        uint256 startingSharesBalance = wethVault.balanceOf(user);
        uint256 amoutToWithdraw = 1 ether;

        vm.prank(user);
        wethVault.withdraw(amoutToWithdraw, user, user);

        assertEq(weth.balanceOf(user), startingBalance + amoutToWithdraw);
        assert(wethVault.balanceOf(user) < startingSharesBalance);
    }

    function testRedeem() public hasGuardian userIsInvested {
        uint256 startingBalance = weth.balanceOf(user);
        uint256 startingSharesBalance = wethVault.balanceOf(user);
        uint256 amoutToRedeem = 1 ether;

        vm.prank(user);
        wethVault.redeem(amoutToRedeem, user, user);

        assert(weth.balanceOf(user) > startingBalance);
        assertEq(wethVault.balanceOf(user), startingSharesBalance - amoutToRedeem);
    }
}
