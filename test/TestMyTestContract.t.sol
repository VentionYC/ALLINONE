// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {MyTestContract} from "../src/MyTestContract.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract TestMyTestContract is StdInvariant, Test {
    MyTestContract myContract;

    function setUp() public {
        myContract = new MyTestContract();
        targetContract(address(myContract));
    }

    function testAlwaysZero(uint256 data) public {
        myContract.doStuff(data);
        assert(myContract.thisShouldAlwaysBeZero() == 0);
    }

    function invariant_statefulTestAlwaysZero() public {
        assert(myContract.thisShouldAlwaysBeZero() == 0);
    }


}