// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "../interfaces/IPermissiveAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable {
    using ECDSA for bytes32;
    mapping(bytes32 => uint256) private _remainingFeeForPermission;
    mapping(bytes32 => uint256) private _remainingValueForPermission;
    mapping(address => bytes32) public operatorPermissions;
    IEntryPoint private immutable _entryPoint;
    uint96 private _nonce;

    constructor(address __entryPoint) {
        _entryPoint = IEntryPoint(__entryPoint);
    }

    /* GETTERS */

    function nonce() public view override returns (uint256) {
        return _nonce;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    /* EXTERNAL FUNCTIONS */

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions,
        uint256 maxValue,
        uint256 maxFee
    ) external {
        _requireFromEntryPointOrOwner();
        bytes32 oldValue = operatorPermissions[operator];
        operatorPermissions[operator] = merkleRootPermissions;
        _remainingFeeForPermission[merkleRootPermissions] = maxFee;
        _remainingValueForPermission[merkleRootPermissions] = maxValue;
        emit OperatorMutated(operator, oldValue, merkleRootPermissions);
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
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature)) {
            (, , , Permission memory permission, bytes32[] memory proof) = abi
                .decode(
                    userOp.callData[4:],
                    (address, uint256, bytes, Permission, bytes32[])
                );

            if (permission.operator != hash.recover(userOp.signature))
                validationData = SIG_VALIDATION_FAILED;

            bytes32 permHash = _validateMerklePermission(permission, proof);
            _validatePermission(userOp, permission, permHash);
        }
        _payPrefund(missingAccountFunds);
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission,
        bytes32 permissionHash
    ) external {
        _requireFromEntryPointOrOwner();
        if (msg.sender != owner()) {
            uint fee = tx.gasprice * gasleft();
            if (fee > _remainingFeeForPermission[permissionHash])
                revert ExceededFees(
                    fee,
                    _remainingFeeForPermission[permissionHash]
                );
            _remainingValueForPermission[permissionHash] =
                _remainingValueForPermission[permissionHash] -
                value;
            _remainingFeeForPermission[permissionHash] =
                _remainingFeeForPermission[permissionHash] -
                fee;
            if (permission.expiresAtUnix != 0) {
                if (block.timestamp >= permission.expiresAtUnix)
                    revert ExpiredPermission(
                        block.timestamp,
                        permission.expiresAtUnix
                    );
            } else if (permission.expiresAtBlock != 0) {
                if (block.number >= permission.expiresAtBlock)
                    revert ExpiredPermission(
                        block.number,
                        permission.expiresAtBlock
                    );
            }
        }
        (bool success, ) = dest.call{value: value}(func);
        (success);
    }

    /* INTERNAL */

    function _validatePermission(
        UserOperation calldata userOp,
        Permission memory permission,
        bytes32 permissionHash
    ) public view {
        (address to, uint256 value, bytes memory callData, , ) = abi.decode(
            bytes(userOp.callData[4:]),
            (address, uint256, bytes, Permission, bytes32)
        );
        if (permission.to != to) revert InvalidTo(to, permission.to);
        // if (_remainingFeeForPermission[permissionHash] < value)
        //     revert ExceededValue(value, permission.maxValue);
        if (permission.selector != bytes4(callData))
            revert InvalidSelector(bytes4(callData), permission.selector);
        if (permission.expiresAtUnix != 0 && permission.expiresAtBlock != 0)
            revert InvalidPermission();
        address paymaster = address(0);
        assembly {
            let paymasterOffset := calldataload(add(userOp, 288))
            paymaster := calldataload(add(paymasterOffset, add(userOp, 32)))
        }
        if (permission.maxFee == 0 && permission.paymaster != paymaster)
            revert InvalidPaymaster(permission.paymaster, paymaster);
    }

    function _validateMerklePermission(
        Permission memory permission,
        bytes32[] memory proof
    ) internal view returns (bytes32 permHash) {
        permHash = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
                permission.maxValue,
                permission.maxFee,
                permission.paymaster,
                permission.expiresAtUnix,
                permission.expiresAtBlock
            )
        );
        bool isValidProof = MerkleProof.verify(
            proof,
            operatorPermissions[permission.operator],
            permHash
        );
        if (!isValidProof) revert InvalidProof();
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner(),
            "account: not from EntryPoint or owner"
        );
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override {
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
