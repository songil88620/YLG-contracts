// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Storage {

    uint256 number;
    string public name = "";
    uint8 public  decimal = 10;


    constructor(
        string memory n,
        uint8 d       
    ) {
        name = n;
        decimal = d;
    }

  
    function store(uint256 num) public {
        number = num;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256){
        return number;
    }

    function getName() public view returns (string memory){
        return name;
    }

    function getDecimal() public view returns (uint8){
        return decimal;
    }
}