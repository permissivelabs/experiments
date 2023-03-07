// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "./Permission.sol";

interface IPermissiveAccount is IAccount {

    error SamePermissions();
    error NotAllowed(address);

    event OperatorMutated(address operator, bytes32 oldPermissions, bytes32 newPermissions);

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external;
}
