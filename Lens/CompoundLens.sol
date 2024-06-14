// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

// import "../CErc20.sol";
// import "../CToken.sol" ;
// import "../PriceOracle.sol";
// import "../EIP20Interface.sol";
// import "../Governance/GovernorAlpha.sol";
// import "../Governance/Comp.sol";
// import "../PriceOracle.sol";
// import "../Comptroller.sol";



interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (CToken[] memory);
    function claimComp(address) external;
    function compAccrued(address) external view returns (uint);
    function compSpeeds(address) external view returns (uint);
    function compSupplySpeeds(address) external view returns (uint);
    function compBorrowSpeeds(address) external view returns (uint);
    function borrowCaps(address) external view returns (uint);
    function mintGuardianPaused(address) external view returns (bool);
    function closeFactorMantissa() external view returns (uint);
    function liquidationIncentiveMantissa() external view returns (uint);
    function getAllMarkets()  external view returns (CToken[] memory);
    function getCompAddress() external view returns (address);
    function compBorrowState(address) external view returns (uint224, uint32);
    function compSupplyState(address) external view returns (uint224, uint32);

}
interface EIP20Interface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function balanceOf(address owner) external view returns (uint256 balance);
    function allowance(address owner, address spender) external view returns (uint256 remaining);
}

interface CompInterface {
    function balanceOf(address account) external view returns (uint);
    function getCurrentVotes(address account) external view returns (uint96);
    function delegates(address) external view returns (address);
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}

interface PriceOracle {
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
}

interface CErc20Interface {
  function underlying() external view returns (address);
}

interface CToken {
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function getCash() external view returns (uint);

    function comptroller() external returns (address);

    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function reserveFactorMantissa() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function totalReserves() external view returns (uint);
    function totalSupply() external view returns (uint);
}


interface GovernorBravoInterface {
    
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }
    struct Proposal {
        uint id;
        address proposer;
        uint eta;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executed;
    }
    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas);
    function proposals(uint proposalId) external view returns (Proposal memory);
    function getReceipt(uint proposalId, address voter) external view returns (Receipt memory);
}

