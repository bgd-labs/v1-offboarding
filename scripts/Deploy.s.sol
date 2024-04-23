// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

interface ILendingPool {
  function initialize(address _addressesProvider) external;
}

//  command: make deploy-ledger contract=scripts/Deploy.s.sol:Deploy chain=mainnet
contract Deploy is Script {
  address constant ADDRESSES_PROVIDER = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

  function run() external {
    vm.startBroadcast();
    // deploy zero IR
    bytes memory irBytecode = abi.encodePacked(
      vm.getCode(
        'UpdatedCollateralReserveInterestRateStrategy.sol:CollateralReserveInterestRateStrategy'
      ),
      abi.encode(address(ADDRESSES_PROVIDER), 0, 0, 0, 0, 0)
    );
    address ir;
    assembly {
      ir := create(0, add(irBytecode, 0x20), mload(irBytecode))
    }
    // deploy LiquidationManager
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
    // deploy new core
    bytes memory coreBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPool.sol:LendingPoolCore')
    );
    address core;
    assembly {
      core := create(0, add(coreBytecode, 0x20), mload(coreBytecode))
    }
    vm.stopBroadcast();
  }
}
