// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GuardBase, IERC20, SafeERC20} from "./GuardBase.sol";


contract Guard is Ownable, GuardBase {
    using SafeERC20 for IERC20;
   error Guard__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Guard__UpdatedStakePrice(uint256 oldStakePrice, uint256 newStakePrice);
    event Guard__UpdatedFee(uint256 oldFee, uint256 newFee);
    event Guard__SweptTokens(address asset);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(
        address aavePool,
        address uniswapV2Router,
        address weth,
        address tokenOne,
        address tokenTwo,
        address GuardToken
    )
        Ownable(msg.sender)
        GuardBase(aavePool, uniswapV2Router, weth, tokenOne, tokenTwo, GuardToken)
    {}

        function updateGuardianStakePrice(uint256 newStakePrice) external onlyOwner {
        s_guardianStakePrice = newStakePrice;
        emit Guard__UpdatedStakePrice(s_guardianStakePrice, newStakePrice);
    }

   
    function updateGuardianAndDaoCut(uint256 newCut) external onlyOwner {
        s_guardianAndDaoCut = newCut;
        //audit: emit a wrong event, need add a new event.
        emit Guard__UpdatedStakePrice(s_guardianAndDaoCut, newCut);
    }

    /* scoop：抢购
     * @notice Any excess ERC20s can be scooped up by the DAO. 
     * @notice This is often just little bits left around from swapping or rounding errors
     * @dev Since this is owned by the DAO, the funds will always go to the DAO. 
     * @param asset The ERC20 to sweep
     */
    function sweepErc20s(IERC20 asset) external {
        uint256 amount = asset.balanceOf(address(this));
        emit Guard__SweptTokens(address(asset));
        asset.safeTransfer(owner(), amount);
    }
}
