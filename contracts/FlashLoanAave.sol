//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract FlashLoanAave is FlashLoanSimpleReceiverBase {
    //rinkeby address
    uint24 private constant poolFee = 3000;
    address private constant UNISWAP_V2_ROUTER =0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address private constant ATOKEN =0x784c47Ba17A32e9C636cf917c9034c0aD1E87d41;
    address private constant SWAPROUTER =0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant DEVADDRESS =0x6aCB38f47C14594F58614B89Aac493e1Ab3B4C34;

    constructor(IPoolAddressesProvider provider)
        public
        FlashLoanSimpleReceiverBase(provider)
    {}

    //aave上借eth
    function flashSwap(address _loanToken, uint256 _amount) public {
        bytes memory params = "";
        uint16 referralCode = 0;
        POOL.flashLoanSimple( //aave单币种借贷
            address(this),
            _loanToken,
            _amount,
            params,
            referralCode
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        //V2兑换ATOKEN
        address[] memory path;
        path[0] = WETH;
        path[1] = ATOKEN;
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactETHForTokens(
            0,
            path,
            address(this),
            block.timestamp
        );
        //调用uniswap v3 swap token
        uint256 amountToken = IERC20(ATOKEN).balanceOf(address(this));
        TransferHelper.safeApprove(ATOKEN, address(SWAPROUTER), amountToken);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: ATOKEN,
                tokenOut: WETH,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountToken,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        //调用v3 swap获得的代币数量
        uint256 amountOut = ISwapRouter(SWAPROUTER).exactInputSingle(params);
        //还款aave
        uint256 amountRequired = amount + premium;
        IERC20(asset).approve(address(POOL), amountRequired);
        IERC20(asset).transfer(DEVADDRESS, amountOut - amountRequired); //套利所得给开发者
        return true;
    }
}
