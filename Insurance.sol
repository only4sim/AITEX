pragma solidity ^0.5.0;

contract owned {
    address public owner;

    constructor ()  public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner  public {
        owner = newOwner;
    }
}



contract Insurance is owned{
    // Contract Variables and events
    Proposal[] public proposals;
    uint public numProposals;
    mapping (address => uint) public memberId;
    Member[] public members;

    event ProposalAdded(uint proposalID, string description);
    event Voted(uint proposalID, bool position, address voter, string justification);
    event ProposalTallied(uint proposalID, int result, uint quorum, bool active);
    event MembershipChanged(address member, bool isMember);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes, int newMajorityMargin);
    event receivedEther(address sender, uint amount);

    
    struct Proposal {
        uint odds;
        string description;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        int currentResult;
        Vote[] votes;
        mapping (address => bool) voted;
        mapping(address => uint256) balanceOf;
    }

    struct Member {
        address member;
        string name;
        uint memberSince;
    }

    struct Vote {
        bool inSupport;
        address voter;
        string justification;
    }

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyMembers {
        require(memberId[msg.sender] != 0);
        _;
    }

    /**
     * Constructor function
     */
    constructor () public {

        // It necessary to add an empty first member
        addMember(0x0000000000000000000000000000000000000000, "");
        // and let's add the founder, to save a step later
        addMember(owner, 'founder');
    }

    /**
     * Add member
     *
     * Make `targetMember` a member named `memberName`
     *
     * @param targetMember ethereum address to be added
     * @param memberName public name for that member
     */
    function addMember(address targetMember, string memory memberName) onlyOwner public {
        uint id = memberId[targetMember];
        if (id == 0) {
            memberId[targetMember] = members.length;
            id = members.length++;
        }

        members[id] = Member({member: targetMember, memberSince: now, name: memberName});
        emit MembershipChanged(targetMember, true);
    }

    /**
     * Remove member
     *
     * @notice Remove membership from `targetMember`
     *
     * @param targetMember ethereum address to be removed
     */
    function removeMember(address targetMember) onlyOwner public {
        require(memberId[targetMember] != 0);

        for (uint i = memberId[targetMember]; i<members.length-1; i++){
            members[i] = members[i+1];
        }
        delete members[members.length-1];
        members.length--;
    }



    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param jobDescription Description of job
     */
    function newProposal(
        uint insuranceOdds,
        string memory jobDescription
    )
        onlyMembers public
        returns (uint proposalID)
    {
        proposalID = proposals.length++;
        Proposal storage p = proposals[proposalID];
        p.odds = insuranceOdds;
        p.description = jobDescription;
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        emit ProposalAdded(proposalID, jobDescription);
        numProposals = proposalID+1;

        return proposalID;
    }

    /**
     * Add proposal in Ether
     *
     * Propose to send `etherAmount` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     * This is a convenience function to use if the amount to be given is in round number of ether units.
     *
     * @param jobDescription Description of job
     */
    function newProposalInEther(
        uint insuranceOdds,
        string memory jobDescription
    )
        onlyMembers public
        returns (uint proposalID)
    {
        return newProposal(insuranceOdds, jobDescription);
    }

    function changeStateOfProposal(
        bool proposalstate
    )
        onlyMembers public
    {
        Proposal storage p = proposals[proposals.length-1]; // Get the proposal
        p.proposalPassed = proposalstate;
    }



    function () payable external {
        Proposal storage p = proposals[proposals.length-1]; // Get the proposal
        require(!p.voted[msg.sender]);                  // If has already voted, cancel
        p.voted[msg.sender] = true;                     // Set this voter as having voted
        p.numberOfVotes++;                              // Increase the number of votes
        
        uint amount = msg.value;
        p.balanceOf[msg.sender] += amount;
        emit receivedEther(msg.sender, msg.value);
    }
    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalNumber` and execute it if approved
     *
     */
    function executeProposal() public {
        Proposal storage p = proposals[proposals.length-1];

        require(p.proposalPassed == true && !p.executed);
        
        uint256 amount = p.balanceOf[msg.sender];
        p.balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount*p.odds)) {
                } else {
                    p.balanceOf[msg.sender] = amount;
                }
            }
    }
}
