// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.6.12;
/*                                 /$$    /$$                 /$$  /$$            
                                  | $$   | $$                | $$ | $$            
  /$$$$$$  /$$$$$$$/$$   /$$      | $$   | $$/$$$$$$ /$$   /$| $$/$$$$$$  /$$$$$$$
 |____  $$/$$_____|  $$ /$$/      |  $$ / $$|____  $| $$  | $| $|_  $$_/ /$$_____/
  /$$$$$$| $$      \  $$$$/        \  $$ $$/ /$$$$$$| $$  | $| $$ | $$  |  $$$$$$ 
 /$$__  $| $$       >$$  $$         \  $$$/ /$$__  $| $$  | $| $$ | $$ /$\____  $$
|  $$$$$$|  $$$$$$$/$$/\  $$         \  $/ |  $$$$$$|  $$$$$$| $$ |  $$$$/$$$$$$$/
 \_______/\_______|__/  \__/          \_/   \_______/\______/|__/  \___/|_______/ */
                                                                                  
// An Open X Project                                                                                  

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces/IVelodromePair.sol";

import './Interfaces/IGauge.sol';
import "./Interfaces/IACX.sol";
import "./Interfaces/IWETH.sol";
import "./acxToken.sol";
import "./lpHelper.sol";

contract vaultFactory is Ownable, lpHelper{
    using SafeMath for uint256;

	// The struct for the pool information.
	struct PoolInfo {
		address rewardToken;
		address underlyingLp;
		address acxToken;
		address gauge;
		uint256 totalStaked;
		address[] path;
		uint256 lastCollectionTimestamp;
	}

	// Array of pools and mapping to check if pair already exists.
	PoolInfo[] public Pools;
	mapping(address => bool) public pairExists;

	// Variables for fees.
	uint256 public bountyfeePer10K = 100;
	uint256 public performanceFeePer10K = 600;
	uint256 public zapFeePer10K = 10;
	uint256 public perfPool = 0;


	address public weth = 0x4200000000000000000000000000000000000006;
	

	uint private unlocked = 1;
    //reentrancy guard
    modifier lock() {
        require(unlocked == 1, 'OpenX LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // Method to get the length of pools.
	function poolsLength() public view returns (uint256){
		return Pools.length;
	}

	// Method to add a new vault.
	function addVault(address _underlyingLp, address _gauge, address[] memory path) public onlyOwner{
		require(pairExists[_underlyingLp] == false, "Pool Already Exists.");
		pairExists[_underlyingLp] = true;
		PoolInfo memory newPool;
		acxToken acx = new acxToken(string(abi.encodePacked('acx-', IVelodromePair(_underlyingLp).symbol())) , string(abi.encodePacked('Auto Compounding X ', IVelodromePair(_underlyingLp).symbol())));
		newPool.acxToken = address(acx);
		newPool.gauge = _gauge;
		newPool.underlyingLp = _underlyingLp;
		newPool.rewardToken = IGauge(_gauge).rewardToken();
		newPool.path = path;
		Pools.push(newPool);
	}

	// Method to update the path for token swaps.
	function updatePath(uint256 _pid, address[] memory _path) public onlyOwner {
		Pools[_pid].path = _path;
	}

	// Method to update the performance pool.
	function updatePerfPool(uint256 _pid) public onlyOwner{
		perfPool = _pid;
	}

	// Method to update the fees.
	function updateFees(uint256 _bountyfeePer10K, uint256 _performanceFeePer10K, uint256 _zapFeePer10K) public onlyOwner {
		require(_bountyfeePer10K.add(_performanceFeePer10K).add(_zapFeePer10K) <= 1000, "Max 10%");
		bountyfeePer10K = _bountyfeePer10K;
		performanceFeePer10K = _performanceFeePer10K;
		zapFeePer10K = _zapFeePer10K;
	}


	// Method to deposit into a pool.
	function deposit(uint256 _pid, uint256 _amount, address _to) public lock{
		IERC20 lpToken = IERC20(Pools[_pid].underlyingLp);
		safeTransferFrom(address(lpToken), msg.sender, address(this), _amount);
		_deposit(_pid, _amount, _to);
	}

	// Internal method to handle the deposit logic.
	function _deposit(uint256 _pid, uint256 _amount, address _to) internal {
		IACX acxToken = IACX(Pools[_pid].acxToken);
		IERC20 lpToken = IERC20(Pools[_pid].underlyingLp);
		IGauge gauge = IGauge(Pools[_pid].gauge);
		uint256 totalSupply = acxToken.totalSupply();

		if(totalSupply == 0){
			acxToken.mint(_to, _amount);
		}else{
			if(Pools[_pid].lastCollectionTimestamp != block.timestamp){
				Pools[_pid].lastCollectionTimestamp = block.timestamp;
				claimBounty(_pid,_to);
			}
			uint256 lpBal = gauge.balanceOf(address(this));
			
            uint256 _mintAmount = _amount.mul(totalSupply).div(lpBal);
            acxToken.mint(_to, _mintAmount);
		}


		lpToken.approve(address(gauge), _amount);
		gauge.deposit(_amount);
		Pools[_pid].totalStaked += _amount;
	}

	// Method to withdraw from a pool.
	function withdraw(uint256 _pid, uint256 _amount, address _to) public lock{
		_withdraw(_pid, _amount, msg.sender, _to);
	}

	// Internal method to handle the withdrawal logic.
	function _withdraw(uint256 _pid, uint256 _amount,address _from, address _to) internal returns(uint256) {
		IACX acxToken = IACX(Pools[_pid].acxToken);
		IERC20 lpToken = IERC20(Pools[_pid].underlyingLp);
		IGauge gauge = IGauge(Pools[_pid].gauge);
		uint256 totalSupply = acxToken.totalSupply();
		uint256 lpBal = gauge.balanceOf(address(this));
		uint256 withdrawAmount = _amount.mul(lpBal).div(totalSupply);
		
		acxToken.burn(_from, _amount);
		gauge.withdraw(withdrawAmount);
		safeTransfer(address(lpToken), _to, withdrawAmount);

		Pools[_pid].totalStaked -= withdrawAmount;
		return withdrawAmount;
	}

    // Method to claim the bounty.
    function claimBounty(uint256 _pid, address _to) public {
    	address rewardToken = Pools[_pid].rewardToken;
    	IGauge gauge = IGauge(Pools[_pid].gauge);
    	uint256 earned = gauge.earned(address(this));
    	if(earned < 1*10**17){
    		return;
    	}
    	uint256 bounty = earned.mul(bountyfeePer10K).div(10000);
    	uint256 performance = earned.mul(bountyfeePer10K).div(10000);
    	gauge.getReward(address(this));

    	safeTransfer(rewardToken, _to, bounty);

    	earned = earned.sub(performance).sub(bounty);
    	uint256 amount = _compound(_pid, earned);

    	uint256 amountPerf = _compound(perfPool, performance);
    	_deposit(perfPool, amountPerf, owner());

    	Pools[_pid].totalStaked += amount;

    	IERC20(Pools[_pid].underlyingLp).approve(address(gauge), amount);
		gauge.deposit(amount);

    }

    // Method to handle the compounding.
    function _compound(uint256 _pid, uint256 _amount) internal returns(uint256){
    	uint256 len = Pools[_pid].path.length;
    	address outToken = Pools[_pid].rewardToken;
    	for(uint i; i < len; i++){

    		(_amount, outToken) = _swapToken(Pools[_pid].path[i], outToken, _amount);
    	}
    	if(len > 0){
    		return _addLiquidity(outToken, Pools[_pid].underlyingLp,  _amount);
    	}else{
    		return _addLiquidity(Pools[_pid].rewardToken, Pools[_pid].underlyingLp,  _amount);
    	}
    }

    // Method to zap.
    function zap(uint256 _pid,address _inToken, uint256 _amount, address[] memory _path, address _to) public payable lock {
    	uint256 len = _path.length;

    	if(_inToken == weth){
    		IWETH(weth).deposit{value: msg.value}();
    	}else{
			safeTransferFrom(_inToken, msg.sender, address(this), _amount);
    	}

    	for(uint i; i < len; i++){
    		(_amount, _inToken) = _swapToken(_path[i], _inToken, _amount);
    	}

    	_amount = _addLiquidity(_inToken, Pools[_pid].underlyingLp, _amount);
    	
    	uint256 feeAmount = _amount.mul(zapFeePer10K).div(10000);
    	_deposit(_pid, feeAmount, owner());
    	_deposit(_pid, _amount.sub(feeAmount), _to);
    }

    // Method to unzap.
    function unzap(uint256 _pid,address _outToken, uint256 _amount, address[] memory _path, address _to) public lock {
    	uint256 len = _path.length;
    	address outToken = _outToken;
    	address token0 = IVelodromePair(Pools[_pid].underlyingLp).token0();
    	address token1 = IVelodromePair(Pools[_pid].underlyingLp).token1();

    	if(_outToken == address(0)){
    		_amount = _withdraw(_pid, _amount, msg.sender, address(this));
    		uint256 feeAmount = _amount.mul(zapFeePer10K).div(10000);

    		_deposit(_pid, feeAmount, owner());
    		safeTransfer(Pools[_pid].underlyingLp, Pools[_pid].underlyingLp, _amount.sub(feeAmount));
	    	(uint256 amount0, uint256 amount1) = IVelodromePair(Pools[_pid].underlyingLp).burn(address(this)); 
	    	if (token0 == weth) {
	    		IWETH(weth).withdraw(amount0);
	    		safeTransferETH(_to, amount0);
	    	}else{
				safeTransfer(token0, _to, amount0);
	    	}
	    	if (token1 == weth) {
	    		IWETH(weth).withdraw(amount1);
	    		safeTransferETH(_to, amount1);
	    	}else{
	    		safeTransfer(token1, _to, amount1);
	    	}
    	}else{
	    	_withdraw(_pid, _amount, msg.sender, Pools[_pid].underlyingLp);
	    	(uint256 amount0, uint256 amount1) = IVelodromePair(Pools[_pid].underlyingLp).burn(address(this)); 
	    	if(token0 == outToken){
	    		(_amount, outToken) = _swapToken(Pools[_pid].underlyingLp, token1, amount1);
	    		_amount += amount0;
	    	}else{
	    	    (_amount, outToken) = _swapToken(Pools[_pid].underlyingLp, token0, amount0);
	    	   	_amount += amount1;
			}

	    	for(uint i; i < len; i++){
	    		(_amount, outToken) = _swapToken(_path[i], outToken, _amount);
	    	}

	    	uint256 feeAmount = _amount.mul(zapFeePer10K).div(10000);

	    	if(_outToken == weth){
	    		IWETH(weth).withdraw(_amount);
	    		safeTransferETH(owner(), feeAmount);
	    		safeTransferETH(_to, _amount.sub(feeAmount));
	    	}else{
				safeTransfer(_outToken, owner(), feeAmount);
				safeTransfer(_outToken, _to, _amount.sub(feeAmount));
	    	}
    	}
    }

    //Receive Eth
    receive() external payable{}


    function safeTransferETH(address to, uint _value) internal {
        (bool success,) = to.call{value:_value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

   	function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FROM_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

}