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
    mapping(address => uint256) public _remainingFeeForOperator;
    mapping(address => uint256) public _remainingValueForOperator;
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
        _remainingFeeForOperator[operator] = maxFee;
        _remainingValueForOperator[operator] = maxValue;
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
            _validateMerklePermission(permission, proof);
            _validatePermission(userOp, permission);
        }
        _payPrefund(missingAccountFunds);
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata
    ) external {
        _requireFromEntryPointOrOwner();
        // if (msg.sender != owner()) {
        //     uint fee = tx.gasprice * gasleft();
        //     if (fee > _remainingFeeForOperator[permission.operator]) {
        //         revert ExceededFees(
        //             fee,
        //             _remainingFeeForOperator[permission.operator]
        //         );
        //     }
        //     console.log("before update state");
        //     _remainingValueForOperator[permission.operator] -= value;
        //     _remainingFeeForOperator[permission.operator] -= fee;
        //     console.log("after update state");
        //     if (permission.expiresAtUnix != 0) {
        //         if (block.timestamp >= permission.expiresAtUnix)
        //             revert ExpiredPermission(
        //                 block.timestamp,
        //                 permission.expiresAtUnix
        //             );
        //     } else if (permission.expiresAtBlock != 0) {
        //         if (block.number >= permission.expiresAtBlock)
        //             revert ExpiredPermission(
        //                 block.number,
        //                 permission.expiresAtBlock
        //             );
        //     }
        // }
        console.log(dest, value);
        console.logBytes(func);
        (bool success, bytes memory result) = dest.call{value: value}(func);
        console.log(success);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /* INTERNAL */

    function _validatePermission(
        UserOperation calldata userOp,
        Permission memory permission
    ) internal view {
        (address to, uint256 value, bytes memory callData, , ) = abi.decode(
            userOp.callData[4:],
            (address, uint256, bytes, Permission, bytes32[])
        );
        if (permission.to != to) revert InvalidTo(to, permission.to);
        if (_remainingValueForOperator[permission.operator] < value)
            revert ExceededValue(
                value,
                _remainingValueForOperator[permission.operator]
            );
        if (permission.selector != bytes4(callData))
            revert InvalidSelector(bytes4(callData), permission.selector);
        if (permission.expiresAtUnix != 0 && permission.expiresAtBlock != 0)
            revert InvalidPermission();
        address paymaster = address(0);
        assembly {
            let paymasterOffset := calldataload(add(userOp, 288))
            paymaster := calldataload(add(paymasterOffset, add(userOp, 20)))
        }
        if (paymaster != permission.paymaster)
            revert InvalidPaymaster(paymaster, permission.paymaster);
    }

    function _validateMerklePermission(
        Permission memory permission,
        bytes32[] memory proof
    ) public view {
        bytes32 permHash = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
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

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
