///////////////////////////////////////////
// KITTEN TOKEN
///////////////////////////////////////////

//      /\_____/\
//     /  o   o  \
//    ( ==  ^  == )
//     )           (
//    (             )
//   ( (  )   (  )   )
//  (__(__)___(__)__)

// WEBSITE: KITTENTOKEN.NET
// SOCIAL MEDIA
    // TWITTER:
    // TELEGRAM:
    // DISCORD:

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;   

import {ERC20}              from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable}            from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IUniswapV2Factory}  from "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ReentrancyGuard}    from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract CoinToken is ERC20, Ownable, ReentrancyGuard {

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public uniswapV2Pair;
    address payable private devWallet;
    address payable public marketingWallet;
    address payable public charityWallet;
    address private constant DEAD_ADDRESS = address(0xdead);
    address private constant ZERO_ADDRESS = address(0);
    
    mapping(address => bool)    private  isExcludedFromFees;
    mapping(address => bool)    private  isExcludedFromMaxTransactionAmount;
    mapping(address => bool)    private  automatedMarketMakerPairs;
    // Bot are manually added by the owner to this mapping. Bots are only restricted from trading as long as limitsRemoved = false.
    mapping(address => bool)    private  bots;
    mapping(address => uint256) private  tokenHolderLastTransferBlockNumber;

    // Fees are on a scale from 0 to 1000. A fee of 1 means 0.1%, 10 means 1%. 
    // Total sell fee can't be higher than max_total_sell_fee. Total buy fee can't be higher than max_total_buy_fee. 
    uint8 public liquidityFee;
    uint8 public devFee;
    uint8 public marketingFee;
    uint8 public burnFee;
    uint8 public charityFee;
    uint8 private constant maxTotalBuyFee  = 50;
    uint8 private constant maxTotalSellFee = 50;
    // Multiplier will multiply the total fee amount. If the total fee is 2% and the sell multiplier is 150%, the new total sell fee is 3%.
    uint16 public buyMultiplier = 100;  
    uint16 public sellMultiplier = 100;

    // Anti whale. 
    uint256 public maxTransactionAmount;
    uint256 public maxWallet;

    // The swapTokensAtAmount will be dynamicly changed after every swap based on a percentage of the total supply. 
    // The swapTokensAtAmountTotalSupplyPercentage is on a scale of 0 to 1000.
    uint256 private swapTokensAtAmount;
    uint8   private swapTokensAtAmountTotalSupplyPercentage;

    bool private isTradingOpen = false;
    bool private swapping = false;
    bool private swapEnabled = false;
    bool private transferDelayEnabled = true;
    bool private limitsRemoved = false;

    // ERRORS. Errors are more gas efficient than require.
    error ZeroAddress();
    error DeadAddress();
    error TransferExceedsBalance();
    error TransferFailed();
    error TransferDelayAlreadyDisabled();
    error TransferDelayTryAgainLater();
    error MaxWalletExceeded();
    error ToSmallOrToLargeTransactionAmount();
    error InsufficientTokenBalance();
    error InsufficientEthBalance();
    error TradingIsAlreadyOpen();
    error TradingClosed();
    error FailedSetter();
    error LimitsAlreadyRemoved();

    // EVENTS
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed boolValue);
    event SetExcludedFromFees(address indexed account, bool boolValue);
    event SetExcludedFromMaxTransaction(address indexed account, bool boolValue);
    event LimitsRemoved(uint256 maxTransactionAmount, uint256 maxWallet);
    event TradingOpened(uint256 timestamp);
    event AutoLiquify(uint256 amountTokens, uint256 amountETH);
    event SetFeeUpdated(uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee, uint8 newCharityFee, uint16 buyMultiplier, uint16 sellMultiplier);
    event SetSwapPossibility(bool swapEnabled);
    event SetSwapTokensAtAmountPercentage(uint8 percentage);
    event SetFeeReceivers(address indexed newDevWalletAddress, address indexed newMarketingWalletAddress, address indexed newCharityWalletAddress);
    
    constructor(address _initialOwner,
                uint256 _tokenSupply, 
                address _routerAddress,
                uint8   _lqFee,
                uint8   _devFee,
                uint8   _marketingFee,
                uint8   _burnFee,
                uint8   _charityFee,
                address _devWallet,
                address _marketingWallet,
                address _charityWallet
    ) ERC20('Kitten Token', 'KITTEN') 
      Ownable(_initialOwner) {
        // Total fee cannot exceed the max buy and sell limits.
        validateTotalFee(_lqFee, _devFee, _burnFee, _marketingFee, _charityFee, buyMultiplier, sellMultiplier);

        uniswapV2Router = IUniswapV2Router02(_routerAddress);
        uniswapV2Pair   = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        liquidityFee = _lqFee;
        devFee = _devFee;
        marketingFee = _marketingFee;
        burnFee = _burnFee;
        charityFee = _charityFee;
        maxTransactionAmount = _tokenSupply / 100;
        maxWallet = _tokenSupply / 100;
        swapTokensAtAmountTotalSupplyPercentage =  5; // 0.5%
        swapTokensAtAmount = (_tokenSupply * swapTokensAtAmountTotalSupplyPercentage) / 1000;
        devWallet       = payable(_devWallet);
        marketingWallet = payable(_marketingWallet);
        charityWallet   = payable(_charityWallet);

        isExcludedFromFees[_initialOwner]    =  true;
        isExcludedFromFees[address(this)]    =  true;
        isExcludedFromFees[_devWallet]       =  true;
        isExcludedFromFees[_marketingWallet] =  true;
        isExcludedFromFees[_charityWallet]   =  true;

        isExcludedFromMaxTransactionAmount[_initialOwner]    = true;
        isExcludedFromMaxTransactionAmount[address(this)]    = true;
        isExcludedFromMaxTransactionAmount[_devWallet]       = true;
        isExcludedFromMaxTransactionAmount[_marketingWallet] = true;
        isExcludedFromMaxTransactionAmount[_charityWallet]   = true;
        isExcludedFromMaxTransactionAmount[uniswapV2Pair]    = true;

        automatedMarketMakerPairs[uniswapV2Pair] = true;

        mint(address(_initialOwner), _tokenSupply);
    }

    receive() external payable {}

    ///////////////////////////////
    // CUSTOM ERC20 FUNCTIONS
    ///////////////////////////////

    function mint(address account, uint256 amount) private {
        if (account == ZERO_ADDRESS) revert ZeroAddress();
        super._update(ZERO_ADDRESS, account, amount);
    }

    function burn(address from, uint256 amount) private {
        if (!isTradingOpen) revert TradingClosed();
        if (from == ZERO_ADDRESS) revert ZeroAddress();
        super._update(from, ZERO_ADDRESS, amount);
    }

    // Override the ERC20 _update function to implement custom logic. super._update() will emit Transfer event.
    function _update(address from, address to, uint256 amount) internal override {
        // Basic checks if the transaction can proceed
        // Before trading is open no transaction should succeed, except owner transactions and the transaction related to the initial adding of liquidity to the uniswap pair.
        if (!isTradingOpen && !(from == owner()) && !(from == address(this) && to == uniswapV2Pair)) revert TradingClosed();
        if (!limitsRemoved && (bots[from] || bots[to])) revert TransferFailed();
        if (from == DEAD_ADDRESS || to == DEAD_ADDRESS) revert DeadAddress();  
        if (balanceOf(from) < amount) revert TransferExceedsBalance();
        if (amount < 1000) revert ToSmallOrToLargeTransactionAmount();
        if (swapping) {
            super._update(from, to, amount);
            return;
        }

        // Transaction validation. All check functions could revert the transaction at certain scenario's.
        if (from != owner() && to != owner()) {
            if(transferDelayEnabled) delayTransactionCheck(from, to);
            if(!limitsRemoved) {
                maxWalletCheck(to, amount);
                maxTransactionAmountCheck(from, to, amount);
            }
        }

        // Swapping
        if(shouldSwapBack(from)) {
            swapping = true;
            swapAndLiquify(checkRatio());
            swapping = false;
        }

        // Fees
        if (isFeeAppliedOnTransaction(from, to)) amount = processFee(amount, from, to);

        // Transfer the remaining amount after the fees have been deducted.
        super._update(from, to, amount);
    }

    //////////////////////////
    // CUSTOM FUNCTIONS
    //////////////////////////

    // Add liquidity to Uniswap pair.
    // This contract must have at least 10 ETH available before calling this function.
    function addLqToUniswap() external onlyOwner() {
        if(isTradingOpen) revert TradingIsAlreadyOpen();
        uint256 eth_balance = address(this).balance;
        if(eth_balance < 10 ether) revert InsufficientEthBalance();
        transfer(address(this), balanceOf(owner()));
        addLiquidity(balanceOf(address(this)), eth_balance);
    }

    function openTrading() external onlyOwner() {
        if(isTradingOpen) revert TradingIsAlreadyOpen();
        isTradingOpen = true;
        swapEnabled = true;
        emit TradingOpened(block.timestamp);
    }

    // Add liquidity to Uniswap V2 pool. Triggered during the initial liquidity addition and during the swapping process.
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private returns (uint256, uint256, uint256) {
        if(balanceOf(address(this)) <  tokenAmount) revert InsufficientTokenBalance();
        if(address(this).balance    <  ethAmount)   revert InsufficientEthBalance();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        (uint256 amountTokenAddedToPool, uint256 amountETHAddedToPool, uint256 amountLiquidityToken) = uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(), 
            block.timestamp
        );

        return (amountTokenAddedToPool, amountETHAddedToPool, amountLiquidityToken);
    }

    ////////////////////////////////////
    // TRANSACTION VALIDATION FUNCTIONS
    ////////////////////////////////////

    // When transfer delay is enabled a not excluded user can only make 1 transaction in one block.
    // Transfer delay is permanent disabled after the function removeLimits() successfully ran.
    function delayTransactionCheck(address from, address to) private {
        if (transferDelayEnabled && !isExcludedFromFees[from] && !isExcludedFromFees[to] && to != address(uniswapV2Router) && !automatedMarketMakerPairs[to] && !isExcludedFromMaxTransactionAmount[to]) {
            if(tokenHolderLastTransferBlockNumber[tx.origin] >= block.number || tokenHolderLastTransferBlockNumber[to] >= block.number) {
                revert TransferDelayTryAgainLater();
            }
            tokenHolderLastTransferBlockNumber[tx.origin] = block.number;
            tokenHolderLastTransferBlockNumber[to]        = block.number;
        }
    }

    // Wallet token balance cannot be higher than the maxWallet amount unless the wallet address is excluded.
    // Function removeLimits() will set the maxWallet amount permanently to 100% of the total supply.
    function maxWalletCheck(address to, uint256 amount) private view {
        if (to != address(this) && !automatedMarketMakerPairs[to] && !isExcludedFromMaxTransactionAmount[to]){
            if(amount + balanceOf(to) > maxWallet) revert MaxWalletExceeded();
        }
    }

    // Transaction amount cannot be higher than the maxTransactionAmount unless the wallet address is exluded.
    // Function removeLimits() will set the maxTransactionAmount amount permanently to 100% of the total supply.
    function maxTransactionAmountCheck(address from, address to, uint256 amount) private view {
        if(amount > maxTransactionAmount) {
            if (
                (automatedMarketMakerPairs[from] && !isExcludedFromMaxTransactionAmount[to]) 
                ||
                (automatedMarketMakerPairs[to] && !isExcludedFromMaxTransactionAmount[from])
            ) revert ToSmallOrToLargeTransactionAmount();
        }
    }

    ////////////////////////////////////
    // FEE FUNCTIONS
    ////////////////////////////////////

    // Check if fee must be applied on the transaction
    function isFeeAppliedOnTransaction(address from, address to) private view returns(bool) {
        return !(   isExcludedFromFees[from] 
                    || isExcludedFromFees[to]
                    || (devFee == 0 && marketingFee == 0 && burnFee == 0 && liquidityFee == 0 && charityFee == 0)
        );
    }

    // Process the fees to the target wallets and burn tokens.
    function processFee(uint256 tokenAmount, address from, address to) private returns(uint256) {
            uint16 multiplier = 100;
            if (automatedMarketMakerPairs[from]) {
                multiplier = buyMultiplier;
            } else if (automatedMarketMakerPairs[to]) {
                multiplier = sellMultiplier;
            }
            uint256 feeAmount       = (tokenAmount * (liquidityFee + devFee + marketingFee + charityFee) * multiplier) / (100 * 1000);
            uint256 burnAmount      = (tokenAmount * burnFee * multiplier) / (100 * 1000);
            uint256 transferAmount  = tokenAmount - feeAmount - burnAmount;
            
            // Transfer the fees
            if(feeAmount  > 0) super._update(from, address(this), feeAmount);
            if(burnAmount > 0) burn(from, burnAmount);

            return transferAmount;
    }

    // This function is triggered after every fee structure change and will check if total fee amount will not exceed the max total fee limits.
    function validateTotalFee(uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee, uint8 newCharityFee, uint16 newBuyMultiplier, uint16 newSellMultiplier) private pure {
        if(newBuyMultiplier < 50 || newBuyMultiplier > 150 || newSellMultiplier < 100 || newSellMultiplier > 200) revert FailedSetter();
        uint256 totalFees = newLiquidityFee + newDevFee + newBurnFee + newMarketingFee + newCharityFee;
        if((totalFees * newBuyMultiplier)  / 100 > maxTotalBuyFee)  revert FailedSetter();
        if((totalFees * newSellMultiplier) / 100 > maxTotalSellFee) revert FailedSetter();
    }

    ////////////////////////////////////
    // SWAP AND LIQUIFY FUNCTIONS
    ////////////////////////////////////

    // Check if transaction must trigger a swap.
    function shouldSwapBack(address from) private view returns(bool) {
        if(swapEnabled && !swapping && !automatedMarketMakerPairs[from] && from != address(this) && balanceOf(address(this)) > swapTokensAtAmount && (getTotalFeeAmount() - burnFee) != 0) {
            return true;
        }
        else {
            return false;
        }
    }

    // Swap tax and liquidity tokens for ETH. The ETH is added to the Uniswap pair and the marketing and dev wallets.
    // Liquidity will only be added to the pair if the liquidityFee > 0 and the backing of the Uniswap pair <= 30.
    function swapAndLiquify(uint256 ratio) private nonReentrant returns (uint256, uint256, uint256, uint256) {
        uint8   totalFee = getTotalFeeAmount() - burnFee;
        uint256 dynamicLiquidityFee = ratio > 30 ? 0 : liquidityFee;
        uint256 tokenAmountToLiquify = dynamicLiquidityFee > 0 ? (swapTokensAtAmount * dynamicLiquidityFee) / totalFee / 2: 0;
        uint256 amountToSwap = swapTokensAtAmount - tokenAmountToLiquify;

        uint256 amountEthBefore = address(this).balance;
        swapTokensForEth(amountToSwap);
        uint256 amountEthSwapped = address(this).balance - amountEthBefore;

        uint256 totalETHFee = dynamicLiquidityFee > 0 ? totalFee - (dynamicLiquidityFee/2) : totalFee;

        // Transfer ETH to the fee receivers
        if(marketingFee > 0) marketingWallet.call{value: (amountEthSwapped * marketingFee) / totalETHFee}("");
        if(devFee > 0)       devWallet.call{value: (amountEthSwapped * devFee) / totalETHFee}("");
        if(charityFee > 0)   charityWallet.call{value: (amountEthSwapped * charityFee) / totalETHFee}("");

        // Update swapTokensAtAmount because burning is reducing the total supply.
        swapTokensAtAmount = (totalSupply() * swapTokensAtAmountTotalSupplyPercentage) / 1000;

        // Add liquidity to Uniswap pair.
        if (dynamicLiquidityFee > 0) {
            uint256 amountEthToLiquify = (amountEthSwapped * dynamicLiquidityFee) / totalETHFee / 2;
            (uint256 amountTokenAddedToPool, uint256 amountETHAddedToPool, uint256 amountLiquidityToken) = addLiquidity(tokenAmountToLiquify, amountEthToLiquify);
            emit AutoLiquify(amountTokenAddedToPool, amountETHAddedToPool);
            return (amountEthSwapped, amountTokenAddedToPool, amountETHAddedToPool, amountLiquidityToken);
        }

        return(amountEthSwapped, 0, 0, 0);
    }

    // This function checks if the token's Uniswap pair backing (liquidity backing) exceeds a given threshold (ratio).
    // The return variable is used to decide whether liquidity must be added to the Uniswap pair.
    function checkRatio() private view returns(uint256) {
        return (100 * balanceOf(uniswapV2Pair) * 2) / totalSupply();
    }

    // Triggered by the swapAndLiquify function. 
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    ////////////////////////////////////
    // MANUAL TOKEN SEND FUNCTIONS
    ////////////////////////////////////

    // Recover any ERC20 tokens that might be accidentally sent to the contract's address.
    function clearStuckToken(address tokenAddress, uint256 tokens) external onlyOwner() returns(bool) {
        if(tokens == 0) tokens = ERC20(tokenAddress).balanceOf(address(this));
        return ERC20(tokenAddress).transfer(owner(), tokens);
    }

    function manualSwap() external onlyOwner() returns(uint256, uint256, uint256, uint256) {
        (uint256 amountEthSwapped, uint256 amountTokenReturn, uint256 amountETHReturn, uint256 liquidityReturn) = swapAndLiquify(checkRatio());
        return (amountEthSwapped, amountTokenReturn, amountETHReturn, liquidityReturn);
    }

    //////////////////////////
    // SETTERS
    //////////////////////////

    function setFeeWallets(address newDevWalletAddress, address newMarketingWalletAddress, address newCharityWallet) external onlyOwner() {
        if(newDevWalletAddress == ZERO_ADDRESS || newMarketingWalletAddress == ZERO_ADDRESS || newCharityWallet == ZERO_ADDRESS) revert FailedSetter();
        devWallet       = payable(newDevWalletAddress);
        marketingWallet = payable(newMarketingWalletAddress);
        charityWallet   = payable(newCharityWallet);
        emit SetFeeReceivers(newDevWalletAddress, newMarketingWalletAddress, newCharityWallet);
    }

    function setFees(uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee, uint8 newCharityFee, uint16 newBuyMultiplier, uint16 newSellMultiplier) external onlyOwner() {
        validateTotalFee(newLiquidityFee, newDevFee, newBurnFee, newMarketingFee, newCharityFee, newBuyMultiplier, newSellMultiplier);
        liquidityFee = newLiquidityFee;
        devFee = newDevFee;
        burnFee = newBurnFee;
        marketingFee = newMarketingFee;
        charityFee = newCharityFee;
        buyMultiplier = newBuyMultiplier;
        sellMultiplier = newSellMultiplier;
        emit SetFeeUpdated(newLiquidityFee, newDevFee, newBurnFee, newMarketingFee, newCharityFee, newBuyMultiplier, newSellMultiplier);
    }

    function setFeeExclusionForAccount(address account, bool boolValue) external onlyOwner() {
        if(account == ZERO_ADDRESS) revert FailedSetter();
        isExcludedFromFees[account] = boolValue;
        emit SetExcludedFromFees(account, boolValue);
    }

    function setExclusionFromMaxTransaction(address account, bool boolValue) external onlyOwner() {
        if(account == ZERO_ADDRESS) revert FailedSetter();
        isExcludedFromMaxTransactionAmount[account] = boolValue;
        emit SetExcludedFromMaxTransaction(account, boolValue);
    }

    function setAutomatedMarketMakerPair(address pair, bool boolValue) external onlyOwner() {
        if(pair == uniswapV2Pair || pair == ZERO_ADDRESS) revert FailedSetter();
        automatedMarketMakerPairs[pair] = boolValue;
        emit SetAutomatedMarketMakerPair(pair, boolValue);
    }

    function addBots(address[] memory _bots) external onlyOwner {
        for (uint i = 0; i < _bots.length; i++) {
            bots[_bots[i]] = true;
        }
    }

    function delBots(address[] memory _notBot) external onlyOwner {
      for (uint i = 0; i < _notBot.length; i++) {
          bots[_notBot[i]] = false;
      }
    }

    function removeLimits() external onlyOwner {
        if(limitsRemoved) revert LimitsAlreadyRemoved();
        maxTransactionAmount = totalSupply();
        maxWallet = totalSupply();
        transferDelayEnabled = false;
        limitsRemoved = true;
        emit LimitsRemoved(maxTransactionAmount, maxWallet);
    }       

    function setSwapTokensAtAmountSupplyPercentage(uint8 newSwapTokensAtAmountSupplyPercentage) external onlyOwner {
        if(newSwapTokensAtAmountSupplyPercentage < 1 || newSwapTokensAtAmountSupplyPercentage > 10) revert FailedSetter();
        swapTokensAtAmountTotalSupplyPercentage = newSwapTokensAtAmountSupplyPercentage;
        emit SetSwapTokensAtAmountPercentage(newSwapTokensAtAmountSupplyPercentage);
    } 

    function setSwapPossibility(bool boolValue) external onlyOwner {
        swapEnabled = boolValue;
        emit SetSwapPossibility(boolValue);
    }

    function stopTransferDelay() external onlyOwner {
        if(!transferDelayEnabled) revert TransferDelayAlreadyDisabled();
        transferDelayEnabled = false;
    }

    //////////////////////////
    // GETTERS
    //////////////////////////

    function getTotalFeeAmount() private view returns(uint8) {
        return liquidityFee + devFee + marketingFee + burnFee + charityFee;
    }

    function getBot(address account) external view onlyOwner returns(bool) {
        return bots[account];
    }

}