contract CompoundLens {
    uint public constant BLOCKS_PER_DAY = 43200;
    struct Double {
        uint mantissa;
    }
    struct PendingReward {
        address cTokenAddress;
        uint256 amount;
    }
    struct RewardSummary {
        address distributorAddress;
        address rewardTokenAddress;
        uint256 totalRewards;
        PendingReward[] pendingRewards;
    }
    struct CTokenAllData {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
        uint compSupplySpeed;
        uint compBorrowSpeed;
        uint borrowCap;
        bool mintGuardianPaused;
        uint underlyingPrice;
        uint dailySupplyComp;
        uint dailyBorrowComp;
        string symbol;
    }

    struct CTokenAllDataWithAccount {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
        uint compSupplySpeed;
        uint compBorrowSpeed;
        uint borrowCap;
        bool mintGuardianPaused;
        uint underlyingPrice;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
        uint dailySupplyComp;
        uint dailyBorrowComp;
         string symbol;
    }
    struct AccountAllData {
        uint closeFactorMantissa;
        uint liquidationIncentiveMantissa;
        CToken[] marketsIn;
        uint liquidity;
        uint shortfall;
        CompBalanceMetadataExt compMetadata;
        uint capFactoryAllowance;
        CTokenAllDataWithAccount[] cTokens;
    }
    struct ClaimVenusLocalVariables {
        uint totalRewards;
        uint224 borrowIndex;
        uint32 borrowBlock;
        uint224 supplyIndex;
        uint32 supplyBlock;
    }
    struct CTokenMetadata {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
        uint compSupplySpeed;
        uint compBorrowSpeed;
        uint borrowCap;
        uint dailySupplyComp;
        uint dailyBorrowComp;
        
    }
    struct NoAccountAllData {
        uint closeFactorMantissa;
        uint liquidationIncentiveMantissa;
        CTokenAllData[] cTokens;
    }


    function getCompSpeeds(ComptrollerLensInterface comptroller, CToken cToken) internal returns (uint, uint) {
        // Getting comp speeds is gnarly due to not every network having the
        // split comp speeds from Proposal 62 and other networks don't even
        // have comp speeds.
        uint compSupplySpeed = 0;
        (bool compSupplySpeedSuccess, bytes memory compSupplySpeedReturnData) =
            address(comptroller).call(
                abi.encodePacked(
                    comptroller.compSupplySpeeds.selector,
                    abi.encode(address(cToken))
                )
            );
        if (compSupplySpeedSuccess) {
            compSupplySpeed = abi.decode(compSupplySpeedReturnData, (uint));
        }

        uint compBorrowSpeed = 0;
        (bool compBorrowSpeedSuccess, bytes memory compBorrowSpeedReturnData) =
            address(comptroller).call(
                abi.encodePacked(
                    comptroller.compBorrowSpeeds.selector,
                    abi.encode(address(cToken))
                )
            );
        if (compBorrowSpeedSuccess) {
            compBorrowSpeed = abi.decode(compBorrowSpeedReturnData, (uint));
        }

        // If the split comp speeds call doesn't work, try the  oldest non-spit version.
        if (!compSupplySpeedSuccess || !compBorrowSpeedSuccess) {
            (bool compSpeedSuccess, bytes memory compSpeedReturnData) =
            address(comptroller).call(
                abi.encodePacked(
                    comptroller.compSpeeds.selector,
                    abi.encode(address(cToken))
                )
            );
            if (compSpeedSuccess) {
                compSupplySpeed = compBorrowSpeed = abi.decode(compSpeedReturnData, (uint));
            }
        }
        return (compSupplySpeed, compBorrowSpeed);
    }
    struct CompMarketState {
        uint224 index;
        uint32 block;
    }


    function cTokenMetadata(CToken cToken) public returns (CTokenMetadata memory) {
        uint exchangeRateCurrent = cToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(cToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(cToken.symbol(), "kETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            CErc20Interface cErc20 = CErc20Interface(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        (uint compSupplySpeed, uint compBorrowSpeed) = getCompSpeeds(comptroller, cToken);

        uint borrowCap = 0;
        (bool borrowCapSuccess, bytes memory borrowCapReturnData) =
            address(comptroller).call(
                abi.encodePacked(
                    comptroller.borrowCaps.selector,
                    abi.encode(address(cToken))
                )
            );
        if (borrowCapSuccess) {
            borrowCap = abi.decode(borrowCapReturnData, (uint));
        }
        uint compSupplySpeedPerBlock = comptroller.compSupplySpeeds(address(cToken));
        uint compBorrowSpeedPerBlock = comptroller.compBorrowSpeeds(address(cToken));
        return CTokenMetadata({
            cToken: address(cToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals,
            compSupplySpeed: compSupplySpeed,
            compBorrowSpeed: compBorrowSpeed,
            borrowCap: borrowCap,
            dailySupplyComp:compSupplySpeedPerBlock * BLOCKS_PER_DAY,
            dailyBorrowComp: compBorrowSpeedPerBlock * BLOCKS_PER_DAY
        });
    }

    function cTokenMetadataAll(CToken[] calldata cTokens) external returns (CTokenMetadata[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenMetadata[] memory res = new CTokenMetadata[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(cTokens[i]);
        }
        return res;
    }

    struct CTokenBalances {
        address cToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function cTokenBalances(CToken cToken, address payable account) public returns (CTokenBalances memory) {
        uint balanceOf = cToken.balanceOf(account);
        uint borrowBalanceCurrent = cToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = cToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(cToken.symbol(), "kETH")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            CErc20Interface cErc20 = CErc20Interface(address(cToken));
            EIP20Interface underlying = EIP20Interface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(cToken));
        }

        return CTokenBalances({
            cToken: address(cToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function buildCTokenAllData(CToken cToken) public returns (CTokenAllData memory) {
        uint exchangeRateCurrent = cToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(cToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(cToken.symbol(), "KETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            CErc20Interface cErc20 = CErc20Interface(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        (uint compSupplySpeed, uint compBorrowSpeed) = getCompSpeeds(comptroller, cToken);

        uint borrowCap = 0;
        (bool borrowCapSuccess, bytes memory borrowCapReturnData) =
            address(comptroller).call(
                abi.encodePacked(
                    comptroller.borrowCaps.selector,
                    abi.encode(address(cToken))
                )
            );
        if (borrowCapSuccess) {
            borrowCap = abi.decode(borrowCapReturnData, (uint));
        }

        PriceOracle priceOracle = comptroller.oracle();
        uint compSupplySpeedPerBlock = comptroller.compSupplySpeeds(address(cToken));
        uint compBorrowSpeedPerBlock = comptroller.compBorrowSpeeds(address(cToken));

        return CTokenAllData({
            cToken: address(cToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals,
            compSupplySpeed: compSupplySpeed,
            compBorrowSpeed: compBorrowSpeed,
            borrowCap: borrowCap,
            mintGuardianPaused: comptroller.mintGuardianPaused(address(cToken)),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken),
            dailySupplyComp:compSupplySpeedPerBlock * BLOCKS_PER_DAY,
            dailyBorrowComp: compBorrowSpeedPerBlock * BLOCKS_PER_DAY,
            symbol:cToken.symbol()
        });
    }

    function cTokenBalancesAll(CToken[] calldata cTokens, address payable account) external returns (CTokenBalances[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenBalances[] memory res = new CTokenBalances[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenBalances(cTokens[i], account);
        }
        return res;
    }

    struct CTokenUnderlyingPrice {
        address cToken;
        uint underlyingPrice;
    }

    function queryAllNoAccount(CToken[] calldata cTokens) external returns (NoAccountAllData memory) {
        uint cTokenCount = cTokens.length;
        CTokenAllData[] memory cTokensRes = new CTokenAllData[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            cTokensRes[i] = buildCTokenAllData(cTokens[i]);
        }

        uint liquidationIncentive = 0;
        uint closeFactor = 0;
        if(cTokenCount > 0) {
            ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cTokens[0].comptroller()));
            liquidationIncentive = comptroller.liquidationIncentiveMantissa();
            closeFactor = comptroller.closeFactorMantissa();
        }

        return NoAccountAllData({
            closeFactorMantissa: closeFactor,
            liquidationIncentiveMantissa: liquidationIncentive,
            cTokens: cTokensRes
        });
    }

    function cTokenUnderlyingPrice(CToken cToken) public returns (CTokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return CTokenUnderlyingPrice({
            cToken: address(cToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken)
        });
    }

    function cTokenUnderlyingPriceAll(CToken[] calldata cTokens) external returns (CTokenUnderlyingPrice[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenUnderlyingPrice[] memory res = new CTokenUnderlyingPrice[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(cTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        CToken[] markets;
        uint liquidity;
        uint shortfall;
    }


    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
            markets: comptroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct GovReceipt {
        uint proposalId;
        bool hasVoted;
        bool support;
        uint96 votes;
    }

  

    struct GovBravoReceipt {
        uint proposalId;
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    function getGovBravoReceipts(GovernorBravoInterface governor, address voter, uint[] memory proposalIds) public view returns (GovBravoReceipt[] memory) {
        uint proposalCount = proposalIds.length;
        GovBravoReceipt[] memory res = new GovBravoReceipt[](proposalCount);
        for (uint i = 0; i < proposalCount; i++) {
            GovernorBravoInterface.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovBravoReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovProposal {
        uint proposalId;
        address proposer;
        uint eta;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        bool canceled;
        bool executed;
    }

    

    struct GovBravoProposal {
        uint proposalId;
        address proposer;
        uint eta;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executed;
    }

    function setBravoProposal(GovBravoProposal memory res, GovernorBravoInterface governor, uint proposalId) internal view {
        GovernorBravoInterface.Proposal memory p = governor.proposals(proposalId);

        res.proposalId = proposalId;
        res.proposer = p.proposer;
        res.eta = p.eta;
        res.startBlock = p.startBlock;
        res.endBlock = p.endBlock;
        res.forVotes = p.forVotes;
        res.againstVotes = p.againstVotes;
        res.abstainVotes = p.abstainVotes;
        res.canceled = p.canceled;
        res.executed = p.executed;
    }

    function getGovBravoProposals(GovernorBravoInterface governor, uint[] calldata proposalIds) external view returns (GovBravoProposal[] memory) {
        GovBravoProposal[] memory res = new GovBravoProposal[](proposalIds.length);
        for (uint i = 0; i < proposalIds.length; i++) {
            (
                address[] memory targets,
                uint[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas
            ) = governor.getActions(proposalIds[i]);
            res[i] = GovBravoProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                abstainVotes: 0,
                canceled: false,
                executed: false
            });
            setBravoProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct CompBalanceMetadata {
        uint balance;
        uint votes;
        address delegate;
    }

    function getCompBalanceMetadata(CompInterface comp, address account) external view returns (CompBalanceMetadata memory) {
        return CompBalanceMetadata({
            balance: comp.balanceOf(account),
            votes: uint256(comp.getCurrentVotes(account)),
            delegate: comp.delegates(account)
        });
    }

    struct CompBalanceMetadataExt {
        uint balance;
        uint votes;
        address delegate;
        uint allocated;
    }

    function getCompBalanceMetadataExt(CompInterface comp, ComptrollerLensInterface comptroller, address account) external returns (CompBalanceMetadataExt memory) {
        uint balance = comp.balanceOf(account);
        comptroller.claimComp(account);
        uint newBalance = comp.balanceOf(account);
        uint accrued = comptroller.compAccrued(account);
        uint total = add(accrued, newBalance, "sum comp total");
        uint allocated = sub(total, balance, "sub allocated");

        return CompBalanceMetadataExt({
            balance: balance,
            votes: uint256(comp.getCurrentVotes(account)),
            delegate: comp.delegates(account),
            allocated: allocated
        });
    }

    struct CompVotes {
        uint blockNumber;
        uint votes;
    }

    function getCompVotes(CompInterface comp, address account, uint32[] calldata blockNumbers) external view returns (CompVotes[] memory) {
        CompVotes[] memory res = new CompVotes[](blockNumbers.length);
        for (uint i = 0; i < blockNumbers.length; i++) {
            res[i] = CompVotes({
                blockNumber: uint256(blockNumbers[i]),
                votes: uint256(comp.getPriorVotes(account, blockNumbers[i]))
            });
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }

    function queryAllWithAccount(CToken[] calldata cTokens, address payable account, CompInterface comp, address capFactory) external returns (AccountAllData memory) {
        uint cTokenCount = cTokens.length;
        CTokenAllDataWithAccount[] memory cTokensRes = new CTokenAllDataWithAccount[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            CTokenAllData memory cTokenAllData = buildCTokenAllData(cTokens[i]);
            CTokenBalances memory cTokenBalance = cTokenBalances(cTokens[i], account);
            
            cTokensRes[i] = CTokenAllDataWithAccount({
                cToken: cTokenAllData.cToken,
                exchangeRateCurrent: cTokenAllData.exchangeRateCurrent,
                supplyRatePerBlock: cTokenAllData.supplyRatePerBlock,
                borrowRatePerBlock: cTokenAllData.borrowRatePerBlock,
                reserveFactorMantissa: cTokenAllData.reserveFactorMantissa,
                totalBorrows: cTokenAllData.totalBorrows,
                totalReserves: cTokenAllData.totalReserves,
                totalSupply: cTokenAllData.totalSupply,
                totalCash: cTokenAllData.totalCash,
                isListed: cTokenAllData.isListed,
                collateralFactorMantissa: cTokenAllData.collateralFactorMantissa,
                underlyingAssetAddress: cTokenAllData.underlyingAssetAddress,
                cTokenDecimals: cTokenAllData.cTokenDecimals,
                underlyingDecimals: cTokenAllData.underlyingDecimals,
                compSupplySpeed: cTokenAllData.compSupplySpeed,
                compBorrowSpeed: cTokenAllData.compBorrowSpeed,
                borrowCap: cTokenAllData.borrowCap,
                mintGuardianPaused: cTokenAllData.mintGuardianPaused,
                underlyingPrice: cTokenAllData.underlyingPrice,
                balanceOf: cTokenBalance.balanceOf,
                borrowBalanceCurrent: cTokenBalance.borrowBalanceCurrent,
                balanceOfUnderlying: cTokenBalance.balanceOfUnderlying,
                tokenBalance: cTokenBalance.tokenBalance,
                tokenAllowance: cTokenBalance.tokenAllowance,
                dailySupplyComp: cTokenAllData.dailySupplyComp,
                dailyBorrowComp: cTokenAllData.dailyBorrowComp,
                symbol:cTokenAllData.symbol
            });
        }

        uint liquidationIncentive = 0;
        uint closeFactor = 0;

        CToken[] memory accountMarketsIn;
        uint liquidity = 0;
        uint shortfall = 0;

        uint compBalance = 0;
        uint compVotes = 0;
        address compDelegate;
        uint compAllocated = 0;

        uint capFactoryAllowance = 0;
        if(cTokenCount > 0) {
            ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cTokens[0].comptroller()));
            liquidationIncentive = comptroller.liquidationIncentiveMantissa();
            closeFactor = comptroller.closeFactorMantissa();

            AccountLimits memory accountLimits = getAccountLimits(comptroller, account);
            accountMarketsIn = accountLimits.markets;
            liquidity = accountLimits.liquidity;
            shortfall = accountLimits.shortfall;

            // CompBalanceMetadataExt memory compMetadata = this.getCompBalanceMetadataExt(comp, comptroller, account);
            CompBalanceMetadataExt memory compMetadata = this.getCompBalanceMetadataExt(CompInterface(address(comp)), comptroller, account);
            compBalance = compMetadata.balance;
            compVotes = compMetadata.votes;
            compDelegate = compMetadata.delegate;
            compAllocated = compMetadata.allocated;

            EIP20Interface compEIP20 = EIP20Interface(address(comp));
            capFactoryAllowance = compEIP20.allowance(account, capFactory);
        }

        return AccountAllData({
            closeFactorMantissa: closeFactor,
            liquidationIncentiveMantissa: liquidationIncentive,
            marketsIn: accountMarketsIn,
            liquidity: liquidity,
            shortfall: shortfall,
            compMetadata: CompBalanceMetadataExt({
                balance: compBalance,
                votes: compVotes,
                delegate: compDelegate,
                allocated: compAllocated
            }),
            capFactoryAllowance: capFactoryAllowance,
            cTokens: cTokensRes
        });
    }
    struct Exp {
        uint mantissa;
    }
     mapping(address => CompMarketState) public compSupplyState;
     mapping(address => mapping(address => uint)) public compSupplierIndex;
     
    uint224 public constant compInitialIndex = 1e36;
    
    function pendingRewards(
        address holder,
        ComptrollerLensInterface comptroller
    ) external  returns (RewardSummary memory) {
        CToken[] memory cTokens = comptroller.getAllMarkets();
        // ClaimVenusLocalVariables memory vars;
        RewardSummary memory rewardSummary;
        rewardSummary.distributorAddress = address(comptroller);
        rewardSummary.rewardTokenAddress = comptroller.getCompAddress();
       
        CompBalanceMetadataExt memory compMetadata = this.getCompBalanceMetadataExt(CompInterface(address(comptroller.getCompAddress())), comptroller, holder);
        rewardSummary.totalRewards = compMetadata.allocated;
        rewardSummary.pendingRewards = new PendingReward[](cTokens.length);
        
        return rewardSummary;
    }
}
