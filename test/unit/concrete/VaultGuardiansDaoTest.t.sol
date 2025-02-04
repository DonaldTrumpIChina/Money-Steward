// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Base_Test} from "../../Base.t.sol";
import {Vault} from "../../../src/protocol/Vault.sol";
import {IERC20} from "../../../src/protocol/Guard.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {GuardBase} from "../../../src/protocol/GuardBase.sol";

contract GuardDaoTest is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testDaoSetupIsCorrect() public {
        assertEq(vaultGuardianToken.balanceOf(msg.sender), 0);
        assertEq(vaultGuardianToken.owner(), address(guard));
    }
}
