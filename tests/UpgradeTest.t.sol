// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';

interface IAToken {
  function redeem(uint256 _amount) external;
}

interface ILendingPool {
  function liquidationCall(
    address _collateral,
    address _reserve,
    address _user,
    uint256 _purchaseAmount,
    bool _receiveAToken
  ) external payable;

  function repay(address _reserve, uint256 _amount, address payable _onBehalfOf) external payable;

  function offboardingLiquidationCall(
    address _collateral,
    address _reserve,
    address _user,
    uint256 _purchaseAmount
  ) external payable;

  function getUserAccountData(
    address _user
  )
    external
    view
    returns (
      uint256 totalLiquidityETH,
      uint256 totalCollateralETH,
      uint256 totalBorrowsETH,
      uint256 totalFeesETH,
      uint256 availableBorrowsETH,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );

  function getReserveData(
    address _reserve
  )
    external
    view
    returns (
      uint256 totalLiquidity,
      uint256 availableLiquidity,
      uint256 totalBorrowsStable,
      uint256 totalBorrowsVariable,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256 stableBorrowRate,
      uint256 averageStableBorrowRate,
      uint256 utilizationRate,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      address aTokenAddress,
      uint40 lastUpdateTimestamp
    );

  function getUserReserveData(
    address _reserve,
    address _user
  )
    external
    view
    returns (
      uint256 currentATokenBalance,
      uint256 currentBorrowBalance,
      uint256 principalBorrowBalance,
      uint256 borrowRateMode,
      uint256 borrowRate,
      uint256 liquidityRate,
      uint256 originationFee,
      uint256 variableBorrowIndex,
      uint256 lastUpdateTimestamp,
      bool usageAsCollateralEnabled
    );
}

interface ILendingPoolAddressesProvider {
  function getLendingPoolCore() external view returns (address);

  function setLendingPoolCoreImpl(address _core) external;

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address _pool) external;

  function getLendingPoolLiquidationManager() external view returns (address);

  function setLendingPoolLiquidationManager(address _manager) external;
}

interface IPoolConfigurator {
  function setReserveInterestRateStrategyAddress(
    address _reserve,
    address _rateStrategyAddress
  ) external;

  function deactivateReserve(address _reserve) external;
}

interface ILendingPoolCore {
  function getReserves() external view returns (address[] memory);

  function getReserveInterestRateStrategyAddress(address) external view returns (address);

  function getReserveATokenAddress(address) external view returns (address);

  function getReserveLiquidityCumulativeIndex(address) external view returns (uint256);

  function getReserveVariableBorrowsCumulativeIndex(address) external view returns (uint256);

  function getReserveCurrentLiquidityRate(address) external view returns (uint256);

  function getReserveCurrentVariableBorrowRate(address) external view returns (uint256);

  function getReserveCurrentStableBorrowRate(address) external view returns (uint256);
}

interface IEarnRebalance {
  function rebalance() external;
}

