// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "./Permission.sol";

interface IPermissiveAccount is IAccount {
    // emitted when an operator gets granted
    event OperatorGranted(address operator, bytes32 merkleRootPermissions);
    // emitted when an operator has no more permissions
    event OperatorRevoked(address operator);
    // emitted when an operator has new permissions
    event OperatorMutated(address operator, bytes32 merkleRootPermissions);

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external;

    function isOperatorGrantedForPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external view returns (bool);
}
