pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract BABELPlaceholder is ERC20 {
    constructor(string memory name, string memory symbol, uint256 amount) ERC20(name, symbol) {
        _update(address(0), msg.sender, amount);
    }
}