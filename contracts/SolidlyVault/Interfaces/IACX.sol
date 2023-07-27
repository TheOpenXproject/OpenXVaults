// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IACX{
	function burn(address _to, uint256 _amount) external;
	function mint(address _to, uint256 _amount) external;
	function totalSupply() external returns(uint256);
}