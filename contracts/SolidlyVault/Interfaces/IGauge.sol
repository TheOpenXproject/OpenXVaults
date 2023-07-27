// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IGauge{
	function getReward(address account) external;
	function deposit(uint amount) external;
	function withdraw(uint amount) external;
	function balanceOf(address) external view returns (uint);
    function earned(address account) external view returns (uint);
    function rewardToken() external view returns (address);

}