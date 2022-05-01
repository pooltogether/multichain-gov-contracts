// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mintable is ERC20 {

    constructor() ERC20("Mintable", "MINT") {
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}