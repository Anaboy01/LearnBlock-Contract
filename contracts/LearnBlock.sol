// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract EduTechQuiz is ERC721Enumerable {
    uint256 public nextContentId;
    uint256 public nextUserId;
    uint256 public nextBadgeId;

    address[] public trustees;
    mapping(address => bool) public isTrustee;

    struct QuizQuestion {
        string question;
        string[] options;
        uint256 correctAnswerIndex;
    }

    struct Content {
        string title;
        string body;
        string[] sources;
        QuizQuestion[] quizQuestions;
        uint256 pointReward;
        bool exists;
    }

    struct UserProfile {
        uint256 userId;
        uint256 articlesRead;
        uint256 quizzesTaken;
        uint256 totalPointsEarned;
        uint256 totalPointsRedeemed;
        uint256 badges;
        bool goldenBadgeClaimed;
    }

    mapping(uint256 => Content) public contents;
    mapping(address => UserProfile) public profiles;
    mapping(address => mapping(uint256 => bool)) public hasCompleted;

    event ContentRegistered(uint256 indexed contentId);
    event ArticleRead(address indexed user, uint256 indexed contentId);
    event QuizTaken(address indexed user, uint256 indexed contentId, uint256 points);
    event BadgeMinted(address indexed user, uint256 badgeId, bool isGolden);
    event XFIRewardClaimed(address indexed user, uint256 amount);

    modifier onlyTrustee() {
        require(isTrustee[msg.sender], "Not authorized");
        _;
    }

    constructor(address[] memory _trustees) ERC721("EduTechBadge", "ETB") {
        require(_trustees.length > 0, "At least one trustee required");
        for (uint256 i = 0; i < _trustees.length; i++) {
            address trustee = _trustees[i];
            require(trustee != address(0), "Invalid trustee");
            require(!isTrustee[trustee], "Duplicate trustee");
            isTrustee[trustee] = true;
            trustees.push(trustee);
        }
        nextContentId = 1;
        nextUserId = 1;
        nextBadgeId = 1;
    }

    receive() external payable {}

    /* ========== CONTENT OPERATIONS ========== */

    function registerContent(
        string memory title,
        string memory body,
        string[] memory sources,
        uint256 pointReward
    ) external onlyTrustee {
        uint256 cid = nextContentId;
        Content storage c = contents[cid];
        c.title = title;
        c.body = body;
        c.sources = sources;
        c.pointReward = pointReward;
        c.exists = true;

        emit ContentRegistered(cid);
        nextContentId++;
    }

    function addQuizQuestion(
        uint256 contentId,
        string memory question,
        string[] memory options,
        uint256 correctAnswerIndex
    ) external onlyTrustee {
        require(contents[contentId].exists, "Content not found");
        require(correctAnswerIndex < options.length, "Invalid answer index");

        contents[contentId].quizQuestions.push(QuizQuestion({
            question: question,
            options: options,
            correctAnswerIndex: correctAnswerIndex
        }));
    }

    /* ========== USER OPERATIONS ========== */

    function _ensureRegistered(address user) internal {
        if (profiles[user].userId == 0) {
            profiles[user].userId = nextUserId;
            nextUserId++;
        }
    }

    function readArticle(uint256 contentId) external {
        require(contents[contentId].exists, "Content not found");
        _ensureRegistered(msg.sender);
        UserProfile storage u = profiles[msg.sender];
        u.articlesRead++;
        emit ArticleRead(msg.sender, contentId);
    }

    function takeQuiz(uint256 contentId) external {
        require(contents[contentId].exists, "Content not found");
        _ensureRegistered(msg.sender);
        require(!hasCompleted[msg.sender][contentId], "Already completed");

        UserProfile storage u = profiles[msg.sender];
        Content storage c = contents[contentId];

        u.quizzesTaken++;
        u.totalPointsEarned += c.pointReward;
        hasCompleted[msg.sender][contentId] = true;

        emit QuizTaken(msg.sender, contentId, c.pointReward);
        _checkBadgeMint(msg.sender);
    }

    /* ========== BADGE OPERATIONS ========== */

    function _checkBadgeMint(address user) internal {
        UserProfile storage u = profiles[user];
        uint256 totalBadgesEarned = u.totalPointsEarned / 500;

        while (u.badges < totalBadgesEarned) {
            bool isGolden = false;
            u.badges++;

            if (u.badges == 5 && !u.goldenBadgeClaimed) {
                isGolden = true;
                u.goldenBadgeClaimed = true;
            }

            uint256 badgeId = nextBadgeId;
            nextBadgeId++;
            _safeMint(user, badgeId);

            emit BadgeMinted(user, badgeId, isGolden);
        }
    }

    /* ========== REWARD CLAIM ========== */

    function claimXFIReward() external {
        UserProfile storage u = profiles[msg.sender];

        uint256 unredeemedPoints = u.totalPointsEarned - u.totalPointsRedeemed;
        require(unredeemedPoints > 0, "No points to redeem");

        uint256 reward = unredeemedPoints * 1e17; // 0.1 XFI per point
        require(address(this).balance >= reward, "Insufficient contract balance");

        u.totalPointsRedeemed += unredeemedPoints;

        (bool sent, ) = payable(msg.sender).call{value: reward}("");
        require(sent, "Failed to send XFI");

        emit XFIRewardClaimed(msg.sender, reward);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getContent(uint256 contentId)
        external
        view
        returns (
            string memory title,
            string memory body,
            string[] memory sources,
            uint256 pointReward
        )
    {
        Content storage c = contents[contentId];
        require(c.exists, "Content not found");
        return (c.title, c.body, c.sources, c.pointReward);
    }

    function getQuizQuestions(uint256 contentId)
        external
        view
        returns (
            string[] memory questions,
            string[][] memory options,
            uint256[] memory correctIndexes
        )
    {
        Content storage c = contents[contentId];
        require(c.exists, "Content not found");

        uint256 len = c.quizQuestions.length;
        questions = new string[](len);
        options = new string[][](len);
        correctIndexes = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            QuizQuestion storage q = c.quizQuestions[i];
            questions[i] = q.question;
            options[i] = q.options;
            correctIndexes[i] = q.correctAnswerIndex;
        }
    }

    function getUserProfile(address user)
        external
        view
        returns (
            uint256 userId,
            uint256 articlesRead,
            uint256 quizzesTaken,
            uint256 totalPointsEarned,
            uint256 totalPointsRedeemed,
            uint256 unredeemedPoints,
            uint256 badges,
            bool goldenBadgeClaimed
        )
    {
        UserProfile storage u = profiles[user];
        require(u.userId != 0, "User not registered");
        return (
            u.userId,
            u.articlesRead,
            u.quizzesTaken,
            u.totalPointsEarned,
            u.totalPointsRedeemed,
            u.totalPointsEarned - u.totalPointsRedeemed,
            u.badges,
            u.goldenBadgeClaimed
        );
    }

    function getAllContentIds() external view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](nextContentId - 1);
        for (uint256 i = 1; i < nextContentId; i++) {
            ids[i - 1] = i;
        }
        return ids;
    }

    function getUserCompletedContent(address user) external view returns (bool[] memory) {
        uint256 total = nextContentId - 1;
        bool[] memory completed = new bool[](total);
        for (uint256 i = 1; i <= total; i++) {
            completed[i - 1] = hasCompleted[user][i];
        }
        return completed;
    }

    function getUnredeemedPoints(address user) external view returns (uint256) {
        UserProfile storage u = profiles[user];
        return u.totalPointsEarned - u.totalPointsRedeemed;
    }

    function getUserBadgeIds(address user) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory ids = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            ids[i] = tokenOfOwnerByIndex(user, i);
        }
        return ids;
    }

    function isUserRegistered(address user) external view returns (bool) {
        return profiles[user].userId != 0;
    }

    function getTrustees() external view returns (address[] memory) {
        return trustees;
    }
}
