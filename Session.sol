// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface Oracle {
    function getTokenPrice(address _token) external view returns (uint256);
}

// todo: make it into upgradeable
contract SessionContract is Ownable {
   struct Session {
        address creator;
        uint256 blockTimestamp;
        uint256 totalTokens;
        address winner;
        uint256 highestPrice;
        mapping(address => bool) acceptedTokens;
        mapping(address => uint256) tokenPrices;
        mapping(address => mapping(uint256 => uint256)) sessionBalances;
    }

    mapping(uint256 => Session) public sessions;
     address[] public acceptedTokensArray; // Array to track accepted tokens
    mapping(address => bool) public acceptedTokens;
    mapping(address => address) public oracles;
    uint256 private sessionId;
    mapping(uint256 => address) public sessionWinners;
    mapping(uint256 => address) public sessionHosts;

    event SessionCreated(uint256 sessionId, address creator, uint256 blockTimestamp);
    event TokensDeposited(uint256 sessionId, address sender, address token, uint256 amount);
    event SessionEnded(uint256 sessionId, address host, address winner, uint256 hostReward, uint256 winnerReward);
    event AcceptedTokenChanged(address token, bool isAccepted);
    event OracleChanged(address token, address oracle);


    constructor() {
        sessionId = 0;
        // owner = msg.sender;
    }

    function createSession() external {
        sessionId++;
        sessions[sessionId].creator = msg.sender;
        sessions[sessionId].blockTimestamp = block.timestamp;
        emit SessionCreated(sessionId, msg.sender, block.timestamp);
    }

    function depositTokens(uint256 _sessionId, address _token, uint256 _amount) external payable {
        require(_sessionId <= sessionId, "Invalid session ID");
        Session storage session = sessions[_sessionId];
        require(session.creator != address(0), "Session does not exist");
        require(acceptedTokens[_token], "Token not accepted");

        address oracleAddress = oracles[_token];
        require(oracleAddress != address(0), "Oracle not set for token");

        uint256 tokenPrice = Oracle(oracleAddress).getTokenPrice(_token);
        require(tokenPrice > 0, "Token price not set");

        // Transfer ERC20 tokens
        if (_token != address(0)) {
            IERC20 erc20 = IERC20(_token);
            require(erc20.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        } else {
            // Native Ether transfer
            require(msg.value == _amount, "Invalid amount");
        }
        // Update token balance for the session
        session.sessionBalances[_token][_sessionId] += _amount;

        // Update total tokens for the session
        session.totalTokens += _amount;

        // Check if sender is potential winner
        if (_amount * tokenPrice > session.highestPrice) {
            session.winner = msg.sender;
            session.highestPrice = _amount * tokenPrice;
        }

        emit TokensDeposited(_sessionId, msg.sender, _token, _amount);
    }

    function endSession(uint256 _sessionId) external {
        require(_sessionId <= sessionId, "Invalid session ID");
        Session storage session = sessions[_sessionId];
        require(session.creator != address(0), "Session does not exist");
        require(session.creator == msg.sender, "Only the session creator can end the session");

        uint256 totalTokens = session.totalTokens;
        require(totalTokens > 0, "No tokens deposited in the session");

        uint256 hostReward = (totalTokens * 70) / 100;
        uint256 winnerReward = totalTokens - hostReward;

            // Transfer ERC20 tokens
        for (uint256 i = 0; i < acceptedTokensArray.length; i++) {
            address token = acceptedTokensArray[i];
            uint256 tokenBalance = session.sessionBalances[token][_sessionId];
            if (token != address(0) && tokenBalance > 0) {
                IERC20 erc20 = IERC20(token);
                require(erc20.transfer(session.creator, (hostReward * tokenBalance) / totalTokens), "Token transfer failed");
                require(erc20.transfer(session.winner, (winnerReward * tokenBalance) / totalTokens), "Token transfer failed");
            }
        }

        // Transfer native Ether
        uint256 etherBalance = session.sessionBalances[address(0)][_sessionId];
        if (etherBalance > 0) {
            payable(session.creator).transfer((hostReward * etherBalance) / totalTokens);
            payable(session.winner).transfer((winnerReward * etherBalance) / totalTokens);
        }

        emit SessionEnded(_sessionId, session.creator, session.winner, hostReward, winnerReward);

        // Clean up the session data
        delete sessions[_sessionId];
    }

    function getSessionBalance(uint256 _sessionId) external view returns (address[] memory tokens, uint256[] memory balances) {
        Session storage session = sessions[_sessionId];
        tokens = new address[](acceptedTokensArray.length);
        balances = new uint256[](acceptedTokensArray.length);

        for (uint256 i = 0; i < acceptedTokensArray.length; i++) {
            address token = acceptedTokensArray[i];
            tokens[i] = token;
            balances[i] = session.sessionBalances[token][_sessionId];
        }
    }


    function setAcceptedToken(address _token, bool _isAccepted) external onlyOwner {
        acceptedTokens[_token] = _isAccepted;
        emit AcceptedTokenChanged(_token, _isAccepted);

        // Update acceptedTokensArray
        if (_isAccepted) {
            acceptedTokensArray.push(_token);
        } else {
            // Remove token from acceptedTokensArray
            for (uint256 i = 0; i < acceptedTokensArray.length; i++) {
                if (acceptedTokensArray[i] == _token) {
                    acceptedTokensArray[i] = acceptedTokensArray[acceptedTokensArray.length - 1];
                    acceptedTokensArray.pop();
                    break;
                }
            }
        }
    }

    function setOracle(address _token, address _oracle) external onlyOwner {
        oracles[_token] = _oracle;
        emit OracleChanged(_token, _oracle);
    }

       
}