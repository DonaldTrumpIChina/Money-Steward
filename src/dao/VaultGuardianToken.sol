// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract VaultGuardianToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    constructor() ERC20("VaultGuardianToken", "VGT") ERC20Permit("VaultGuardianToken") Ownable(msg.sender) {}

    // The following functions are overrides required by Solidity.
    /** @notice this is a function to update the balance before
        transfer.
     */  
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address ownerOfNonce) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(ownerOfNonce);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
