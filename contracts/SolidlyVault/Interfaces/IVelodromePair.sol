// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IVelodromePair {
  function allowance(address owner, address spender)external view returns(uint256);
  function approve(address spender, uint256 amount)external returns(bool);
  function balanceOf(address account)external view returns(uint256);
  function burn(address to)external returns(uint256 amount0, uint256 amount1);
  function getAmountOut(uint256 amountIn, address tokenIn)external view returns(uint256);
  function getReserves() external view returns(uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
  function mint(address to)external returns(uint256 liquidity);
  function name() external view returns(string memory);
  function quote(address tokenIn, uint256 amountIn, uint256 granularity)external view returns(uint256 amountOut);
  function reserve0() external view returns(uint256);
  function reserve1() external view returns(uint256);


  function stable() external view returns(bool);
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data)external;
  function symbol() external view returns(string memory);
  function token0() external view returns(address);
  function token1() external view returns(address);


}
