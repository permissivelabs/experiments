// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "../interfaces/IPermissiveAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../library/AllowedArguments.sol";

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable {
    using AllowedArguments for bytes;

    using ECDSA for bytes32;

    mapping(bytes32 => uint256) private _feeUsedForPermission;
    mapping(bytes32 => uint256) private _valueUsedForPermission;
    mapping(address => bytes32) public operatorPermission;

    uint96 private _nonce;

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external onlyOwner {
        bytes32 oldValue = operatorPermission[operator];
        bool isRevoked = (merkleRootPermissions == bytes32(0));
        operatorPermission[operator] = merkleRootPermissions;

        if (oldValue == merkleRootPermissions) {
            return; // Value unchanged, no event emitted
        }

        if (isRevoked) {
            emit OperatorRevoked(operator);
        } else if (oldValue == bytes32(0)) {
            emit OperatorGranted(operator, merkleRootPermissions);
        } else {
            emit OperatorMutated(operator, merkleRootPermissions);
        }
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission
    ) external {
        permission.allowed_arguments.areArgumentsAllowed(func);
    }

    function isOperatorGrantedForPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external view returns (bool) {
        bytes32 storedRoot = operatorPermission[operator];
        return storedRoot == merkleRootPermissions;
    }

    function nonce() public view override returns (uint256) {
        return _nonce;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(address(0));
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        override(BaseAccount, IAccount)
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        validationData = _validateSignature(userOp, userOpHash);
        if (userOp.initCode.length == 0) {
            _validateAndUpdateNonce(userOp);
        }
        _payPrefund(missingAccountFunds);
    }

    function _requireFromEntryPoint() internal view override {
        require(
            msg.sender == address(entryPoint()),
            "account: not from EntryPoint"
        );
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp)
        internal
        override
    {
        require(_nonce++ == userOp.nonce, "account: invalid nonce");
    }

    function _payPrefund(uint256 missingAccountFunds) internal override {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            (success);
            //ignore failure (its EntryPoint's job to verify, not account.)
        }
    }
}
