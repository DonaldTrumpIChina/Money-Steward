// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Base_Test} from "../../Base.t.sol";
import {Vault} from "../../../src/protocol/Vault.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Guard, IERC20} from "../../../src/protocol/Guard.sol";

contract GuardTest is Base_Test {
    address user = makeAddr("user");

    uint256 mintAmount = 100 ether;

    function setUp() public override {
        Base_Test.setUp();
    }

    function testUpdateGuardianStakePrice() public {
        uint256 newStakePrice = 10;
        vm.prank(guard.owner());
        guard.updateGuardianStakePrice(newStakePrice);
        assertEq(guard.getGuardianStakePrice(), newStakePrice);
    }

    function testUpdateGuardianStakePriceOnlyOwner() public {
        uint256 newStakePrice = 10;
        vm.prank(user);
        vm.expectRevert();
        guard.updateGuardianStakePrice(newStakePrice);
    }

    function testUpdateGuardianAndDaoCut() public {
        uint256 newGuardianAndDaoCut = 10;
        vm.prank(guard.owner());
        guard.updateGuardianAndDaoCut(newGuardianAndDaoCut);
        assertEq(guard.getGuardianAndDaoCut(), newGuardianAndDaoCut);
    }

    function testUpdateGuardianAndDaoCutOnlyOwner() public {
        uint256 newGuardianAndDaoCut = 10;
        vm.prank(user);
        vm.expectRevert();
        guard.updateGuardianAndDaoCut(newGuardianAndDaoCut);
    }

    function testSweepErc20s() public {
        ERC20Mock mock = new ERC20Mock();
        mock.mint(mintAmount, msg.sender);
        vm.prank(msg.sender);
        mock.transfer(address(guard), mintAmount);

        uint256 balanceBefore = mock.balanceOf(address(vaultGuardianGovernor));

        vm.prank(guard.owner());
        guard.sweepErc20s(IERC20(mock));

        uint256 balanceAfter = mock.balanceOf(address(vaultGuardianGovernor));

        assertEq(balanceAfter - balanceBefore, mintAmount);
    }
}
