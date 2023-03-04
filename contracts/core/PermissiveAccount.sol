// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "../interfaces/IPermissiveAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable {
    mapping(bytes32 => uint256) private _feeUsedForPermission;
    mapping(bytes32 => uint256) private _valueUsedForPermission;
    mapping(address => bytes32) private _operatorPermission;

    uint96 private _nonce;

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external onlyOwner {
        _operatorPermission[operator] = merkleRootPermissions;
    }

    function isGrantedOperator(address operator) external view returns (bool) {
        return _operatorPermission[operator] != bytes32(0);
    }

    function isOperatorGrantedForPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external view returns (bool) {
        bytes32 storedRoot = _operatorPermission[operator];
        return storedRoot == merkleRootPermissions;
    }

    function isValidPermission(Permission memory permission)
        external
        pure
        returns (bool)
    {
        return false;
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
    ) internal override returns (uint256 validationData) {
        return 2;
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
