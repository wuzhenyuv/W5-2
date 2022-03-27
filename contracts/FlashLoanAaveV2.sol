//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@aave/protocol-v2/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
//import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";


contract FlashLoanAaveV2 is FlashLoanReceiverBase {
    //rinkeby address
    uint24 private constant poolFee = 3000;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant ATOKEN = 0x30BE9592439516A433f77924Fb34ca14ac675686;
    address private constant BAT = 0x2d12186Fbb9f9a8C28B3FfdD4c42920f8539D738;
    address private constant SWAPROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant DEVADDRESS = 0x6aCB38f47C14594F58614B89Aac493e1Ab3B4C34;

    constructor(ILendingPoolAddressesProvider _addressProvider)
        public
        FlashLoanReceiverBase(_addressProvider)
    {}

    //aave上借BAT
    function flashSwap(address _loanToken, uint256 _amount) public {
        address receiver = address(this);
        address[] memory assets = new address[](1);
        assets[0] = _loanToken;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;
        LENDING_POOL.flashLoan(
            receiver,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        //uniswap V2上用借来的BAT兑换ATOKEN
        address[] memory path = new address[](2);
        path[0] = BAT;
        path[1] = ATOKEN;
        uint256 batAmount = IERC20(BAT).balanceOf(address(this));
        IERC20(BAT).approve(UNISWAP_V2_ROUTER, batAmount);
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            batAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        //调用uniswap v3 swap token
        uint256 amountToken = IERC20(ATOKEN).balanceOf(address(this));
        IERC20(ATOKEN).approve(SWAPROUTER, amountToken);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: ATOKEN,
                tokenOut: BAT,
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
        uint256 amountRequired = amounts[0] + premiums[0];
        IERC20(assets[0]).approve(address(LENDING_POOL), amountRequired);
        IERC20(assets[0]).transfer(DEVADDRESS, amountOut - amountRequired); //套利所得给开发者
        return true;
    }
}
