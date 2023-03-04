// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

struct Permission {
    // the operator
    address operator;
    // the address allowed to interact with
    address to;
    // the function selector
    bytes4 selector;
    // specific calldata that allowed
    bytes allowed_calldata;
    // the maximum value allowed to this permission
    uint256 maxValue;
    // max fee allowed to be spent on this permission
    uint256 maxFee;
    // set only if maxFee is 0
    address paymaster;
    // the timestamp when the permission isn't valid anymore
    // @dev can be 0 if expires_at_block != 0
    uint256 expires_at_unix;
    // the block when the permission isn't valid anymore
    // @dev can be 0 if expires_at_unix != 0
    uint256 expires_at_block;
}