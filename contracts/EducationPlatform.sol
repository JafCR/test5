pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/*
// To use with Remix:
import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/access/Roles.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/Ownable.sol";
*/

contract EducationPlatform is Ownable {

    using Roles for Roles.Role; // We want to use the Roles library
    Roles.Role universityOwners; //Stores University owner Roles
    Roles.Role teachers; // Stores teacher Roles
    Roles.Role students; // Stores student Roles;

    // ID Generators for universities and platform users
    uint public universityIdGenerator;
    uint UserIdGenerator;

    mapping (uint => University) public universities; // Mapping to keep track of the Universities
    mapping (address => PlatformMember) platformUsers; // Mapping to keep track of the Students in the platform

    struct University {
        string name;
        string description;
        string website;
        string phoneNumber;
        bool open;
        uint courseIdGenerator;
        address payable UniversityOwner;
        mapping (uint => Course) courses; //Mappint to track all classes available for this University
    }

    // This structs is to store the information of a Platform member. Has a flag to identify if the member is Owner or not.
    struct PlatformMember {
        string fullName;
        string email;
        uint id;
        bool isUniversityOwner;
    }

    struct Course {
        string courseName;
        uint cost;
        bool active;
        uint activeStudents;
        uint seatsAvailable; //to simulate a student buying multiple seats for a course
        uint totalSeats;
    }


    // Events
    event LogUniversityAdded(string name, string desc, uint universityId);
    event LogCourseAdded(string _courseName, uint cost, uint _seatsAvailable, uint courseId);

    // Modifiers
    modifier validAddress(address _address) {
        require(_address != address(0), "ADDRESS CANNOT BE THE ZERO ADDRESS");
        _;
    }

    modifier isUniversityOwner(address _addr) {
        require(universityOwners.has(_addr), "DOES NOT HAVE UNIVERSITY OWNER ROLE");
        _;
    }

    modifier isStudent(address _addr) {
        require(students.has(_addr), "DOES NOT HAVE STUDENT ROLE");
        _;
    }

    modifier enoughSeats(uint _universityId, uint _courseId, uint _quantity) {
        require((universities[_universityId].courses[_courseId].seatsAvailable >= _quantity), "NOT ENOUGH SEATS IN THIS COURSE - CONTACT UNIVERSITY OWNER");
        _;
    }

    modifier ownerAtUniversity(uint _universityId) {
        require((universities[_universityId].UniversityOwner == msg.sender), "DOES NOT BELONG TO THE UNIVERSITY OWNERS OR IS INACTIVE");
        require(universityOwners.has(msg.sender), "DOES NOT HAVE UNIVERSITY OWNER ROLE");
        _;
    }

    modifier courseIsActive(uint _universityId, uint _courseId) {
        require((universities[_universityId].courses[_courseId].active == true), "COURSE IS INACTIVE - CONTACT UNIVERSITY OWNER");
        _;
    }

    modifier paidEnough(uint _universityId, uint _courseId, uint _quantity)
    {
        uint coursePrice = universities[_universityId].courses[_courseId].cost;
        require((universities[_universityId].courses[_courseId].seatsAvailable >= _quantity), "NOT ENOUGH SEATS IN THIS COURSE - CONTACT UNIVERSITY OWNER");
        require(msg.value >= (coursePrice * _quantity), "NOT ENOUGH FEES PAID");
        _;
    }

    
    modifier checkValue(uint _universityId, uint _courseId, uint _quantity, address payable _addr)  {
    //refund them after pay for item
        _;
        uint coursePrice = universities[_universityId].courses[_courseId].cost * _quantity;
        uint total2RefundAfterPay = msg.value - coursePrice;
        _addr.transfer(total2RefundAfterPay);
    }


    // Add Universities
    function addUniversity(string memory _name, string memory _description, string memory _website, string memory _phoneNumber)
    public onlyOwner
    {
        University memory newUniversity;
        newUniversity.name = _name;
        newUniversity.description = _description;
        newUniversity.website = _website;
        newUniversity.phoneNumber = _phoneNumber;
        newUniversity.open = false;
        universities[universityIdGenerator] = newUniversity;
        universityIdGenerator += 1;

        emit LogUniversityAdded(_name, _description, universityIdGenerator);
    }

    // Add a Course
    function addCourse(uint _universityId, string memory _courseName, uint _cost, uint _seatsAvailable) public
    ownerAtUniversity(_universityId)
    returns (bool)
    {
        Course memory newCourse;
        newCourse.courseName = _courseName;
        newCourse.seatsAvailable = _seatsAvailable;
        newCourse.totalSeats = _seatsAvailable;
        newCourse.cost = _cost;
        newCourse.active = true;
        newCourse.activeStudents = 0;

        uint courseId = universities[_universityId].courseIdGenerator;
        universities[_universityId].courses[courseId] = newCourse;
        universities[_universityId].courseIdGenerator += 1;

        emit LogCourseAdded(_courseName, _cost, _seatsAvailable, courseId);
        return true;
    }


    // Modify a Course
    function updateCourse(uint _universityId, uint _courseId, string memory _courseName, uint _cost, uint _seatsAvailable, bool _isActive)
    public
    ownerAtUniversity(_universityId)
    returns (bool)
    {
        Course memory newCourse;
        newCourse.courseName = _courseName;
        newCourse.seatsAvailable = _seatsAvailable;
        newCourse.totalSeats = _seatsAvailable;
        newCourse.cost = _cost;
        newCourse.active = _isActive;
        universities[_universityId].courses[_courseId] = newCourse;
        return true;
    }


    // Get University details
    function getUniversity(uint _uniId)
    public view
    returns (string memory name, string memory description, string memory website, string memory phone)
    {
        name = universities[_uniId].name;
        website = universities[_uniId].website;
        description = universities[_uniId].description;
        phone = universities[_uniId].phoneNumber;
        return (name, description, website, phone);
    }

    /*
    Roles and membership
    */

    function addUniversityOwner(address payable _ownerAddr, uint _universityId, string memory _name, string memory _email)
    public onlyOwner
    validAddress(_ownerAddr)
    returns (bool)
    {
        PlatformMember memory newPlatformMember;
        newPlatformMember.fullName = _name;
        newPlatformMember.email = _email;
        newPlatformMember.id = UserIdGenerator;
        newPlatformMember.isUniversityOwner = true;
        universityOwners.add(_ownerAddr);

        platformUsers[_ownerAddr] = newPlatformMember;
        UserIdGenerator += 1;

        universities[_universityId].UniversityOwner = _ownerAddr;
        universities[_universityId].open = true;

        return true;
    }


    // Registers a new user into the Platform - Owner or Student
    function addStudent(address _addr, string memory _name, string memory _email) public
    validAddress(_addr)
    returns (bool)
    {
        PlatformMember memory newPlatformMember;
        newPlatformMember.fullName = _name;
        newPlatformMember.email = _email;
        newPlatformMember.id = UserIdGenerator;
        students.add(_addr);
        newPlatformMember.isUniversityOwner = false;

        platformUsers[_addr] = newPlatformMember;
        UserIdGenerator += 1;
        return true;
    }


    /*
    Students specific functions
    - Buy/Pay course
    */

    function buyCourse(uint _uniId, uint _courseId, uint _quantity)
    public payable
    isStudent(msg.sender)
    //enoughSeats(_uniId, _courseId, _quantity) //had to include this modifier into paidEnough to prevent: CompilerError: Stack too deep, try removing local variables.
    paidEnough(_uniId, _courseId, _quantity)
    checkValue(_uniId, _courseId, _quantity, msg.sender)
    {
        //uint totalCoursePrice = universities[_uniId].courses[_courseId].cost * _quantity;
        //universities[_uniId].UniversityOwner.transfer(totalCoursePrice);
        universities[_uniId].courses[_courseId].seatsAvailable -= _quantity;
    }

    function withdrawCourseFunds(uint _uniId, uint _courseId)
    public payable
    ownerAtUniversity(_uniId)
    {
        uint courseBalance = (universities[_uniId].courses[_courseId].totalSeats - universities[_uniId].courses[_courseId].seatsAvailable) * universities[_uniId].courses[_courseId].cost;
        msg.sender.transfer(courseBalance);
        //emit an event
    }

}