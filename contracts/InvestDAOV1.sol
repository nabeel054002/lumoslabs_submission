//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

contract MutualFundV2 is ERC20Burnable, Ownable, AutomationCompatibleInterface{
    uint public interval;
    struct propsl{
        address deadlineToken;
        uint deadlineTime;
    }
    propsl[] public deadline;
    uint public deadline_size=0;

    uint public recentTime;

    address public recentAddress;

    uint256 constant price = 0.01 ether;

    IUniswapV2Router01 uniswap;

    address[] public users;
    mapping (address=>uint256) public balances;

    cryptoBought[5] public Portfolio;
    uint8 public number=0;
    struct cryptoBought{
        address tokenAddress;
        string tokenName;
        uint8 decimals;
        uint256 timeBought;
    }
    struct Proposal{
        address tokenAddress;
        string tokenName;
        uint8 decimals;
        uint256 peopleForYes;
        uint256 peopleForNay;
        uint256 votesForYes;
        uint256 votesForNo;
        mapping(address => uint256) voters;
        //mapping for address of voter to number of tokens he used to vote
        //if final score is positive we buy, else we dont.
    }
    enum Vote{
        Bullish,
        Bearish
    }
    mapping(address=>Proposal) public proposals;
    constructor(address _uniswap, uint updateInterval) ERC20("FundToken","FD"){
        uniswap = IUniswapV2Router01(_uniswap);
        recentTime = block.timestamp;
        interval = 7*updateInterval;
    }

    function takePart() payable public{
        require(balances[msg.sender]*10 + msg.value>=price, "atleast 0.1 ether worth");
        //msg.value/price is not gonna give an accurate way to have fractional tokens
        if(balances[msg.sender]==0){
            users.push(msg.sender);
        }
        balances[msg.sender] += msg.value/price;
        _mint(msg.sender, msg.value/price);

    }

    function createProposal(address _tokenAddress, string calldata _tokenName, uint8 _decimals) public payable{
        require(msg.value>=0.001 ether, "feestoadd = 0.1 ether");
        Proposal storage proposal = proposals[_tokenAddress];
        proposal.tokenAddress = _tokenAddress;
        proposal.decimals = _decimals;
        proposal.peopleForYes=1;
        proposal.tokenName = _tokenName;
        proposal.peopleForNay = 0;
        proposal.votesForYes = balances[msg.sender];
        proposal.votesForNo = 0;
        proposal.voters[msg.sender] = balances[msg.sender];
        recentTime = block.timestamp;
        recentAddress = proposal.tokenAddress;
        deadline.push(propsl(recentAddress, recentTime));
        deadline_size+=1;
        
    }

    function voteOnProposal(address _tokenAddress, Vote vote)public {
        require(proposals[_tokenAddress].voters[msg.sender] < balances[msg.sender], "user already voted");
        if(vote==Vote.Bullish){
            proposals[_tokenAddress].peopleForYes+=1;
            proposals[_tokenAddress].votesForYes += (balances[msg.sender] - proposals[_tokenAddress].voters[msg.sender]);
            proposals[_tokenAddress].voters[msg.sender] = balances[msg.sender];
        }
        if(vote==Vote.Bearish){
            //assuming their vote remains the same even after extra minting
            proposals[_tokenAddress].peopleForNay+=1;
            proposals[_tokenAddress].votesForNo += (balances[msg.sender] - proposals[_tokenAddress].voters[msg.sender]);
            proposals[_tokenAddress].voters[msg.sender] = balances[msg.sender];
        }
        //can be greater since the individual can liquidate ownership.
    }

    function executeProposal (address tokenAddress) public{
        //once the deadline for a proposal is finished, this function is called to see 
        //whether the proposal got acccepted or not
        if(proposals[tokenAddress].votesForYes>proposals[tokenAddress].votesForNo){
            if(number<4){
                //the number of crypto assets is still less than 5
                for(uint8 i=0; i<number; i++){
                    address token = Portfolio[i].tokenAddress;
                    uint256 amountIn = (ERC20(token).balanceOf(address(this))*number)/(number+1);
                    address[] memory path = new address[](2);
                    path[0] = token;
                    path[1] = tokenAddress;
                    uniswap.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
                    //do note the above functino is not secure towards price manipulation and should not be used for production.
                }
                cryptoBought storage crypto = Portfolio[number+1];
                crypto.tokenAddress = tokenAddress;
                crypto.tokenName = proposals[tokenAddress].tokenName;
                crypto.decimals = proposals[tokenAddress].decimals;
                crypto.timeBought = block.timestamp;
                number++; 
                //to take care of the eth that is left idle, which we got from more members joining, since the last function call 
                uint256 toBuyAmount = (address(this).balance)/number;
                for(uint8 i=0; i<number; i++){
                    address[] memory path = new address[](2);
                    path[0] = uniswap.WETH();
                    path[1] = Portfolio[i].tokenAddress;
                    uniswap.swapETHForExactTokens{value:toBuyAmount}(0,path, address(this), block.timestamp);
                    
                }
            } else{
                //the number of crypto assets is 5
                // at any time we can only have 5 assets
                //when we want to add a new proposal, we remove the oldest crypto 
                //from our portfolio and simply replace the same funds for the new crypto
                address[] memory path = new address[](2);
                cryptoBought storage crypto = Portfolio[number%5];
                number++;
                path[0] = crypto.tokenAddress;
                path[1] = tokenAddress;
                uniswap.swapExactTokensForTokens(ERC20(crypto.tokenAddress).balanceOf(address(this)), 0, path, address(this), block.timestamp);
                crypto.tokenAddress = tokenAddress;
                crypto.tokenName = proposals[tokenAddress].tokenName;
                crypto.decimals = proposals[tokenAddress].decimals;
                crypto.timeBought = block.timestamp;
                number++;
                uint256 toBuyAmount = (address(this).balance)/5;
                //we also have to take care of the eth that we got through more members joining in, since the last function call
                for(uint8 i=0; i<5; i++){
                    //dispensing of eth resting idle in this contract, can use chainlink keepers to do this as well...
                    //address[] memory path_t = new address[](2);
                    path[0] = uniswap.WETH();
                    path[1] = Portfolio[i].tokenAddress;
                    uniswap.swapETHForExactTokens{value:toBuyAmount}(0,path, address(this), block.timestamp);
                }
            }
        } else{
            delete proposals[tokenAddress];
        }
        
    }
    //the below 2 functions were taken from chainlink keepers, to see the result on a proposal
    //the deadline i have kept is 7 days, i will input days period through the constructor

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - recentTime) > interval;
        
    }
    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - recentTime) > interval ) {
            deadline.pop();
            deadline_size-=1;
            executeProposal(recentAddress);
            recentTime = deadline[deadline.length - 1].deadlineTime;
            recentAddress = deadline[deadline.length - 1].deadlineToken;
        }
        
    }

    function liquidateOwnership(uint256 amountLiquidate) public {
        //function for a member to call when s/he wants to give up part or whole of his ownership
        uint256 balance_user = ERC20(address(this)).balanceOf(msg.sender);
        require(amountLiquidate <= balance_user, "Liquidating more than u hv");
        uint256 total_balance = totalSupply();
        uint256 ratio = (balance_user/total_balance)*(amountLiquidate/balance_user);
        // if(amountLiquidate==balance_user){
        //     delete users[msg.sender];
        // }
        uint256 amountEth = (address(this).balance)*(ratio);
        payable(msg.sender).transfer(amountEth);
        uint8 i;
        uint256 balance;
        //give the part of the portfolio back, in the same tokens that were a part of the portfolio
        for(i=0; i<5; i++){
            balance = ERC20(Portfolio[i].tokenAddress).balanceOf(address(this));
            ERC20(Portfolio[i].tokenAddress).transfer(msg.sender, balance*ratio);
        }
        //burn the tokens for whose worth msg.sender, wants to liquidate his/her stake in this dao
        ERC20Burnable(address(this)).burnFrom(msg.sender, amountLiquidate);
        balances[msg.sender] -= amountLiquidate;
    }
}
//contract address : 0x3f9A1B67F3a3548e0ea5c9eaf43A402d12b6a273