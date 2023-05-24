// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

contract MockOracle {
    mapping(address => uint256) public tokenPrices;

    function setTokenPrice(address _token, uint256 _price) external {
        tokenPrices[_token] = _price;
    }

    function getTokenPrice(address _token) external view returns (uint256) {
        return tokenPrices[_token];
    }
}
