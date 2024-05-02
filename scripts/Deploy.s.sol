// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {Script} from 'forge-std/Script.sol';

interface ILendingPool {
  function initialize(address _addressesProvider) external;
}

library DeployLib {
  address constant ADDRESSES_PROVIDER = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

  function _deploy(Vm vm) internal returns (address, address, address, address) {
    bytes memory irBytecode = abi.encodePacked(
      vm.getCode(
        'UpdatedCollateralReserveInterestRateStrategy.sol:CollateralReserveInterestRateStrategy'
      ),
      abi.encode(ADDRESSES_PROVIDER, 0, 0, 0, 0, 0)
    );
    bytes memory liquidationManagerBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPoolLiquidationManager.sol:LendingPoolLiquidationManager')
    );
    bytes memory coreBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPool.sol:LendingPoolCore')
    );
    bytes memory poolBytecode = abi.encodePacked(vm.getCode('UpdatedLendingPool.sol:LendingPool'));
    address liquidationManager;
    address ir;
    address core;
    address pool;
    assembly {
      ir := create(0, add(irBytecode, 0x20), mload(irBytecode))
      liquidationManager := create(
        0,
        add(liquidationManagerBytecode, 0x20),
        mload(liquidationManagerBytecode)
      )
      core := create(0, add(coreBytecode, 0x20), mload(coreBytecode))
      pool := create(0, add(poolBytecode, 0x20), mload(poolBytecode))
    }

    ILendingPool(pool).initialize(ADDRESSES_PROVIDER);

    return (liquidationManager, ir, core, pool);
  }
}

//  command: make deploy-ledger contract=scripts/Deploy.s.sol:Deploy chain=mainnet
contract Deploy is Script {
  address constant ADDRESSES_PROVIDER = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

  function run() external {
    vm.startBroadcast();
    DeployLib._deploy(vm);
    vm.stopBroadcast();
  }
}
