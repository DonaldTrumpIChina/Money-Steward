
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vault} from "./Vault.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault, IVaultData} from "../interfaces/IVault.sol";
import {AStaticTokenData, IERC20} from "../abstract/AStaticTokenData.sol";
import {VaultGuardianToken} from "../dao/VaultGuardianToken.sol";


contract GuardBase is AStaticTokenData, IVaultData {
    using SafeERC20 for IERC20;
    error GuardBase__NotEnoughWeth(uint256 amount, uint256 amountNeeded);
    error GuardBase__NotAGuardian(address guardianAddress, IERC20 token);
    error GuardBase__CantQuitGuardianWithNonWethVaults(address guardianAddress);
    error GuardBase__CantQuitWethWithThisFunction();
    error GuardBase__TransferFailed();
    error GuardBase__FeeTooSmall(uint256 fee, uint256 requiredFee);
    error GuardBase__NotApprovedToken(address token);
   /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address private immutable i_aavePool;
    address private immutable i_uniswapV2Router;
    //治理币
    VaultGuardianToken private immutable i_vgToken;

    uint256 private constant GUARDIAN_FEE = 0.1 ether;

    // DAO updatable values
    uint256 internal s_guardianStakePrice = 10 ether;
    uint256 internal s_guardianAndDaoCut = 1000;

    // The guardian's address mapped to the asset, mapped to the allocation data
    mapping(address guardianAddress => mapping(IERC20 asset => IVault Vault)) private s_guardians;
    mapping(address token => bool approved) private s_isApprovedToken;
    mapping(address => uint256) public guardianVgToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event GuardianAdded(address guardianAddress, IERC20 token);
    event GaurdianRemoved(address guardianAddress, IERC20 token);
    //audit: not used
    event InvestedInGuardian(address guardianAddress, IERC20 token, uint256 amount);
    //audit :not used
    event DinvestedFromGuardian(address guardianAddress, IERC20 token, uint256 amount);
    event GuardianUpdatedHoldingAllocation(address guardianAddress, IERC20 token);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    //audit-done
    modifier onlyGuardian(IERC20 token) {
        if (address(s_guardians[msg.sender][token]) == address(0)) {
            revert GuardBase__NotAGuardian(msg.sender, token);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(
        address aavePool,
        address uniswapV2Router,
        address weth,
        address tokenOne, // USDC
        address tokenTwo, // LINK
        address vgToken
    ) AStaticTokenData(weth, tokenOne, tokenTwo) {
        s_isApprovedToken[weth] = true;
        s_isApprovedToken[tokenOne] = true;
        s_isApprovedToken[tokenTwo] = true;

        i_aavePool = aavePool;
        i_uniswapV2Router = uniswapV2Router;
        i_vgToken = VaultGuardianToken(vgToken);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
       function becomeGuardian(AllocationData memory wethAllocationData) external returns (address) {
        Vault wethVault =
        new Vault(IVault.ConstructorData({
            asset: i_weth,
            vaultName: WETH_VAULT_NAME,
            vaultSymbol: WETH_VAULT_SYMBOL,
            guardian: msg.sender,
            allocationData: wethAllocationData,
            aavePool: i_aavePool,
            uniswapRouter: i_uniswapV2Router,
            guardianAndDaoCut: s_guardianAndDaoCut,
            guard: address(this),
            weth: address(i_weth),
            usdc: address(i_tokenOne)
        }));
        return _becomeTokenGuardian(i_weth, wethVault);
    }

       function becomeTokenGuardian(AllocationData memory allocationData, IERC20 token)
        external
        onlyGuardian(i_weth)
        returns (address)
    {
        //slither-disable-next-line uninitialized-local
        Vault tokenVault;
        // i_tokenOne is USDC, i_tokenTwo is LINK
        if (address(token) == address(i_tokenOne)) {
            tokenVault =
            new Vault(IVault.ConstructorData({
                asset: token,
                vaultName: TOKEN_ONE_VAULT_NAME,
                vaultSymbol: TOKEN_ONE_VAULT_SYMBOL,
                guardian: msg.sender,
                allocationData: allocationData,
                aavePool: i_aavePool,
                uniswapRouter: i_uniswapV2Router,
                guardianAndDaoCut: s_guardianAndDaoCut,
                guard: address(this),
                weth: address(i_weth),
                usdc: address(i_tokenOne)
            }));
        } else if (address(token) == address(i_tokenTwo)) {
            tokenVault =
            new Vault(IVault.ConstructorData({
                asset: token,
                vaultName: TOKEN_TWO_VAULT_NAME,
                vaultSymbol: TOKEN_TWO_VAULT_SYMBOL,
                guardian: msg.sender,
                allocationData: allocationData,
                aavePool: i_aavePool,
                uniswapRouter: i_uniswapV2Router,
                guardianAndDaoCut: s_guardianAndDaoCut,
                guard: address(this),
                weth: address(i_weth),
                usdc: address(i_tokenOne)
            }));
        } else {
            revert GuardBase__NotApprovedToken(address(token));
        }
        return _becomeTokenGuardian(token, tokenVault);
    }

      function quitGuardian() external onlyGuardian(i_weth) returns (uint256) {
        if (_guardianHasNonWethVaults(msg.sender)) {
           revert GuardBase__CantQuitWethWithThisFunction();
        }
        return _quitGuardian(i_weth);
    }

        function quitGuardian(IERC20 token) external onlyGuardian(token) returns (uint256) {
        if (token == i_weth) {
            revert GuardBase__CantQuitWethWithThisFunction();
        }
        return _quitGuardian(token);
    }

       function updateHoldingAllocation(IERC20 token, AllocationData memory tokenAllocationData)
        external
        onlyGuardian(token)
    {
        emit GuardianUpdatedHoldingAllocation(msg.sender, token);
        s_guardians[msg.sender][token].updateHoldingAllocation(tokenAllocationData);
    }

   
    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
       function _quitGuardian(IERC20 token) private returns (uint256) {
        IVault tokenVault = IVault(s_guardians[msg.sender][token]);
        tokenVault.divest();
        s_guardians[msg.sender][token] = IVault(address(0));
        emit GaurdianRemoved(msg.sender, token);
        i_vgToken.burn(msg.sender, guardianVgToken[msg.sender]);
        tokenVault.setNotActive();
        uint256 maxRedeemable = tokenVault.maxRedeem(msg.sender);
        uint256 numberOfAssetsReturned = tokenVault.redeem(maxRedeemable, msg.sender, msg.sender);
        return numberOfAssetsReturned;
    }

        function _guardianHasNonWethVaults(address guardian) private view returns (bool) {
        if (address(s_guardians[guardian][i_tokenOne]) != address(0)) {
            return true;
        } else {
            return address(s_guardians[guardian][i_tokenTwo]) != address(0);
        }
    }

        function _becomeTokenGuardian(IERC20 token, Vault tokenVault) private returns (address) {
        s_guardians[msg.sender][token] = IVault(address(tokenVault));
        emit GuardianAdded(msg.sender, token);
        i_vgToken.mint(msg.sender, s_guardianStakePrice);
        guardianVgToken[msg.sender] += s_guardianStakePrice;
        token.safeTransferFrom(msg.sender, address(this), s_guardianStakePrice);
        bool succ = token.approve(address(tokenVault), s_guardianStakePrice);
        if (!succ) {
            revert GuardBase__TransferFailed();
        }
        uint256 shares = tokenVault.deposit(s_guardianStakePrice, msg.sender);
        if (shares == 0) {
            revert GuardBase__TransferFailed();
        }
        return address(tokenVault);
    }
   
    /*//////////////////////////////////////////////////////////////
                   EXTERNAL AND PUBLIC VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getVaultFromGuardianAndToken(address guardian, IERC20 token) external view returns (IVault) {
        return s_guardians[guardian][token];
    }

 
    function isApprovedToken(address token) external view returns (bool) {
        return s_isApprovedToken[token];
    }

 
    function getAavePool() external view returns (address) {
        return i_aavePool;
    }

 
    function getUniswapV2Router() external view returns (address) {
        return i_uniswapV2Router;
    }


    function getGuardianStakePrice() external view returns (uint256) {
        return s_guardianStakePrice;
    }

  
    function getGuardianAndDaoCut() external view returns (uint256) {
        return s_guardianAndDaoCut;
    }
}
