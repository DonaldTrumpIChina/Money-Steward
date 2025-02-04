// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Base_Test} from "../../Base.t.sol";
import {Vault} from "../../../src/protocol/Vault.sol";
import {IERC20} from "../../../src/protocol/Guard.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {GuardBase} from "../../../src/protocol/GuardBase.sol";

contract GuardFuzzTest is Base_Test {
    event OwnershipTransferred(address oldOwner, address newOwner);

    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_transferOwner(address newOwner) public {
        vm.assume(newOwner != address(0));

        vm.startPrank(guard.owner());
        guard.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(guard.owner(), newOwner);
    }
}
