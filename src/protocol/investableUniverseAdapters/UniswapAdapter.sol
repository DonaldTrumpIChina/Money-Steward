// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IUniswapV2Router01} from "../../vendor/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "../../vendor/IUniswapV2Factory.sol";
import {AStaticUSDCData, IERC20} from "../../abstract/AStaticUSDCData.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapAdapter is AStaticUSDCData {
    error UniswapAdapter__TransferFailed();

    using SafeERC20 for IERC20;

    IUniswapV2Router01 internal immutable i_uniswapRouter;
    IUniswapV2Factory internal immutable i_uniswapFactory;

    address[] private s_pathArray;

    event UniswapInvested(uint256 tokenAmount, uint256 wethAmount, uint256 liquidity);
    event UniswapDivested(uint256 tokenAmount, uint256 wethAmount);

    constructor(address uniswapRouter, address weth, address tokenOne) AStaticUSDCData(weth, tokenOne) {
        i_uniswapRouter = IUniswapV2Router01(uniswapRouter);
        i_uniswapFactory = IUniswapV2Factory(i_uniswapRouter.factory());
    }

    function _uniswapInvest(IERC20 token, uint256 amount) internal {
        IERC20 counterPartyToken = token == i_weth ? i_tokenOne : i_weth;
        uint256 amountOfTokenToSwap = amount / 2;
        s_pathArray = [address(token), address(counterPartyToken)];

        bool succ = token.approve(address(i_uniswapRouter), amountOfTokenToSwap);
        if (!succ) {
            revert UniswapAdapter__TransferFailed();
        }
        uint256[] memory amounts = i_uniswapRouter.swapExactTokensForTokens({
            amountIn: amountOfTokenToSwap,
            amountOutMin: 0,
            path: s_pathArray,
            to: address(this),
            deadline: block.timestamp
        });

        succ = counterPartyToken.approve(address(i_uniswapRouter), amounts[1]);
        if (!succ) {
            revert UniswapAdapter__TransferFailed();
        }
        //audit: if amounts[0] is fee, next line is duplicate.
        succ = token.approve(address(i_uniswapRouter), amountOfTokenToSwap + amounts[0]);
        if (!succ) {
            revert UniswapAdapter__TransferFailed();
        }

        // amounts[1] should be the WETH amount we got back
        (uint256 tokenAmount, uint256 counterPartyTokenAmount, uint256 liquidity) = i_uniswapRouter.addLiquidity({
            tokenA: address(token),
            tokenB: address(counterPartyToken),
        //audit: if amounts[0] is fee, should be amountOfTokenToSwap - amounts[0].
            amountADesired: amountOfTokenToSwap + amounts[0],
            amountBDesired: amounts[1],
            amountAMin: 0,
            amountBMin: 0,
            to: address(this),
            deadline: block.timestamp
        });
        emit UniswapInvested(tokenAmount, counterPartyTokenAmount, liquidity);
    }

    /**
     * @notice The LP tokens of the added liquidity are burnt
     * @notice The other token (which isn't the vault's underlying asset token) is swapped for the vault's underlying asset token
     * @param token The vault's underlying asset token
     * @param liquidityAmount The amount of LP tokens to burn
     */
    function _uniswapDivest(IERC20 token, uint256 liquidityAmount) internal returns (uint256 amountOfAssetReturned) {
        IERC20 counterPartyToken = token == i_weth ? i_tokenOne : i_weth;

        (uint256 tokenAmount, uint256 counterPartyTokenAmount) = i_uniswapRouter.removeLiquidity({
            tokenA: address(token),
            tokenB: address(counterPartyToken),
            liquidity: liquidityAmount,
            amountAMin: 0,
            amountBMin: 0,
            to: address(this),
            deadline: block.timestamp
        });
        s_pathArray = [address(counterPartyToken), address(token)];
        // AddLiquidity we change a half of vaultShare underlying token to other,
        // now we swap the other token to vaultShare underlying token.
        uint256[] memory amounts = i_uniswapRouter.swapExactTokensForTokens({
            amountIn: counterPartyTokenAmount,
            amountOutMin: 0,
            path: s_pathArray,
            to: address(this),
            deadline: block.timestamp
        });
        emit UniswapDivested(tokenAmount, amounts[1]);
        //audit: we should make amount[1] plus tokenAmount, which equal total
        //amount of underlying token we withdraw from uniswap.
        amountOfAssetReturned = amounts[1];
    }
    // slither-disable-end reentrancy-benign
    // slither-disable-end reentrancy-events
    // slither-disable-end reentrancy-eth
}
