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
// TWITTER:  @thekittentoken
// TELEGRAM: @TheKittenToken
// DISCORD:  https://discord.gg/aCuD638U

// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IUniswapV2Factory} from "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {CheckAddress} from "lib/check-address/contracts/CheckAddress.sol";
import {console} from "forge-std/console.sol";

// Inherited ERC20 contract uses 18 decimals.
contract CoinToken is ERC20, Ownable, ReentrancyGuard {
    using CheckAddress for address;

    IUniswapV2Router02 private immutable router;
    address public immutable pair;
    address payable private devWallet = payable(0x5AF825DFD9C2B6c61748b85974A9F175B35521fA);
    address payable private marketingWallet = payable(0xE15910F41FC6e2351A2b914B627C6bE2a9FC4af2);
    address payable private charityWallet = payable(0x09F0B837624B16c709EFce38EeA23BAB872FCD9e);
    address private constant DEAD_ADDRESS = address(0xdead);
    address private constant ZERO_ADDRESS = address(0);

    mapping(address => bool) private isExcludedFromFees;
    mapping(address => bool) private isExcludedFromMaxTransactionAmount;

    // Fees are on a scale from 0 to 1000. A fee of 1 means 0.1%, 10 means 1%.
    // Total sell fee can't be higher than max_total_sell_fee. Total buy fee can't be higher than max_total_buy_fee.
    uint8 public liquidityFee;
    uint8 public devFee;
    uint8 public marketingFee;
    uint8 public burnFee;
    uint8 public charityFee;
    uint8 private constant MAX_TOTAL_BUY_FEE = 50;
    uint8 private constant MAX_TOTAL_SELL_FEE = 50;
    // Multiplier will multiply the total fee amount. If the total fee is 2% and the sell multiplier is 150%, the new total sell fee is 3%.
    uint8 public buyMultiplier = 100;
    uint8 public sellMultiplier = 100;

    // Anti whale. Only active if limitsRemoved = false.
    uint256 private maxTransactionAmount;
    uint256 private maxWallet;

    // The swapTokensAtAmount will be dynamicly changed after every swap based on a percentage of the total supply.
    // The swapTokensAtAmountTotalSupplyPercentage is on a scale of 0 to 1000.
    uint256 private swapTokensAtAmount;
    uint8 private swapTokensAtAmountTotalSupplyPercentage = 5; // 0.5%

    bool private swapping = false;
    bool private swapEnabled = false;
    bool private limitsRemoved = false;

    // ERRORS. Errors are more gas efficient than require.
    error InvalidAddress();
    error MaxWalletExceeded();
    error MaxTransactionAmountExceeded();
    error InsufficientTokenBalance();
    error InsufficientEthBalance();
    error FailedSetter();
    error LimitsAlreadyRemoved();
    error InvalidChain();

    // EVENTS
    event SetExcludedFromFees(address indexed account, bool boolValue);
    event SetExcludedFromMaxTransaction(address indexed account, bool boolValue);
    event LimitsRemoved(uint256 maxTransactionAmount, uint256 maxWallet);
    event TransferFailed(address indexed wallet, uint256 amount);
    event AutoLiquify(uint256 amountTokens, uint256 amountETH);
    event SwapFailed(uint256 tokenAmount);
    event SetFeeUpdated(
        uint8 newLiquidityFee,
        uint8 newDevFee,
        uint8 newBurnFee,
        uint8 newMarketingFee,
        uint8 newCharityFee,
        uint16 buyMultiplier,
        uint16 sellMultiplier
    );
    event SetSwapPossibility(bool swapEnabled);
    event SetSwapTokensAtAmountPercentage(uint8 percentage);
    event SetFeeReceivers(
        address indexed newDevWalletAddress,
        address indexed newMarketingWalletAddress,
        address indexed newCharityWalletAddress
    );

    constructor(uint8 _liquidityFee, uint8 _devFee, uint8 _marketingFee, uint8 _burnFee, uint8 _charityFee)
        ERC20("Kitten Token", "KITTEN")
        Ownable(0x05D6320A78faE08aC2f06865C85076a99a8E7468)
    {
        // Total fee cannot exceed the max buy and sell limits.
        validateTotalFee(_liquidityFee, _devFee, _burnFee, _marketingFee, _charityFee, buyMultiplier, sellMultiplier);

        // Contract can be deployed on Binance, Ethereum and Arbitrum chains.
        if (block.chainid == 56) {
            // Binance
            router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        } else if (block.chainid == 1) {
            //Ethereum Mainnet
            router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        } else if (block.chainid == 42161) {
            // Arbitrum.
            router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        } else {
            revert InvalidChain();
        }

        pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());
        // Max allowance for router. ERC20 contract will not decrease allowance after transfers, so the max allowance is permanent.
        _approve(address(this), address(router), type(uint256).max);

        liquidityFee = _liquidityFee;
        devFee = _devFee;
        marketingFee = _marketingFee;
        burnFee = _burnFee;
        charityFee = _charityFee;

        uint256 startSupply = 1_000_000_000 * 10 ** decimals();
        maxTransactionAmount = startSupply / 100;
        maxWallet = startSupply / 100;
        swapTokensAtAmount = (startSupply * swapTokensAtAmountTotalSupplyPercentage) / 1000;

        isExcludedFromFees[owner()] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[devWallet] = true;
        isExcludedFromFees[marketingWallet] = true;
        isExcludedFromFees[charityWallet] = true;

        isExcludedFromMaxTransactionAmount[owner()] = true;
        isExcludedFromMaxTransactionAmount[address(this)] = true;
        isExcludedFromMaxTransactionAmount[devWallet] = true;
        isExcludedFromMaxTransactionAmount[marketingWallet] = true;
        isExcludedFromMaxTransactionAmount[charityWallet] = true;
        isExcludedFromMaxTransactionAmount[pair] = true;

        mint(owner(), startSupply);
    }

    receive() external payable {}

    ///////////////////////////////
    // CUSTOM ERC20 FUNCTIONS
    ///////////////////////////////

    function mint(address account, uint256 amount) private {
        if (account == ZERO_ADDRESS || account == DEAD_ADDRESS) {
            revert InvalidAddress();
        }

        super._update(ZERO_ADDRESS, account, amount);
    }

    function burn(address from, uint256 amount) private {
        if (from == ZERO_ADDRESS || from == DEAD_ADDRESS) {
            revert InvalidAddress();
        }

        super._update(from, ZERO_ADDRESS, amount);
    }

    // Override the ERC20 _update function to implement custom logic. super._update() will emit the Transfer event.
    function _update(address from, address to, uint256 amount) internal override {
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }

        // Basic checks if the transaction can proceed
        // super._transfer is already checking if the from or to address is the zero address.
        if (from == DEAD_ADDRESS || to == DEAD_ADDRESS) {
            revert InvalidAddress();
        }

        if (balanceOf(from) < amount) {
            revert InsufficientTokenBalance();
        }

        if (swapping) {
            super._update(from, to, amount);
            return;
        }

        // Transaction validation. All validation functions can revert the transaction at certain scenario's.
        if (from != owner() && to != owner() && !limitsRemoved) {
            maxWalletCheck(to, amount);
            maxTransactionAmountCheck(from, to, amount);
        }

        // Swapping
        if (shouldSwapBack(from, to)) {
            swapping = true;
            swapAndLiquify(checkRatio());
            swapping = false;
        }

        // Fees
        if (isFeeAppliedOnTransaction(from, to, amount)) {
            amount = processFee(amount, from, to);
        }

        // Transfer the remaining amount after the fees have been deducted.
        super._update(from, to, amount);
    }

    //////////////////////////
    // CUSTOM FUNCTIONS
    //////////////////////////

    // Add liquidity to pair. Triggered during the swapping process.
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private returns (uint256, uint256, uint256) {
        (uint256 amountTokenAddedToPool, uint256 amountETHAddedToPool, uint256 amountLiquidityToken) =
            router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, owner(), block.timestamp);

        return (amountTokenAddedToPool, amountETHAddedToPool, amountLiquidityToken);
    }

    function removeLimits() external onlyOwner {
        if (limitsRemoved) {
            revert LimitsAlreadyRemoved();
        }

        maxTransactionAmount = totalSupply();
        maxWallet = totalSupply();
        limitsRemoved = true;
        emit LimitsRemoved(maxTransactionAmount, maxWallet);
    }

    ////////////////////////////////////
    // TRANSACTION VALIDATION FUNCTIONS
    ////////////////////////////////////

    // Wallet token balance cannot be higher than the maxWallet amount unless the wallet address is excluded.
    // Function removeLimits() will set the maxWallet amount permanently to 100% of the total supply.
    function maxWalletCheck(address to, uint256 amount) private view {
        if (!isExcludedFromMaxTransactionAmount[to]) {
            if ((amount + balanceOf(to)) > maxWallet) {
                revert MaxWalletExceeded();
            }
        }
    }

    // Transaction amount cannot be higher than the maxTransactionAmount unless the wallet address is exluded.
    // Function removeLimits() will set the maxTransactionAmount amount permanently to 100% of the total supply.
    function maxTransactionAmountCheck(address from, address to, uint256 amount) private view {
        if (amount > maxTransactionAmount) {
            if (
                (from == pair && !isExcludedFromMaxTransactionAmount[to])
                    || (to == pair && !isExcludedFromMaxTransactionAmount[from])
            ) {
                revert MaxTransactionAmountExceeded();
            }
        }
    }

    ////////////////////////////////////
    // FEE FUNCTIONS
    ////////////////////////////////////

    // Check if fee must be applied on the transaction.
    function isFeeAppliedOnTransaction(address from, address to, uint256 amount) private view returns (bool) {
        return !(
            isExcludedFromFees[from] || isExcludedFromFees[to]
                || (devFee == 0 && marketingFee == 0 && burnFee == 0 && liquidityFee == 0 && charityFee == 0)
                || amount < 1000
        );
    }

    // Process the fees to the target wallet and burn tokens.
    // Process the fees to the target wallet and burn tokens.
    function processFee(uint256 tokenAmount, address from, address to) private returns (uint256) {
        uint16 multiplier = 100;
        if (from == pair) {
            multiplier = buyMultiplier;
        } else if (to == pair) {
            multiplier = sellMultiplier;
        }
        uint256 feeAmount = (tokenAmount * (liquidityFee + devFee + marketingFee + charityFee) * multiplier) / (100 * 1000);
        uint256 burnAmount = (tokenAmount * burnFee * multiplier) / (100 * 1000);
        uint256 transferAmount = tokenAmount - (feeAmount + burnAmount);

        // Transfer the fees
        if (feeAmount > 0) {
            super._update(from, address(this), feeAmount);
        }

        if (burnAmount > 0) {
            burn(from, burnAmount);
        }

        return transferAmount;
    }

    // This function is triggered after every fee structure change and will check if total fee amount will not exceed the max total fee limits.
    function validateTotalFee(
        uint8 newLiquidityFee,
        uint8 newDevFee,
        uint8 newBurnFee,
        uint8 newMarketingFee,
        uint8 newCharityFee,
        uint16 newBuyMultiplier,
        uint16 newSellMultiplier
    ) private pure {
        if (newBuyMultiplier < 50 || newBuyMultiplier > 150 || newSellMultiplier < 100 || newSellMultiplier > 200) {
            revert FailedSetter();
        }

        uint256 totalFees = newLiquidityFee + newDevFee + newBurnFee + newMarketingFee + newCharityFee;
        if ((totalFees * newBuyMultiplier) / 100 > MAX_TOTAL_BUY_FEE) {
            revert FailedSetter();
        }

        if ((totalFees * newSellMultiplier) / 100 > MAX_TOTAL_SELL_FEE) {
            revert FailedSetter();
        }
    }

    // Validate if the address is a contract or a wallet. Usint the CheckAddress library.
    function validateAddress(address account, bool isContract) private view {
        if (account == ZERO_ADDRESS || account == DEAD_ADDRESS) {
            revert FailedSetter();
        }

        if (isContract) {
            // Ensure the address is a contract
            if (!account.isContract()) {
                revert FailedSetter();
            }
        } else {
            // Ensure the address is an EOA
            if (!account.isExternal()) {
                revert FailedSetter();
            }
        }
    }

    ////////////////////////////////////
    // SWAP AND LIQUIFY FUNCTIONS
    ////////////////////////////////////

    // Check if transaction must trigger a swap.
    function shouldSwapBack(address from, address to) private view returns (bool) {
        if (
            swapEnabled && !swapping && from != pair && from != address(this) && from != owner() && to != owner()
                && balanceOf(address(this)) > swapTokensAtAmount && (getTotalFeeAmount() - burnFee) != 0
        ) {
            return true;
        } else {
            return false;
        }
    }

    // Swap contract tokens collected by tax for ETH. A paired amount of ETH and tokens are added to the pair.
    // ETH is added to the marketing, dev and charity wallets.
    // Liquidity will only be added to the pair if the liquidityFee > 0 and the backing of the pair <= 30.
    // Return values: amountEthSwapped, amountTokenAddedToPool, amountETHAddedToPool, amountLiquidityToken.
    function swapAndLiquify(uint256 ratio) private nonReentrant returns (uint256, uint256, uint256, uint256) {
        uint8 totalFee = getTotalFeeAmount() - burnFee;
        uint256 dynamicLiquidityFee = ratio > 30 ? 0 : liquidityFee;
        uint256 tokenAmountToLiquify = dynamicLiquidityFee > 0 ? (swapTokensAtAmount * dynamicLiquidityFee) / (totalFee * 2) : 0;
        uint256 amountToSwap = swapTokensAtAmount - tokenAmountToLiquify;
        uint256 amountEthBefore = address(this).balance;

        if (!swapTokensForEth(amountToSwap)) {
            emit SwapFailed(amountToSwap);
            return (0, 0, 0, 0); // Exit early if the swap failed
        }

        uint256 amountEthSwapped = address(this).balance - amountEthBefore;
        uint256 totalETHFee = dynamicLiquidityFee > 0 ? totalFee - (dynamicLiquidityFee / 2) : totalFee;

        if (marketingFee > 0) {
            (bool success,) = marketingWallet.call{value: (amountEthSwapped * marketingFee) / totalETHFee}("");
            if (!success) {
                emit TransferFailed(marketingWallet, (amountEthSwapped * marketingFee) / totalETHFee);
            }
        }

        if (devFee > 0) {
            (bool success,) = devWallet.call{value: (amountEthSwapped * devFee) / totalETHFee}("");
            if (!success) {
                emit TransferFailed(devWallet, (amountEthSwapped * devFee) / totalETHFee);
            }
        }

        if (charityFee > 0) {
            (bool success,) = charityWallet.call{value: (amountEthSwapped * charityFee) / totalETHFee}("");
            if (!success) {
                emit TransferFailed(charityWallet, (amountEthSwapped * charityFee) / totalETHFee);
            }
        }

        // Update swapTokensAtAmount because burning is reducing the total supply.
        swapTokensAtAmount = (totalSupply() * swapTokensAtAmountTotalSupplyPercentage) / 1000;

        // Add liquidity to the pair.
        if (dynamicLiquidityFee > 0) {
            uint256 amountEthToLiquify = (amountEthSwapped * dynamicLiquidityFee) / (totalETHFee * 2);
            (uint256 amountTokenAddedToPool, uint256 amountETHAddedToPool, uint256 amountLiquidityToken) =
                addLiquidity(tokenAmountToLiquify, amountEthToLiquify);
            emit AutoLiquify(amountTokenAddedToPool, amountETHAddedToPool);
            return (amountEthSwapped, amountTokenAddedToPool, amountETHAddedToPool, amountLiquidityToken);
        }

        return (amountEthSwapped, 0, 0, 0);
    }

    // This function checks if the token's pair backing (liquidity backing) exceeds a given threshold (ratio).
    // The return variable is used to decide whether liquidity must be added to the pair.
    function checkRatio() private view returns (uint256) {
        return (100 * balanceOf(pair) * 2) / totalSupply();
    }

    // Triggered by the swapAndLiquify function.
    function swapTokensForEth(uint256 tokenAmount) private returns (bool) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, 0, path, address(this), block.timestamp
        ) {
            return true;
        } catch {
            return false;
        }
    }

    ////////////////////////////////////
    // MANUAL TOKEN SEND FUNCTIONS
    ////////////////////////////////////

    // Recover any ERC20 tokens that might be accidentally sent to the contract's address.
    function clearStuckToken(address tokenAddress, uint256 tokens) external onlyOwner returns (bool) {
        if(tokenAddress == address(this)) {
            revert InvalidAddress();
        }

        if (tokens == 0) {
            tokens = ERC20(tokenAddress).balanceOf(address(this));
        }

        return ERC20(tokenAddress).transfer(owner(), tokens);
    }

    function manualSwap() external onlyOwner returns (uint256, uint256, uint256, uint256) {
        (uint256 amountEthSwapped, uint256 amountTokenReturn, uint256 amountETHReturn, uint256 liquidityReturn) =
            swapAndLiquify(checkRatio());
        return (amountEthSwapped, amountTokenReturn, amountETHReturn, liquidityReturn);
    }

    //////////////////////////
    // SETTERS
    //////////////////////////

    function setFeeWallets(address newDevWalletAddress, address newMarketingWalletAddress, address newCharityWallet)
        external
        onlyOwner
    {
        validateAddress(newDevWalletAddress, false);
        validateAddress(newMarketingWalletAddress, false);
        validateAddress(newCharityWallet, false);

        devWallet = payable(newDevWalletAddress);
        marketingWallet = payable(newMarketingWalletAddress);
        charityWallet = payable(newCharityWallet);

        isExcludedFromFees[newDevWalletAddress] = true;
        isExcludedFromFees[newMarketingWalletAddress] = true;
        isExcludedFromFees[newCharityWallet] = true;

        isExcludedFromMaxTransactionAmount[newDevWalletAddress] = true;
        isExcludedFromMaxTransactionAmount[newMarketingWalletAddress] = true;
        isExcludedFromMaxTransactionAmount[newCharityWallet] = true;

        emit SetFeeReceivers(newDevWalletAddress, newMarketingWalletAddress, newCharityWallet);
    }

    function setFees(
        uint8 newLiquidityFee,
        uint8 newDevFee,
        uint8 newBurnFee,
        uint8 newMarketingFee,
        uint8 newCharityFee,
        uint8 newBuyMultiplier,
        uint8 newSellMultiplier
    ) external onlyOwner {
        validateTotalFee(
            newLiquidityFee, newDevFee, newBurnFee, newMarketingFee, newCharityFee, newBuyMultiplier, newSellMultiplier
        );
        liquidityFee = newLiquidityFee;
        devFee = newDevFee;
        burnFee = newBurnFee;
        marketingFee = newMarketingFee;
        charityFee = newCharityFee;
        buyMultiplier = newBuyMultiplier;
        sellMultiplier = newSellMultiplier;
        emit SetFeeUpdated(
            newLiquidityFee, newDevFee, newBurnFee, newMarketingFee, newCharityFee, newBuyMultiplier, newSellMultiplier
        );
    }

    function setFeeExclusionForAccount(address account, bool boolValue) external onlyOwner {
        if (account == ZERO_ADDRESS || account == DEAD_ADDRESS) {
            revert FailedSetter();
        }

        isExcludedFromFees[account] = boolValue;
        emit SetExcludedFromFees(account, boolValue);
    }

    function setExclusionFromMaxTransaction(address account, bool boolValue) external onlyOwner {
        if (account == ZERO_ADDRESS || account == DEAD_ADDRESS || account == pair) {
            revert FailedSetter();
        }

        isExcludedFromMaxTransactionAmount[account] = boolValue;
        emit SetExcludedFromMaxTransaction(account, boolValue);
    }

    function setSwapTokensAtAmountSupplyPercentage(uint8 newSwapTokensAtAmountSupplyPercentage) external onlyOwner {
        if (newSwapTokensAtAmountSupplyPercentage < 1 || newSwapTokensAtAmountSupplyPercentage > 10) {
            revert FailedSetter();
        }

        swapTokensAtAmountTotalSupplyPercentage = newSwapTokensAtAmountSupplyPercentage;
        emit SetSwapTokensAtAmountPercentage(newSwapTokensAtAmountSupplyPercentage);
    }

    function setSwapPossibility(bool boolValue) external onlyOwner {
        swapEnabled = boolValue;
        emit SetSwapPossibility(boolValue);
    }

    //////////////////////////
    // GETTERS
    //////////////////////////

    function getTotalFeeAmount() private view returns (uint8) {
        return liquidityFee + devFee + marketingFee + burnFee + charityFee;
    }

}
