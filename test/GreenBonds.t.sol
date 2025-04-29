// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/GreenBonds.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1 million tokens to deployer
    }
}

contract GreenBondsTest is Test {
    GreenBonds public greenBonds;
    MockToken public paymentToken;
    
    address public admin = address(1);
    address public issuer = address(2);
    address public verifier = address(3);
    address public investor1 = address(4);
    address public investor2 = address(5);
    
    // Bond parameters
    string public name = "Green Energy Bond";
    string public symbol = "GEB";
    uint256 public faceValue = 1000 * 10**18; // 1000 tokens per bond
    uint256 public totalSupply = 1000; // 1000 bonds
    uint256 public couponRate = 500; // 5.00%
    uint256 public couponPeriod = 90 days; // Quarterly payments
    uint256 public maturityPeriod = 3 * 365 days; // 3 years
    string public projectDescription = "Solar farm in California";
    string public impactMetrics = "CO2 reduction, renewable energy production";
    
    event BondPurchased(address indexed investor, uint256 amount, uint256 tokensSpent);
    event CouponClaimed(address indexed investor, uint256 amount);
    event BondRedeemed(address indexed investor, uint256 amount, uint256 tokensReceived);
    event ImpactReportAdded(uint256 indexed reportId, string reportURI);
    event ImpactReportVerified(uint256 indexed reportId);
    event FundsAllocated(string projectComponent, uint256 amount);
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock token and mint some to test accounts
        paymentToken = new MockToken();
        
        // Deploy GreenBonds contract
        greenBonds = new GreenBonds(
            name,
            symbol,
            faceValue,
            totalSupply,
            couponRate,
            couponPeriod,
            maturityPeriod,
            address(paymentToken),
            projectDescription,
            impactMetrics
        );
        
        // Setup roles
        greenBonds.grantRole(greenBonds.ISSUER_ROLE(), issuer);
        greenBonds.addVerifier(verifier);
        
        // Transfer tokens to investors
        paymentToken.transfer(investor1, 5000 * 10**18);
        paymentToken.transfer(investor2, 5000 * 10**18);
        
        vm.stopPrank();
    }
    
    function test_Initialization() public view{
        assertEq(greenBonds.name(), name);
        assertEq(greenBonds.symbol(), symbol);
        assertEq(greenBonds.faceValue(), faceValue);
        assertEq(greenBonds.totalSupply(), totalSupply);
        assertEq(greenBonds.availableSupply(), totalSupply);
        assertEq(greenBonds.couponRate(), couponRate);
        assertEq(greenBonds.couponPeriod(), couponPeriod);
        assertEq(greenBonds.projectDescription(), projectDescription);
        assertEq(greenBonds.impactMetrics(), impactMetrics);
        
        // Check roles
        assertTrue(greenBonds.hasRole(greenBonds.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(greenBonds.hasRole(greenBonds.ISSUER_ROLE(), admin));
        assertTrue(greenBonds.hasRole(greenBonds.ISSUER_ROLE(), issuer));
        assertTrue(greenBonds.hasRole(greenBonds.VERIFIER_ROLE(), verifier));
    }
    
    function test_PurchaseBonds() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Approve tokens for purchase
        paymentToken.approve(address(greenBonds), cost);
        
        // Check event emission
        vm.expectEmit(true, false, false, true);
        emit BondPurchased(investor1, bondAmount, cost);
        
        // Purchase bonds
        greenBonds.purchaseBonds(bondAmount);
        
        // Check state changes
        assertEq(greenBonds.bondHoldings(investor1), bondAmount);
        assertEq(greenBonds.availableSupply(), totalSupply - bondAmount);
        assertEq(greenBonds.lastCouponClaimDate(investor1), block.timestamp);
        assertEq(paymentToken.balanceOf(address(greenBonds)), cost);
        
        vm.stopPrank();
    }
    
    function test_PurchaseBonds_InsufficientSupply() public {
        uint256 bondAmount = totalSupply + 1;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Approve tokens for purchase
        paymentToken.approve(address(greenBonds), cost);
        
        // Attempt to purchase more bonds than available
        vm.expectRevert(GreenBonds.InsufficientBondsAvailable.selector);
        greenBonds.purchaseBonds(bondAmount);
        
        vm.stopPrank();
    }
    
    function test_PurchaseBonds_ZeroAmount() public {
        vm.startPrank(investor1);
        
        // Attempt to purchase zero bonds
        vm.expectRevert(GreenBonds.InvalidBondAmount.selector);
        greenBonds.purchaseBonds(0);
        
        vm.stopPrank();
    }
    
    function test_PurchaseBonds_AfterMaturity() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Approve tokens for purchase
        paymentToken.approve(address(greenBonds), cost);
        
        // Warp to after maturity
        vm.warp(block.timestamp + maturityPeriod + 1);
        
        // Attempt to purchase bonds after maturity
        vm.expectRevert(GreenBonds.BondMatured.selector);
        greenBonds.purchaseBonds(bondAmount);
        
        vm.stopPrank();
    }
    
    function test_CalculateClaimableCoupon() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Purchase bonds
        paymentToken.approve(address(greenBonds), cost);
        greenBonds.purchaseBonds(bondAmount);
        
        // Advance time by one coupon period
        vm.warp(block.timestamp + couponPeriod);
        
        // Calculate coupon
        uint256 bondValue = bondAmount * faceValue;
        uint256 annualCoupon = bondValue * couponRate / 10000; // Convert basis points to percentage
        uint256 expectedCoupon = annualCoupon * couponPeriod / 365 days;
        
        assertEq(greenBonds.calculateClaimableCoupon(investor1), expectedCoupon);
        
        vm.stopPrank();
    }
    
    function test_ClaimCoupon() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Purchase bonds
        paymentToken.approve(address(greenBonds), cost);
        greenBonds.purchaseBonds(bondAmount);
        
        // Advance time by one coupon period
        vm.warp(block.timestamp + couponPeriod);
        
        // Calculate expected coupon
        uint256 bondValue = bondAmount * faceValue;
        uint256 annualCoupon = bondValue * couponRate / 10000; // Convert basis points to percentage
        uint256 expectedCoupon = annualCoupon * couponPeriod / 365 days;
        
        // Check event emission
        vm.expectEmit(true, false, false, true);
        emit CouponClaimed(investor1, expectedCoupon);
        
        // Claim coupon
        uint256 balanceBefore = paymentToken.balanceOf(investor1);
        greenBonds.claimCoupon();
        uint256 balanceAfter = paymentToken.balanceOf(investor1);
        
        // Verify state changes
        assertEq(balanceAfter - balanceBefore, expectedCoupon);
        assertEq(greenBonds.lastCouponClaimDate(investor1), block.timestamp);
        
        vm.stopPrank();
    }
    
    function test_ClaimCoupon_NoCouponAvailable() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Purchase bonds
        paymentToken.approve(address(greenBonds), cost);
        greenBonds.purchaseBonds(bondAmount);
        
        // Attempt to claim coupon immediately (no time passed)
        vm.expectRevert(GreenBonds.NoCouponAvailable.selector);
        greenBonds.claimCoupon();
        
        vm.stopPrank();
    }
    
    function test_RedeemBonds() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        // Setup: We need to ensure the contract has enough tokens to pay out both principal and interest
        // Mint extra tokens to admin and send to contract to cover interest payments
        vm.startPrank(admin);
        uint256 extraTokens = bondAmount * faceValue; // Extra tokens to cover interest
        paymentToken.transfer(address(greenBonds), extraTokens);
        vm.stopPrank();
        
        vm.startPrank(investor1);
        
        // Purchase bonds
        paymentToken.approve(address(greenBonds), cost);
        greenBonds.purchaseBonds(bondAmount);
        
        // Advance time to exactly maturity (avoids excessive interest calculation)
        vm.warp(greenBonds.maturityDate());
        
        // Calculate expected redemption value (principal + final coupon)
        uint256 principalAmount = bondAmount * faceValue;
        
        // Calculate coupon amount matching the contract's calculation
        uint256 claimableCoupon = greenBonds.calculateClaimableCoupon(investor1);
        uint256 expectedTotal = principalAmount + claimableCoupon;
        
        // Check event emission
        vm.expectEmit(true, false, false, true);
        emit BondRedeemed(investor1, bondAmount, expectedTotal);
        
        // Redeem bonds
        uint256 balanceBefore = paymentToken.balanceOf(investor1);
        greenBonds.redeemBonds();
        uint256 balanceAfter = paymentToken.balanceOf(investor1);
        
        // Verify state changes
        assertEq(balanceAfter - balanceBefore, expectedTotal);
        assertEq(greenBonds.bondHoldings(investor1), 0);
        assertEq(greenBonds.lastCouponClaimDate(investor1), 0);
        
        vm.stopPrank();
    }
    
    function test_RedeemBonds_BeforeMaturity() public {
        uint256 bondAmount = 2;
        uint256 cost = bondAmount * faceValue;
        
        vm.startPrank(investor1);
        
        // Purchase bonds
        paymentToken.approve(address(greenBonds), cost);
        greenBonds.purchaseBonds(bondAmount);
        
        // Attempt to redeem before maturity
        vm.expectRevert(GreenBonds.BondNotMatured.selector);
        greenBonds.redeemBonds();
        
        vm.stopPrank();
    }
    
    function test_RedeemBonds_NoBonds() public {
        vm.startPrank(investor1);
        
        // Advance time to maturity
        vm.warp(block.timestamp + maturityPeriod + 1);
        
        // Attempt to redeem with no bonds
        vm.expectRevert(GreenBonds.NoBondsToRedeem.selector);
        greenBonds.redeemBonds();
        
        vm.stopPrank();
    }
    
    function test_AddImpactReport() public {
        string memory reportURI = "https://example.com/report1";
        string memory reportHash = "0x1234567890abcdef";
        string memory metrics = "50 tons CO2 reduced";
        
        vm.startPrank(issuer);
        
        // Check event emission
        vm.expectEmit(true, false, false, true);
        emit ImpactReportAdded(0, reportURI);
        
        // Add impact report
        greenBonds.addImpactReport(reportURI, reportHash, metrics);
        
        // Verify report was added
        assertEq(greenBonds.getImpactReportCount(), 1);
        
        // Get report details
        (string memory storedURI, string memory storedHash, uint256 timestamp, string memory storedMetrics, bool verified) = greenBonds.impactReports(0);
        
        assertEq(storedURI, reportURI);
        assertEq(storedHash, reportHash);
        assertEq(storedMetrics, metrics);
        assertEq(verified, false);
        assertEq(timestamp, block.timestamp);
        
        vm.stopPrank();
    }
    
    function test_VerifyImpactReport() public {
        // First add a report
        vm.startPrank(issuer);
        greenBonds.addImpactReport("https://example.com/report1", "0x1234567890abcdef", "50 tons CO2 reduced");
        vm.stopPrank();
        
        vm.startPrank(verifier);
        
        // Check event emission
        vm.expectEmit(true, false, false, true);
        emit ImpactReportVerified(0);
        
        // Verify the report
        greenBonds.verifyImpactReport(0);
        
        // Check report is now verified
        (,,,, bool verified) = greenBonds.impactReports(0);
        assertTrue(verified);
        
        vm.stopPrank();
    }
    
    function test_VerifyImpactReport_DoesNotExist() public {
        vm.startPrank(verifier);
        
        // Attempt to verify non-existent report
        vm.expectRevert(GreenBonds.ReportDoesNotExist.selector);
        greenBonds.verifyImpactReport(0);
        
        vm.stopPrank();
    }
    
    function test_VerifyImpactReport_AlreadyVerified() public {
        // First add and verify a report
        vm.startPrank(issuer);
        greenBonds.addImpactReport("https://example.com/report1", "0x1234567890abcdef", "50 tons CO2 reduced");
        vm.stopPrank();
        
        vm.startPrank(verifier);
        greenBonds.verifyImpactReport(0);
        
        // Attempt to verify again
        vm.expectRevert(GreenBonds.ReportAlreadyVerified.selector);
        greenBonds.verifyImpactReport(0);
        
        vm.stopPrank();
    }
    
    function test_IssuerEmergencyWithdraw() public {
        uint256 withdrawAmount = 1000 * 10**18;
        
        // First, have an investor purchase bonds to get funds in the contract
        vm.startPrank(investor1);
        paymentToken.approve(address(greenBonds), withdrawAmount);
        greenBonds.purchaseBonds(withdrawAmount / faceValue);
        vm.stopPrank();
        
        vm.startPrank(issuer);
        
        // Attempt to withdraw too early
        vm.expectRevert(GreenBonds.TooEarlyForWithdrawal.selector);
        greenBonds.issuerEmergencyWithdraw(withdrawAmount);
        
        // Advance time beyond 30-day timelock
        vm.warp(block.timestamp + 31 days);
        
        // Now withdraw should succeed
        uint256 balanceBefore = paymentToken.balanceOf(issuer);
        greenBonds.issuerEmergencyWithdraw(withdrawAmount);
        uint256 balanceAfter = paymentToken.balanceOf(issuer);
        
        // Verify state changes
        assertEq(balanceAfter - balanceBefore, withdrawAmount);
        
        vm.stopPrank();
    }
    
    function test_IssuerEmergencyWithdraw_InsufficientFunds() public {
        // First, have an investor purchase 1 bond
        vm.startPrank(investor1);
        paymentToken.approve(address(greenBonds), faceValue);
        greenBonds.purchaseBonds(1);
        vm.stopPrank();
        
        vm.startPrank(issuer);
        
        // Advance time beyond 30-day timelock
        vm.warp(block.timestamp + 31 days);
        
        // Attempt to withdraw more than available
        uint256 excessiveAmount = faceValue * 2;
        vm.expectRevert(GreenBonds.InsufficientFunds.selector);
        greenBonds.issuerEmergencyWithdraw(excessiveAmount);
        
        vm.stopPrank();
    }
    
}