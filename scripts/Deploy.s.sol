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
    bytes memory irBytecode = abi.encodePacked(
      vm.getCode(
        'UpdatedCollateralReserveIntrestRateStrategy.sol:CollateralReserveInterestRateStrategy'
      ),
      abi.encode(
        address(ADDRESSES_PROVIDER),
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
    vm.stopBroadcast();
  }
}
