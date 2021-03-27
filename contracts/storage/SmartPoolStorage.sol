// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


library SmartPoolStorage {

  bytes32 public constant sSlot = keccak256("SmartPoolStorage.storage.location");

  struct Storage{
    address controller;
    uint256 cap;
    mapping(FeeType=>Fee) fees;
  }

  struct Fee{
    uint256 ratio;
    uint256 denominator;
    uint256 lastTimestamp;
  }

  enum FeeType{
    JOIN_FEE,EXIT_FEE,MANAGEMENT_FEE
  }

  function load() internal pure returns (Storage storage s) {
    bytes32 loc = sSlot;
    assembly {
      s_slot := loc
    }
  }
}