contract UpgradeTest is Test {
  ILendingPoolAddressesProvider public constant ADDRESSES_PROVIDER =
    ILendingPoolAddressesProvider(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);
  IPoolConfigurator public constant CONFIGURATOR =
    IPoolConfigurator(0x4965f6FA20fE9728deCf5165016fc338a5a85aBF);
  ILendingPoolCore public constant CORE =
    ILendingPoolCore(0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3);

  ILendingPool public constant POOL = ILendingPool(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 19574504);
  }

  function _executeUpgrade() internal {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    bytes memory liquidationManagerBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPoolLiquidationManager.sol:LendingPoolLiquidationManager')
    );
    address liquidationManager;
    assembly {
      liquidationManager := create(
        0,
        add(liquidationManagerBytecode, 0x20),
        mload(liquidationManagerBytecode)
      )
    }

    bytes memory irBytecode = abi.encodePacked(
      vm.getCode(
        'UpdatedCollateralReserveInterestRateStrategy.sol:CollateralReserveInterestRateStrategy'
      ),
      abi.encode(address(ADDRESSES_PROVIDER), 0, 0, 0, 0, 0)
    );
    bytes memory coreBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPool.sol:LendingPoolCore')
    );
    address ir;
    address core;
    assembly {
      ir := create(0, add(irBytecode, 0x20), mload(irBytecode))
      core := create(0, add(coreBytecode, 0x20), mload(coreBytecode))
    }

    // 1. update core to update irs one last time
    ADDRESSES_PROVIDER.setLendingPoolCoreImpl(core);
    // 2. update irs to be zero & deactivate reserve
    address[] memory reserves = CORE.getReserves();
    for (uint256 i = 0; i < reserves.length; i++) {
      CONFIGURATOR.setReserveInterestRateStrategyAddress(reserves[i], ir);
    }
    // 3. upgrade liquidationManager
    ADDRESSES_PROVIDER.setLendingPoolLiquidationManager(liquidationManager);
    vm.stopPrank();
  }

  struct V1User {
    address payable user;
    address collateral;
    address debt;
  }

  function test_healthyLiquidateShouldUse500bpsLB() public {
    _executeUpgrade();
    V1User[] memory users = _getUsers();
    for (uint256 i = 0; i < users.length; i++) {
      (, uint256 currentBorrowBalance, , , , , , , , ) = POOL.getUserReserveData(
        users[i].debt,
        users[i].user
      );
      // offboarding liquidations should provide a fixed 1% bonus
      (, uint256 totalCollateralETHBefore, uint256 totalBorrowsETHBefore, , , , , ) = POOL
        .getUserAccountData(users[i].user);
      if (users[i].debt == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
        deal(address(this), 1000 ether);
        POOL.liquidationCall{value: currentBorrowBalance}(
          users[i].collateral,
          users[i].debt,
          users[i].user,
          type(uint256).max,
          false
        );
      } else {
        deal(users[i].debt, address(this), currentBorrowBalance);
        assertEq(currentBorrowBalance, IERC20(users[i].debt).balanceOf(address(this)));
        IERC20(users[i].debt).approve(ADDRESSES_PROVIDER.getLendingPoolCore(), 0);
        IERC20(users[i].debt).approve(ADDRESSES_PROVIDER.getLendingPoolCore(), type(uint256).max);
        POOL.liquidationCall(
          users[i].collateral,
          users[i].debt,
          users[i].user,
          type(uint256).max,
          false
        );
      }
      (, uint256 totalCollateralETHAfter, uint256 totalBorrowsETHAfter, , , , , ) = POOL
        .getUserAccountData(users[i].user);

      uint256 collateralDiff = totalCollateralETHBefore - totalCollateralETHAfter;
      uint256 borrowsDiff = totalBorrowsETHBefore - totalBorrowsETHAfter;
      assertGt(collateralDiff, borrowsDiff);
      assertApproxEqAbs((borrowsDiff * 1 ether) / collateralDiff, 0.95 ether, 0.005 ether); // should be ~3% + rounding
    }
  }

  function test_repay() public {
    _executeUpgrade();

    V1User[] memory users = _getUsers();
    for (uint256 i = 0; i < users.length; i++) {
      vm.startPrank(users[i].user);

      // repay
      _repayV1(users[i].debt, users[i].user);

      vm.stopPrank();
    }
  }

  function test_redeem() public {
    _executeUpgrade();

    V1User[] memory users = _getUsers();

    for (uint256 i = 0; i < users.length; i++) {
      vm.startPrank(users[i].user);

      // redeem
      _redeemV1(users[i].collateral, users[i].user, 100);

      vm.stopPrank();
    }
  }

  function test_rates() public {
    address[] memory reserves = CORE.getReserves();
    uint256 snapshot = vm.snapshot();
    for (uint256 i = 0; i < reserves.length; i++) {
      uint256 lIndexBefore = CORE.getReserveLiquidityCumulativeIndex(reserves[i]);
      uint256 vIndexBefore = CORE.getReserveVariableBorrowsCumulativeIndex(reserves[i]);
      _executeUpgrade();
      uint256 lIndexAfter = CORE.getReserveLiquidityCumulativeIndex(reserves[i]);
      uint256 vIndexAfter = CORE.getReserveVariableBorrowsCumulativeIndex(reserves[i]);
      uint256 liquidityRateAfter = CORE.getReserveCurrentLiquidityRate(reserves[i]);

      assertEq(lIndexBefore, lIndexAfter);
      assertEq(vIndexBefore, vIndexAfter);
      assertEq(liquidityRateAfter, 0);
      vm.revertTo(snapshot);
    }
  }

  function test_rebalanceUSDC() public {
    _executeUpgrade();
    IEarnRebalance(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e).rebalance();
  }

  // function test_rebalanceTUSD() public {
  //   IEarnRebalance(0x73a052500105205d34Daf004eAb301916DA8190f).rebalance();
  // }

  function test_rebalanceDAI() public {
    _executeUpgrade();
    IEarnRebalance(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01).rebalance();
  }

  function test_rebalanceLINK() public {
    _executeUpgrade();
    IEarnRebalance(0x29E240CFD7946BA20895a7a02eDb25C210f9f324).rebalance();
  }

  function _getUsers() internal pure returns (V1User[] memory) {
    V1User[] memory users = new V1User[](1);
    users[0] = V1User(
      payable(0x532e32e13eeD4200Cf3e28bD0Cf245c2F6CAfD71),
      AaveV2EthereumAssets.LINK_UNDERLYING,
      AaveV2EthereumAssets.USDC_UNDERLYING
    );
    return users;
  }

  function _repayV1(address debtAsset, address payable user) internal {
    (, uint256 currentBorrowBalance, , , , , uint256 originationFee, , , ) = POOL
      .getUserReserveData(debtAsset, user);
    uint256 debt = currentBorrowBalance + originationFee;
    if (debtAsset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      deal(user, debt);
      POOL.repay{value: debt}(debtAsset, type(uint256).max, user);
    } else {
      deal(debtAsset, user, debt);
      IERC20(debtAsset).approve(ADDRESSES_PROVIDER.getLendingPoolCore(), 0);
      IERC20(debtAsset).approve(ADDRESSES_PROVIDER.getLendingPoolCore(), type(uint256).max);
      POOL.repay(debtAsset, type(uint256).max, user);
    }
    (, uint256 currentBorrowBalanceAfter, , , , , uint256 originationFeeAfter, , , ) = POOL
      .getUserReserveData(debtAsset, user);
    assertEq(currentBorrowBalanceAfter + originationFeeAfter, 0, vm.toString(debtAsset));
  }

  function _redeemV1(address token, address user, uint256 amount) internal {
    (uint256 currentATokenBalance, , , , , , , , , ) = POOL.getUserReserveData(token, user);
    address aToken = CORE.getReserveATokenAddress(token);
    IAToken(aToken).redeem(amount);
    (uint256 currentATokenBalanceAfter, , , , , , , , , ) = POOL.getUserReserveData(token, user);
    assertEq(currentATokenBalance - amount, currentATokenBalanceAfter);
  }
}
