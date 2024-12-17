// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

contract MyTestContract {
    uint256 public thisShouldAlwaysBeZero = 0;

    uint256 public hiddenTrap = 0;

    function doStuff (uint256 data) public {
        if(data == 2){
            thisShouldAlwaysBeZero = 0;
        }
    }
}