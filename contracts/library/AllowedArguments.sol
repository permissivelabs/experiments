// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

library AllowedArguments {
    function areArgumentsAllowed(bytes calldata allowed, bytes calldata data) public returns(bool) {
        bytes memory arguments = data[4:];
        if(allowed[0] == 0){
            // next step
        }else if(uint8(allowed[0]) == 1) {
            // require(allowed[], "Invalid calldata");
        }
    }
}
