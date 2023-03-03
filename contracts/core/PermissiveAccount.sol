// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "../interfaces/IPermissiveAccount.sol";
import "../interfaces/Permission.sol";

abstract contract PermissiveAccount is BaseAccount, IPermissiveAccount {
    mapping(bytes32 => uint256) feeUsedForPermission;
    mapping(bytes32 => uint256) valueUsedForPermission;
}
