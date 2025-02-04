// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Base_Test} from "../../Base.t.sol";
import {Vault} from "../../../src/protocol/Vault.sol";
import {IERC20} from "../../../src/protocol/Guard.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {GuardBase} from "../../../src/protocol/GuardBase.sol";

import {Guard} from "../../../src/protocol/Guard.sol";
import {VaultGuardianGovernor} from "../../../src/dao/VaultGuardianGovernor.sol";
import {VaultGuardianToken} from "../../../src/dao/VaultGuardianToken.sol";
import {console} from "forge-std/console.sol";

contract GuardBaseTest is Base_Test {
    address public guardian = makeAddr("guardian");
    address public user = makeAddr("user");

    Vault public wethVault;
    Vault public usdcVault;
    Vault public linkVault;

    uint256 guardianAndDaoCut;
    uint256 stakePrice;
    uint256 mintAmount = 100 ether;

    // 500 hold, 250 uniswap, 250 aave
    AllocationData allocationData = AllocationData(500, 250, 250);
    AllocationData newAllocationData = AllocationData(0, 500, 500);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event GuardianAdded(address guardianAddress, IERC20 token);
    event GaurdianRemoved(address guardianAddress, IERC20 token);
    event InvestedInGuardian(address guardianAddress, IERC20 token, uint256 amount);
    event DinvestedFromGuardian(address guardianAddress, IERC20 token, uint256 amount);
    event GuardianUpdatedHoldingAllocation(address guardianAddress, IERC20 token);

    function setUp() public override {
        Base_Test.setUp();
        guardianAndDaoCut = guard.getGuardianAndDaoCut();
        stakePrice = guard.getGuardianStakePrice();
    }

    function testDefaultsToNonFork() public view {
        assert(block.chainid != 1);
    }

    function testSetupAddsTokensAndPools() public {
        assertEq(guard.isApprovedToken(usdcAddress), true);
        assertEq(guard.isApprovedToken(linkAddress), true);
        assertEq(guard.isApprovedToken(wethAddress), true);

        assertEq(address(guard.getWeth()), wethAddress);
        assertEq(address(guard.getTokenOne()), usdcAddress);
        assertEq(address(guard.getTokenTwo()), linkAddress);

        assertEq(guard.getAavePool(), aavePool);
        assertEq(guard.getUniswapV2Router(), uniswapRouter);
    }

    function testBecomeGuardian() public {
        weth.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        weth.approve(address(guard), mintAmount);
        address wethVault2 = guard.becomeGuardian(allocationData);
        vm.stopPrank();

        assertEq(address(guard.getVaultFromGuardianAndToken(guardian, weth)), wethVault2);
    }

    function testBecomeGuardianMovesStakePrice() public {
        weth.mint(mintAmount, guardian);

        vm.startPrank(guardian);
        uint256 wethBalanceBefore = weth.balanceOf(address(guardian));
        weth.approve(address(guard), mintAmount);
        guard.becomeGuardian(allocationData);
        vm.stopPrank();

        uint256 wethBalanceAfter = weth.balanceOf(address(guardian));
        assertEq(wethBalanceBefore - wethBalanceAfter, guard.getGuardianStakePrice());
    }

    function testBecomeGuardianEmitsEvent() public {
        weth.mint(mintAmount, guardian);

        vm.startPrank(guardian);
        weth.approve(address(guard), mintAmount);
        vm.expectEmit(false, false, false, true, address(guard));
        emit GuardianAdded(guardian, weth);
        guard.becomeGuardian(allocationData);
        vm.stopPrank();
    }

    function testCantBecomeTokenGuardianWithoutBeingAWethGuardian() public {
        usdc.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        usdc.approve(address(guard), mintAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                GuardBase.GuardBase__NotAGuardian.selector, guardian, address(weth)
            )
        );
        guard.becomeTokenGuardian(allocationData, usdc);
        vm.stopPrank();
    }

   
    function testUpdatedHoldingAllocationEmitsEvent() public hasGuardian {
        vm.startPrank(guardian);
        vm.expectEmit(false, false, false, true, address(guard));
        emit GuardianUpdatedHoldingAllocation(guardian, weth);
        guard.updateHoldingAllocation(weth, newAllocationData);
        vm.stopPrank();
    }

    function testOnlyGuardianCanUpdateHoldingAllocation() public hasGuardian {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(GuardBase.GuardBase__NotAGuardian.selector, user, weth)
        );
        guard.updateHoldingAllocation(weth, newAllocationData);
        vm.stopPrank();
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

    // we need uniswapV2 and aaveV3 pool to test these following two function.
    // function testQuitGuardian() public hasGuardian {
    //     vm.startPrank(guardian);
    //     wethVault.approve(address(guard), mintAmount);
    //     guard.quitGuardian();
        
    //     vm.stopPrank();

    //     assertEq(address(guard.getVaultFromGuardianAndToken(guardian, weth)), address(0));
    // }

    // function testQuitGuardianEmitsEvent() public hasGuardian {
    //     vm.startPrank(guardian);
    //     wethVault.approve(address(guard), mintAmount);
    //     vm.expectEmit(false, false, false, true, address(guard));
    //     emit GaurdianRemoved(guardian, weth);
    //     guard.quitGuardian();
    //     vm.stopPrank();
    // }

    function testBecomeTokenGuardian() public hasGuardian {
        usdc.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        usdc.approve(address(guard), mintAmount);
        address tokenVault = guard.becomeTokenGuardian(allocationData, usdc);
        usdcVault = Vault(tokenVault);
        vm.stopPrank();

        assertEq(address(guard.getVaultFromGuardianAndToken(guardian, usdc)), tokenVault);
    }

    function testBecomeTokenGuardianOnlyApprovedTokens() public hasGuardian {
        ERC20Mock mockToken = new ERC20Mock();
        mockToken.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        mockToken.approve(address(guard), mintAmount);

        vm.expectRevert(
            abi.encodeWithSelector(GuardBase.GuardBase__NotApprovedToken.selector, address(mockToken))
        );
        guard.becomeTokenGuardian(allocationData, mockToken);
        vm.stopPrank();
    }

    function testBecomeTokenGuardianTokenOneName() public hasGuardian {
        usdc.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        usdc.approve(address(guard), mintAmount);
        address tokenVault = guard.becomeTokenGuardian(allocationData, usdc);
        usdcVault = Vault(tokenVault);
        vm.stopPrank();

        assertEq(usdcVault.name(), guard.TOKEN_ONE_VAULT_NAME());
        assertEq(usdcVault.symbol(), guard.TOKEN_ONE_VAULT_SYMBOL());
    }

    function testBecomeTokenGuardianTokenTwoNameEmitsEvent() public hasGuardian {
        link.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        link.approve(address(guard), mintAmount);

        vm.expectEmit(false, false, false, true, address(guard));
        emit GuardianAdded(guardian, link);
        guard.becomeTokenGuardian(allocationData, link);
        vm.stopPrank();
    }

    modifier hasTokenGuardian() {
        usdc.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        usdc.approve(address(guard), mintAmount);
        address tokenVault = guard.becomeTokenGuardian(allocationData, usdc);
        usdcVault = Vault(tokenVault);
        vm.stopPrank();
        _;
    }
    // we need uniswapV2 and aaveV3 pool to test these following two function.
    // function testCantQuitWethGuardianWithTokens() public hasGuardian hasTokenGuardian {
    //     vm.startPrank(guardian);
    //     usdcVault.approve(address(Guard), mintAmount);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(GuardBase.GuardBase__CantQuitWethWithThisFunction.selector)
    //     );
    //     Guard.quitGuardian(weth);
    //     vm.stopPrank();
    // }

    // function testCantQuitWethGuardianWithTokenQuit() public hasGuardian {
    //     vm.startPrank(guardian);
    //     wethVault.approve(address(Guard), mintAmount);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(GuardBase.GuardBase__CantQuitWethWithThisFunction.selector)
    //     );
    //     Guard.quitGuardian(weth);
    //     vm.stopPrank();
    // }

    function testCantQuitWethWithOtherTokens() public hasGuardian hasTokenGuardian {
        vm.startPrank(guardian);
        usdcVault.approve(address(guard), mintAmount);
        vm.expectRevert(
            abi.encodeWithSelector(GuardBase.GuardBase__CantQuitWethWithThisFunction.selector)
        );
        guard.quitGuardian();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetVault() public hasGuardian hasTokenGuardian {
        assertEq(address(guard.getVaultFromGuardianAndToken(guardian, weth)), address(wethVault));
        assertEq(address(guard.getVaultFromGuardianAndToken(guardian, usdc)), address(usdcVault));
    }

    function testIsApprovedToken() public {
        assertEq(guard.isApprovedToken(usdcAddress), true);
        assertEq(guard.isApprovedToken(linkAddress), true);
        assertEq(guard.isApprovedToken(wethAddress), true);
    }

    function testIsNotApprovedToken() public {
        ERC20Mock mock = new ERC20Mock();
        assertEq(guard.isApprovedToken(address(mock)), false);
    }

    function testGetAavePool() public {
        assertEq(guard.getAavePool(), aavePool);
    }

    function testGetUniswapV2Router() public {
        assertEq(guard.getUniswapV2Router(), uniswapRouter);
    }

    function testGetGuardianStakePrice() public {
        assertEq(guard.getGuardianStakePrice(), stakePrice);
    }

    function testGetGuardianDaoAndCut() public {
        assertEq(guard.getGuardianAndDaoCut(), guardianAndDaoCut);
    }
}
