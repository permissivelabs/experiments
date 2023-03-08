// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "../interfaces/IPermissiveAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable {
    using ECDSA for bytes32;

    // mapping(bytes32 => uint256) private _feeUsedForPermission;
    // mapping(bytes32 => uint256) private _valueUsedForPermission;
    mapping(address => bytes32) public operatorPermissions;
    IEntryPoint private immutable _entryPoint;

    uint96 private _nonce;

    constructor(address __entryPoint) {
        _entryPoint = IEntryPoint(__entryPoint);
    }

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions
    ) external onlyOwner {
        bytes32 oldValue = operatorPermissions[operator];
        if (oldValue == merkleRootPermissions) {
            revert SamePermissions();
        }
        operatorPermissions[operator] = merkleRootPermissions;
        emit OperatorMutated(operator, oldValue, merkleRootPermissions);
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission,
        bytes32[] calldata proof
    ) external {
        (bool success, ) = dest.call{value: value}(func);
        (success);
    }

    function nonce() public view override returns (uint256) {
        return _nonce;
    }

    function entryPoint() public view override returns(IEntryPoint) {
        return _entryPoint;
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
        if (userOp.initCode.length == 0) {
            _validateAndUpdateNonce(userOp);
        }
        (Permission memory perm, bytes32[] memory proof) = abi.decode(userOp.callData[4:], (Permission, bytes32[]));
        validationData = _validateSignature(userOp, userOpHash);
        // hash operation
        bytes32 permHash = keccak256(
            abi.encode(
                perm.operator,
                perm.to,
                perm.selector,
                perm.maxValue,
                perm.maxFee,
                perm.paymaster,
                perm.expires_at_unix,
                perm.expires_at_block
            )
        );
        bool isAllowed = MerkleProof.verify(proof, operatorPermissions[perm.operator], permHash);
        if(!isAllowed) revert NotAllowed(perm.operator);
        _validatePermission(userOp, perm);
        _payPrefund(missingAccountFunds);
    }

    function _validatePermission(UserOperation memory userOp, Permission memory permission) public {
        (address to, uint256 value, bytes memory callData,,) = abi.decode(userOp.callData, (address, uint256, bytes, Permission, bytes32));
        if(permission.to != to) revert InvalidTo(to, permission.to);
        if(permission.maxValue < value) revert ExceededValue(value, permission.maxValue);
        // check gas on execute
        if(permission.paymaster != address(0) && permission.maxFee > 0)revert InvalidPermission();
        if(permission.selector != bytes4(callData)) revert InvalidSelector(bytes4(callData), permission.selector);
        address paymaster = address(0);
        assembly {
            let initCodeSize := mload(add(userOp, 64))
            let callDataSize := mload(add(add(userOp, 96), initCodeSize))
            paymaster := mload(add(add(add(userOp, 256), initCodeSize), callDataSize))
            let mask := shl(12, sub(exp(2, 160), 1))
            paymaster := and(mask, paymaster)
        }
        if(permission.maxFee == 0 && permission.paymaster != paymaster) revert InvalidPaymaster(permission.paymaster, paymaster);
        // check timestamps on execute
    }

    // function _updateValue(uint256 value)

    function _requireFromEntryPoint() internal view override {
        require(
            msg.sender == address(entryPoint()),
            "account: not from EntryPoint"
        );
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
        // address operator
    ) internal override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        //  && operator != hash.recover(userOp.signature)
        if (owner() != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp)
        internal
        override
    {
        require(++_nonce == userOp.nonce, "account: invalid nonce");
    }

    function _payPrefund(uint256 missingAccountFunds) internal override {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            (success);
        }
    }
}
