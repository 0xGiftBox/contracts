// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GiftBoxToken is ERC20, ERC20Burnable, Ownable {
    constructor(string memory fundName, string memory symbolSuffix)
        ERC20(
            string.concat("GiftBox Token: ", fundName),
            string.concat("gbt", symbolSuffix)
        )
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
