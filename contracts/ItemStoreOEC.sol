// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IJswapRouter {
    function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);
}

contract ItemStoreOEC is Ownable {
    mapping(address => uint256) public nonces;
    mapping(uint256 => uint256) public itemPrices;
    IJswapRouter immutable jswapRouter;

    constructor(IJswapRouter _jswapRouter) {
        jswapRouter = _jswapRouter;
    }

    function setPrices(uint256[] calldata ids, uint256[] calldata prices) external onlyOwner {
        require(ids.length == prices.length, "Maidverse: Length not equal");
        for(uint256 i = 0; i < ids.length; i++) {
            itemPrices[ids[i]] = prices[i];
        }
    }

    function priceAsOKT(uint256 priceAsETH) public view returns(uint256) {
        address[] memory path = new address[](3);
        path[0] = address(0x8F8526dbfd6E38E3D8307702cA8469Bae6C56C15);
        path[1] = address(0x382bB369d343125BfB2117af9c149795C6C65C50);
        path[2] = address(0xEF71CA2EE68F45B9Ad6F72fbdb33d707b872315C);
        return jswapRouter.getAmountsIn(priceAsETH, path)[0];
    }

    function buyItem(bytes32 hash, uint256 itemId) external payable {
        require(hash == keccak256(abi.encodePacked(msg.sender, nonces[msg.sender]++, itemId)), "Maidverse: Wrong hash");
        require(msg.value > 0, "Maidverse: Wrong price");

        uint256 _priceAsOKT = priceAsOKT(itemPrices[itemId]);
        require(msg.value >= _priceAsOKT, "Maidverse: Wrong price");

        if(msg.value > _priceAsOKT) payable(msg.sender).transfer(msg.value - _priceAsOKT);
    }

    function buyItems(bytes32[] calldata hashes, uint256[] calldata itemIds) external payable {
        require(hashes.length == itemIds.length, "Maidverse: Length not equal");
        require(msg.value > 0, "Maidverse: Wrong price");

        uint256 nonce = nonces[msg.sender];
        uint256 price;
        for(uint256 i = 0; i < hashes.length; i++) {
            require(hashes[i] == keccak256(abi.encodePacked(msg.sender, nonce++, itemIds[i])), "Maidverse: Wrong hash");
            price += itemPrices[itemIds[i]];
        }

        uint256 _priceAsOKT = priceAsOKT(price);
        require(msg.value >= _priceAsOKT, "Maidverse: Wrong price");

        if(msg.value > _priceAsOKT) payable(msg.sender).transfer(msg.value - _priceAsOKT);

        nonces[msg.sender] = nonce;
    }

    function withdraw(address payable recipient, address token, uint256 amount) external onlyOwner {
        if(token == address(0)) {
            uint256 oktBal = address(this).balance;
            require(oktBal > 0, "Maidverse: Zero amount");
            if(oktBal < amount) amount = oktBal;
            recipient.transfer(amount);
        } else {
            uint256 tokenBal = IERC20(token).balanceOf(address(this));
            require(tokenBal > 0, "Maidverse: Zero amount");
            if(tokenBal < amount) amount = tokenBal;
            SafeERC20.safeTransfer(IERC20(token), recipient, amount);
        }
    }
}