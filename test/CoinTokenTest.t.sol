// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test} from "forge-std/Test.sol";
import {CoinToken} from "../src/CoinToken.sol";
import {DeployCoinToken} from "../script/DeployCoinToken.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {console} from "forge-std/console.sol"; // Import console.sol for logging
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Address} from "lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Pair} from "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory}  from "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {TestToken} from "./TestToken.sol";

// Forge test command will include all test functions with 'test' in the name.
// Some functions are commented because they exceed the max local variables (16). See foundry.toml. This causes the compiler to run way longer.
// TEST PRIVATE FUNCTIONS INDIRECT BY CALLING ANOTHER TEMPORARY TOKEN CONTRACT FUNCTIONS
// function startPrank(address sender, address origin) external;
// Transfer delay enabled test functions will not work properly if via_ir=true in foundry.toml file.
contract CoinTokenTest is StdCheats,Test {
    using Address for address;
    CoinToken coinToken;
    TestToken testToken;
    HelperConfig.NetworkConfig config;
    address owner_address;
    address marketingWallet;
    address devWallet;
    address charityWallet;
    uint256 decimals;
    address TEAM_WALLET   = makeAddr('team_wallet');
    address TEAM_WALLET_VESTED   = makeAddr('team_vested');
    address PRESALEWALLET = makeAddr('presale');
    address USER  = makeAddr('user'); //create fake user
    address USER1 = makeAddr('user1'); //create fake user
    address USER2 = makeAddr('user2'); //create fake user
    address USER3 = makeAddr('user3'); //create fake user
    address USER4 = makeAddr('user4'); //create fake user
    uint256 constant STARTING_USER_BALANCE = 10 ether; //give fake user balance later on in the code
    uint8 token_amount_percentage_liquidity_start = 30;
    IUniswapV2Pair public pair;
    IUniswapV2Router02 public router;
    address constant weth_address_mainnet = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniswapV2Factory public factory;
    uint256 tokenAmountPresale;
    uint256 tokenAmountUniswap;
    uint256 tokenAmountTeamVested;
    uint256 tokenAmountOwner;

    // ERRORS. It is not possible to get the errors like this: coinToken.ZeroAddress. Have to manually import the errors like below.
    // Can check for specific errors: vm.expectRevert(abi.encodeWithSelector(InsufficientEthBalance.selector));
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
    error InvalidLiquidityPercentage();

    function setUp() external {
        DeployCoinToken deployCoinToken = new DeployCoinToken();
        (coinToken, config) = deployCoinToken.run();
        decimals =   coinToken.decimals();
        router   =   IUniswapV2Router02(coinToken.uniswapV2Router());
        pair     =   IUniswapV2Pair(coinToken.uniswapV2Pair()); //getUniswapV2Pair()
        factory  =   IUniswapV2Factory(IUniswapV2Pair(pair).factory());
        devWallet = coinToken.getDevWallet();
        marketingWallet = coinToken.getMarketingWallet();
        charityWallet = coinToken.charityWallet();
        testToken = new TestToken();
        console.log('Pair address: ', address(pair));
        console.log('factory address: ', address(factory));
        //console.log('Testtoken address: ', address(testToken));
        console.log('Router address: ', address(router));
        console.log('Address testcontract: ', address(this));
        console.log('Address weth eth mainnet: ', router.WETH());
        console.log('Address token: ', address(coinToken));
        console.log('Address dev wallet: ', address(coinToken.getDevWallet()));
        console.log('Address marketing wallet: ', address(coinToken.getMarketingWallet()));
        console.log('Address charity wallet: ', address(coinToken.charityWallet()));
        //Programmatically allocate Ether to an address within the testing environment.
        vm.deal(USER, STARTING_USER_BALANCE); //give fake user balance
        vm.deal(address(coinToken), 40 ether);
        owner_address = coinToken.owner();
        vm.deal(address(coinToken.owner()), STARTING_USER_BALANCE);
        console.log('Address fake user: ', address(USER));
        console.log('Starting cointoken balance fake user: ', coinToken.balanceOf(USER));
        console.log('Starting ETH balance fake user: ', address(USER).balance);
        console.log('Address fake user1: ', address(USER1));
        console.log('Starting cointoken balance fake user1: ', coinToken.balanceOf(USER1));
        console.log('Starting ETH balance fake user1: ', address(USER1).balance);
        console.log('Address fake user2: ', address(USER2));
        console.log('Starting cointoken balance fake user2: ', coinToken.balanceOf(USER2));
        console.log('Starting ETH balance fake user2: ', address(USER2).balance);
        console.log('Address fake user3: ', address(USER3));
        console.log('Starting cointoken balance fake user3: ', coinToken.balanceOf(USER3));
        console.log('Starting ETH balance fake user3: ', address(USER3).balance);
        console.log('Address fake user3: ', address(USER4));
        console.log('Starting cointoken balance fake user3: ', coinToken.balanceOf(USER4));
        console.log('Starting ETH balance fake user3: ', address(USER4).balance);
        console.log('Address owner: ', address(owner_address));
        console.log('Starting cointoken balance owner: ', coinToken.balanceOf(owner_address));
        console.log('Starting ETH balance owner: ', address(owner_address).balance);
        console.log('Address cointoken: ', address(coinToken));
        console.log('Starting cointoken balance cointoken: ', coinToken.balanceOf(address(coinToken)));
        console.log('Starting ETH balance cointoken: ', address(coinToken).balance);
        console.log('END SETUP LOG -------------------------------------');
        console.log('-------------------------------------------');
    }

    ///////////////////////////////////////////////////
    // HELPER FUNCTIONS FOR REPEATING TESTING TASKS.
    ///////////////////////////////////////////////////

    // In the constructor all tokens are minted to the owner. This function will send tokens from the owner to a user. 
    // This test function will be called from multiple other test functions. Make you sure you dont nest pranks.
    function sendTokensFromOwnerTo(address to, uint256 tokenAmount, bool proceed_to_next_block) public {
        console.log('Send tokens from the owner to ', to, ' . Amount of tokens: ', tokenAmount);
        vm.startPrank(owner_address, owner_address);
        uint256 ownerBalanceBefore = coinToken.balanceOf(owner_address);
        uint256 userBalanceBefore  = coinToken.balanceOf(to);
        // Owner can send more than max transaction amount
        coinToken.transfer(address(to), tokenAmount);
        assertEq(ownerBalanceBefore - tokenAmount, coinToken.balanceOf(owner_address), 'sendTokensFromOwner. Invalid owner balance');
        assertEq(userBalanceBefore + tokenAmount, coinToken.balanceOf(to), 'sendTokensFromOwner. Invalid to address balance');
        vm.stopPrank();

        if(proceed_to_next_block) {
            console.log('Current block number: ', block.number);
            vm.roll(block.number + 1);
            console.log('Rolling to next block number: ', block.number);
        }
        console.log('END SENDING TOKENS FROM OWNER TO ..................');
    }

    // Buy tokens with eth. From is pair to is user. All eth is always used in the uniswap function.
    // Trading must be opened before calling this function. Test with owner so no transaction checks and fees are applied.
    // Cannot test the exact number of token balances (because of possible taxes). Can test for exact eth amount balances.
    // ETH is sent directly in the transaction: In this swap, you are sending ETH to the router as part of the function call. 
    // The {value: ethAmount} sends ETH from your wallet to the router directly. Since ETH doesn't require an allowance like ERC20 tokens, you don't need to approve anything before calling this function.
    function uniswapUserBuyTokens(uint256 tokenAmount, uint256 ethAmount, address account) public {
        vm.startPrank(account, account);
        console.log('Start uniswap router transaction. User buys tokens for eth. From is pair, to is user.');
        uint256 allowanceRouterBefore = coinToken.allowance(account, address(router));
        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 ethBalanceBefore = address(account).balance;
        uint256 tokenBalanceBefore = coinToken.balanceOf(address(account));

        //coinToken.approve(address(router), tokenAmount);
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(coinToken);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            tokenAmount, //min amount of tokens
            path,
            account,
            block.timestamp
        );
        console.log('Tokens are bought.... ');

        // Not calculating exact tokens amounts because fees could be substracted. Do calculate exact eth amounts
        assertEq(allowanceRouterBefore, coinToken.allowance(account, address(router)), 'Invalid allowance');
        assertTrue(tokenBalanceBefore < coinToken.balanceOf(address(account)), 'Invalid user token balance 1');
        assertEq(ethBalanceBefore-ethAmount, address(account).balance, 'Invalid user token balance 1');
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();
        assertTrue(reserve_cointoken_before_pair > reserve_cointoken_after_pair, 'Invalid pair token balance 1.1');
        assertEq(reserve_weth_before_pair+ethAmount, reserve_weth_after_pair, 'Invalid pair eth balance');

        console.log('Stop uniswap router transaction.');
        vm.stopPrank();
    }

    // Owner buys token so no fees are applied. Cannot check for exact received token amount but it must be > 0.
    function testUniswapUserBuyTokens() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        console.log('Step 1');

        sendTokensBackToOwner();
        console.log('Step 2');

        vm.deal(owner_address, 10 ether);
        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 tokenBalanceBeforeOwner = coinToken.balanceOf(address(owner_address));
        console.log('token balance before owner: ', tokenBalanceBeforeOwner);

        uint256 tokenAmount = 1000 * 10 ** decimals;
        console.log('uniswapUserBuyTokens checks..');
        uniswapUserBuyTokens(tokenAmount, 0.5 ether, owner_address);
        console.log('End uniswapUserBuyTokens checks..');

        uint256 tokensAddedToOwner = coinToken.balanceOf(address(owner_address)) - tokenBalanceBeforeOwner;
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();
        assertEq(reserve_cointoken_before_pair-tokensAddedToOwner, reserve_cointoken_after_pair, 'Invalid pair token balance 1.1');
    }

    // Always all tokens are used router.swapExactTokensForETHSupportingFeeOnTransferTokens. 
    // Amount of received eth cannot directly be calculated but it must > 0.
    // Test with owner so no transaction checks and fees are applied.
    // DONT TRIGGER THIS FUNCTION WHEN a swap is triggered
    function uniswapUserSellsTokens(uint256 tokenAmount, address user) public {
        vm.startPrank(user, user);
        console.log('Start uniswap router transaction. User sells tokens for eth. From is user, to is pair.');
        uint256 allowanceRouterBefore = coinToken.allowance(user, address(router));
        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 ethBalanceBefore = address(user).balance;
        uint256 tokenBalanceBefore = coinToken.balanceOf(address(user));

        address[] memory path = new address[](2);
        path[0] = address(coinToken);
        path[1] = router.WETH();
        coinToken.approve(address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, //amountIn
            0, //amountOutMin
            path,
            user, // The address that will receive the eth
            block.timestamp
        );

        // Not calculating exact eth amounts because fees could be substracted????
        assertEq(allowanceRouterBefore, coinToken.allowance(user, address(router)), 'Invalid allowance');

        assertEq(tokenBalanceBefore - tokenAmount, coinToken.balanceOf(address(user)), 'Invalid user token balance 1');
        assertTrue(ethBalanceBefore < address(user).balance, 'Invalid user eth balance 1');

        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();
        assertEq(reserve_cointoken_before_pair+tokenAmount, reserve_cointoken_after_pair, 'Invalid pair token balance');
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance');

        console.log('Stop uniswap router transaction.');
        vm.stopPrank();
    }

    // Owner buys eth so no fees are applied. Cannot check for exact received token amount but it must be > 0.
    function testUniswapUserSellsTokens() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        console.log('test0.5');
        
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        console.log('test1');
        vm.stopPrank();

        sendTokensBackToOwner();

        vm.deal(owner_address, 10 ether);
        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 ethBalanceBeforeOwner = address(owner_address).balance;
        console.log('test2.5');

        uint256 tokenAmount = 10000 * 10 ** decimals;
        console.log('uniswapUserBuyTokens checks..');
        uniswapUserSellsTokens(tokenAmount, owner_address);
        console.log('End uniswapUserBuyTokens checks..');

        uint256 ethAddedToOwner = address(owner_address).balance - ethBalanceBeforeOwner;
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();
        assertEq(reserve_weth_before_pair - ethAddedToOwner, reserve_weth_after_pair, 'invalid pair weth balance 11.1');
    }

    function sendOutPreDexTokens(uint8 param1, uint8 param2, uint8 param3, uint8 param4) public {
        tokenAmountPresale = (coinToken.totalSupply() * param1) / 100;
        sendTokensFromOwnerTo(PRESALEWALLET, tokenAmountPresale, false);
        assertEq(tokenAmountPresale, coinToken.balanceOf(PRESALEWALLET), 'check1');

        tokenAmountTeamVested = (coinToken.totalSupply() * param2) / 100;
        sendTokensFromOwnerTo(TEAM_WALLET_VESTED, tokenAmountTeamVested, false);
        assertEq(tokenAmountTeamVested, coinToken.balanceOf(TEAM_WALLET_VESTED), 'check2');

        uint256 tokenAmountTeam = (coinToken.totalSupply() * param4) / 100;
        sendTokensFromOwnerTo(TEAM_WALLET, tokenAmountTeam, false);
        assertEq(tokenAmountTeam, coinToken.balanceOf(TEAM_WALLET), 'check3');

        tokenAmountUniswap = (coinToken.totalSupply() * param3) / 100;
        assertEq(tokenAmountUniswap, coinToken.balanceOf(owner_address), 'check4');
    }

    function sendTokensBackToOwner() public {
        vm.startPrank(TEAM_WALLET, TEAM_WALLET);
        uint256 teamTokenBalanceBefore = coinToken.balanceOf(TEAM_WALLET);
        coinToken.transfer(owner_address, teamTokenBalanceBefore);
        assertEq(coinToken.balanceOf(TEAM_WALLET), 0, 'check3');
        assertEq(coinToken.balanceOf(owner_address), teamTokenBalanceBefore, 'check3');
        vm.stopPrank();
    }

    /////////////////////////////////////////////
    // CONSTRUCTOR, TOP LEVEL VARIABLES, SETTERS AND GETTERS
    // CUSTOM FUNCTIONS CALLED IN CONSTRUCTOR mint() AND ValidateTotalFee()
    /////////////////////////////////////////////

    function testConstructor() public view {
        assertEq(config.initialOwner ,  coinToken.owner());
        assertEq('KITTEN'               ,  coinToken.symbol());
        assertEq('Kitten Token'         ,  coinToken.name());
        assertEq(18, coinToken.decimals());

        assertEq(config.routerAddress, address(coinToken.uniswapV2Router()), 'Invalid router.');
        assertTrue(address(coinToken.uniswapV2Pair()) != address(0), 'Pair is address(0)');
        bool isValid = (pair.token0() == weth_address_mainnet) || (pair.token0() == address(coinToken));
        assertEq(isValid, true, 'Invalid pair address1');
        bool isValid1 = (pair.token1() == weth_address_mainnet) || (pair.token1() == address(coinToken));
        assertEq(isValid1, true, 'Invalid pair address2');
        assertEq(config.lqFee, coinToken.liquidityFee(), 'Invalid lq fee');
        assertEq(config.devFee, coinToken.devFee(), 'Invalid dev fee');
        assertEq(config.marketingFee, coinToken.marketingFee(), 'Invalid marketing fee');
        assertEq(config.burnFee, coinToken.burnFee(), 'Invalid burn fee');
        assertEq(config.charityFee, coinToken.charityFee(), 'Invalid charity fee');
        assertEq(100, coinToken.buyMultiplier(), 'Invalid buy multiplier');
        assertEq(100, coinToken.sellMultiplier(), 'Invalid sell multiplier');
        assertEq(config.tokenSupply/100,  coinToken.maxTransactionAmount(), 'Invalid max tx');
        assertEq(config.tokenSupply/100,  coinToken.maxWallet(), 'Invalid max wallet');
        assertEq(5,  coinToken.getSwapTokensAtAmountTotalSupplyPercentage(), 'Invalid swap percentage');
        assertEq((config.tokenSupply * 5) / 1000,  coinToken.getSwapTokensAtAmount(), 'Invalid swap percentage');
        assertEq(address(config.devWallet), coinToken.getDevWallet());
        assertEq(address(config.marketingWallet), coinToken.getMarketingWallet());
        assertEq(address(config.charityWallet), coinToken.charityWallet());

        assertEq(true,                coinToken.getIsExcludedFromFees(owner_address));
        assertEq(true,                coinToken.getIsExcludedFromFees(address(coinToken)));
        assertEq(true,                coinToken.getIsExcludedFromFees(address(coinToken.getMarketingWallet())));
        assertEq(true,                coinToken.getIsExcludedFromFees(address(coinToken.getDevWallet())));
        assertEq(true,                coinToken.getIsExcludedFromFees(address(coinToken.charityWallet())));

        assertEq(true,                coinToken.getIsExcludedFromMaxTransactionAmount(owner_address));
        assertEq(true,                coinToken.getIsExcludedFromMaxTransactionAmount(address(coinToken)));
        assertEq(true,                coinToken.getIsExcludedFromMaxTransactionAmount(address(coinToken.getMarketingWallet())));
        assertEq(true,                coinToken.getIsExcludedFromMaxTransactionAmount(address(coinToken.getDevWallet())));
        assertEq(true,                coinToken.getIsExcludedFromMaxTransactionAmount(address(coinToken.charityWallet())));
        assertEq(true,                coinToken.getIsExcludedFromMaxTransactionAmount(address(coinToken.uniswapV2Pair())), 'Pair is not excluded from max transaction');

        assertEq(true,                coinToken.getAutomatedMarketMakerPairs(address(pair)));

        assertEq(config.tokenSupply  ,  coinToken.totalSupply());
        assertEq(config.tokenSupply  ,  coinToken.balanceOf(owner_address));

        assertEq(config.lqFee+config.devFee+config.marketingFee+config.burnFee+config.charityFee, coinToken.triggerGetTotalFeeAmount());

        assertEq(address(0xdead), coinToken.getDeadAddress());
        assertEq(address(0), coinToken.getZeroAddress());

        assertEq(false, coinToken.getIsTradingOpen());
        assertEq(false, coinToken.getSwapping());
        assertEq(false, coinToken.getSwapEnabled());
        assertEq(true, coinToken.getTransferDelayEnabled());
        assertEq(false, coinToken.getLimitsRemoved());
        assertEq(50, coinToken.getMaxTotalBuyFee());
        assertEq(50, coinToken.getMaxTotalSellFee());
    }

    // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee, uint16 newBuyMultiplier, uint16 newSellMultiplier
    // Start values max_total_buy_fee = 50, max_total_sell_fee = 50.
    function testValidateFee() public {
        // Total buy fee including multiplier = 100 and sell = 200.
        console.log('test1');
        coinToken.triggerValidateTotalFee(5,5, 5, 5, 5, 100, 200);

        // Total buy fee including multiplier = 100 and sell = 200.
        console.log('test2'); 
        coinToken.triggerValidateTotalFee(10, 10, 10, 10, 10, 50, 100);

        // Buy multiplier is lower/higher than boundry
        console.log('test3');
        vm.expectRevert();
        coinToken.triggerValidateTotalFee(10, 1, 10, 10, 10, 49, 100);
        console.log('test4');
        vm.expectRevert();
        coinToken.triggerValidateTotalFee(10, 10, 10, 10, 11, 301, 100);

        // Sell multiplier is lower/higher than boundry
        console.log('test5');
        vm.expectRevert();
        coinToken.triggerValidateTotalFee(10, 10, 10, 10, 10, 100, 49);
        console.log('test6');
        vm.expectRevert();
        coinToken.triggerValidateTotalFee(10, 10, 10, 10, 10, 100, 301);

        // Fee including multiplier is > max_total_buy_fee
        console.log('test7');
        vm.expectRevert();
        coinToken.triggerValidateTotalFee(10, 10, 11, 10, 10, 100, 50);

        // Fee including multiplier is > max_total_sell_fee
        console.log('test8');
        vm.expectRevert();
        coinToken.triggerValidateTotalFee(10, 10, 1, 10, 10, 50, 125);

        // All fees can be zero
        console.log('test9');
        coinToken.triggerValidateTotalFee(0, 0, 0, 0, 0, 100, 100);
    }

    function testSettersAndGetters() public {
        ///////////////////////
        // PERMISSIONS
        ///////////////////////
        vm.startPrank(address(USER));

        vm.expectRevert();
        coinToken.setFeeWallets(USER1, USER2, USER3);

        vm.expectRevert();
        coinToken.setFees(10, 10, 10, 10, 10, 100, 100);

        vm.expectRevert();
        coinToken.setFeeExclusionForAccount(address(USER), true);

        vm.expectRevert();
        coinToken.setExclusionFromMaxTransaction(owner_address, true);

        vm.expectRevert();
        coinToken.setAutomatedMarketMakerPair(owner_address, true);

        vm.expectRevert();
        address bot1  = address(0x456);
        address bot2  = address(0x457);
        address bot3  = address(0x789);
        address bot4  = address(0x790);
        address[] memory bots = new address[](3);
        bots[0] = bot1;
        bots[1] = bot2;
        bots[2] = bot3;
        coinToken.addBots(bots);
        vm.expectRevert();
        coinToken.delBots(bots);

        vm.expectRevert();
        coinToken.setMaxWallet(5);

        vm.expectRevert();
        coinToken.setSwapTokensAtAmountSupplyPercentage(10);
        
        vm.expectRevert();
        coinToken.setSwapPossibility(true);

        vm.expectRevert();
        coinToken.stopTransferDelay();

        vm.stopPrank();
        ////////////////////////////
        ////////////////////////////

        // Test setting by owner
        vm.startPrank(address(owner_address));

        coinToken.setFeeWallets(USER1, USER2, USER3);
        assertEq(coinToken.getDevWallet(), address(USER1));
        assertEq(coinToken.getMarketingWallet(), address(USER2));
        assertEq(coinToken.charityWallet(), address(USER3));

        // Validate fees is tested is another test function
        console.log('1.');
        coinToken.setFees(5,6,7,8,11, 103,104);
        assertEq(coinToken.liquidityFee(), 5);
        assertEq(coinToken.devFee(), 6);
        assertEq(coinToken.burnFee(), 7);
        assertEq(coinToken.marketingFee(), 8);
        assertEq(coinToken.charityFee(),11);
        assertEq(coinToken.buyMultiplier(), 103);
        assertEq(coinToken.sellMultiplier(), 104);
        assertEq(coinToken.triggerGetTotalFeeAmount(), 5+6+7+8+11);

        console.log('2.');
        vm.expectRevert();
        coinToken.setFeeExclusionForAccount(address(0), true);
        assertEq(coinToken.getIsExcludedFromFees(address(USER)), false, 'Invalid 1');
        coinToken.setFeeExclusionForAccount(address(USER), true);
        assertEq(coinToken.getIsExcludedFromFees(address(USER)), true, 'Invalid 2');

        console.log('3.');
        vm.expectRevert();
        coinToken.setExclusionFromMaxTransaction(address(0), true);
        coinToken.setExclusionFromMaxTransaction(USER, true);
        assertEq(coinToken.getIsExcludedFromMaxTransactionAmount(USER), true, 'Invalid 3');

        console.log('4.');
        vm.expectRevert();
        coinToken.setAutomatedMarketMakerPair(address(pair), false);
        console.log('5.');
        vm.expectRevert();
        coinToken.setAutomatedMarketMakerPair(address(0), false);
        coinToken.setAutomatedMarketMakerPair(USER, true);
        assertEq(coinToken.getAutomatedMarketMakerPairs(USER), true, 'Invalid 4');

        coinToken.addBots(bots);
        assertTrue(coinToken.getBot(bot1));
        assertTrue(coinToken.getBot(bot2));
        assertTrue(coinToken.getBot(bot3));
        assertFalse(coinToken.getBot(bot4));

        console.log('6.');
        vm.expectRevert();
        coinToken.setMaxWallet(9);
        console.log('6.1');
        vm.expectRevert();
        coinToken.setMaxWallet(1001);
        coinToken.setMaxWallet(11);
        assertEq(coinToken.maxWallet(), (coinToken.totalSupply() * 11) / 1000, 'Invalid 5');

        console.log('7.');
        vm.expectRevert();
        coinToken.setSwapTokensAtAmountSupplyPercentage(11);
        console.log('8.');
        vm.expectRevert();
        coinToken.setSwapTokensAtAmountSupplyPercentage(0);
        coinToken.setSwapTokensAtAmountSupplyPercentage(10);
        assertEq(10, coinToken.getSwapTokensAtAmountTotalSupplyPercentage(), 'Invalid setter SwapTokensAtAmountSupplyPercentage');

        coinToken.setSwapPossibility(true);
        assertEq(coinToken.getSwapEnabled(),  true, 'Invalid 6');

        coinToken.stopTransferDelay();
        assertEq(coinToken.getTransferDelayEnabled(), false, 'Invalid 7');
        console.log('9.');
        vm.expectRevert(); //TransferDelayAlreadyDisabled
        coinToken.stopTransferDelay();
        
        vm.stopPrank();
    }

    function testRemoveLimits() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(USER, USER);
        vm.expectRevert();
        coinToken.removeLimits();
        vm.stopPrank();
        console.log('test1');

        vm.startPrank(owner_address, owner_address);
        uint256 old_max_tx_amount = coinToken.maxTransactionAmount();
        uint256 old_max_wallet_amount = coinToken.maxWallet();
        coinToken.setFees(5, 5, 5, 5, 5, 100, 140);
        console.log('test6');
        coinToken.removeLimits();
        assertEq(config.tokenSupply, coinToken.maxTransactionAmount());
        assertEq(config.tokenSupply, coinToken.maxWallet());
        assertEq(true, coinToken.getLimitsRemoved());
        assertEq(coinToken.getMaxTotalBuyFee(), 50);
        assertEq(coinToken.getMaxTotalSellFee(), 50);
        console.log('test7');

        vm.expectRevert();
        coinToken.removeLimits();
        console.log('test8');

        coinToken.addLqToUniswap();
        coinToken.openTrading();
        coinToken.setSwapPossibility(false);
        vm.stopPrank();
        console.log('test9');

        sendTokensBackToOwner();

        // Test if old max wallet and max transaction threshold can be threspassed
        vm.deal(USER, 10 ether);
        uniswapUserBuyTokens(1000000, 2 ether, USER);
        assertTrue(coinToken.balanceOf(USER) > old_max_tx_amount, 'test 10');
        assertTrue(coinToken.balanceOf(USER) > old_max_wallet_amount, 'test11');
        console.log('test10');
    }

    // ///////////////////////////////////////////////////////////////////////////////////////////////////
    // TEST THE CHAIN OF FUNCTIONS RELATED TO OPEN TRADING. addLiquidity() and openTrading()
    // WILL ALSO TRIGGER _UPDATE. MAKE SURE IT WILL NOT REVERT, ENTER THE TRANSACTACTION CHECKS, FEE CHECKS, SWAPPING.
    // ///////////////////////////////////////////////////////////////////////////////////////////////////

    function testAddLiquidity() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        console.log('test1');

        vm.startPrank(owner_address, owner_address);
        // Check pair reserves before. Should be 0.
        (uint112 reserve_cointoken_before, uint112 reserve_weth_before, ) = pair.getReserves();
        assertEq(reserve_cointoken_before, 0, 'Reserve before open trading is not 0.');
        assertEq(reserve_weth_before, 0, 'Reserve weth before open trading is not 0.');
        uint256 lq_tokens_balance_before = pair.balanceOf(owner_address);
        console.log('test2');

        // Send tokens from the owner to token contract. 95% of the total supply.
        // Start with adding less than the desired ETH and tokens to test the reverts.
        uint256 ethLiquidityAmount = 10 ether;
        sendTokensFromOwnerTo(address(coinToken), tokenAmountUniswap-100000, false);
        console.log('test3');
        // assertEq(address(coinToken).balance, ethLiquidityAmount, 'invalid cointoken eth balance');
        vm.expectRevert(abi.encodeWithSelector(InsufficientTokenBalance.selector));
        coinToken.triggerAddLiquidity(tokenAmountUniswap, ethLiquidityAmount);
        console.log('test4');
        sendTokensFromOwnerTo(address(coinToken), 100000, false);
        console.log('test5');
        uint256 token_contract_token_balance_before = coinToken.balanceOf(address(coinToken));
        assertEq(token_contract_token_balance_before, tokenAmountUniswap, 'Invalid cointoken balance before');
        vm.deal(address(coinToken), 9 ether);
        vm.expectRevert(abi.encodeWithSelector(InsufficientEthBalance.selector)); 
        coinToken.triggerAddLiquidity(tokenAmountUniswap, ethLiquidityAmount);
        console.log('test6');

        // Add liquidity. At the initial liquidity addition all eth and tokens must be added.
        // When adding liquidity after the first time, not all eth and tokens are always added to the pool (most likely a part of it).
        // Remaining eth and tokens are returned to the token contract.
        vm.deal(address(coinToken), ethLiquidityAmount);
        (uint256 amountTokenAddedToPool, uint256 amountETHAddedToPool, uint256 amountLiquidityToken) = coinToken.triggerAddLiquidity(tokenAmountUniswap, ethLiquidityAmount);
        assertEq(coinToken.allowance(address(coinToken), address(router)), 0, 'Invalid allowance');

        // Check pair reserves after.
        (uint112 reserve_cointoken_after, uint112 reserve_weth_after, ) = pair.getReserves();
        assertEq(reserve_cointoken_after, tokenAmountUniswap, 'Invalid pair token balance after');
        assertEq(reserve_weth_after, ethLiquidityAmount, 'Invalid pair eth balance after');
        // Check eth and cointoken balance cointoken contract
        assertEq(coinToken.balanceOf(address(coinToken)), 0, 'Invalid token balance after open trading for token address');
        assertEq(address(coinToken).balance, 0, 'Invalid eth balance after open trading for token address');
        // Liquidity tokens owner
        assertTrue(pair.balanceOf(owner_address) == (lq_tokens_balance_before + amountLiquidityToken), 'Invalid liquidity tokens');
        vm.stopPrank();
    }

    function testAddLqToUniswap() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        // Only owner can open trading
        vm.startPrank(USER);
        vm.expectRevert();
        coinToken.addLqToUniswap();
        vm.stopPrank();

        // cointoken contract has not enough eth. Must revert.
        vm.startPrank(owner_address, owner_address);
        vm.deal(address(coinToken), 9 ether);
        vm.expectRevert(abi.encodeWithSelector(InsufficientEthBalance.selector));
        coinToken.addLqToUniswap();
        vm.stopPrank();

        vm.startPrank(owner_address, owner_address);
        vm.deal(address(coinToken), 10 ether);
        coinToken.addLqToUniswap();
        // Owner only has 5% of begin amount of tokens left
        assertEq(tokenAmountOwner, coinToken.balanceOf(owner_address), 'Invalid owner token balance');
        // Cointoken balance of cointokens is 0
        assertEq(0, coinToken.balanceOf(address(coinToken)), 'Invalid cointoken token balance');
        // Check eth balance substraction cointoken contract. Must be 0.
        assertEq(0, address(coinToken).balance, 'Invalid eth balance token contract.');
        // Liquidity is succesfully added to pair. check token pair init and reserves of pair.
        // Could be that 1st param is weth instead of cointoken
        (uint112 reserve_cointoken1, uint112 reserve_weth1, ) = pair.getReserves();
        assertEq(reserve_weth1, 10 ether, 'Invalid eth balance pair');
        assertEq(reserve_cointoken1, tokenAmountUniswap, 'Invalid token balance pair');
        // Test if the owner has succesfully received the liquidity pool tokens
        assertTrue(pair.balanceOf(owner_address) > 0, "Owner wallet did not receive LP tokens");
    }

    function testOpenTrading() public {
        vm.startPrank(USER, USER);
        vm.expectRevert();
        coinToken.openTrading();
        vm.stopPrank();

        vm.startPrank(owner_address, owner_address);
        coinToken.openTrading();
        // isTradingOpen is true after function run
        assertTrue(coinToken.getIsTradingOpen(), 'Error IsTradingOpen');
        assertTrue(coinToken.getSwapEnabled(), 'Error getSwapEnabled');

        // After succesfull run of openTrading it cannot be called again. Revert.
        vm.expectRevert(abi.encodeWithSelector(TradingIsAlreadyOpen.selector));
        coinToken.openTrading();
        vm.stopPrank();
    }

    function testOpenTradingUniswapTransaction() public {

        //Below revert are not working for some reason. When remove the expectreverts the function calls will fail..
        //vm.expectRevert();
        //uniswapUserBuyTokens(10000 * 10 ** decimals, 0.1 ether, USER);
        //console.log('test2');
        // vm.expectRevert();
        // uniswapUserSellsTokens(tokenAmount, USER);
        // console.log('test3');

        sendOutPreDexTokens(50, 5, 40, 5);
        uint256 tokenAmount = 10 * 10 ** decimals;
        //sendTokensFromOwnerTo(USER, tokenAmount, false);
        console.log('test1');

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        console.log('test4');
        coinToken.openTrading();
        console.log('test4.5');
        vm.stopPrank();
        sendTokensBackToOwner();

        vm.deal(owner_address, 10 ether);
        uniswapUserBuyTokens(tokenAmount, 0.1 ether, owner_address);
        console.log('test5');
        // some tax marging
        uniswapUserSellsTokens(tokenAmount/100*50, owner_address);
        console.log('test6');
    }

    function testBurn() public {
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 1000 * 10 ** decimals;

        vm.expectRevert(abi.encodeWithSelector(TradingClosed.selector));
        coinToken.triggerBurn(owner_address, tokenAmount);
        console.log('test1');
        vm.stopPrank();

        sendOutPreDexTokens(50, 5, 40, 5);
        console.log('test2');

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        console.log('test3');
        coinToken.openTrading();
        console.log('test4');
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        coinToken.triggerBurn(address(0), tokenAmount);
        console.log('test5');
        vm.stopPrank();

        sendTokensBackToOwner();

        vm.startPrank(owner_address, owner_address);
        uint256 owner_balance_before = coinToken.balanceOf(owner_address);
        uint256 tokenSupplyBefore = coinToken.totalSupply();

        coinToken.triggerBurn(owner_address, tokenAmount);
        console.log('test6');
        assertEq(owner_balance_before-tokenAmount, coinToken.balanceOf(owner_address), 'Invalid owner balance');
        assertEq(tokenSupplyBefore-tokenAmount, coinToken.totalSupply(), 'Invalid total supply balance');

        vm.stopPrank();
    }

    ////////////////////////////////////
    // MANUAL TOKEN  SEND FUNCTIONS
    ////////////////////////////////////

    //Custom TestToken contract created (TestToken.sol)
    function testStuckToken() public {
        // Send testtokens to USER
        console.log('step 1');
        testToken.transfer(USER, 5000 * 10 ** 18);

        //1. test tokens send from USER to cointoken contract are stuck
        vm.startPrank(USER);
        testToken.transfer(address(coinToken), 1000 * 10 ** decimals); // Send 1000 tokens to the cointoken contract
        assertEq(testToken.balanceOf(address(coinToken)), 1000 * 10 ** decimals, 'Invalid 1');
        assertEq(testToken.balanceOf(USER), 4000 * 10 ** decimals, 'Invalid 2'); // Initial tokens - 1000
        assertEq(testToken.balanceOf(owner_address), 0, 'Invalid 3'); // Initial tokens - 1000
        vm.stopPrank();

        // Revert because no tokens
        vm.startPrank(USER1);
        vm.expectRevert();
        coinToken.clearStuckToken(address(testToken), 0); // Passing 0 recovers the full amount
        vm.stopPrank();

        // Send stuck tokens to owner.
        vm.startPrank(owner_address);
        coinToken.clearStuckToken(address(testToken), 900 * 10 ** decimals);
        assertEq(testToken.balanceOf(address(coinToken)), 100 * 10 ** decimals, 'Invalid 3');
        assertEq(testToken.balanceOf(owner_address), 900 * 10 ** decimals, 'Invalid 4'); 
        coinToken.clearStuckToken(address(testToken), 0);
        assertEq(testToken.balanceOf(address(coinToken)), 0, 'Invalid 5');
        assertEq(testToken.balanceOf(owner_address), 1000 * 10 ** decimals, 'Invalid 6'); 
        vm.stopPrank();
    }

    // testManualSendEth and testManualSendTokens are removed from the token contract
    //////////////////////

    // function testManualSendEth() public {
    //     // Revert because no permission
    //     vm.startPrank(USER);
    //     vm.expectRevert();
    //     coinToken.manualSendEth();
    //     vm.stopPrank();

    //     vm.startPrank(owner_address, owner_address);
    //     vm.deal(address(coinToken), 1 ether);
    //     coinToken.manualSendEth();
    //     assertEq(0, address(coinToken).balance, 'Invalid eth balance token contract.');
    //     assertEq(1 ether, address(marketingWallet).balance, 'Invalid eth balance owner.');
    //     vm.stopPrank();
    // }

    // function testManualSendTokens() public {
    //     // Revert because no permission
    //     vm.startPrank(USER);
    //     vm.expectRevert();
    //     coinToken.manualSendTokens();
    //     vm.stopPrank();

    //     vm.startPrank(owner_address, owner_address);
    //     coinToken.openTrading(token_amount_percentage_liquidity_start);
    //     vm.stopPrank();

    //     sendTokensFromOwnerTo(address(coinToken), 10000 * 10 ** decimals, false);

    //     vm.startPrank(owner_address, owner_address);
    //     coinToken.manualSendTokens();
    //     assertEq(0, coinToken.balanceOf(address(coinToken)), 'Invalid eth balance token contract.');
    //     assertEq(10000 * 10 ** decimals, coinToken.balanceOf(marketingWallet), 'Invalid eth balance owner.');
    //     vm.stopPrank();
    // }

    function testReceive() public {
        vm.deal(USER, 10 ether);
        uint256 initialBalance = address(coinToken).balance;
        console.log('Init balance eth: ', initialBalance);

        // Send 1 ether to the contract
        vm.startPrank(USER, USER);
        (bool success, ) = address(coinToken).call{value: 1 ether}("");
        assertTrue(success, "Failed to send Ether");
        uint256 afterBalance = address(coinToken).balance;
        console.log('After balance eth: ', afterBalance);
        assertEq(afterBalance, initialBalance+1 ether, "invalid cointoekn balance");
        assertEq(address(USER).balance, 10 ether -1 ether, "invalid user balance");
        vm.stopPrank();
    }

    ///////////////////////////////
    // TRANSACTION CHECK FUNCTIONS
    ///////////////////////////////

    function test_updateInitialChecks() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        uint256 amountToken = 10 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, amountToken, false);
        console.log('test1');

        // Trading is closed. 1.Owner is allow to send tokens. 2. USER should not be able to send any tokens.
        // from == address(this) && to == uniswapV2Pair) will tested in openTrading()
        vm.startPrank(USER, USER);
        vm.expectRevert(abi.encodeWithSelector(TradingClosed.selector));
        coinToken.transfer(USER2, amountToken);
        vm.stopPrank();

        // Dead address
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();

        vm.startPrank(owner_address, owner_address);
        vm.expectRevert(abi.encodeWithSelector(DeadAddress.selector));
        coinToken.transfer(address(0xdead), amountToken);

        // Bots
        address bot1  = address(0x456);
        address bot2  = address(0x456);
        address bot3  = address(0x789);
        address[] memory bots = new address[](3);
        bots[0] = bot1;
        bots[1] = bot2;
        bots[2] = bot3;
        coinToken.addBots(bots);
        assertTrue(coinToken.getBot(bot1));
        assertTrue(coinToken.getBot(bot2));
        assertTrue(coinToken.getBot(bot3));
        vm.expectRevert(abi.encodeWithSelector(TransferFailed.selector));
        coinToken.transfer(bot1, amountToken);

        // To small token amount
        vm.expectRevert(abi.encodeWithSelector(ToSmallOrToLargeTransactionAmount.selector));
        coinToken.transfer(USER2, 999);
        vm.stopPrank();

        //  Insufficient balance
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(TransferExceedsBalance.selector));
        coinToken.transfer(USER2, amountToken+1);
        vm.stopPrank();
    }

    function testBotsOnlyBlockedWhenLimitsAreNotRemoved() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        uint256 amountToken = 100 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, amountToken, false);
        console.log('step1');

        vm.startPrank(owner_address, owner_address);
        // Bots
        address bot1  = address(0x456);
        address bot2  = address(0x456);
        address bot3  = address(USER);
        address[] memory bots = new address[](3);
        bots[0] = bot1;
        bots[1] = bot2;
        bots[2] = bot3;
        coinToken.addBots(bots);
        assertTrue(coinToken.getBot(bot1));
        assertTrue(coinToken.getBot(bot2));
        assertTrue(coinToken.getBot(bot3));
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        console.log('step2');

        sendTokensBackToOwner();

        vm.startPrank(USER, USER);
        vm.expectRevert(abi.encodeWithSelector(TransferFailed.selector));
        coinToken.transfer(USER2, amountToken);
        vm.stopPrank();
        console.log('step3');

        vm.startPrank(owner_address, owner_address);
        coinToken.setFees(5, 5, 5, 3, 2, 100, 100);
        coinToken.removeLimits();
        vm.stopPrank();

        vm.startPrank(USER, USER);
        coinToken.transfer(USER2, amountToken);
        assertEq(0, coinToken.balanceOf(USER) ,'fail 1');
        // Tax
        assertTrue(coinToken.balanceOf(USER2) > ((amountToken/10) *8),'fail 2');
        vm.stopPrank();
        console.log('step5');
    }

    // Transfer delay enabled test functions will not work properly if via_ir=true in foundry.toml file.
    // Forge test will do all transfers within a testfunction in the same blocknumber unless you explicity tell forge to use: vm.roll
    function testTransferDelayEnabled() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        // Setup will also trigger _update because of mint
        // Open trading and send tokens from owner to user
        vm.startPrank(owner_address, owner_address); //function startPrank(address sender, address origin) external;
        coinToken.addLqToUniswap(); // 1.transaction from owner to cointoken. 2. transaction from cointoken to uniswap pair address
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(owner_address), 'test1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(coinToken)), 'test2');
        sendTokensFromOwnerTo(USER, 1000 * 10 ** decimals, false);
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(owner_address), 'test3');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(USER), 'test4');
        uint256 second_block = block.number + 1;
        vm.roll(second_block);
        vm.stopPrank();

        // Second below transaction must fail because USER can only send one transaction in the same block
        vm.startPrank(USER, USER);
        console.log("transfer from user to user2 triggers");
        // Transfer from user to user2
        coinToken.transfer(USER2, 100 * 10 ** decimals);
        assertEq(second_block, coinToken.getTokenHolderLastTransferBlockNumber(USER), 'test5');
        assertEq(second_block, coinToken.getTokenHolderLastTransferBlockNumber(USER2), 'test6');
        vm.expectRevert(abi.encodeWithSelector(TransferDelayTryAgainLater.selector));
        coinToken.transfer(USER2, 50 * 10 ** decimals);
        vm.stopPrank();

        // Second transaction must succeed because in different block
        uint256 third_block = block.number + 1;
        vm.roll(third_block);
        vm.startPrank(USER, USER);
        // Transfer from user to user2
        coinToken.transfer(USER2, 100 * 10 ** decimals);
        assertEq(third_block, coinToken.getTokenHolderLastTransferBlockNumber(USER), 'test7');
        assertEq(third_block, coinToken.getTokenHolderLastTransferBlockNumber(USER2), 'test8');
        uint256 fourth_block = block.number + 1;
        vm.roll(fourth_block);
        coinToken.transfer(USER2, 50 * 10 ** decimals);
        assertEq(fourth_block, coinToken.getTokenHolderLastTransferBlockNumber(USER), 'test9');
        assertEq(fourth_block, coinToken.getTokenHolderLastTransferBlockNumber(USER2), 'test10');
        vm.stopPrank();
    }

    // When USER3 is selling tokens trough the uniswap router (swapTokensForEth).msg.sender=router,from=USER3,tx.origin=USER3,to=pair
    // WHEN USER3 is buying tokens for eth trought the router (swapethfortokens).msg.sender=pair,from=pair,tx.origin=USER3,to=USER3
    function test1TransferDelayEnabledPair() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        // Test sell token transfer through router.
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();

        // Owner is initiaint the transaction so user3 should not be added to the TokenHolderLastTransferTimestamp mapping
        uint256 first_block_number = block.number;
        sendTokensFromOwnerTo(USER3, 10000 * 10 ** decimals, false);
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(USER3));

        vm.startPrank(USER3, USER3);
        uint256 first_block = block.number;
        uint256 tokenAmount = 500 * 10 ** decimals;
        address[] memory path = new address[](2);
        path[0] = address(coinToken);
        path[1] = router.WETH();
        coinToken.approve(address(router), tokenAmount);
        // USER3 IS SELLING TOKENS (from is USER3 and to is pair). In this case no entry should be added to getTokenHolderLastTransferBlockNumber.
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            USER3,
            block.timestamp
        );
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(USER3)));
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)));
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)));

        // USER3 IS SELLING TOKENS (from is USER3 and to is pair) within the same block as the previous transaction.
        // In this case no entry should be added to getTokenHolderLastTransferBlockNumber.
        coinToken.approve(address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            USER3,
            block.timestamp
        );
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(USER3));
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)));
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)));

        // USER3 is buying tokens (from=pair, to=USER3). Pair must not be added to mapping. Second transaction must throw error.
        vm.deal(USER3, 10 ether);
        address[] memory path1 = new address[](2);
        path1[0] = router.WETH();
        path1[1] = address(coinToken);
        coinToken.approve(address(router), tokenAmount);
        console.log('Swap eth for tokens 1.....');
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER3,
            block.timestamp
        );
        assertEq(first_block, coinToken.getTokenHolderLastTransferBlockNumber(USER3), 'Invalid 1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 3');
        coinToken.approve(address(router), tokenAmount);
        // ADD CHECKING FOR SPECIFIC ERROR: [FAIL. Reason: Error != expected error: UniswapV2: TRANSFER_FAILED != 0x768acefe]
        vm.expectRevert();
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER3,
            block.timestamp
        );
        vm.stopPrank();

        vm.roll(block.number + 1);
        uint256 second_block = block.number;

        // USER1, USER2, USER3 AND USER4 ARE BUYING TOKENS (EACH ONE TRANSACTION) IN THE SAME BLOCK. NO ERROR SHOULD BE THROWN.
        vm.deal(USER1, 10 ether);
        vm.deal(USER2, 10 ether);
        vm.deal(USER4, 10 ether);

        vm.startPrank(USER1, USER1);
        coinToken.approve(address(router), tokenAmount);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER1,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(second_block, coinToken.getTokenHolderLastTransferBlockNumber(USER1), 'Invalid 10.1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 10.2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 10.3');

        vm.startPrank(USER2, USER2);
        coinToken.approve(address(router), tokenAmount);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER2,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(second_block, coinToken.getTokenHolderLastTransferBlockNumber(USER2), 'Invalid 11.1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 11.2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 11.3');

        vm.startPrank(USER3, USER3);
        coinToken.approve(address(router), tokenAmount);
        console.log('TRANSACTION FROM USER 3...');
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER3,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(second_block, coinToken.getTokenHolderLastTransferBlockNumber(USER3), 'Invalid 12.1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 12.2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 12.3');

        vm.startPrank(USER4, USER4);
        coinToken.approve(address(router), tokenAmount);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER4,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(second_block, coinToken.getTokenHolderLastTransferBlockNumber(USER4), 'Invalid 14.1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 14.2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 14.3');

        // USER4 IS MAKING A SECOND BUY IN THE SAME BLOCK. ERROR SHOULD BE THROWN.
        vm.startPrank(USER4, USER4);
        coinToken.approve(address(router), tokenAmount);
        vm.expectRevert();
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER4,
            block.timestamp
        );
        vm.stopPrank();
    }
    
    function testTransferDelayDisabled() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        coinToken.stopTransferDelay();
        assertFalse(coinToken.getTransferDelayEnabled(), 'Invalid 1');
        vm.stopPrank();

        sendTokensBackToOwner();

        vm.deal(USER1, 10 ether);
        vm.deal(USER2, 10 ether);
        uint256 tokenAmount = 500 * 10 ** decimals;
        address[] memory path1 = new address[](2);
        path1[0] = router.WETH();
        path1[1] = address(coinToken);

        vm.startPrank(USER1, USER1);
        coinToken.approve(address(router), tokenAmount);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER1,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(USER1), 'Invalid 10.1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 10.2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 10.3');

        vm.startPrank(USER2, USER2);
        coinToken.approve(address(router), tokenAmount);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.01 ether}(
            tokenAmount,
            path1,
            USER2,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(USER2), 'Invalid 11.1');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(pair)), 'Invalid 11.2');
        assertEq(0, coinToken.getTokenHolderLastTransferBlockNumber(address(router)), 'Invalid 11.3');
    }

    function testMaxWalletCheck() public {
        uint256 maxWalletAmount = coinToken.maxWallet();
        uint256 amountLowerThanMaxWallet  = maxWalletAmount - 1;
        uint256 amountHigherThanMaxWallet = maxWalletAmount + 1;

        //1. Check max wallet limit (only to address is relevant). 
        //1.1. to = token contract. amount < maxWallet. Not revert
        console.log('1.1');
        coinToken.triggerMaxWalletCheck(address(coinToken), amountLowerThanMaxWallet);
        //1.2. to = token contract. amount = max wallet
        console.log('1.2');
        coinToken.triggerMaxWalletCheck(address(coinToken), maxWalletAmount);
        //1.3. to = token contract. amount > maxWallet
        console.log('1.3');
        coinToken.triggerMaxWalletCheck(address(coinToken), amountHigherThanMaxWallet);
        //1.4. to = uniswap pair. amount > maxWallet
        console.log('1.4');

        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        coinToken.triggerMaxWalletCheck(address(pair), amountHigherThanMaxWallet);
        
        //1.5. add address to automatedMarketMakerPairs. amount > maxWallet
        console.log('1.5');
        vm.startPrank(owner_address);
        coinToken.setAutomatedMarketMakerPair(USER2, true);
        vm.stopPrank();
        coinToken.triggerMaxWalletCheck(USER2, amountHigherThanMaxWallet);
        //1.6. to = user. amount < maxWallet
        console.log('1.6');
        coinToken.triggerMaxWalletCheck(USER, amountLowerThanMaxWallet);
        //1.7. to = user. amount = maxWallet
        console.log('1.7');
        coinToken.triggerMaxWalletCheck(USER, maxWalletAmount);
        //1.8. to = user. amount > maxWallet
        console.log('1.8');
        vm.expectRevert(abi.encodeWithSelector(MaxWalletExceeded.selector));
        coinToken.triggerMaxWalletCheck(USER, amountHigherThanMaxWallet);
        //1.9. to = devwallet. amount > maxWallet
        console.log('1.9');
        coinToken.triggerMaxWalletCheck(coinToken.getDevWallet(), amountHigherThanMaxWallet);
        //1.10 Send tokens to user.
        uint256 tokenAmount = 1 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, tokenAmount, false); 
        vm.expectRevert(abi.encodeWithSelector(MaxWalletExceeded.selector));
        coinToken.triggerMaxWalletCheck(USER, maxWalletAmount);
    }

    function testMaxTransactionCheck() public {
        uint256 maxTransactionAmount = coinToken.maxTransactionAmount();
        uint256 amountLowerThanMaxTransactionAmount   = coinToken.maxTransactionAmount() - 1;
        uint256 amountHigherThanMaxTransactionAmount  = coinToken.maxTransactionAmount() + 1;
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();

        console.log('1.1. Transfer between wallets. No max transaction check should happen.');
        coinToken.triggerMaxTransactionCheck(USER, USER1, maxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(USER, USER1, amountLowerThanMaxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(USER, USER1, amountHigherThanMaxTransactionAmount);

        console.log('1.2. Pair buying transaction. From is pair, to io. To is excluded.');
        coinToken.triggerMaxTransactionCheck(address(pair), owner_address, amountHigherThanMaxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(address(pair), owner_address, maxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(address(pair), owner_address, amountLowerThanMaxTransactionAmount);

        console.log('1.4. Pair buying transaction. From is pair, to is user. To is not excluded.');
        vm.expectRevert();
        coinToken.triggerMaxTransactionCheck(address(pair), USER, amountHigherThanMaxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(address(pair), USER, maxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(address(pair), USER, amountLowerThanMaxTransactionAmount);

        console.log('1.5. Pair selling transaction. From is user, to is pair. From is excluded.');
        coinToken.triggerMaxTransactionCheck(owner_address, address(pair), amountHigherThanMaxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(owner_address, address(pair), maxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(owner_address, address(pair), amountLowerThanMaxTransactionAmount);

        console.log('1.5. Pair selling transaction. From is user, to is pair. From is not excluded.');
        vm.expectRevert();
        coinToken.triggerMaxTransactionCheck(USER1, address(pair), amountHigherThanMaxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(USER1, address(pair), maxTransactionAmount);
        coinToken.triggerMaxTransactionCheck(USER1, address(pair), amountLowerThanMaxTransactionAmount);
    }

    //////////////////////////////////
    // SWAPPING
    //////////////////////////////////
    function testShouldSwapBack() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        // 1. swap is disabled
        assertFalse(coinToken.triggerShouldSwapBack(address(pair)));

        // 2. swap is enabled.
        vm.startPrank(owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();

        assertFalse(coinToken.triggerShouldSwapBack(address(pair)));
        // 3. swap is enabled from is token address
        assertFalse(coinToken.triggerShouldSwapBack(address(coinToken)));
        // 4. swap is enabled, from is USER, balance token address < swapTokensAtAmount
        assertFalse(coinToken.triggerShouldSwapBack(USER));
        // 5. swap is enabled, from is USER, balance token address = swapTokensAtAmount
        sendTokensFromOwnerTo(address(coinToken), coinToken.getSwapTokensAtAmount(), false);
        assertFalse(coinToken.triggerShouldSwapBack(USER));
        // 6. swap is enabled, from is pair, balance token address > swapTokensAtAmount
        sendTokensFromOwnerTo(address(coinToken), 10000, false);
        assertFalse(coinToken.triggerShouldSwapBack(address(pair)));
        //TotalFee - burn fee must be > 0 for swapping to be true. Only burnfee > 0
        vm.startPrank(owner_address);
        coinToken.setFees(0, 0, 10, 0, 0, 100, 100);
        assertFalse(coinToken.triggerShouldSwapBack(USER));

        coinToken.setFees(0, 0, 10, 0, 10, 100, 100);
        assertTrue(coinToken.triggerShouldSwapBack(USER));
        vm.stopPrank();
    }
    
    //Supply 1 billion. 15% of total tokens in pool. Than backing is exactly 30%.
    function testCheckRatio() public {
        sendOutPreDexTokens(75, 5, 15, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        assertEq(30, coinToken.triggerCheckRatio(), 'Invalid 1');
        vm.stopPrank();
    }

    // Supply 1 billion. 16% of total tokens in pool. Than backing > 30.
    function testCheckRatio1() public {
        sendOutPreDexTokens(74, 5, 16, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        assertTrue(coinToken.triggerCheckRatio() > 30, 'Invalid 1');
        vm.stopPrank();
    }

    // Supply 1 billion. 14% of total tokens in pool. Than backing > 30.
    function testCheckRatio2() public {
        sendOutPreDexTokens(76, 5, 14, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        assertTrue(coinToken.triggerCheckRatio() < 30, 'Invalid 1');
        vm.stopPrank();
    }

    //////////////////////////
    //SWAPPING TEST. COMMENT THIS TESTS OTHER WISE A ERROR WILL THROWN BECAUSE OF TO MANY LOCAL VARIABLES. TO SOLVE THIS ERROR SEE FOUNDRY.TOML
    ////////////////////////////
    
    // Liquidity fee is not zero but because of liquidity ratio the dynamic liquidity fee will be set to zero.
    // 1. swap tokens for eth is executed 2.fees are distributed to dev and marketing wallet. 3. swaptokensatamount is updated
    function testSwapAndLiquifyFeeZeroBecauseOfRatio() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.setFees(5, 5, 7, 8, 9, 100, 100); 
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);

        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.triggerSwapAndLiquify(35);
        assertTrue(amountLiquidityToken1 == 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 == 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 == 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 != 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity          = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = 0;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + swapTokensAtAmountBefore, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // No liquidity add to pool
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - swapTokensAtAmountBefore, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee;
        uint256 amountEthMarketing = (amountEthSwapped1 * coinToken.marketingFee()) / totalETHFee;
        uint256 amountEthDev       = (amountEthSwapped1 * coinToken.devFee()) / totalETHFee;
        uint256 amountEthCharity   = (amountEthSwapped1 * coinToken.charityFee()) / totalETHFee;
        uint256 amountEthToLiquify = 0;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        console.log('Amount eth not used: ', amountEthNotUsed);
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(reserve_weth_before_pair - amountEthSwapped1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Dev, marketing and charity wallet should reveive eth (fees)
        assertTrue(eth_balance_before_marketing < eth_balance_after_marketing, 'Invalid marketing wallet eth balance1');
        assertEq(eth_balance_before_marketing + amountEthMarketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertTrue(eth_balance_before_dev < eth_balance_after_dev, 'Invalid dev wallet eth balance1');
        assertEq(eth_balance_before_dev + amountEthDev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertTrue(eth_balance_before_charity < eth_balance_after_charity, 'Invalid Charity eth balance1');
        assertEq(eth_balance_before_charity + amountEthCharity, eth_balance_after_charity, 'Invalid Charity eth balance2');
        // Owner should not receive any eth
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');

        vm.stopPrank();
    }

    // Must decrease the total supply first (burning) before calling the swap and liquidfy to update the swapTokensAtAmount value
    function testSwapAndLiquifyNewSwapTokensForEthValue() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 total_supply_before = coinToken.totalSupply();
        uint256 swapTokensAtAmount = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount: ', swapTokensAtAmount);
        console.log('Total supply: ', total_supply_before);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);
        vm.stopPrank();

        // First transaction with fee
        console.log('Begin buy transaction with fee.....');
        vm.deal(USER, 10 ether);
        uniswapUserBuyTokens(1000*10**decimals, 0.1 ether, USER);
        console.log('Token balance USER after transfer: ', coinToken.balanceOf(USER));
        console.log('ETH balance USER after transfer: ', address(USER).balance);

        // Balance cointoken must be > swaptokensatamount to trigger swap
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmount, false);
        //uint256 tokenBalanceBefore = coinToken.balanceOf(address(coinToken));
        console.log('Cointoken balance tokens: ', coinToken.balanceOf(address(coinToken)));
        uint256 total_supply_after =  coinToken.totalSupply();
        console.log('total_supply_after: ', total_supply_after);

        vm.roll(block.number + 1);

        // Second transacion with fee. Is triggering the swap and liquidy. Must use a sell transacion else the swapping is not triggered.
        // Must approve the transaction before calling the router function
        // Not using the generic uniswap sell function because this function call will trigger a swap causing issues in the token contract token balance checks
        vm.startPrank(USER, USER);
        console.log('Begin sell transaction2 with fee.....');
        address[] memory path = new address[](2);
        path[0] = address(coinToken);
        path[1] = router.WETH();
        coinToken.approve(address(router), 100*10**decimals);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            100*10**decimals, //amountIn
            0, //amountOutMin
            path,
            USER, // The address that will receive the eth
            block.timestamp
        );
        //uniswapUserSellsTokens(100*10**decimals, USER);
        console.log('Token balance USER after transfer2: ', coinToken.balanceOf(USER));
        console.log('ETH balance USER after transfer2: ', address(USER).balance);
        vm.stopPrank();

        uint256 total_supply_after1 =  coinToken.totalSupply();
        console.log('total_supply_after1: ', total_supply_after1);
        assertTrue(total_supply_before > total_supply_after1, 'Invalid burn1');
        uint256 amountBurned = total_supply_before - total_supply_after1;
        console.log('Amount burned: ', amountBurned);
        // Dont take the burm amount from transaction two in account because the fees are processed after the swapAndLiquify.
        assertEq(coinToken.getSwapTokensAtAmount(), (total_supply_after * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, 'Invalid new swaptokensamount token amount');
    }

    // All fees not zero. Ratio is 25 so liquifi must happen.
    function testSwapAndLiquifyAllFeesNotZero() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.setFees(15, 5, 7, 8, 9, 100, 100); 
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);

        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.triggerSwapAndLiquify(25);
        assertTrue(amountLiquidityToken1 > 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 > 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 > 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 > 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity          = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = (swapTokensAtAmountBefore * coinToken.liquidityFee()) / totalFee / 2;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        // Swap tokens for eth is adding tokens from the cointoken contract to the pair (swapTokensAtAmountBefore - tokenAmountToLiquify)
        // Add liquidity is adding tokens from the cointoken contract to the pair.
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + (swapTokensAtAmountBefore - tokenAmountToLiquify) + amountTokenAddedToPool1, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // When adding the liquidity to the pool some tokens can be returned to the token contract
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - (swapTokensAtAmountBefore - tokenAmountToLiquify) - amountTokenAddedToPool1, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid charity token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee - (coinToken.liquidityFee()/2);
        uint256 amountEthMarketing = (amountEthSwapped1 * coinToken.marketingFee()) / totalETHFee;
        uint256 amountEthDev       = (amountEthSwapped1 * coinToken.devFee()) / totalETHFee;
        uint256 amountEthCharity       = (amountEthSwapped1 * coinToken.charityFee()) / totalETHFee;
        //uint256 amountEthToLiquify = (amountEthSwapped1 * coinToken.liquidityFee()) / totalETHFee / 2;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq((reserve_weth_before_pair - amountEthSwapped1) + amountETHAddedToPool1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Dev an marketing wallet should reveive eth (fees)
        assertTrue(eth_balance_before_marketing < eth_balance_after_marketing, 'Invalid marketing wallet eth balance1');
        assertEq(eth_balance_before_marketing + amountEthMarketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertTrue(eth_balance_before_dev < eth_balance_after_dev, 'Invalid dev wallet eth balance1');
        assertEq(eth_balance_before_dev + amountEthDev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertTrue(eth_balance_before_charity < eth_balance_after_charity, 'Invalid charity wallet eth balance1');
        assertEq(eth_balance_before_charity + amountEthCharity, eth_balance_after_charity, 'Invalid charity wallet eth balance2');
        // Owner should not receive any eth
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner + amountLiquidityToken1, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');

        vm.stopPrank();
    }

    // All fees not zero except liquidity. LiquidtyFee = 0 (not because of the ratio)
    function testSwapAndLiquifyOnlyLiquidityFeeZero() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.setFees(0, 5, 7, 8, 9, 100, 100); 
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);

        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        uint256 liquidity_tokens_before_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.triggerSwapAndLiquify(25);
        assertTrue(amountLiquidityToken1 == 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 == 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 == 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 != 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity              = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = 0;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + swapTokensAtAmountBefore, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // No liquidity add to pool
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - swapTokensAtAmountBefore, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee;
        uint256 amountEthMarketing = (amountEthSwapped1 * coinToken.marketingFee()) / totalETHFee;
        uint256 amountEthDev       = (amountEthSwapped1 * coinToken.devFee()) / totalETHFee;
        uint256 amountEthCharity       = (amountEthSwapped1 * coinToken.charityFee()) / totalETHFee;
        uint256 amountEthToLiquify = 0;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        console.log('Amount eth not used: ', amountEthNotUsed);
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(reserve_weth_before_pair - amountEthSwapped1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Dev an marketing wallet should reveive eth (fees)
        assertTrue(eth_balance_before_marketing < eth_balance_after_marketing, 'Invalid marketing wallet eth balance1');
        assertEq(eth_balance_before_marketing + amountEthMarketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertTrue(eth_balance_before_dev < eth_balance_after_dev, 'Invalid dev wallet eth balance1');
        assertEq(eth_balance_before_dev + amountEthDev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertTrue(eth_balance_before_charity < eth_balance_after_charity, 'Invalid charity wallet eth balance1');
        assertEq(eth_balance_before_charity + amountEthCharity, eth_balance_after_charity, 'Invalid charity wallet eth balance2');
        // Owner should not receive any eth
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');

        vm.stopPrank();
    }

    // All fees zero except liquidity.
    function testSwapAndLiquifyOnlyLiquidityFeeNotZero() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.setFees(40, 0, 0, 0, 0, 100, 100); 
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);

        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        uint256 liquidity_tokens_before_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.triggerSwapAndLiquify(25);
        assertTrue(amountLiquidityToken1 != 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 != 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 != 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 != 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity              = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = (swapTokensAtAmountBefore * coinToken.liquidityFee()) / totalFee / 2;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        // Swap tokens for eth is adding tokens from the cointoken contract to the pair (swapTokensAtAmountBefore - tokenAmountToLiquify)
        // Add liquidity is adding tokens from the cointoken contract to the pair.
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + (swapTokensAtAmountBefore - tokenAmountToLiquify) + amountTokenAddedToPool1, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // When adding the liquidity to the pool some tokens can be returned to the token contract
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - (swapTokensAtAmountBefore - tokenAmountToLiquify) - amountTokenAddedToPool1, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid charity wallet token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee - (coinToken.liquidityFee()/2);
        uint256 amountEthMarketing = 0;
        uint256 amountEthDev       = 0;
        uint256 amountEthCharity       = 0;
        uint256 amountEthToLiquify = (amountEthSwapped1 * coinToken.liquidityFee()) / totalETHFee / 2;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        assertTrue(reserve_weth_before_pair >= reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq((reserve_weth_before_pair - amountEthSwapped1) + amountETHAddedToPool1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Owner, dev, marketing should not receive any eth
        assertEq(eth_balance_before_marketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertEq(eth_balance_before_dev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertEq(eth_balance_before_charity, eth_balance_after_charity, 'Invalid charity wallet eth balance2');
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner + amountLiquidityToken1, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');

        vm.stopPrank();
    }

    // Only dev is zero. 
    function testSwapAndLiquifyOnlyDevFeeZero() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee, uint8 charityFee
        coinToken.setFees(15, 0, 7, 8, 9, 100, 100); 
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);

        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        //uint256 liquidity_tokens_before_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.triggerSwapAndLiquify(25);
        assertTrue(amountLiquidityToken1 != 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 != 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 != 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 != 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity          = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = (swapTokensAtAmountBefore * coinToken.liquidityFee()) / totalFee / 2;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        // Swap tokens for eth is adding tokens from the cointoken contract to the pair (swapTokensAtAmountBefore - tokenAmountToLiquify)
        // Add liquidity is adding tokens from the cointoken contract to the pair.
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + (swapTokensAtAmountBefore - tokenAmountToLiquify) + amountTokenAddedToPool1, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // When adding the liquidity to the pool some tokens can be returned to the token contract
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - (swapTokensAtAmountBefore - tokenAmountToLiquify) - amountTokenAddedToPool1, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid charity wallet token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee - (coinToken.liquidityFee()/2);
        uint256 amountEthMarketing = (amountEthSwapped1 * coinToken.marketingFee()) / totalETHFee;
        uint256 amountEthDev       = 0;
        uint256 amountEthCharity   = (amountEthSwapped1 * coinToken.charityFee()) / totalETHFee;
        //uint256 amountEthToLiquify = (amountEthSwapped1 * coinToken.liquidityFee()) / totalETHFee / 2;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq((reserve_weth_before_pair - amountEthSwapped1) + amountETHAddedToPool1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Dev an marketing wallet should reveive eth (fees)
        assertTrue(eth_balance_before_marketing < eth_balance_after_marketing, 'Invalid marketing wallet eth balance1');
        assertEq(eth_balance_before_marketing + amountEthMarketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertEq(eth_balance_before_dev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertEq(eth_balance_before_charity + amountEthCharity, eth_balance_after_charity, 'Invalid charity wallet eth balance2');
        // Owner should not receive any eth
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner + amountLiquidityToken1, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');

        vm.stopPrank();
    }

    // Liquidity fee is zero because of ratio
    function testSwapAndLiquifyMarketingAndLiquidityFeeZero() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.setFees(0, 5, 7, 0, 9, 100, 100); 
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);

        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        uint256 liquidity_tokens_before_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.triggerSwapAndLiquify(35);
        assertTrue(amountLiquidityToken1 == 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 == 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 == 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 != 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity          = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = 0;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + swapTokensAtAmountBefore, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // No liquidity add to pool
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - swapTokensAtAmountBefore, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid charity wallet token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee;
        uint256 amountEthMarketing = (amountEthSwapped1 * coinToken.marketingFee()) / totalETHFee;
        uint256 amountEthDev       = (amountEthSwapped1 * coinToken.devFee()) / totalETHFee;
        uint256 amountEthCharity       = (amountEthSwapped1 * coinToken.charityFee()) / totalETHFee;
        uint256 amountEthToLiquify = 0;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        console.log('Amount eth not used: ', amountEthNotUsed);
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(reserve_weth_before_pair - amountEthSwapped1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Dev should reveive eth (fees)
        assertEq(eth_balance_before_marketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertTrue(eth_balance_before_dev < eth_balance_after_dev, 'Invalid dev wallet eth balance1');
        assertEq(eth_balance_before_dev + amountEthDev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertEq(eth_balance_before_charity + amountEthCharity, eth_balance_after_charity, 'Invalid Charity wallet eth balance2');
        // Owner should not receive any eth
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');

        vm.stopPrank();
    }

    function testSwapAndLiquifyManual() public {

        vm.startPrank(USER, USER);
        vm.expectRevert();
        coinToken.manualSwap();
        vm.stopPrank();
        console.log('checkpoint1');

        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 swapTokensAtAmountBefore = coinToken.getSwapTokensAtAmount();
        console.log('Swap tokens at amount before: ', swapTokensAtAmountBefore);
        // After open trading all eth is taken from contract
        vm.deal(address(coinToken), 10 ether);

        // uint8 newLiquidityFee, uint8 newDevFee, uint8 newBurnFee, uint8 newMarketingFee
        coinToken.setFees(5, 5, 7, 8, 9, 100, 100);
        console.log('checkpoint2');
        uint8 totalFee = coinToken.triggerGetTotalFeeAmount() - coinToken.burnFee();
        vm.stopPrank();

        sendTokensFromOwnerTo(address(coinToken), swapTokensAtAmountBefore + 1000, false);
        console.log('checkpoint3');
        vm.startPrank(owner_address, owner_address);
        (uint112 reserve_cointoken_before_pair, uint112 reserve_weth_before_pair, ) = pair.getReserves();
        uint256 token_balance_before_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_before_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_before_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_before_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_before_owner          = coinToken.balanceOf(address(owner_address));
        uint256 eth_balance_before_cointoken        = address(coinToken).balance;
        uint256 eth_balance_before_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_before_dev              = address(devWallet).balance;
        uint256 eth_balance_before_charity          = address(charityWallet).balance;
        uint256 eth_balance_before_owner            = address(owner_address).balance;
        uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));
        console.log('checkpoint3.5');

        (uint256 amountEthSwapped1, uint256 amountTokenAddedToPool1, uint256 amountETHAddedToPool1, uint256 amountLiquidityToken1) = coinToken.manualSwap();
        console.log('checkpoint4');
        assertTrue(amountLiquidityToken1 == 0, 'Invalid return value liquidity');
        assertTrue(amountTokenAddedToPool1 == 0 , 'amountTokenReturn invalid');
        assertTrue(amountETHAddedToPool1 == 0, 'amountETHReturn invalid');
        assertTrue(amountEthSwapped1 != 0, 'Invalid amountEthSwapped');

        // After swap balances
        (uint112 reserve_cointoken_after_pair, uint112 reserve_weth_after_pair, ) = pair.getReserves();
        console.log('checkpoint5');

        uint256 token_balance_after_cointoken      = coinToken.balanceOf(address(coinToken));
        uint256 token_balance_after_marketing      = coinToken.balanceOf(address(marketingWallet));
        uint256 token_balance_after_dev            = coinToken.balanceOf(address(devWallet));
        uint256 token_balance_after_charity        = coinToken.balanceOf(address(charityWallet));
        uint256 token_balance_after_owner          = coinToken.balanceOf(address(owner_address));

        uint256 eth_balance_after_cointoken        = address(coinToken).balance;
        uint256 eth_balance_after_marketing        = address(marketingWallet).balance;
        uint256 eth_balance_after_dev              = address(devWallet).balance;
        uint256 eth_balance_after_charity          = address(charityWallet).balance;
        uint256 eth_balance_after_owner            = address(owner_address).balance;

        uint256 liquidity_tokens_after_cointoken   = pair.balanceOf(address(coinToken));
        uint256 liquidity_tokens_after_marketing   = pair.balanceOf(address(marketingWallet));
        uint256 liquidity_tokens_after_dev         = pair.balanceOf(address(devWallet));
        uint256 liquidity_tokens_after_charity     = pair.balanceOf(address(charityWallet));
        uint256 liquidity_tokens_after_owner       = pair.balanceOf(address(owner_address));

        /////////////
        // Check token balances. Only cointoken and pair balances are updated.
        /////////////
        uint256 tokenAmountToLiquify = 0;
        assertEq(0, coinToken.allowance(address(this), address(router)), 'Invalid allowance cointoken to router');
        assertEq(reserve_cointoken_after_pair, reserve_cointoken_before_pair + swapTokensAtAmountBefore, 'Invalid pair token balance');
        // Swap tokens for eth is substracting the tokenAmountToLiquify (all tokens are used) from the coinToken contract. 
        // No liquidity add to pool
        assertEq(token_balance_after_cointoken, token_balance_before_cointoken - swapTokensAtAmountBefore, 'Invalid cointoken token balance');
        // No tokens added or substracted for marketing, dev and owner
        assertEq(token_balance_before_marketing, token_balance_after_marketing, 'Invalid marketing wallet token balance.');
        assertEq(token_balance_before_dev, token_balance_after_dev, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_charity, token_balance_after_charity, 'Invalid dev wallet token balance');
        assertEq(token_balance_before_owner, token_balance_after_owner,  'Invalid owner token balance');
        console.log('Amount of tokens not used to add to the pool: ', swapTokensAtAmountBefore - tokenAmountToLiquify - amountTokenAddedToPool1);

        ///////////////////////
        // ETH balance
        ///////////////////////
        uint256 totalETHFee        =  totalFee;
        uint256 amountEthMarketing = (amountEthSwapped1 * coinToken.marketingFee()) / totalETHFee;
        uint256 amountEthDev       = (amountEthSwapped1 * coinToken.devFee()) / totalETHFee;
        uint256 amountEthCharity   = (amountEthSwapped1 * coinToken.charityFee()) / totalETHFee;
        uint256 amountEthNotUsed   = amountEthSwapped1 - amountETHAddedToPool1 - amountEthMarketing - amountEthDev - amountEthCharity;
        console.log('Amount eth not used: ', amountEthNotUsed);
        assertTrue(reserve_weth_before_pair > reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(reserve_weth_before_pair - amountEthSwapped1, reserve_weth_after_pair, 'Invalid pair eth balance2');
        assertEq(eth_balance_after_cointoken, eth_balance_before_cointoken + amountEthNotUsed, 'Invalid cointoken eth balance1');
        
        // Dev, marketing and charity wallet should reveive eth (fees)
        assertTrue(eth_balance_before_marketing < eth_balance_after_marketing, 'Invalid marketing wallet eth balance1');
        assertEq(eth_balance_before_marketing + amountEthMarketing, eth_balance_after_marketing, 'Invalid marketing wallet eth balance2');
        assertTrue(eth_balance_before_dev < eth_balance_after_dev, 'Invalid dev wallet eth balance1');
        assertEq(eth_balance_before_dev + amountEthDev, eth_balance_after_dev, 'Invalid dev wallet eth balance2');
        assertTrue(eth_balance_before_charity < eth_balance_after_charity, 'Invalid Charity eth balance1');
        assertEq(eth_balance_before_charity + amountEthCharity, eth_balance_after_charity, 'Invalid Charity eth balance2');
        // Owner should not receive any eth
        assertEq(eth_balance_before_owner, eth_balance_after_owner, 'Invalid owner eth balance');

        // Liquidity tokens balance
        assertEq(liquidity_tokens_after_cointoken, 0, 'Invalid liquidity tokens balance token contract');
        assertEq(liquidity_tokens_after_marketing, 0, 'Invalid liquidity tokens balance marketing contract');
        assertEq(liquidity_tokens_after_dev      , 0, 'Invalid liquidity tokens balance dev contract');
        assertEq(liquidity_tokens_after_charity  , 0, 'Invalid liquidity tokens balance charity contract');
        assertEq(liquidity_tokens_after_owner, liquidity_tokens_before_owner, 'Invalid liquidity tokens balance owner contract');

        // New swaptokens at amount value. Should be the same because no tokens were burned.
        console.log('New swap tokens at amount value: ', coinToken.getSwapTokensAtAmount());
        assertEq((coinToken.totalSupply() * coinToken.getSwapTokensAtAmountTotalSupplyPercentage()) / 1000, coinToken.getSwapTokensAtAmount(), 'Invalid newgetSwapTokensAtAmount');
        console.log('checkpoint6');
        vm.stopPrank();
    }

    //From token contract to uniswap pair. Tokens are substraced from token contract and added to pair, 
    //eth is added to token contract. After transaction the router must have 0 allowance. No fee is taken.
    function testSwapTokensForEth() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();

        // Send tokens to token contract
        uint256 tokenAmount = 100000 * 10 ** decimals;
        uint256 transferAmount = tokenAmount / 2;
        console.log('Transaction 1, sending tokens from owner to token contract');
        sendTokensFromOwnerTo(address(coinToken), tokenAmount, false);
        console.log('Transaction 2, sending tokens from token contract to pair. ETH from pair to token contract.');
        uint256 token_eth_balance_before = address(coinToken).balance;
        (uint112 pair_token_reserve_before, uint112 pair_eth_reserve_before, ) = pair.getReserves();
        coinToken.triggerSwapTokensForEth(transferAmount);
        uint256 token_eth_balance_after = address(coinToken).balance;
        (uint112 pair_token_reserve_after, uint112 pair_eth_reserve_after, ) = pair.getReserves();
        // Allowence of token to router must be 0
        assertEq(coinToken.allowance(address(coinToken), address(router)), 0, 'Invalid allowence');
        // Token contract has 0 tokens
        assertEq(coinToken.balanceOf(address(coinToken)), tokenAmount - transferAmount, 'Invalid token contract balance');
        // Tokens are added to pair
        assertEq(pair_token_reserve_after, pair_token_reserve_before + transferAmount, 'Invalid pair token balance');
        // ETH is substracted from pair
        assertEq(pair_eth_reserve_before - (token_eth_balance_after-token_eth_balance_before), pair_eth_reserve_after, 'Invalid pair eth balance');
        // ETH is added to cointoken contract
        assertTrue(address(coinToken).balance > token_eth_balance_before, 'Invalid token eth balance');
    }

    /////////////////////////////////////////////
    // FEES
    /////////////////////////////////////////////

    function testIsFeeAppliedOnTransaction() public {
        vm.startPrank(owner_address, owner_address);
        // From and to are exluded
        assertFalse(coinToken.triggerIsFeeAppliedOnTransaction(owner_address, address(this)), 'fail 1');
        // From is excluded
        assertFalse(coinToken.triggerIsFeeAppliedOnTransaction(owner_address, USER), 'fail 2');
        // To is excluded
        assertFalse(coinToken.triggerIsFeeAppliedOnTransaction(USER, owner_address), 'fail 3');
        // From and to are not excluded. 3 fees are zero. 1 fee is not zero
        coinToken.setFees(0, 0, 10, 0, 10, 100, 100);
        assertTrue(coinToken.triggerIsFeeAppliedOnTransaction(USER2, USER), 'fail 4');
        // From and to are not excluded. All fees are not zero.
        coinToken.setFees(5, 6, 10, 12, 5, 100, 100);
        assertTrue(coinToken.triggerIsFeeAppliedOnTransaction(USER2, USER), 'fail 5');
        // From is excluded and all fees are zero. Charity fee cannot be zero.
        coinToken.setFees(0, 0, 0, 0, 0, 100, 100);
        assertFalse(coinToken.triggerIsFeeAppliedOnTransaction(owner_address, USER), 'fail 8');
        // To is excluded and all fees are zero
        coinToken.setFees(0, 0, 0, 0, 0, 100, 100);
        assertFalse(coinToken.triggerIsFeeAppliedOnTransaction(USER, owner_address), 'fail 8');
        // From and to are excluded and all fees are zero
        coinToken.setFees(0, 0, 0, 0, 0, 100, 100);
        assertFalse(coinToken.triggerIsFeeAppliedOnTransaction(address(coinToken), owner_address), 'fail 9');
        vm.stopPrank();
    }

    // TEST PROCESS FEE. Scenarios. 1. Transfer between wallets. 2. Buy transaction (from is pair to is user). 3. Sell transaction (from is user to is pair)
    // isFeeAppliedOnTransaction is already checking if all fees are zero. If yes, process fee function is not triggered.

    // 1. TRANSFER BETWEEN WALLETS-------------------------------------------------------------------

    // 1.1. All fees are not zero. Sell and by multiplier are 100.
    function testProcessFeeBetweenWallet11() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();

        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        coinToken.setFees(11, 12, 13, 8, 6, 100, 100);
        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, owner_address, USER);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + tokenAmount/1000*(11+12+8+6), 'Invalid token contract amount');
        assertEq(coinToken.totalSupply(), total_supply_before - (tokenAmount/1000*13), 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount/1000*950, 'Invalid transferamount');
    }

    // 1.2. All fees are not zero. Sell and by multiplier are 125 (should have no effect because is transfer between wallets).
    function testProcessFeeBetweenWallet12() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        coinToken.setFees(5,6,7,8,9, 125, 125);
        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, owner_address, USER);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + tokenAmount/1000*(5+6+8+9), 'Invalid token contract amount');
        assertEq(coinToken.totalSupply(), total_supply_before - (tokenAmount/1000*7), 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount/1000*965, 'Invalid transferamount');
    }

    // 1.3. Burn fee is zero. Marketing fee is zero. Buy(150) and sell(125) multiplier (should have no effect).
    function testProcessFeeBetweenWallet13() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        coinToken.setFees(5,6,0,8,9, 125, 150);
        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, owner_address, USER);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + tokenAmount/1000*(5+6+8+9), 'Invalid token contract amount');
        assertEq(coinToken.totalSupply(), total_supply_before, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount/1000*972, 'Invalid transferamount');
    }

    // 1.4. Burn fee is not zero. Other fees are zero. Buy(150) and sell(125) multiplier (should have no effect).
    function testProcessFeeBetweenWallet14() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        coinToken.setFees(0, 0, 13, 0, 0, 150, 125);
        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, owner_address, USER);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before, 'Invalid token contract amount');
        assertEq(coinToken.totalSupply(), total_supply_before - ((tokenAmount*(13))/1000), 'Invalid burn amount');
        assertEq(transferAmount, ((tokenAmount*987)/1000), 'Invalid transferamount');
    }

    // 2.   Buy transaction (from is pair to is user)----------------------------------------------------------------------------

    // 2.1. All fees are not zero. Buy multiplier(110), sell (125)
    function testProcessFeePairBuy21() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        coinToken.setFees(5,6,7,8,9, 110, 125);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, address(pair), USER);
        uint256 feeAmount  = ((tokenAmount*(5+6+8+9)*110) / (100*1000));
        uint256 burnAmount = ((tokenAmount*7*110) / (100*1000));
        assertTrue(burnAmount > 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount > 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    // 2.2. All fees are not zero. Buy multiplier(125), sell (130)
    function testProcessFeePairBuy22() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        coinToken.setFees(5,6,7,8,9, 125, 130);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, address(pair), USER);
        uint256 feeAmount  = ((tokenAmount*(5+6+8+9)*125) / (100*1000));
        uint256 burnAmount = ((tokenAmount*7*125) / (100*1000));
        assertTrue(feeAmount > 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount > 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    // 2.3. Burn fee is zero. Marketing fee is zero. Buy multiplier (108), sell(111)
    function testProcessFeePairBuy23() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        uint16 buyMultiplier  = 108;
        uint16 sellMultiplier = 111;
        coinToken.setFees(11, 12, 0, 0, 6, buyMultiplier, sellMultiplier);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, address(pair), USER);
        uint256 feeAmount  = ((tokenAmount*(11+12+0+6)*buyMultiplier) / (100*1000));
        uint256 burnAmount = ((tokenAmount*0*buyMultiplier) / (100*1000));
        console.log('burnAmount: ', burnAmount);
        assertTrue(feeAmount > 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount == 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    // 2.4. Burn fee is not zero. Other fees are zero. Buy multiplier(145), sell(150).
    function testProcessFeePairBuy24() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint256 tokenAmount = 10000 * 10 ** decimals;
        uint16 buyMultiplier  = 145;
        uint16 sellMultiplier = 150;
        coinToken.setFees(0, 0, 13, 0, 0, buyMultiplier, sellMultiplier);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, address(pair), USER);
        uint256 feeAmount  = ((tokenAmount*(0+0+0)*buyMultiplier) / (100*1000));
        uint256 burnAmount = ((tokenAmount*13*buyMultiplier) / (100*1000));
        assertTrue(feeAmount == 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount > 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    // SELL TRANSACTION -----------------------------------------------------------------
    // 3.1. All fees are not zero. Multiplier buy(110), sell(125).
    function testProcessFeePairSell31() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint16 buyMultiplier  = 110;
        uint16 sellMultiplier = 125;
        coinToken.setFees(5,6,7,8,9, buyMultiplier, sellMultiplier);
        vm.stopPrank();
        uint256 tokenAmount = 10000 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, tokenAmount, false);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, USER, address(pair));
        uint256 feeAmount  = ((tokenAmount*(5+6+8+9)*sellMultiplier) / (100*1000));
        uint256 burnAmount = ((tokenAmount*7*sellMultiplier) / (100*1000));
        assertTrue(feeAmount > 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount > 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    // 3.2. All fees are not zero. Multiplier buy(120), sell(133).
    function testProcessFeePairSell32() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint16 buyMultiplier  = 120;
        uint16 sellMultiplier = 133;
        coinToken.setFees(5,6,7,8,9, buyMultiplier, sellMultiplier);
        vm.stopPrank();
        uint256 tokenAmount = 10000 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, tokenAmount, false);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, USER, address(pair));
        uint256 feeAmount  = ((tokenAmount*(5+6+8+9)*sellMultiplier) / (100*1000));
        uint256 burnAmount = ((tokenAmount*7*sellMultiplier) / (100*1000));
        assertTrue(feeAmount > 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount > 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }
   
    // 3.3. Burn fee is zero. Marketing fee is zero. Multiplier buy(110), sell(125).
    function testProcessFeePairSell33() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint16 buyMultiplier  = 110;
        uint16 sellMultiplier = 125;
        coinToken.setFees(11, 12, 0, 0, 6, buyMultiplier, sellMultiplier);
        vm.stopPrank();
        uint256 tokenAmount = 10000 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, tokenAmount, false);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, USER, address(pair));
        uint256 feeAmount  = ((tokenAmount*(11+12+0+6)*sellMultiplier) / (100*1000));
        uint256 burnAmount = ((tokenAmount*0*sellMultiplier) / (100*1000));
        assertTrue(feeAmount > 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount == 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    // 3.4. Burn fee is not zero. Other fees are zero. Sell multiplier is 150, buy 100.
    function testProcessFeePairSell34() public{
        sendOutPreDexTokens(50, 5, 40, 5);
        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        uint16 buyMultiplier  = 100;
        uint16 sellMultiplier = 150;
        coinToken.setFees(0, 0, 10, 0, 0, buyMultiplier, sellMultiplier);
        vm.stopPrank();
        uint256 tokenAmount = 10000 * 10 ** decimals;
        sendTokensFromOwnerTo(USER, tokenAmount, false);

        uint256 total_supply_before = coinToken.totalSupply();
        uint256 coinToken_token_balance_before =  coinToken.balanceOf(address(coinToken));
        uint256 transferAmount = coinToken.triggerProcessfee(tokenAmount, USER, address(pair));
        uint256 feeAmount  = ((tokenAmount*(0+0+0)*sellMultiplier) / (100*1000));
        uint256 burnAmount = ((tokenAmount*10*sellMultiplier) / (100*1000));
        assertTrue(feeAmount == 0);
        assertEq(coinToken.balanceOf(address(coinToken)), coinToken_token_balance_before + feeAmount, 'Invalid token contract amount');
        assertTrue(burnAmount > 0);
        assertEq(coinToken.totalSupply(), total_supply_before - burnAmount, 'Invalid burn amount');
        assertEq(transferAmount, tokenAmount-feeAmount-burnAmount, 'Invalid transferamount');
    }

    /////////////////////////////////
    // TRANSFER TESTS
    // Add automated market pair
    // use router calls to buy and sell tokens with different uses
    // test fee processing, swap, token price.
    //token price = weth pair reserve / token pair reserve = ... weth per token. This is weth price per token (not dollar)
    /////////////////////////////////

    // Add automated market pair. Test max wallet, transfer delay, max transaction.
    // Swap can be triggered when new market pair is the from address.
    function testAddingAutomatedMarketPair() public {
        sendOutPreDexTokens(50, 5, 40, 5);
        console.log('Step1');

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        console.log('Step2');

        sendTokensBackToOwner();
        console.log('Step3');

        uint256 amountToTransfer = coinToken.maxWallet();
        sendTokensFromOwnerTo(USER, amountToTransfer+10000, false);
        sendTokensFromOwnerTo(USER1, 100000, false);
        sendTokensFromOwnerTo(USER2, 100000, false);
        sendTokensFromOwnerTo(USER3, 100000, false);
        sendTokensFromOwnerTo(USER4, 100001, false);
        console.log('Step4');

        vm.startPrank(owner_address, owner_address);
        coinToken.setAutomatedMarketMakerPair(USER1, true);
        coinToken.setExclusionFromMaxTransaction(USER1, true);
        // Set fees to make the next test block easier.
        coinToken.setFees(0, 0, 0, 0, 0, 100, 100);
        vm.stopPrank();
        console.log('Step5');

        // Transfer delay can only be triggered when automated market pair is from address (user buy token transaction)
        vm.startPrank(USER2, USER2);
        coinToken.transfer(USER1, 10000);
        coinToken.transfer(USER1, 10000);
        assertEq(120000, coinToken.balanceOf(USER1), 'Invalid token balance user1');
        vm.stopPrank();
        console.log('Step6');

        vm.roll(block.number + 1);
        // AutomatedMarketMakerPair must be able to have a balance > maxWallet
        vm.startPrank(USER, USER);
        uint256 user_balance_before = coinToken.balanceOf(USER1);
        coinToken.transfer(USER1, amountToTransfer);
        assertTrue(user_balance_before + amountToTransfer == coinToken.balanceOf(USER1) && coinToken.balanceOf(USER1) > coinToken.maxWallet(), 'Invalid token balance user4');
        vm.stopPrank();
        console.log('Step7');

        vm.roll(block.number + 1);
        // AutomatedMarketMakerPair must be able to make sell tokens > max transaction amount
        vm.startPrank(USER1, USER1);
        uint256 user_balance_before1 = coinToken.balanceOf(USER1);
        uint256 owner_balance_before1 = coinToken.balanceOf(owner_address);
        coinToken.transfer(owner_address, coinToken.maxTransactionAmount() + 1);
        assertEq(owner_balance_before1 + (coinToken.maxTransactionAmount() + 1), coinToken.balanceOf(owner_address));
        assertEq(user_balance_before1 - (coinToken.maxTransactionAmount() + 1), coinToken.balanceOf(USER1));
        vm.stopPrank();
        console.log('Step8');

        vm.roll(block.number + 1);
        sendTokensFromOwnerTo(address(coinToken), coinToken.getSwapTokensAtAmount()+1, false);
        console.log('Step9');

        vm.startPrank(owner_address);
        coinToken.setFees(11, 12, 13, 8, 6, 100, 100);
        coinToken.setFeeExclusionForAccount(USER1, true);
        vm.stopPrank();
        console.log('Step10');

        // Test that swap will not be triggered if market pair is from address
        // Also test no fees are paid.
        uint256 marketing_eth_balance_before = address(marketingWallet).balance;
        uint256 ampTokenBalanceBefore = coinToken.balanceOf(USER1);
        uint256 user2TokenBalanceBefore = coinToken.balanceOf(USER2);
        vm.startPrank(USER1, USER1);
        console.log('Step10.1: ', ampTokenBalanceBefore);
        coinToken.transfer(USER2, 10000);
        console.log('Step10.2');
        assertEq(ampTokenBalanceBefore - 10000, coinToken.balanceOf(USER1), 'Error1');
        assertEq(10000 + user2TokenBalanceBefore, coinToken.balanceOf(USER2), 'Error2');
        assertTrue(address(marketingWallet).balance == marketing_eth_balance_before);
        vm.stopPrank();
        console.log('Step11');
    }
 
    function testTransferFunction() public { 
        sendOutPreDexTokens(50, 5, 40, 5);
        uint256 amountToken = 10000 * 10 ** decimals;

        vm.startPrank(owner_address, owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();

        sendTokensBackToOwner();

        console.log('From and to addresses are zero address');
        vm.startPrank(address(0), address(0));
        vm.expectRevert();
        coinToken.transfer(USER, amountToken);
        vm.stopPrank();

        console.log('Not enough balance');
        vm.startPrank(USER, USER);
        vm.expectRevert();
        coinToken.transfer(address(coinToken), amountToken);
        vm.stopPrank();

        console.log('Zero tokens');
        vm.startPrank(owner_address, owner_address);
        vm.expectRevert();
        coinToken.transfer(USER, 0);
        vm.stopPrank();
        
        // Max transfer value
        console.log('Max transfer value');
        vm.startPrank(owner_address);
        // Owner can send more than max transaction amount.
        uint256 tokenAmount = coinToken.maxTransactionAmount() + 1;
        coinToken.transfer(address(USER), tokenAmount);
        vm.stopPrank();
        vm.startPrank(USER, USER);
        console.log('Balance user: ', coinToken.balanceOf(USER));
        console.log('Token amount: ', tokenAmount);
        console.log('Max transaction value: ', coinToken.maxTransactionAmount());
        // User cannot send more than max transaction amount.
        vm.expectRevert();
        coinToken.transfer(address(USER2), tokenAmount);
        vm.stopPrank();
    }

    // Combination of uniswap buys, sells and wallet transaction. Track token price movement, fee processing and swap
    // Price is reserve cointoken/reserve weth
    function testTransactions1() public {
        sendOutPreDexTokens(50, 5, 40, 5);

        vm.startPrank(owner_address);
        coinToken.addLqToUniswap();
        coinToken.openTrading();
        vm.stopPrank();
        sendTokensBackToOwner();
        vm.startPrank(owner_address, owner_address);
        //uint256 liquidity_tokens_before_owner       = pair.balanceOf(address(owner_address));
        uint256 beginSupply = coinToken.totalSupply();
        // (uint112 reserve_cointoken_pair1, uint112 reserve_weth_pair1, ) = pair.getReserves();
        // uint256 price1 = ((reserve_weth_pair1 * 10 ** decimals) / reserve_cointoken_pair1);
        // console.log('cointoken reserve1: ', reserve_cointoken_pair1);
        // console.log('weth reserve1: ', reserve_weth_pair1);
        // console.log('Price 1: ', price1);
        coinToken.setMaxWallet(1000); //100% of total supply
        coinToken.setMaxTransaction(beginSupply);
        vm.stopPrank();
        console.log('step1');

        // Max transaction error
        // vm.deal(USER, 1000 ether);
        //uint256 maxTxAmount = coinToken.maxTransactionAmount();
        // uint256 ethAmount = 10 ether;
        // //vm.expectRevert();
        // uniswapUserBuyTokens(maxTxAmount, ethAmount, address(USER));

        // Remove max wallet and transaction limits
        // vm.startPrank(owner_address);
        // coinToken.setMaxWallet(1000); //100% of total supply
        // coinToken.setMaxTransaction(coinToken.totalSupply());
        // vm.stopPrank();

        // If supply is 1 billion, 10 ether will buy around 50% of all tokens
        vm.deal(USER, 1000 ether);
        vm.deal(USER1, 1000 ether);
        uniswapUserBuyTokens(10000 * 10 ** decimals, 10 ether, USER);
        console.log('USER TOKEN BALANCE AFTER TRANSACTION 1: ', coinToken.balanceOf(USER));
        console.log('USER ETH BALANCE AFTER TRANSACTION 1: ', address(USER).balance);
        (uint112 reserve_cointoken_pair2, uint112 reserve_weth_pair2, ) = pair.getReserves();
        uint256 price2 = ((reserve_weth_pair2 * 10 ** decimals) / reserve_cointoken_pair2);
        console.log('cointoken reserve2: ', reserve_cointoken_pair2);
        console.log('weth reserve2: ', reserve_weth_pair2);
        console.log('Price 2: ', price2);
        console.log('TOTAl Burned tokens1: ', beginSupply - coinToken.totalSupply());
        console.log('total Tax received1: ', coinToken.balanceOf(address(coinToken)));
        console.log('Ratio1: ', coinToken.triggerCheckRatio());

        // Swap is not triggered because of buy transaction
        uniswapUserBuyTokens(10000 * 10 ** decimals, 10 ether, USER1);
        console.log('USER1 TOKEN BALANCE AFTER TRANSACTION 2: ', coinToken.balanceOf(USER1));
        console.log('USER1 ETH BALANCE AFTER TRANSACTION 2: ', address(USER1).balance);
        (uint112 reserve_cointoken_pair3, uint112 reserve_weth_pair3, ) = pair.getReserves();
        uint256 price3 = ((reserve_weth_pair3 * 10 ** decimals) / reserve_cointoken_pair3);
        console.log('cointoken reserve3: ', reserve_cointoken_pair3);
        console.log('weth reserve3: ', reserve_weth_pair3);
        console.log('Price 3: ', price3);
        console.log('total Burned tokens3: ', beginSupply - coinToken.totalSupply());
        console.log('total Tax received3: ', coinToken.balanceOf(address(coinToken)));
        console.log('Ratio2: ', coinToken.triggerCheckRatio());
        
        vm.roll(block.number +1);
        //console.log('swaptokenatamount: ', coinToken.getSwapTokensAtAmount());
        //Sell is triggering swap.
        vm.startPrank(USER, USER);
        address[] memory path = new address[](2);
        path[0] = address(coinToken);
        path[1] = router.WETH();
        coinToken.approve(address(router), 2500*10**decimals);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            2500*10**decimals, //amountIn
            0, //amountOutMin
            path,
            USER, // The address that will receive the eth
            block.timestamp
        );
        vm.stopPrank();
        console.log('USER TOKEN BALANCE AFTER TRANSACTION 4: ', coinToken.balanceOf(USER));
        console.log('USER ETH BALANCE AFTER TRANSACTION 4: ', address(USER).balance);
        (uint112 reserve_cointoken_pair4, uint112 reserve_weth_pair4, ) = pair.getReserves();
        uint256 price4 = ((reserve_weth_pair4 * 10 ** decimals) / reserve_cointoken_pair4);
        console.log('cointoken reserve4: ', reserve_cointoken_pair4);
        console.log('weth reserve4: ', reserve_weth_pair4);
        console.log('Price 4: ', price4);
        console.log('burned 4: ', beginSupply - coinToken.totalSupply());
        console.log('tax4: ', coinToken.balanceOf(address(coinToken)));
        console.log('Liquidity tokens owner after swap: ', pair.balanceOf(address(owner_address)));
        console.log('eth tax added to marketing: ', address(marketingWallet).balance);
        console.log('eth tax added to dev: ', address(devWallet).balance);
        console.log('Ratio3: ', coinToken.triggerCheckRatio());
    }

}
