// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenWithLiquidityPool is ERC20 {
    using SafeMath for uint256;

    address public admin;
    uint256 public totalLiquidity;
    uint256 public ethLiquidity;

    event LiquidityAdded(address indexed provider, uint256 tokenAmount, uint256 ethAmount);
    event LiquidityRemoved(address indexed provider, uint256 tokenAmount, uint256 ethAmount);
    event TokensSwapped(address indexed swapper, uint256 ethAmount, uint256 tokenAmount);

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK"){
        _mint(msg.sender, initialSupply);
        admin = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == admin, "you are not owner");
        _;
    }

    function initializePool(uint256 _tokenAmount) external payable onlyOwner {
        require(totalLiquidity == 0, "Pool already initialized");
        require(_tokenAmount > 0 && msg.value > 0, "Invalid amounts");

        _transfer(msg.sender, address(this), _tokenAmount);
        totalLiquidity = _tokenAmount;
        ethLiquidity = msg.value;

        emit LiquidityAdded(msg.sender, _tokenAmount, msg.value);
    }

    function getPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount.mul(997);
        uint256 numerator = inputAmountWithFee.mul(outputReserve);
        uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
        return numerator.div(denominator);
    }

    function ethToToken() external payable {
        require(msg.value > 0, "ETH amount should be greater than zero");

        uint256 tokenReserve = balanceOf(address(this));
        uint256 tokensBought = getPrice(msg.value, ethLiquidity, tokenReserve);

        ethLiquidity = ethLiquidity.add(msg.value);
        totalLiquidity = totalLiquidity.sub(tokensBought);

        _transfer(address(this), msg.sender, tokensBought);

        emit TokensSwapped(msg.sender, msg.value, tokensBought);
    }

    function tokenToEth(uint256 _tokenAmount) external {
        require(_tokenAmount > 0, "Token amount should be greater than zero");

        uint256 tokenReserve = balanceOf(address(this));
        uint256 ethBought = getPrice(_tokenAmount, tokenReserve, ethLiquidity);

        totalLiquidity = totalLiquidity.add(_tokenAmount);
        ethLiquidity = ethLiquidity.sub(ethBought);

        _transfer(msg.sender, address(this), _tokenAmount);
        payable(msg.sender).transfer(ethBought);

        emit TokensSwapped(msg.sender, ethBought, _tokenAmount);
    }

    function addLiquidity(uint256 _tokenAmount) external payable onlyOwner {
        require(_tokenAmount > 0 && msg.value > 0, "Invalid amounts");

        _transfer(msg.sender, address(this), _tokenAmount);
        totalLiquidity = totalLiquidity.add(_tokenAmount);
        ethLiquidity = ethLiquidity.add(msg.value);

        emit LiquidityAdded(msg.sender, _tokenAmount, msg.value);
    }

    function removeLiquidity(uint256 _tokenAmount, uint256 _ethAmount) external onlyOwner {
        require(_tokenAmount <= totalLiquidity && _ethAmount <= ethLiquidity, "Invalid amounts");

        totalLiquidity = totalLiquidity.sub(_tokenAmount);
        ethLiquidity = ethLiquidity.sub(_ethAmount);

        _transfer(address(this), msg.sender, _tokenAmount);
        payable(msg.sender).transfer(_ethAmount);

        emit LiquidityRemoved(msg.sender, _tokenAmount, _ethAmount);
    }
}