// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "./Permission.sol";

interface IPermissiveAccount is IAccount {

    error SamePermissions();
    error NotAllowed(address);
    error InvalidTo(address provided, address expected);
    error ExceededValue(uint256 value, uint256 max);
    error InvalidPermission();
    error InvalidPaymaster(address provided, address expected);
    error InvalidSelector(bytes4 provided, bytes4 expected);

    event OperatorMutated(address operator, bytes32 oldPermissions, bytes32 newPermissions);

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external;
}
