// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract DSCEngine {

    error DSCEng_NoZeroTxPlease();

    modifier NoZeroTx (uint256 amount) {
        if (amount ==0) {
            revert DSCEng_NoZeroTxPlease();
        }
        _;
    }

    modifier IsSupportedToken (address token) {
        

    }

    constructor() {}


    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external modifier NoZeroTx(amountCollateral) {
        
    }

}