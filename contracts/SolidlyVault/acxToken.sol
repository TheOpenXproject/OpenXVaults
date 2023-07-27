// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract acxToken is ERC20, Ownable{
    constructor(string memory symbol, string memory name) public ERC20(symbol, name) { }

    function mint(address _to, uint256 _amount) public onlyOwner{
    	_mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public{
        if(msg.sender != owner()){
            require(msg.sender == _from, "No");
        }
    	_burn(_from, _amount);
    }
}