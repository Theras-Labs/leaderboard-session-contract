// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Oracle {
    function getTokenPrice(address _token) external view returns (uint256);
}

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
        bool completed; // Flag to indicate if the session is completed
        // uint256 totalTxs;
        address[] totalViewers;
        uint256 totalPool;
    }

    mapping(uint256 => Session) public sessions;
    address[] public acceptedTokensArray; // Array to track accepted tokens
    mapping(address => bool) public acceptedTokens;
    mapping(address => address) public oracles;
    uint256 private sessionId;
    // mapping(uint256 => address) public sessionWinners;
    mapping(address => uint256) public sessionHosts;

    event SessionCreated(uint256 sessionId, address creator, uint256 blockTimestamp);
    event TokensDeposited(uint256 sessionId, address sender, address token, uint256 amount);
    event SessionCompleted(uint256 sessionId, address host, address winner,  uint256 hostRewardValue, uint256 winnerRewardValue );
        // emit SessionCompleted(_sessionId, msg.sender, hostReward, winnerReward);

    event AcceptedTokenChanged(address token, bool isAccepted);
    event OracleChanged(address token, address oracle);

    constructor() {
        sessionId = 0;
    }

    function createSession() external {
        require(sessionHosts[msg.sender] == 0, "Host already has an active session");
        // require(sessionHosts[msg.sender] != sessionId, "Host already has an active session");


        sessionId++;
        sessions[sessionId].creator = msg.sender;
        sessions[sessionId].blockTimestamp = block.timestamp;
        sessionHosts[msg.sender] = sessionId;

        emit SessionCreated(sessionId, msg.sender, block.timestamp);
    }


    function addViewer(address _viewer, Session storage session) internal {
        // Assuming you have an instance of the Session struct called "session"
        bool duplicateFound = false;
        for (uint256 i = 0; i < session.totalViewers.length; i++) {
            if (session.totalViewers[i] == _viewer) {
                duplicateFound = true;
                break;
            }
        }
        if (!duplicateFound) {
            session.totalViewers.push(_viewer);
        }
    }


    function depositTokens(uint256 _sessionId, address _token, uint256 _amount) external payable {
        require(_sessionId <= sessionId, "Invalid session ID");
        // require(sessionHosts[msg.sender] == _sessionId, "Host does not have an active session");
        Session storage session = sessions[_sessionId];
        require(session.completed != true, "Session has ended" );
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

        // update storage of users joining here
        // avoid duplicated viewers
        addViewer(msg.sender,session );


        // update the value of pool
        session.totalPool += (_amount * tokenPrice);


        // Check if sender is potential winner
        if (_amount * tokenPrice > session.highestPrice) {
            session.winner = msg.sender;
            session.highestPrice = _amount * tokenPrice;
        }

        emit TokensDeposited(_sessionId, msg.sender, _token, _amount);
    }



    function completeSession(uint256 _sessionId) external {
        require(_sessionId <= sessionId, "Invalid session ID");
        require(sessionHosts[msg.sender] == _sessionId, "Host does not have an active session");
        Session storage session = sessions[_sessionId];
        require(session.creator != address(0), "Session does not exist");
        require(session.totalTokens > 0, "No tokens deposited in the session");


        uint256 totalTokens = session.totalTokens;
        uint256 hostReward = (totalTokens * 70) / 100;
        uint256 winnerReward = totalTokens - hostReward;


        uint256 totalPoolValue = session.totalPool;
        uint256 hostRewardValue = (totalPoolValue * 70) / 100;
        uint256 winnerRewardValue = totalPoolValue - hostRewardValue;


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
        // make it require or not?
        uint256 etherBalance = session.sessionBalances[address(0)][_sessionId];
        if (etherBalance > 0) {
            payable(session.creator).transfer((hostReward * etherBalance) / totalTokens);
            payable(session.winner).transfer((winnerReward * etherBalance) / totalTokens);
        }
        

        session.completed = true;
        sessionHosts[msg.sender] = 0;

        emit SessionCompleted(_sessionId, msg.sender, session.winner,  hostRewardValue, winnerRewardValue);

        // event SessionCompleted(uint256 sessionId, address host, address winner,  uint256 hostRewardValue, uint256 winnerRewardValue );
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

    function getAcceptedTokens() external view returns (address[] memory) {
        return acceptedTokensArray;
    }

    //wrong
    function getTotalUsers(uint256 _sessionId) external view returns (uint256) {
        Session storage session = sessions[_sessionId];
        return session.totalTokens;
    }

    function getLeaderboard(uint256 _sessionId) external view returns (address[] memory, uint256[] memory) {
        require(_sessionId <= sessionId, "Invalid session ID");
        Session storage session = sessions[_sessionId];
        address[] memory leaderboard = new address[](5);
        uint256[] memory leaderboardBalances = new uint256[](5);

        for (uint256 i = 0; i < acceptedTokensArray.length; i++) {
            address token = acceptedTokensArray[i];
            uint256 tokenBalance = session.sessionBalances[token][_sessionId];

            for (uint256 j = 0; j < 5; j++) {
                if (tokenBalance > leaderboardBalances[j]) {
                    for (uint256 k = 4; k > j; k--) {
                        leaderboard[k] = leaderboard[k - 1];
                        leaderboardBalances[k] = leaderboardBalances[k - 1];
                    }
                    leaderboard[j] = session.winner;
                    leaderboardBalances[j] = tokenBalance;
                    break;
                }
            }
        }

        return (leaderboard, leaderboardBalances);
    }

    function getActiveSessions() external view returns (uint256[] memory) {
        uint256[] memory activeSessions = new uint256[](sessionId);
        uint256 counter = 0;

        for (uint256 i = 1; i <= sessionId; i++) {
            if (sessions[i].creator != address(0) && !sessions[i].completed) {
                activeSessions[counter] = i;
                counter++;
            }
        }

        return activeSessions;
    }

    function getActiveSessionByHost(address _host) external view returns (uint256) {
        return sessionHosts[_host];
    }

    function getCompletedSessionsByHost(address _host) external view returns (uint256[] memory) {
        uint256[] memory completedSessions = new uint256[](sessionId);
        uint256 counter = 0;

        for (uint256 i = 1; i <= sessionId; i++) {
            if (sessions[i].creator == _host && sessions[i].completed) {
                completedSessions[counter] = i;
                counter++;
            }
        }

        return completedSessions;
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


    function withdraw() external onlyOwner {
        // Withdraw ERC20 tokens
        for (uint256 i = 0; i < acceptedTokensArray.length; i++) {
            address token = acceptedTokensArray[i];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            if (tokenBalance > 0) {
                require(IERC20(token).transfer(owner(), tokenBalance), "Token transfer failed");
            }
        }

        // Withdraw Ether
        uint256 etherBalance = address(this).balance;
        if (etherBalance > 0) {
            payable(owner()).transfer(etherBalance);
        }
    }

}
