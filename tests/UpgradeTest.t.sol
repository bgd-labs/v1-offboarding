// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';

interface ILendingPool {
  function liquidationCall(
    address _collateral,
    address _reserve,
    address _user,
    uint256 _purchaseAmount,
    bool _receiveAToken
  ) external payable;

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

interface ILendingPoolCore {
  function getReserves() external view returns (address[] memory);

  function getReserveInterestRateStrategyAddress(address) external view returns (address);
}

interface ILendingPoolAddressesProvider {
  function getLendingPoolCore() external view returns (address);

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
}

contract UpgradeTest is Test {
  ILendingPoolAddressesProvider public constant provider =
    ILendingPoolAddressesProvider(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);

  ILendingPool public constant pool = ILendingPool(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);

  ILendingPoolCore public constant core =
    ILendingPoolCore(0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3);

  IPoolConfigurator configurator = IPoolConfigurator(0x4965f6FA20fE9728deCf5165016fc338a5a85aBF);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 19075684);
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    provider.setLendingPoolLiquidationManager(0x1a7Dde6344d5F2888209DdB446756FE292e1325e);
    provider.setLendingPoolImpl(0x89A943BAc327c9e217d70E57DCD57C7f2a8C3fA9);

    bytes memory irBytecode = abi.encodePacked(
      vm.getCode(
        'UpdatedCollateralReserveIntrestRateStrategy.sol:CollateralReserveInterestRateStrategy'
      ),
      abi.encode(
        address(provider),
        0,
        10000000000000000000000000, // 1%
        50000000000000000000000000, // 5%
        20000000000000000000000000, // 2%
        100000000000000000000000000 // 10%
      )
    );
    address ir;
    assembly {
      ir := create(0, add(irBytecode, 0x20), mload(irBytecode))
    }

    address[] memory reserves = core.getReserves();
    for (uint256 i = 0; i < reserves.length; i++) {
      configurator.setReserveInterestRateStrategyAddress(reserves[i], ir);
    }
    vm.stopPrank();
  }

  struct V1User {
    address user;
    address collateral;
    address debt;
  }

  function test_healthyLiquidateShouldUse100bpsLB() public {
    V1User[] memory users = new V1User[](1);
    users[0] = V1User(
      0x1F0aeAeE69468727BA258B0cf692E6bfecc2E286,
      0x514910771AF9Ca656af840dff83E8264EcF986CA, // LINK
      0x0000000000085d4780B73119b644AE5ecd22b376 // TUSD
    );
    for (uint256 i = 0; i < users.length; i++) {
      (, uint256 currentBorrowBalance, , , , , , , , ) = pool.getUserReserveData(
        users[i].debt,
        users[i].user
      );
      deal(users[i].debt, address(this), currentBorrowBalance);
      // offboarding liquidations should provide a fixed 1% bonus
      (, uint256 totalCollateralETHBefore, uint256 totalBorrowsETHBefore, , , , , ) = pool
        .getUserAccountData(users[i].user);
      IERC20(users[i].debt).approve(provider.getLendingPoolCore(), type(uint256).max);
      pool.liquidationCall(
        users[i].collateral,
        users[i].debt,
        users[i].user,
        type(uint256).max,
        false
      );
      (, uint256 totalCollateralETHAfter, uint256 totalBorrowsETHAfter, , , , , ) = pool
        .getUserAccountData(users[i].user);

      uint256 collateralDiff = totalCollateralETHBefore - totalCollateralETHAfter;
      uint256 borrowsDiff = totalBorrowsETHBefore - totalBorrowsETHAfter;
      assertGt(collateralDiff, borrowsDiff);
      assertApproxEqAbs((borrowsDiff * 1 ether) / collateralDiff, 0.99 ether, 0.001 ether); // should be ~1% + rounding
    }
  }

  function test_ir() public {
    address[] memory reserves = core.getReserves();
    for (uint256 i = 0; i < reserves.length; i++) {
      emit log_named_address('reserve', reserves[i]);
      emit log_named_address('ir', core.getReserveInterestRateStrategyAddress(reserves[i]));
    }
  }
}
