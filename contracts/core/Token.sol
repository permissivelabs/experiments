// SPDX-License-Identifier: SEE LICENSE IN LICENSE

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint() external {
        _mint(msg.sender, 100 ether);
    }
}
