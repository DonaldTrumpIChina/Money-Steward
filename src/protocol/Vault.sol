// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626Mock} from "./ERC4626Mock.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IVault, IERC4626} from "../interfaces/IVault.sol";
import {AaveAdapter, IPool} from "./investableUniverseAdapters/AaveAdapter.sol";
import {UniswapAdapter} from "./investableUniverseAdapters/UniswapAdapter.sol";
import {DataTypes} from "../vendor/DataTypes.sol";

contract Vault is ERC4626Mock, IVault, AaveAdapter, UniswapAdapter, ReentrancyGuard {
    error Vault__DepositMoreThanMax(uint256 amount, uint256 max);
    error Vault__NotGuardian();
    error Vault__NotVaultGuardianContract();
    error Vault__AllocationNot100Percent(uint256 totalAllocation);
    error Vault__NotActive();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 internal immutable i_uniswapLiquidityToken;
    IERC20 internal immutable i_aaveAToken;
    address private immutable i_guardian;
    address private immutable i_Guard;
    uint256 private immutable i_guardianAndDaoCut;
    bool private s_isActive;
    uint256 public totalAssset;

    AllocationData private s_allocationData;

    uint256 private constant ALLOCATION_PRECISION = 1_000;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event UpdatedAllocation(AllocationData allocationData);
    event NoLongerActive();
    event FundsInvested();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyGuardian() {
        if (msg.sender != i_guardian) {
            revert Vault__NotGuardian();
        }
        _;
    }

    modifier onlyGuard() {
        if (msg.sender != i_Guard) {
            revert Vault__NotVaultGuardianContract();
        }
        _;
    }

    modifier isActive() {
        if (!s_isActive) {
            revert Vault__NotActive();
        }
        _;
    }

    // slither-disable-start reentrancy-eth
    /**
     * @notice removes all supplied liquidity from Uniswap and supplied lending amount from Aave and then re-invests it back into them only if the vault is active
     */
    modifier divestThenInvest() {
        uint256 uniswapLiquidityTokensBalance = i_uniswapLiquidityToken.balanceOf(address(this));
        uint256 aaveAtokensBalance = i_aaveAToken.balanceOf(address(this));

        // Divest
        if (uniswapLiquidityTokensBalance > 0) {
            _uniswapDivest(IERC20(asset()), uniswapLiquidityTokensBalance);
        }
        if (aaveAtokensBalance > 0) {
            _aaveDivest(IERC20(asset()), aaveAtokensBalance);
        }

        _;

        // Reinvest
        if (s_isActive) {
            _investFunds(IERC20(asset()).balanceOf(address(this)));
        }
    }
    
    // slither-disable-end reentrancy-eth

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // We use a struct to avoid stack too deep errors. Thanks Solidity
    
    //audit-done
    constructor(ConstructorData memory constructorData)
        ERC4626Mock(constructorData.asset)
        ERC20(constructorData.vaultName, constructorData.vaultSymbol)
        AaveAdapter(constructorData.aavePool)
        UniswapAdapter(constructorData.uniswapRouter, constructorData.weth, constructorData.usdc)
    {
        i_guardian = constructorData.guardian;
        i_guardianAndDaoCut = constructorData.guardianAndDaoCut;
        i_Guard = constructorData.guard;
        s_isActive = true;
        updateHoldingAllocation(constructorData.allocationData);

        // External calls
        i_aaveAToken =
            IERC20(IPool(constructorData.aavePool).getReserveData(address(constructorData.asset)).aTokenAddress);
        i_uniswapLiquidityToken = IERC20(i_uniswapFactory.getPair(address(constructorData.asset), address(i_weth)));
    }

    /**
     * @notice Sets the vault as not active, which means that the vault guardian has quit
     * @notice Users will not be able to invest in this vault, however, they will be able to withdraw their deposited assets
     */
    //audit-done
    //audit-done
    function setNotActive() public onlyGuard isActive {
        s_isActive = false;
        emit NoLongerActive();
    }
    function divest() external onlyGuard isActive {
        uint256 uniswapLiquidityTokensBalance = i_uniswapLiquidityToken.balanceOf(address(this));
        uint256 aaveAtokensBalance = i_aaveAToken.balanceOf(address(this));
        // Divest
        if (uniswapLiquidityTokensBalance > 0) {
            _uniswapDivest(IERC20(asset()), uniswapLiquidityTokensBalance);
        }
        if (aaveAtokensBalance > 0) {
            _aaveDivest(IERC20(asset()), aaveAtokensBalance);
        }
    }

    /**
     * @notice Allows Vault Guardians to update their allocation ratio (and thus, their strategy of investment)
     * @param tokenAllocationData The new allocation data
     */
    //audit-done
    //audit-done
       function updateHoldingAllocation(AllocationData memory tokenAllocationData) public onlyGuard isActive {
        uint256 totalAllocation = tokenAllocationData.holdAllocation + tokenAllocationData.uniswapAllocation
            + tokenAllocationData.aaveAllocation;
        if (totalAllocation != ALLOCATION_PRECISION) {
            revert Vault__AllocationNot100Percent(totalAllocation);
        }
        s_allocationData = tokenAllocationData;
        emit UpdatedAllocation(tokenAllocationData);
    }

   
    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626Mock, IERC4626)
        isActive
        nonReentrant
        returns (uint256)
    {  
        // Returns the maximum amount of the underlying asset 
        // that can be deposited into the Vault for the receiver,
        // through a deposit call.
        if (assets > maxDeposit(receiver)) {
            revert Vault__DepositMoreThanMax(assets, maxDeposit(receiver));
        }
        // Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
        // current on-chain conditions.
        //q: we cut 1/1000 of share token to guardian and DAO,
        //we cut from the user's share token?
        //or we just mint 1/1000 of share token to guardian and DAO? 
        uint256 shares = previewDeposit(assets);
        // deposit asset and mint share token as shares to receiver
        _deposit(_msgSender(), receiver, assets, shares);
        // mint share token as fee to DAO and guardian
        _mint(i_guardian, shares / i_guardianAndDaoCut);
        _mint(i_Guard, shares / i_guardianAndDaoCut);

        _investFunds(assets);
        return shares;
    }

    
    function _investFunds(uint256 assets) private {
        uint256 uniswapAllocation = (assets * s_allocationData.uniswapAllocation) / ALLOCATION_PRECISION;
        uint256 aaveAllocation = (assets * s_allocationData.aaveAllocation) / ALLOCATION_PRECISION;

        emit FundsInvested();
        _uniswapInvest(IERC20(asset()), uniswapAllocation);
        _aaveInvest(IERC20(asset()), aaveAllocation);
    }

  
    function rebalanceFunds() public isActive divestThenInvest nonReentrant {}

  
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(IERC4626, ERC4626Mock)
        divestThenInvest
        nonReentrant
        returns (uint256)
    {
        uint256 shares = super.withdraw(assets, receiver, owner);
        return shares;
    }

    
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(IERC4626, ERC4626Mock)
        divestThenInvest
        nonReentrant
        returns (uint256)
    {
        uint256 assets = super.redeem(shares, receiver, owner);
        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
   
    function getGuardian() external view returns (address) {
        return i_guardian;
    }

   
    function getGuardianAndDaoCut() external view returns (uint256) {
        return i_guardianAndDaoCut;
    }

   
   
    function getGuard() external view returns (address) {
        return i_Guard;
    }

   
    function getIsActive() external view returns (bool) {
        return s_isActive;
    }

    
    function getAaveAToken() external view returns (address) {
        return address(i_aaveAToken);
    }

   
    function getUniswapLiquidtyToken() external view returns (address) {
        return address(i_uniswapLiquidityToken);
    }

    
    function getAllocationData() external view returns (AllocationData memory) {
        return s_allocationData;
    }
}
