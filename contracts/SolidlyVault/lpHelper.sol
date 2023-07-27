// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces/IVelodromePair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.6.12;

library Babylonian {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }
}



contract lpHelper {
    using SafeMath for uint256;
    
    function calculateSwapInAmount(uint256 reserveIn, uint256 reserveOut, uint256 userIn, bool stable,uint256 amountOut)
    public
    pure
    returns (uint256)
    {
    		if(stable){
				uint ratio = amountOut * 1e18 / (userIn) * reserveIn / reserveOut;
        		return userIn * 1e18 / (ratio + 1e18);    			
    		}
			return
	        Babylonian
	        .sqrt(
	            reserveIn.mul(userIn.mul(3988000) + reserveIn.mul(3988009))
	        )
	        .sub(reserveIn.mul(1997)) / 1994;
    }


    function _addLiquidity(address _token, address _pair, uint256 _amount) internal returns (uint256 liquidity) {
    	address token0 = IVelodromePair(_pair).token0();
    	address token1 = IVelodromePair(_pair).token1();
    	if(token0 != _token){
    		(uint256 amountIn,uint256 amountOut) = _swapTokenForLiq(_pair, token1, _amount);
    		IERC20(token1).transfer(address(_pair), amountIn);
            IERC20(token0).transfer(address(_pair), amountOut);
            liquidity = IVelodromePair(_pair).mint(address(this));
    	}else{
    		(uint256 amountIn,uint256 amountOut) = _swapTokenForLiq(_pair, token0, _amount);
			IERC20(token0).transfer(address(_pair), amountIn);
            IERC20(token1).transfer(address(_pair), amountOut);
            liquidity = IVelodromePair(_pair).mint(address(this));
    	}
    }


    function _swapTokenForLiq(address _pair, address fromToken, uint256 amountIn) internal returns (uint256 inputAmount, uint256 amountOut) {
        IVelodromePair pair = IVelodromePair(_pair);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        bool stable = IVelodromePair(_pair).stable();
        uint256 out = IVelodromePair(_pair).getAmountOut(amountIn, fromToken);
        if (fromToken == pair.token0()) {
        	inputAmount = calculateSwapInAmount(reserve0, reserve1 , amountIn, stable, out);
            IERC20(fromToken).transfer(address(pair), inputAmount);

            amountOut = pair.getAmountOut(inputAmount, fromToken); 
            pair.swap(0, amountOut, address(this), new bytes(0));
            inputAmount = amountIn.sub(inputAmount);
        } else {
        	inputAmount = calculateSwapInAmount(reserve1, reserve0 ,amountIn, stable, out);

            IERC20(fromToken).transfer(address(pair), inputAmount);

            amountOut = pair.getAmountOut(inputAmount, fromToken);
            pair.swap(amountOut, 0, address(this), new bytes(0));
            inputAmount = amountIn.sub(inputAmount);
        }
    }

    function _swapToken(address _pair, address fromToken, uint256 amountIn) internal returns(uint256 amountOut, address outToken){
    	IVelodromePair pair = IVelodromePair(_pair);
        if (fromToken == pair.token0()) {
        	outToken = pair.token1();
            IERC20(fromToken).transfer(address(pair), amountIn);
            amountOut = pair.getAmountOut(amountIn, fromToken);
            pair.swap(0, amountOut, address(this), new bytes(0));
        } else {
        	outToken = pair.token0();
            IERC20(fromToken).transfer(address(pair), amountIn);
            amountOut = pair.getAmountOut(amountIn, fromToken);
            pair.swap(amountOut, 0, address(this), new bytes(0));
        }
    }



}
